# 시나리오 ③: Ingress 라우팅 설계 + 503 원인 분석

> 출제 범위: `contents/06-쿠버네티스-주요-요소-실습.md`
> — Ingress(규칙 정의) vs Ingress Controller(실제 라우팅), prefix 단위 라우팅, 도메인(host) 기반 라우팅,
>   "Controller는 하나여도 여러 Ingress를 참조", Controller 설치 시 AWS LB 자동 생성 → Route53 연결
> 형식: 아키텍처 의사결정 서술형 + 설계/설정 누락형 트러블슈팅
> ※ `⚠ 강의 범위 밖` 표시가 붙은 항목은 06회차에 나오지 않은 내용이다. 아는 선에서 서술하면 되고, 몰라도 감점 없음(알면 가점).

## 배경

이 레포의 `2.ordersystem`을 EKS에 올렸고, 외부 트래픽을 받아야 한다. 노출 대상은 셋이다.

- `order-service` : 고객용 주문 API — `api.shop.com/orders`
- `payment-service` : 결제 API — `api.shop.com/payments`
- `admin-service` : 사내 관리자 콘솔 — **별도 도메인** `admin.shop.com`

챕터에서 다룬 것: Ingress Controller(nginx controller)를 설치하면 AWS에 LB가 자동 생성되고,
그 LB 주소를 Route53에 연결해 도메인으로 접근한다.

## 요구사항

### (1) Ingress 구성 — 챕터 핵심

- 위 3개 서비스를 노출할 때 **Ingress Controller는 몇 개** 필요한가? 챕터 결론("도메인이 다른 Ingress가
  여러 개 있어도 Controller는 하나만 있어도 되고, Controller가 여러 Ingress를 참조")에 근거해 답하라.
- `api.shop.com`의 `/orders`, `/payments`는 **prefix 단위 라우팅**으로, `admin.shop.com`은
  **도메인(host) 기반 라우팅**으로 표현된다. 각각을 챕터 개념으로 설명하라(매니페스트 조각 환영, 강제 아님).

### (2) LB를 몇 개 둘 것인가 — 챕터 개념 + 비용 판단

- 챕터에 따르면 Controller 하나가 여러 Ingress를 참조한다. 이 사실을 활용해 **하나의 Controller/LB
  뒤에 라우팅 규칙을 모으는 구성**과, 서비스마다 Controller/LB를 따로 두는 구성을 **비용·운영 복잡도**
  관점에서 비교하고 무엇을 택할지 결정하라. (챕터: LB가 AWS에 생성됨 = 비용 발생)
- `⚠ 강의 범위 밖`: 관리자 콘솔(`admin.shop.com`)을 사내망에서만 열어야 한다면, host 규칙을 나누는
  것만으로는 접근제어가 안 된다. 어떻게 실제로 막을지(IP allowlist, internal LB 등)를 아는 선에서
  서술하라. (몰라도 됨)

### (3) 503 원인 분석 (설계/설정 누락형)

배포 후 `api.shop.com/orders` 접근 시 **간헐적으로 503**이 뜬다. 매니페스트에 버그를 심은 게 아니라
**설계/설정 누락**으로 생길 수 있는 상황이다. 아래 각 후보가 원인이라면 왜 503이 나는지, 그리고
**챕터에서 배운 명령(`kubectl describe`, `kubectl get`)으로 어떻게 확인**할지 서술하라.

- 후보 A: Ingress 규칙의 backend 서비스 이름/포트가 실제 Service의 이름/포트와 불일치
- 후보 B: Service의 `selector`가 어떤 Pod와도 매칭되지 않아, 트래픽 전달 대상 Pod가 없음
  (챕터: "selector.app을 label로 가지는 pod에 네트워크 정보 전파")
- 후보 C: 본인이 생각하는 추가 원인 1개 (예: Ingress와 대상 Service가 서로 다른 네임스페이스라
  Ingress가 Service를 못 찾음 등)

진단 순서를 `kubectl describe ingress ... / kubectl get svc,pods ...` 형태로 구체적으로 제시하라.

- `⚠ 강의 범위 밖`: "간헐적"이라는 단서에 주목해, 롤링 배포 중 준비 안 된 Pod만 남는 순간
  (readinessProbe 부재) 때문일 수 있다는 가설을 아는 선에서 덧붙여라. 확인에 `kubectl get endpoints`가
  유용하다는 점을 안다면 함께 언급하라. (몰라도 됨)

## 제약 조건

- LB는 개수만큼 비용이 나가므로 불필요하게 늘리지 않는다.
- 관리자 콘솔은 공개 인터넷에 노출되면 안 된다.
- 도메인/인증서 관리 포인트를 최소화하고 싶다.
