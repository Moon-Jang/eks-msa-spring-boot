#!/usr/bin/env bash
# EKS 실습 환경 상태 검증 (read-only)
#
# 사용법:
#   aws-vault exec <프로필> -- .claude/skills/ordersystem-eks-env/scripts/verify.sh
#
# 환경변수: NS(기본 mj-eks), REGION(기본 ap-northeast-2)

set -uo pipefail

NS="${NS:-mj-eks}"
REGION="${REGION:-ap-northeast-2}"

head_() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
run()   { echo "  \$ $*"; "$@" 2>&1 | sed 's/^/  /'; }

if ! kubectl get nodes >/dev/null 2>&1; then
  printf '\033[31m클러스터에 접속할 수 없습니다.\033[0m kubeconfig를 먼저 세팅하세요:\n'
  printf '  aws eks update-kubeconfig --region %s --name <클러스터명>\n' "$REGION"
  exit 1
fi

head_ "L1/L2 노드 · 네임스페이스"
run kubectl get nodes -o wide
run kubectl get ns

head_ "L3 ingress-nginx (NLB)"
run kubectl get pods -n ingress-nginx
run kubectl get svc -n ingress-nginx

head_ "LoadBalancer 타입 Service (전체) — 삭제 시 0이어야 함"
run kubectl get svc -A --field-selector spec.type=LoadBalancer

head_ "L5 cert-manager · 인증서"
run kubectl get pods -n cert-manager
run kubectl get clusterissuer
run kubectl get certificate -A

head_ "L4 애플리케이션 (ns=$NS)"
run kubectl get all -n "$NS"
run kubectl get ingress -n "$NS"
run kubectl get secret -n "$NS"

head_ "L6 오토스케일링"
run kubectl get deployment metrics-server -n kube-system
run kubectl get hpa -A
echo "  \$ kubectl top nodes"
kubectl top nodes 2>&1 | sed 's/^/  /'

head_ "L7 ArgoCD"
run kubectl get pods -n argocd

head_ "L8 모니터링"
run kubectl get pods -n monitoring

head_ "문제 있는 파드 (Running/Succeeded 아님)"
kubectl get pods -A --field-selector status.phase!=Running,status.phase!=Succeeded 2>&1 | sed 's/^/  /'

head_ "최근 Warning 이벤트 (20건)"
kubectl get events -A --field-selector type=Warning \
  --sort-by=.lastTimestamp 2>/dev/null | tail -20 | sed 's/^/  /'

head_ "AWS 로드밸런서 (region=$REGION)"
if aws sts get-caller-identity >/dev/null 2>&1; then
  aws elbv2 describe-load-balancers --region "$REGION" \
    --query 'LoadBalancers[].{Name:LoadBalancerName,Type:Type,State:State.Code,DNS:DNSName}' \
    --output table 2>/dev/null | sed 's/^/  /'
else
  echo "  (AWS 자격증명 없음 — aws-vault exec 로 실행하면 LB까지 확인됩니다)"
fi

printf '\n\033[1m검증 완료.\033[0m\n'
