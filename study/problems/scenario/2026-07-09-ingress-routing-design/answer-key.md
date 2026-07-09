# ⚠️ 스포일러 — 채점 루브릭 (시나리오 ③)

> "유일한 정답"이 아니라 **평가 루브릭**. `범위 밖` 항목은 못 짚어도 감점하지 않는다(짚으면 가점).

## (1) Ingress 구성 — 반드시 언급 (챕터 근거)

- Controller는 **1개면 충분**. 챕터 근거: 도메인이 다른 Ingress가 여러 개여도 하나의 Controller가
  모두 참조해 라우팅한다.
- prefix 라우팅: `api.shop.com` host 아래 `/orders`→order, `/payments`→payment.
  도메인 라우팅: `admin.shop.com` host→admin. (챕터의 "prefix 단위 라우팅"·"도메인 기반 접근" 구분)

## (2) LB 개수 — 반드시 언급 (챕터 근거 + 비용)

- 서비스마다 Controller/LB를 따로 두면 **LB 개수 = 비용**이 선형 증가 + 인증서 관리 포인트 증가.
  Controller 하나 뒤에 규칙을 모으는 구성이 비용·운영상 유리(제약과 부합). 챕터의 "Controller 하나가
  여러 Ingress 참조"를 근거로 삼으면 정답.

### 범위 밖 (알면 가점)
- admin 사내망 제약: host 규칙만 나눈다고 접근제어가 되진 않음. IP allowlist(nginx annotation
  `whitelist-source-range` / 보안그룹·WAF) 또는 internal LB로 분리 등 네트워크 레벨 통제가 필요.

## (3) 503 원인 — 반드시 언급 (챕터 근거)

- 후보 A(backend 이름/포트 불일치): Ingress가 존재하지 않는 Service/포트로 보내 upstream 없음 → 503.
  확인: `kubectl describe ingress`로 backend 확인 → `kubectl get svc`로 이름/포트 대조.
- 후보 B(selector 불일치): Service가 어떤 Pod에도 네트워크 정보를 전파 못해 전달 대상이 없음 → 503.
  확인: `kubectl describe svc`, `kubectl get pods --show-labels`로 라벨 매칭 확인.
- 후보 C 예시: Ingress와 대상 Service가 다른 네임스페이스 → Ingress는 같은 NS의 Service만 참조 →
  backend를 못 찾음. / Controller Pod 자체가 비정상.
- 진단 순서(예): `kubectl get ingress` → `describe ingress`(backend/이벤트) → `kubectl get svc` →
  `kubectl get pods -o wide --show-labels`(라벨/상태) → Controller 로그.

### 범위 밖 (알면 가점)
- "간헐적" 단서 → 롤링 중 readiness 미비로 전달 대상 Pod가 일시적으로 비는 가설.
- `kubectl get endpoints <svc>`가 비어 있는지로 "Service 뒤에 실제 Pod가 있는지"를 직접 확인.

## 흔한 오답 / 누락 포인트
- Controller를 서비스마다 하나씩 설치해야 한다고 오해(챕터 결론과 정반대).
- 503 진단에서 describe/get 없이 추측만 함.
- admin 격리를 "host만 나누면 됨"으로 끝냄(범위 밖이지만 언급하면 가점 포인트).

## 모범 답안 예시 (하나의 예시)
> (1) Controller 1개. api.shop.com에 /orders·/payments prefix 규칙, admin.shop.com host 규칙.
> (2) 단일 Controller/LB 뒤에 규칙을 모아 LB 비용·인증서 관리를 줄인다. (범위 밖: admin은 internal LB
> 나 IP allowlist로 사내망만 허용)
> (3) describe ingress로 backend를, get svc로 이름/포트를, get pods --show-labels로 selector 매칭을
> 확인한다. 다른 NS면 Ingress가 Service를 못 찾는다. (범위 밖: 간헐적이면 readiness 미비 가설,
> get endpoints로 확인)
