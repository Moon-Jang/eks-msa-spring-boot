#!/usr/bin/env bash
# cert-manager가 발급한 TLS Secret을 백업/복원한다.
#
# 왜 필요한가:
#   Let's Encrypt는 동일 도메인 기준 주당 5개까지만 인증서를 발급해준다.
#   클러스터를 지웠다 만들 때마다 새로 발급받으면 금방 한도에 걸리고,
#   한 번 걸리면 일주일을 기다려야 한다.
#   인증서는 90일짜리이므로, 그 안에 재실습할 거면 백업본을 그대로 넣는 게 맞다.
#
# 사용법:
#   백업 (클러스터 지우기 전!):
#     aws-vault exec <프로필> -- .../tls-backup.sh backup
#   복원 (새 클러스터에 네임스페이스까지 만든 뒤, cert-manager 설치 전에):
#     aws-vault exec <프로필> -- .../tls-backup.sh restore
#   목록:
#     .../tls-backup.sh list
#
# 환경변수: NS(기본 mj-eks), SECRET(기본 server-balance-eat-com-tls),
#           BACKUP_DIR(기본 ~/.ordersystem-eks/tls-backup)
#
# 구현 메모: metadata 정리는 sed가 아니라 jq로 한다.
#   BSD sed(macOS)와 GNU sed는 범위+삭제 문법이 달라 조용히 실패했고,
#   그 결과 0바이트 백업이 만들어진 적이 있다. 그래서 저장 후 검증까지 한다.

set -uo pipefail

NS="${NS:-mj-eks}"
SECRET="${SECRET:-server-balance-eat-com-tls}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.ordersystem-eks/tls-backup}"
ACTION="${1:-}"

die()  { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m✔ %s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || die "jq가 필요하다: brew install jq"

# 백업 파일(json)에서 인증서 만료일 추출
cert_expiry_from_file() {
  jq -r '.data["tls.crt"] // empty' "$1" 2>/dev/null \
    | base64 -d 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//'
}

case "$ACTION" in
  backup)
    kubectl get secret "$SECRET" -n "$NS" >/dev/null 2>&1 \
      || die "Secret '$SECRET' 이 네임스페이스 '$NS' 에 없다. 인증서가 아직 발급되지 않았을 수 있다."

    mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"
    TS=$(date +%Y%m%d-%H%M%S)
    OUT="$BACKUP_DIR/$SECRET-$TS.json"

    # 클러스터 고유 메타데이터(uid/resourceVersion/namespace/creationTimestamp 등)를 버리고
    # 다른 클러스터에도 apply 가능한 최소 형태로 남긴다.
    if ! kubectl get secret "$SECRET" -n "$NS" -o json \
        | jq '{
              apiVersion,
              kind,
              type,
              metadata: {name: .metadata.name},
              data
            }' > "$OUT"; then
      rm -f "$OUT"
      die "백업 생성 실패"
    fi

    # ★ 검증: 빈 파일이나 키 누락을 그냥 넘기지 않는다.
    [ -s "$OUT" ] || { rm -f "$OUT"; die "백업 파일이 비어 있다"; }
    for k in "tls.crt" "tls.key"; do
      jq -e --arg k "$k" '.data[$k] // empty' "$OUT" >/dev/null 2>&1 \
        || { rm -f "$OUT"; die "백업에 $k 가 없다"; }
    done
    EXP=$(cert_expiry_from_file "$OUT")
    [ -n "$EXP" ] || { rm -f "$OUT"; die "백업의 인증서를 파싱할 수 없다"; }

    chmod 600 "$OUT"
    ln -sf "$OUT" "$BACKUP_DIR/$SECRET-latest.json"

    ok "백업 완료: $OUT"
    info "인증서 만료: $EXP"
    info "최신 링크: $BACKUP_DIR/$SECRET-latest.json"
    info "⚠ 개인키가 들어 있다. git에 커밋하지 말 것 (레포 밖에 저장된다)."
    ;;

  restore)
    SRC="${2:-$BACKUP_DIR/$SECRET-latest.json}"
    [ -f "$SRC" ] || die "백업 파일이 없다: $SRC  (먼저 backup을 실행했어야 한다)"
    [ -s "$SRC" ] || die "백업 파일이 비어 있다: $SRC"

    EXP=$(cert_expiry_from_file "$SRC")
    [ -n "$EXP" ] || die "인증서를 파싱할 수 없다: $SRC"
    info "백업 인증서 만료: $EXP"

    # 만료 여부 확인 (만료된 걸 넣으면 HTTPS가 조용히 깨진다)
    if ! jq -r '.data["tls.crt"]' "$SRC" | base64 -d \
         | openssl x509 -checkend 0 -noout >/dev/null 2>&1; then
      die "이 인증서는 이미 만료됐다. 복원하지 말고 새로 발급받아라."
    fi
    # 남은 기간이 15일 미만이면 경고 (renewBefore=360h)
    if ! jq -r '.data["tls.crt"]' "$SRC" | base64 -d \
         | openssl x509 -checkend 1296000 -noout >/dev/null 2>&1; then
      info "⚠ 남은 유효기간이 15일 미만이다. 복원해도 cert-manager가 곧 갱신을 시도한다."
    fi

    kubectl get ns "$NS" >/dev/null 2>&1 || die "네임스페이스 '$NS' 가 없다. 먼저 만들어라."
    kubectl apply -n "$NS" -f "$SRC" || die "복원 실패"

    ok "복원 완료: $SECRET → $NS"
    info "Ingress가 이 Secret을 참조하면 바로 HTTPS가 붙는다."
    info "cert-manager는 유효한 Secret이 이미 있으면 재발급하지 않는다 (한도 소모 없음)."
    ;;

  list)
    [ -d "$BACKUP_DIR" ] || die "백업 디렉토리 없음: $BACKUP_DIR"
    printf '\033[1m%s\033[0m\n' "$BACKUP_DIR"
    FOUND=0
    for f in "$BACKUP_DIR"/*.json; do
      [ -e "$f" ] || continue
      case "$f" in *-latest.json) continue;; esac
      FOUND=1
      SIZE=$(wc -c < "$f" | tr -d ' ')
      printf '  %-50s %6sB  만료: %s\n' "$(basename "$f")" "$SIZE" "$(cert_expiry_from_file "$f")"
    done
    [ "$FOUND" = 1 ] || info "(백업 없음)"
    ;;

  *)
    cat <<EOF
사용법: tls-backup.sh {backup|restore|list} [파일경로]

  backup            현재 클러스터의 TLS Secret을 $BACKUP_DIR 에 저장
  restore [파일]    백업본을 현재 클러스터에 복원 (기본: 최신 백업)
  list              백업 목록과 각 인증서 만료일

  대상: namespace=$NS, secret=$SECRET
  (NS / SECRET / BACKUP_DIR 환경변수로 변경 가능)
EOF
    exit 1
    ;;
esac
