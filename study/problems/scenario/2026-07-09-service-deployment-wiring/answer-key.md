# ⚠️ 스포일러 — 채점 루브릭 (시나리오 ①)

> "유일한 정답"이 아니라 **평가 루브릭**. 핵심 포인트를 근거와 함께 짚었는지로 채점한다.
> `범위 밖` 항목은 못 짚어도 감점하지 않는다(짚으면 가점).

## (1) 라벨/셀렉터 — 반드시 언급 (챕터 근거)

- 세 지점 관계: Deployment `template.metadata.labels` → 생성되는 Pod에 라벨 부여 →
  ReplicaSet `selector.matchLabels`와 일치해야 관리됨 → Service `selector`와 일치해야 트래픽 대상.
  세 곳이 같은 라벨(예: `app: payment`)로 정렬돼야 한다. (챕터에 명시된 3자 일치)
- 문제 1 연결: 배포 중 구/신 Pod가 같은 `app` 라벨을 달고 공존하면 Service가 **둘 다에 분산**한다.
  아직 준비 안 된 신 Pod로도 트래픽이 가서 간헐적 실패가 날 수 있다는 통찰.

### 범위 밖 (알면 가점)
- readinessProbe로 준비 전 Pod를 트래픽 대상에서 제외하면 배포 중 실패가 사라진다.
- Deployment가 자동 부여하는 `pod-template-hash`로 리비전별 Pod가 구분된다.

## (2) 엔드포인트 — 반드시 언급 (챕터 근거)

- 주소: `http://payment-service.payment.svc.cluster.local:<port>`
  (최소 `payment-service.payment` 형태로 네임스페이스 명시). 짧은 이름은 호출자와 같은
  네임스페이스(order)에서 먼저 조회되므로 cross-namespace에선 실패.
- port vs targetPort: 앱이 8080 리슨 → `targetPort: 8080`. `port`는 Service가 클러스터 내부에서
  리슨하는 포트(호출자가 쓰는 값). 호출자는 `port`로 부르고 Service가 `targetPort`로 포워딩.
- 흔한 오답: port/targetPort를 반대로 설명하거나 같은 개념으로 뭉뚱그림 / 네임스페이스 누락.

## (3) 로드밸런싱 쏠림 — 반드시 언급 (챕터 근거)

- 챕터 근거: 기본은 라운드 로빈이나 "캐싱 등으로 공평하지 않을 수 있다"를 인용해, 실제로는 특정
  Pod로 쏠릴 수 있음을 설명하면 챕터 범위 내 정답으로 인정.

### 범위 밖 (알면 가점)
- 정확한 원인: 스프링 Keep-Alive 커넥션 풀이 한 번 맺은 커넥션을 특정 Pod에 고정 + ClusterIP는
  L4(커넥션 단위) 분배 → 재분배가 안 일어나 쏠림.
- 완화책: 커넥션 최대 수명 제한(주기적 재수립), 클라이언트/L7 로드밸런싱. `sessionAffinity`는
  오히려 고정을 강화하므로 끄는 게 맞음(켜자고 하면 감점).

## 흔한 오답 / 누락 포인트
- 문제 1을 "Pod가 안 떠서"로만 진단 → 공존 구간의 selector 분산을 못 짚음.
- cross-namespace 주소에서 네임스페이스 생략.
- 쏠림을 "원래 라운드 로빈이 안 공평"으로만 답하고 챕터 문장("캐싱 등") 근거 인용 없음.

## 모범 답안 예시 (하나의 예시)
> (1) 세 라벨을 `app: payment`로 정렬한다. 배포 중엔 구/신 Pod가 같은 라벨로 공존해 Service가 둘 다에
> 분산하므로, 준비 안 된 Pod로 트래픽이 가 간헐적 실패가 난다. (범위 밖: readinessProbe로 해결)
> (2) `http://payment-service.payment.svc.cluster.local:80`. 짧은 이름은 order NS에서 조회돼 안 된다.
> 앱이 8080이면 `targetPort: 8080`, `port: 80`; 호출자는 80으로 부른다.
> (3) 챕터대로 기본은 라운드 로빈이나 캐싱 등으로 한 Pod에 쏠릴 수 있다. (범위 밖: Keep-Alive 커넥션
> 고정 + L4 분배가 원인, 커넥션 수명 제한으로 완화)
