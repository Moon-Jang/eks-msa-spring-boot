# 채점 결과 — max (시나리오 ③ Ingress 라우팅 설계 + 503 원인 분석)

> 채점일: 2026-07-19 · 대상: `answer-max.md` · 기준: `answer-key.md` 루브릭
> 서술형 시나리오이므로 클러스터 검증 없이 정적 평가.

## 종합 판정: 통과 (양호, 약 85%)

핵심 3개 항목의 필수 포인트를 모두 정확히 짚었고 범위 밖 가점 항목에서 창의적 접근도 보였다.
다만 진단의 "구체성"과 후보 C의 논리 정밀도에서 감점 요인이 있다.

---

## (1) Ingress 구성 — 약 95%

**맞은 점**

- **1-1 (Controller 개수)**: "서비스 갯수와 상관없이 controller는 1개면 된다. 하나의 controller가
  여러 ingress 규칙을 모두 참조하기 때문" → 루브릭의 "Controller 1개 + 챕터 근거"를 정확히 충족.
  흔한 오답(서비스마다 Controller 설치)에 빠지지 않음.
- **1-2 (prefix vs host 라우팅)**: "/order, /payment는 같은 도메인의 트래픽을 path로 각각 라우팅",
  "admin.shop.com은 도메인 기반 라우팅"으로 두 방식을 명확히 구분. 루브릭 핵심 구분 충족.

**아쉬운 점 (감점 아님)**

- 아주 사소한 정밀도: "ingress 규칙을 참조"는 맞지만, 정확히는 Controller가 API 서버를 watch하며
  **여러 Ingress 리소스를 병합**해 하나의 라우팅 테이블(nginx.conf 등)로 구성한다는 메커니즘까지
  언급했다면 완성도가 더 높았다.

---

## (2) LB 개수 + 비용 판단 — 약 90%

**맞은 점**

- "서비스마다 LB를 두면 비용이 서비스 증가에 따라 선형 증가", "LB마다 인증서·모니터링을 따로 관리"
  → 루브릭의 "LB 개수 = 비용 선형 증가 + 인증서 관리 포인트 증가"를 정확히 짚음.
- "하나의 컨트롤러와 하나의 LB 구조 선택" → 제약 조건(LB 불필요하게 늘리지 않음, 인증서 관리 최소화)과
  부합하는 올바른 의사결정.

**범위 밖 가점 (매우 좋음)**

- admin 격리에 대해 "host 규칙은 라우팅이지 접근제어가 아니다"라고 정확히 인식(흔한 오답 회피).
- **인증 프록시 Pod를 Ingress Controller 뒤단 앞에 두어 모든 트래픽이 인증을 거치게 하는
  forward-auth 패턴**을 제안. 루브릭 예시(IP allowlist/internal LB)와는 다르나 실무에서 실제 쓰이는
  유효한 패턴(oauth2-proxy, nginx `auth-url` annotation 등) → 가점.

**아쉬운 점 (범위 밖이라 감점 아님)**

- 인증 프록시는 **애플리케이션/인증 레벨 통제**이지, 요구사항인 "공개 인터넷에 노출되면 안 됨(네트워크
  레벨 격리)"을 완전히 만족시키진 못한다. 프록시가 있어도 admin.shop.com 엔드포인트 자체는 인터넷에
  열려 공격 표면이 남는다. 루브릭이 강조한 **network 레벨 통제(internal LB / IP allowlist)**를 함께
  언급하고 그와 인증 프록시의 계층 차이(defense in depth)를 구분했다면 만점.

---

## (3) 503 원인 분석 — 약 75%

### 후보 A — 충족 (약 90%)

- "컨트롤러가 트래픽을 넘겨줄 대상을 찾지 못함" + `kubectl describe ingress`로 backend 확인 →
  `kubectl get svc`로 이름/포트 대조. 루브릭 요구 정확히 충족. `-n namespace`까지 붙여 네임스페이스를
  의식한 점도 좋다.

### 후보 B — 충족 (약 85%)

