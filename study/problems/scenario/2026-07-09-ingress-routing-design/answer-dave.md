# 답안: 시나리오 ③ Ingress 라우팅 설계 + 503 원인 분석

> 문제: study/problems/scenario/2026-07-09-ingress-routing-design/problem.md
> 출제 범위: contents/06-쿠버네티스-주요-요소-실습.md (Ingress vs Ingress Controller, prefix/host 라우팅, Controller 1개가 여러 Ingress 참조, LB 자동생성→Route53)
> 풀이자: dave

---

## (1) Ingress 구성
**묻는 것:**
- 3개 서비스 노출에 `Ingress Controller`는 몇 개 필요한지 (근거: Controller 1개가 여러 Ingress 참조)
- `api.shop.com`의 `/orders`·`/payments`는 `prefix 라우팅`, `admin.shop.com`은 `host 기반 라우팅`으로 각각 설명 (매니페스트 조각 환영·강제 아님)

**답:**

_(작성)_

---

## (2) LB를 몇 개 둘 것인가
**묻는 것:** Controller 1개 + LB 1개에 규칙을 모으는 구성 vs 서비스마다 Controller/LB 분리 구성을 `비용·운영 복잡도`로 비교하고 선택. (+ ⚠ 범위 밖: `admin.shop.com`을 사내망만 열려면 host 규칙만으론 부족 — IP allowlist·internal LB 등 / 몰라도 됨)

**답:**

_(작성)_

---

## (3) 503 원인 분석 (설계/설정 누락형)
**묻는 것:** `api.shop.com/orders` 간헐적 503의 원인 후보별로 "왜 503인지 + `kubectl describe`/`kubectl get`으로 확인법"을 서술하고, 진단 순서를 명령 형태로 제시.
- 후보 A: Ingress backend의 서비스 이름/포트 불일치
- 후보 B: Service `selector`가 어떤 Pod와도 매칭 안 됨 (전달 대상 Pod 없음)
- 후보 C: 본인이 생각하는 추가 원인 1개 (예: Ingress와 Service가 다른 네임스페이스)
- (+ ⚠ 범위 밖: "간헐적" 단서 → 롤링 중 readinessProbe 부재로 준비 안 된 Pod만 남는 순간 가설, `kubectl get endpoints` 활용 / 몰라도 됨)

**답:**

_(작성)_

---

> 제약(참고): LB는 개수만큼 비용 → 불필요하게 늘리지 않기 · 관리자 콘솔은 공개 인터넷 노출 금지 · 도메인/인증서 관리 포인트 최소화
