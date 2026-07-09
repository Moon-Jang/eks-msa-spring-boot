# ⚠️ 스포일러 — 채점 루브릭 (시나리오 ④)

> "유일한 정답"이 아니라 **평가 루브릭**. `범위 밖` 항목은 못 짚어도 감점하지 않는다(짚으면 가점).

## (1) 환경 분리 — 반드시 언급 (챕터 근거)

- namespace로 dev/prod 논리 분리(예: `order-dev`, `order-prod`). 자원 조회/배포를 namespace 단위로 격리.

### 범위 밖 (알면 가점)
- namespace는 이름 공간 분리일 뿐 권한/네트워크를 막아주지 않음 → RBAC, NetworkPolicy, ResourceQuota 필요.

## (2) 앱/DB 배치 — 반드시 언급 (챕터 근거, 핵심 함정)

- 챕터 근거로 반박: 멀티 컨테이너 Pod는 "밀접 협력·높은 내부 통신"(사이드카/로그/health check)에 적합.
  DB는 그런 보조 컨테이너가 아니라 **독립적으로 스케일·영속돼야 하는 상태 저장소**다.
  - Pod 삭제/재생성 시 DB도 같이 죽고(챕터: Pod는 최소 단위이며 ReplicaSet이 재생성), 앱을 replicas로
    늘리면 DB도 여러 개 떠 정합성이 깨진다 → 스케일/생명주기가 묶여 부적절.
- 올바른 배치: 앱은 Deployment(stateless), DB는 **분리**.
- 연결 문자열: `localhost:5432` → **`postgres-service:5432`**(같은 NS) 또는
  `postgres-service.<ns>.svc.cluster.local:5432`. Service가 안정적 이름/가상 IP를 제공하므로 Pod IP가
  바뀌어도 앱이 DB를 찾음(챕터의 서비스 디스커버리). 이 점을 짚어야 함.

### 범위 밖 (알면 가점)
- 데이터 유실 방지: PV/PVC + StatefulSet, 또는 관리형 RDS로 DB를 클러스터 밖으로 빼는 편이 안전.

## (3) 무중단 배포 — 반드시 언급 (챕터 근거)

- Deployment의 롤링 업데이트(새 Pod 생성 후 기존 Pod 순차 종료)로 항상 일부가 살아 502 제거.

### 범위 밖 (알면 가점)
- readinessProbe(준비된 Pod만 트래픽), graceful shutdown/preStop(in-flight 요청 보호).

## (4) 외부 노출 경로 — 반드시 언급 (챕터 근거)

- Nginx 리버스 프록시 → EKS에서는 **Ingress + Ingress Controller(+ AWS LB)** 가 대체.
- 경로(정답 형태): **사용자 → Route53(도메인 shop.com) → AWS LB → Ingress Controller(Ingress 규칙
  해석) → Service(selector로 Pod 선택 + 로드밸런싱) → Pod:8080**
- Service `port`로 받아 컨테이너 `targetPort: 8080`으로 포워딩.

## 흔한 오답 / 누락 포인트
- 앱+DB 한 Pod 배치를 반박 못하거나 근거가 "그냥 안 좋다" 수준(챕터의 "적절한 멀티컨테이너 용도"와
  대비 못함).
- 연결 문자열을 여전히 Pod IP로 박음(Service 디스커버리 누락).
- 외부 경로에서 **Service 단계를 빼먹고** Ingress → Pod 직결로 그림.
- 무중단을 "replicas만 늘리면 됨"으로 끝냄(롤링 업데이트 개념 누락).

## 모범 답안 예시 (하나의 예시)
> (1) order-dev/order-prod namespace로 분리. (범위 밖: 권한/네트워크는 RBAC·NetworkPolicy 필요)
> (2) 멀티 컨테이너는 사이드카처럼 밀접 협력용이지 DB용이 아니다. Pod가 죽으면 DB도 죽고 replicas로
> 늘리면 DB가 중복돼 정합성이 깨진다. 앱은 stateless Deployment, DB는 분리하고 `postgres-service:5432`
> 로 접속한다. (범위 밖: 영속성은 PVC+StatefulSet/RDS)
> (3) 롤링 업데이트로 새 Pod를 띄운 뒤 기존 Pod를 순차 종료해 502를 없앤다. (범위 밖: readiness/graceful)
> (4) 사용자 → Route53(shop.com) → AWS LB → Ingress Controller → Service → Pod:8080. Nginx 프록시를
> Ingress/Controller가 대체한다.