- `kubectl describe svc`의 selector와 `kubectl describe pod`의 label을 비교 → selector 불일치 진단으로 적절.
- 아쉬운 점: 루브릭은 `kubectl get pods --show-labels`를 권장. 파드마다 describe 하는 것보다
  `--show-labels`로 **한 번에 전체 라벨을 조망**하는 것이 진단 효율상 우수. 또 selector 불일치의 가장
  직접적 증거는 **`kubectl get endpoints <svc>`가 비어 있는 것**인데(범위 밖 힌트) 이를 언급 안 함.

### 후보 C — 부분 충족 (약 55%)

- "간헐적 503이면 Pod가 어떤 이슈로 계속 죽어서 트래픽을 못 받는 상황" → 방향성(가용 Pod 부족)은 맞다.
- **문제점 1**: 문제가 요구한 후보 C는 "**설계/설정 누락**으로 인한 추가 원인"(루브릭 예시:
  Ingress와 Service의 네임스페이스 불일치)이다. max의 답변은 설정 누락이 아니라 "Pod가 죽는다"는
  런타임 장애로, 문제 의도(설계/설정 누락형)와 결이 다르다.
- **문제점 2**: 후보 C에 **진단 명령이 전혀 없다.** 문제는 "describe/get으로 어떻게 확인할지 구체적으로
  제시하라"고 명시했고, 루브릭 흔한 오답에 "describe/get 없이 추측만 함"이 있다 → 정확히 이 패턴에 해당.
- **문제점 3**: "간헐적" 단서는 범위 밖 가점 항목인 **롤링 배포 중 readinessProbe 미비로 준비 안 된
  Pod만 남는 순간**을 유도한 것. "Pod가 계속 죽음"은 인접하나, readiness/롤링 맥락과
  `kubectl get endpoints`로 "Service 뒤 실제 Pod 유무"를 확인하는 방법은 언급 못 함.
- **누락**: 전체 **진단 순서**(get ingress → describe ingress → get svc → get pods → controller 로그)를
  하나의 흐름으로 제시하라는 요구가 있었으나, 후보별 명령만 있고 통합 시퀀스 서술이 약하다.

---

## 복습 포인트

1. **진단 도구의 "최적성"**: `describe pod`(개별) vs `get pods --show-labels`(전체 조망), 그리고
   selector-Pod 매칭의 결정적 증거인 `kubectl get endpoints <svc>`. 503 트러블슈팅에서 endpoints가
   비어 있는지 확인하는 것이 selector/readiness 문제를 한 번에 가른다.
2. **후보 C의 "설계/설정 누락" 프레임**: 런타임 장애(Pod crash)가 아니라, 사람이 매니페스트 짤 때
   실수할 수 있는 구조적 누락(네임스페이스 경계, 포트 명명 규칙, readinessProbe 부재 등)으로 확장.
3. **"간헐적" 단서 해석**: 상시 503(구성 오류)과 간헐 503(가용 Pod 수 변동/롤링 중 readiness 공백)의
   원인 계층이 다르다. 간헐성은 보통 시간에 따라 endpoints 집합이 흔들리는 문제다.
4. **네트워크 격리 vs 인증 통제의 계층 구분**: internal LB/IP allowlist(네트워크 레벨)와 forward-auth
   프록시(애플리케이션 레벨)는 상호 보완이지 대체가 아니다.

## 한 단계 더 (후속 질문)

1. 후보 B(selector 불일치)와 후보 C(간헐적 503)를 구분해야 할 때, `kubectl get endpoints <svc>`의
   출력이 각각 어떻게 다를까? "항상 비어 있음" vs "시간에 따라 개수가 출렁임"을 어떻게 활용해 두 원인을
   가려낼 수 있을까?
2. admin.shop.com을 인증 프록시 Pod로 보호할 때, 공격자가 프록시를 우회해 admin-service의 ClusterIP나
   Pod IP로 직접 도달할 수 있다면 그 방어는 유효할까? "공개 인터넷에 노출되면 안 된다"를 네트워크
   레벨에서 보장하려면 인증 프록시에 무엇을 더 결합해야 할까?
