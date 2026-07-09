# 시나리오 ①: Service ↔ Deployment 연결 설계 (서비스 디스커버리 / 로드밸런싱)

> 출제 범위: `contents/06-쿠버네티스-주요-요소-실습.md`
> — Service(selector, port/targetPort, 서비스 디스커버리 FQDN, 라운드 로빈 로드밸런싱),
>   ReplicaSet/Deployment 라벨 매핑(`selector.matchLabels` ↔ `template.labels` ↔ Service `selector`)
> 형식: 아키텍처 의사결정 서술형
> ※ `⚠ 강의 범위 밖` 표시가 붙은 항목은 06회차에 나오지 않은 내용이다. 아는 선에서 서술하면 되고, 몰라도 감점 없음(알면 가점).

## 배경

이 레포의 `2.ordersystem` 스프링 백엔드를 운영 중이다. 트래픽이 늘면서 서비스를 둘로 쪼갰다.

- `order-service` : 주문 API. `order` 네임스페이스에서 Deployment로 운영 (replicas: 4)
- `payment-service` : 결제 API. **`payment` 네임스페이스**에서 별도 팀이 운영 (replicas: 3)

`order-service`가 결제 시 `payment-service`를 HTTP로 호출한다. 두 가지 증상이 있다.

1. **간헐적 호출 실패**: 배포 직후 몇 분간 `order-service` → `payment-service` 호출 일부가 실패하다
   잦아든다. `payment` 팀은 "우리 Pod는 다 `Running`인데?"라고 한다.
2. **로드밸런싱 쏠림**: `payment-service` Pod 3개 중 한 곳에만 트래픽이 몰린다.

## 요구사항

아래를 **설계 결정 + 근거**로 서술하라. 매니페스트 조각을 함께 제시해도 좋다(강제 아님).

### (1) 라벨/셀렉터 전략 — 챕터 핵심

- `payment-service`가 트래픽을 받으려면 세 지점의 라벨이 어떻게 정렬돼야 하는가?
  즉 Deployment `template.metadata.labels`, ReplicaSet `selector.matchLabels`, Service `selector` —
  이 셋의 관계를 설명하라. (06회차에서 "이 라벨은 service의 selector.app과 일치해야 한다"고 다룸)
- 배포 중에는 구버전 Pod와 신버전 Pod가 **같은 `app` 라벨**로 동시에 떠 있을 수 있다.
  Service는 selector에 매칭되는 Pod들에 트래픽을 분산하므로(챕터: "여러 pod가 매핑되면 자동
  로드밸런싱"), 이것이 문제 1(간헐적 실패)과 어떻게 연결될 수 있는지 서술하라.
- `⚠ 강의 범위 밖`: "Pod가 `Running`이어도 요청을 받을 준비가 안 됐을 수 있다"는 문제를 근본적으로
  막는 장치(readinessProbe)를 알고 있다면, 어떻게 쓰면 배포 중 실패가 사라지는지 아는 선에서 덧붙여라.

### (2) 네트워크 엔드포인트 (cross-namespace) — 챕터 핵심

- `order` 네임스페이스의 Pod에서 `payment-service`를 호출할 때 쓸 **정확한 엔드포인트 주소**를 쓰고,
  왜 짧은 이름(`http://payment-service`)만으로는 안 되는지 설명하라. (챕터: 다른 네임스페이스 접근은
  `my-service.<namespace-name>.svc.cluster.local`)
- 스프링 앱이 컨테이너에서 8080을 리슨한다고 할 때 Service의 `port`와 `targetPort`를 각각 어떤 값으로
  잡아야 하는지, 그 둘의 차이를 챕터 정의에 근거해 설명하라.

### (3) 로드밸런싱 쏠림(문제 2)의 원인과 대응

- 챕터는 "Service의 기본 라우팅은 라운드 로빈이지만 **캐싱 등의 이유로 공평하게 라우팅되지 않기도
  한다**"고 했다. 이 문장을 근거로, 왜 Pod 3개 중 하나로 쏠릴 수 있는지 본인 언어로 설명하라.
- `⚠ 강의 범위 밖`: 스프링 클라이언트가 HTTP Keep-Alive 커넥션 풀을 유지한다는 점, ClusterIP
  Service가 커넥션 단위(L4)로 분배한다는 점을 알고 있다면 쏠림의 더 정확한 원인과 완화책(최소 1개)을
  아는 선에서 서술하라.

## 제약 조건

- `payment-service`는 다른 팀 소유라 네임스페이스를 합칠 수 없다.
- 결제 호출 실패는 중복 결제 위험이 있어, 배포 중 실패를 반드시 줄여야 한다.
- 이번 스프린트에서 서비스 메시 전면 도입 같은 큰 인프라 변경은 승인받기 어렵다 —
  가능하면 기본 리소스(Deployment/Service/라벨) 범위에서 먼저 해결하라.
