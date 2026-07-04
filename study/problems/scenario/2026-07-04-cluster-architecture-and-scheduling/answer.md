# 답변 및 채점 정리 (2026-07-04)

> 범위: `contents/3.쿠버네티스-이론-개요.md` 기반 시나리오 문제 + 오답 복기용 개념 퀴즈
> 이 문서는 세션 중 진행한 문답을 시간순으로 정리한 것입니다.

---

## 1. 원본 시나리오 문제 (`problem.md`)

### 문제 1 — 환경 분리 (A: 클러스터 물리 분리 vs B: 네임스페이스 분리)

**답변**
> B를 선택할 것입니다. A 선택으로 EKS를 물리적으로 나누면 독립적인 환경을 보장받아 가용성 측면에서는
> 이점있지만 그로인한 관리 포인트 증가, 비용 증가등이 발목을 잡을 것입니다. 반면 B는 단일 클러스터여서
> SPOF 가 우려되지만 AWS 매니지먼트 시스템이기 때문에 고가용성을 보장받을 수 있습니다. 거기다 k8s에
> 네임스페이스를 통해 클러스터 내부를 논리적인 환경으로 분리가 가능하며 단일 클러스터이기 때문이
> 관리도 쉽습니다.

**채점 — 부분 통과**
- 맞은 부분: B 선택 자체는 타당. A의 비용/관리포인트 증가 단점 정확히 짚음. "AWS 매니지드 컨트롤
  플레인이라 고가용성"이라는 사실관계도 맞음.
- 놓친 부분: 이번 QA팀 사고(운영 Deployment `scale 0`)의 근본 원인은 "클러스터 미분리"가 아니라
  **RBAC 등 권한 분리 부재**라는 연결고리가 빠짐. 네임스페이스만 나눠도 RBAC 없이는 동일 사고가
  재발할 수 있다는 통찰이 없었음.
- 비고: RBAC는 `contents/` 문서(3번, 6번 모두)에 등장하지 않는 내용이라 채점 루브릭이 강의 범위를
  넘어선 부분이 있었음(문제 설계상 인정된 갭).

### 문제 2 — 스케줄링 장애 진단 (신규 Pod 3개 Pending)

**답변**
> 1. kubectl log 명령어를 통해 노드 상세 로그를 파악하고 pending의 원인을 찾을 것 입니다.
> 2. 워커노드의 상태를 관리하는것은 kube-controller-manger 이며 이것은 Deployment와도 밀접하게
>    관련되어 있습니다.
> 3. 잘모르겠음
> 4. 워커노드 리소스가 부족했나?

**채점 — 미통과 (핵심 개념 2곳 오답)**
- 1번: `kubectl logs`는 이미 실행 중인 컨테이너의 로그를 보는 명령. Pending 상태는 컨테이너가 뜬 적이
  없어 로그가 없음 → `kubectl describe pod`의 Events를 봐야 함. 진단 순서(get pods -o wide → describe
  pod → describe node → autoscaler 확인)도 누락.
- 2번: **오답.** Pending과 직접 관련된 컴포넌트는 `kube-controller-manager`가 아니라
  **`kube-scheduler`**. controller-manager는 Deployment/ReplicaSet의 "선언된 상태 유지"를 감시하는
  역할이고, "새 파드를 어느 노드에 배치할지 결정"하는 것은 스케줄러의 역할.
- 3번: 미응답. EKS 관리형이라 우리가 못 만지는 컴포넌트(apiserver/etcd/scheduler/controller-manager)와
  워커노드 쪽이라 만질 수 있는 것(kubelet/kube-proxy/EC2)의 구분이 필요했음.
- 4번: 원인 후보 1개만 제시(요구는 2개 이상). nodeSelector/taint-toleration 제약, AZ 분산 제약 등
  추가 필요.

---

## 2. 문서 내용 검증 (`contents/3.쿠버네티스-이론-개요.md` 재확인)

- **kube-scheduler**: 문서 — "새로 생성된 파드를 감지하고, 그 파드를 실행할 최적의 노드를 선택" → 채점 근거와 일치.
- **kube-controller-manager**: 문서 — "상태 유지를 위한 자동화, Deployment/ReplicaSet 등을 감시하고 필요 시 변경 사항을 반영" → 채점 근거와 일치. (문제 2의 2번 오답 확정)
- **마스터 노드를 EKS가 관리**: 문서 — "aws의 eks는 클러스터 생성시 마스터노드의 생성 및 관리를 지원" → 확인.
- `kubectl logs` vs `describe` 구분은 3번 문서가 아니라 6번 문서(실습편)의 내용, RBAC는 3/6번 문서 어디에도 없는 범위 밖 내용이었음을 확인.

---

## 3. 오답 복기용 개념 퀴즈 1차 (마스터/워커 컴포넌트 구분)

### Q1. kube-scheduler vs kube-controller-manager 정의 + 헷갈리는 이유

**답변**
> 스케줄러는 새로운 파드를 감지하고 노드를 선정해 해당 노드에 파드를 정상적으로 설치하도록
> 명령내린다. 컨트롤러-매니저는 Deployment에 명세된 레플레카셋을 감시하고 에러나 변경사항이
> 있을경우 지정된 레플리카만큼 파드 생성/축소하는 역할을 하고 신규 버전 업데이트시 롤링배포하도록
> 한다

**채점**
- 맞음: 스케줄러(감지+노드선정), 컨트롤러-매니저(레플리카셋 감시, 생성/축소, 롤링배포 오케스트레이션) — 문서 정의와 일치.
- 부정확: "노드에 파드를 설치하도록 명령내린다"는 스케줄러가 아니라 **kubelet**의 역할. 스케줄러는 API 서버를 통해 "이 노드로 배정"만 하고, 실제 설치/실행은 kubelet이 담당.
- 누락: "왜 헷갈리기 쉬운지"에 대한 설명이 빠짐.

### Q2. 컴포넌트 마스터/워커 분류

**답변**
> 마스터노드: kube-apiserver, kube-scheduler, kube-controller-manager, etcd
> 워커노드: kubelet, kube-proxy

**채점 — 통과.** 문서와 정확히 일치.

### Q3. Pending 상태와 직접 관련된 컴포넌트

**답변**
> 가장 직접적인 컴포넌트는 스케줄러야 왜냐면 파드가 최적의 노드에 배정을 못받았기 때문이야.

**채점 — 통과.** 문서 정의(파드 감지+최적 노드 선택)와 정확히 일치. 원본 문제 2번에서 있었던
scheduler/controller-manager 혼동이 정정됨.

### Q4. kubelet vs kube-proxy 역할

**답변**
> 큐블렛은 api 서버로부터 파드생성하라는 명령이 들어왔을때 파드를 생성하는 역할이고
> 프록시에 경우 n대에 파드가 있을때 요청에 맞는 파드로 라우팅하는 역할을해

**채점 — 통과.** 문서 정의(kubelet: API 서버와 통신해 파드 시작/중지/관리, kube-proxy: 트래픽을
적절히 포워딩해 파드 간·외부 통신 가능)와 일치.

### Q5. 롤링 배포 실패(새 Pod 생성/소멸 반복)를 감시·반영하는 컴포넌트

**답변**
> 컨트롤러 매니저

**채점 — 통과.** 문서 정의와 일치.

**1차 퀴즈 총평**: scheduler(배치 결정) vs controller-manager(상태/수량 유지) 구분이 Q3·Q5에서
명확히 정정됨. 남은 세부 경계선(스케줄러는 배정만, 실제 설치는 kubelet)은 Q4 답변에서 이미 스스로
정리함.

---

## 4. 오답 복기용 개념 퀴즈 2차 (문서에서 아직 안 다룬 리소스/개념)

### Q6. Service vs Ingress

**답변**
> 인그레스는 외부 https 요청을 서비스로 라우팅하고 서비스는 그걸 이제 내부 워커노드에 라우팅한다음
> 큐브 프록시가 적절한 파드로 또 라우팅할거야

**채점 — 부분 통과.** 큰 흐름(Ingress → Service)은 맞음. 다만 "Service가 워커노드로 라우팅 → 그다음
kube-proxy가 파드로 라우팅"처럼 **순서를 나눈 것이 부정확**. Service는 라우팅 "규칙"의 선언이고,
kube-proxy는 그 규칙을 네트워크 레벨에서 실제로 수행하는 실행기 — 순차적인 두 홉이 아니라 하나의 층.
정확한 흐름: Ingress(외부, 도메인 기반) → Service(대상 파드 규칙 정의, LB) → kube-proxy(그 규칙을
실제 라우팅으로 수행).

### Q7. ReplicaSet 대비 Deployment가 제공하는 추가 기능

**답변**
> Deployment는 kube apply했을때 파드의 컨테이너 이미지가 변경됐을때 새로 롤링 배포하는기능을
> 가지고 있고 롤백도 할 수 있어

**채점 — 통과.** 문서와 일치. (보충: Deployment가 ReplicaSet을 버전별로 새로 만들어 관리하기 때문에
롤백이 가능하다는 메커니즘까지 알아두면 좋음.)

### Q8. ConfigMap vs Secret

**답변 (1차)**
> 이건 전혀 모르겠어 설명해줘

**설명 제공**: ConfigMap=비민감 설정값(프로필명, 로그레벨, URL 등), Secret=노출되면 안 되는 값(DB
비밀번호, JWT secretKey 등). Secret은 base64 인코딩일 뿐 암호화가 아니라서 RBAC 등으로 추가 보호 필요.

**답변 (복기, Q8-2 — `2.ordersystem`의 `DB_PW`/`jwt.secretKey`/`redis.host` 기준)**
> Sercret 에 넣어야돼 ConfigMap은 비민감성 정보 넣는곳

**채점 — 통과(암묵적).** `DB_PW`/`secretKey` → Secret 명시. `redis.host`를 ConfigMap에 넣어야 한다는
결론은 명시적으로 말하지 않았으나 "ConfigMap은 비민감성 정보 넣는 곳"이라는 기준 제시로 이해한
것으로 판단.

### Q9. etcd의 역할과 장애 영향

**답변 (1차)**
> etcd 는 클러스터 환경변수 같은거 관리하는 곳이라고 들었어 자세히는 몰라

**설명 제공**: etcd는 클러스터의 모든 상태(Pod/Service/ConfigMap/Secret 등)를 저장하는 key-value
분산 DB. kube-apiserver는 사실상 etcd의 게이트웨이. etcd 장애 시 신규 리소스 생성/조회, 스케줄링,
컨트롤러 반영, kubectl 명령 전체가 마비됨(이미 떠 있는 Pod는 즉시 죽지 않음).

**답변 (복기, Q9-2)**
> etcd는 클러스터 내부 모든 상태를 관리하는 db야 apiserver는 해당 상태를 기반으로 동작함으로
> etcd가 죽으면 apiserver의 장애가 발송하고 클러스터가 마비되는거지

**채점 — 통과.** etcd(상태 저장) → apiserver(그 상태 기반 동작) → 장애 전파 인과관계를 정확히 이해.

### Q10. HPA vs Cluster Autoscaler

**답변 (1차)**
> 둘 다 뭔지 몰라 설명해줘

**설명 제공**: HPA=파드 개수 오토스케일(예: CPU 임계치 넘으면 3→6개), Cluster Autoscaler=노드(EC2)
개수 오토스케일. 둘 다 필요한 이유: HPA가 파드를 늘려도 노드 자원이 없으면 Pending에 머물고(CA
필요), CA로 노드만 늘려도 Pod 수가 그대로면 새 노드가 빈 채로 낭비됨(HPA 필요).

**답변 (복기, Q10-2 — 트래픽 10배 폭증 + 노드 자원 소진 상황)**
> 그럼 신규 노드가 생성이 안될거고 scheduler가 최적의 노드를 찾지 못해서 기존 노드들은 부하가
> 증가할거야 결국 서비스 전체의 장애로 이어나갈수도 있지

**채점 — 부분 통과.**
- HPA만 ON / CA OFF: 결론(서비스 장애 가능)은 맞지만 메커니즘이 부정확. "기존 노드 부하가 증가한다"기
  보다, 신규 필요 Pod가 **스케줄링 자체가 안 돼 Pending으로 대기**하고(이 Pending Pod들은 실행이
  안 되므로 그 자체로 부하를 만들지 않음), **처리 용량이 늘지 않은 채로 트래픽만 10배가 되어 기존
  Pod/노드가 과부하**되는 것이 정확한 인과관계.
- CA만 ON / HPA OFF 케이스: **답변 누락.** (정답: 노드는 늘어나지만 Pod 수가 그대로라 새 노드가
  비어 있고, 트래픽은 여전히 소수 Pod에 몰려 장애를 못 막음.)

### Q11. 네임스페이스 격리의 한계 + RBAC

**답변 (1차, Q11)**
> 네임스페이스는 논리적인 영역에 마스터노드는 당연히 분리못하고 워커노드에 들어갈 파드도 dev/prod
> 분리못하지 그래서 권한 RBAC가 있다는게 이게 무슨 약자인지 모르겟어?

**설명 제공**: RBAC = Role-Based Access Control(역할 기반 접근 제어). "이 계정은 어떤 네임스페이스에서
어떤 리소스를 어떤 동작까지 할 수 있다"를 Role 단위로 정의. QA팀 사고도 RBAC로 QA 계정의 쓰기 권한을
dev/staging에 한정했다면 막을 수 있었음.

**답변 (복기, Q11-2 — dev 부하테스트가 prod 응답 저하를 유발하는 이유)**
> (Q11 답변 재활용, 시나리오 구체 연결 없이 일반론만 서술)

**채점 — 시나리오 연결 누락.** "네임스페이스는 논리적 분리만 하고 물리 자원은 안 나눈다"는 설명 자체는
맞지만, "왜 dev 부하테스트가 prod 응답 저하로 이어지는가"에 대한 구체적 연결이 빠짐. 정답 방향:
dev/prod Pod가 **같은 워커 노드(같은 물리 EC2)에 함께 스케줄링될 수 있고**, ResourceQuota/LimitRange
없이는 dev 부하테스트 Pod가 CPU/메모리를 다 써서 **같은 노드의 prod Pod 자원을 잠식**함.

---

## 5. 오답 복기용 개념 퀴즈 3차 (원리를 구체적 시나리오에 적용)

### Q12. CA만 ON / HPA OFF 상태에서 트래픽 폭증 시 `get pods`/`get nodes`/`top pods` 결과 예측

**답변**
> get pods - 파드는 늘어나지 않을거야 HPA 가 꺼졌으니까 수평확장이 안되겠지, get nodes 는 CA 는
> 켜져있으니까 잘될거야. top pods 시 파드가 늘어나지 않았음으로 기존 파드들의 부하가 늘었을거야

**채점 — 통과 (보강 포인트 1개).**
- `get pods`(Pod 수 그대로), `get nodes`(노드 수는 증가), `top pods`(기존 Pod 부하 증가) 모두 정확.
- 보강: `get nodes`로 확인되는 새 노드들은 Pod 수가 안 늘었으니 **거의 비어 있거나 유휴 상태**일 것 —
  "비용은 쓰는데 문제는 안 풀리는" 가장 비효율적인 조합이라는 관찰까지 하면 더 좋음.

### Q13. 배포 후 신버전 Pod 2개 Pending 상황의 진단 명령 순서

**답변**
> kubectl decribe node pod_name 해서 해당 파드에 무슨 event가 있는지 확인해본다. 아마 배정 가능한
> 파드 못뜰텐데 kubectl get node 또는 decribe nodes 해서 상태를 노드 상태를 확인해본다

**채점 — 통과, 지난 오답 정정됨.** `describe pod`로 Events 확인 → `get/describe node`로 노드 상태
확인, 순서와 목적 모두 정확. 원본 문제 2번의 "kubectl logs로 노드 로그 확인"이라는 오답이 완전히
정정됨. (참고: 이상적으로는 `get pods -o wide`로 대상 Pod부터 특정한 뒤 시작하면 더 좋음.)

### Q14. dev→prod 자원 침범 재발 방지책 — ResourceQuota(A) vs taint/toleration/nodeAffinity(B)

**답변**
> A: 개발환경에 용량 제한을 걸어둔다 안걸어 둔다 부하테스트 설정시 부하를 심하게 줄 경우 제한이 없어
> 용량을 계속 늘리게 될 것임으로 비용이 과다 청구될 것이다.
> B: prod 노드 그룹에 taint를 걸어 아무 파드나 접근못하게하고, toleration으로 해당 노드그룹에
> 접근가능하게 한다. 이와 더불어 nodeAffinity를 통해 파드가 해당 노드에만 생성되도록 지정한다

**채점 — 부분 통과.**
- B는 완벽. taint(출입통제)/toleration(허가증)/nodeAffinity(목적지 강제) 구조 정확히 설명.
- A는 방향이 어긋남: ResourceQuota의 이번 시나리오상 핵심 효과는 "비용 과다 청구 방지"가 아니라
  **"dev 네임스페이스가 요청 가능한 CPU/메모리 총량을 제한해 같은 노드에 있는 prod Pod의 자원을
  침범하지 못하게 하는 것"**.
- 힌트로 요구했던 "하나만 적용 시 뚫리는 케이스"에 대한 답 누락. 정답 방향: A만 있으면 dev/prod가
  여전히 같은 물리 노드에 뜰 수 있어 네트워크/디스크 I/O 등 cgroup 밖 자원 경합은 못 막음. B만 있으면
  prod는 안전하지만 dev 자체의 자원 폭주(비용)는 못 막음 — 그래서 실무에선 A+B 병행.

### Q15. Redis Pod가 다른 노드로 재생성돼 IP가 바뀌어도 `order-service`가 재설정 없이 계속 통신되는 이유

**답변**
> kublet는 scheduler로 부터 파드 생성 명령을 받았을거야. 그래서 파드를 생성하고 iptables에 등록을
> 해놨겠지? 해당 파드는 라벨이 yml에 등록된 이름으로 붙었을거야. 서비스는 해당 라벨에 해당하는
> 노드로 라우팅을 했을거고 kube-proxy는 노드내에 지정된 iptables로 라우팅해 파드로 연결됐을거야

**채점 — 부분 통과, 핵심 오귀속 1개.**
- 맞음: 라벨 매칭으로 Service가 파드를 추적한다는 것, kube-proxy가 iptables로 실제 라우팅을
  수행한다는 것.
- 틀림: **"kubelet이 iptables에 등록한다"**는 부분 — kubelet은 컨테이너 실행과 상태(새 IP) 보고까지만
  담당하고, iptables 갱신은 **오직 kube-proxy의 역할**. 또한 "Service가 노드로 라우팅"이 아니라
  Service는 **라벨이 일치하는 파드들(Endpoints)**을 추적하는 것이 정확함(노드 단위가 아니라 파드 단위).
- 정확한 인과관계: ① kubelet이 새 노드에서 컨테이너 시작 + 새 IP를 API 서버에 보고 → ② Service의
  Endpoints가 라벨 매칭 기준으로 자동 갱신(새 IP 반영) → ③ kube-proxy가 이 변화를 감시해 각 노드의
  iptables/ipvs 규칙을 새 IP로 갱신 → ④ `order-service`는 여전히 고정된 `redis-service` 주소로만
  요청하면 되고, 실제 목적지 갱신은 이 체인이 자동으로 처리.

---

## 6. 후속 논의 — 워커 노드 물리적 분리 (taint/toleration/nodeAffinity)

네임스페이스만으로 안 되는 물리적 dev/prod 분리를, 클러스터를 나누지 않고도 해결하는 방법 정리:

- **노드 그룹 분리**: EKS에서 `dev-nodegroup`/`prod-nodegroup`처럼 워커 노드(EC2) 자체를 용도별로 분리.
- **Taint**: prod 노드에 `kubectl taint nodes prod-node-1 env=prod:NoSchedule` — 이 taint를 견디지 못하는
  Pod는 해당 노드에 스케줄링 자체가 안 됨(입구 통제).
- **Toleration**: prod Pod의 spec에 아래처럼 추가해야 그 노드에 뜰 "자격"이 생김(허가증, 강제는 아님).

  ```yaml
  tolerations:
    - key: "env"
      operator: "Equal"
      value: "prod"
      effect: "NoSchedule"
  ```

- **nodeAffinity**: "반드시 이 라벨의 노드로만 가라"는 목적지 강제(노드에 `env=prod` 라벨 필요).

  ```yaml
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: env
                operator: In
                values:
                  - prod
  ```

- 정리: taint=노드 쪽 출입 통제, toleration=Pod 쪽 출입증, nodeAffinity=Pod 쪽 목적지 지정. 셋을 같이
  써야 "다른 팀 Pod가 실수로 못 들어오고, 내 Pod는 반드시 여기로만 간다"가 둘 다 보장됨. 단, **컨트롤
  플레인(API 서버/스케줄러/etcd)은 이 방법으로도 여전히 공유**되며, 이것이 클러스터 물리 분리(A안)와의
  근본적 차이.

---

## 7. 전체 총평 — 남은 학습 포인트

- 스케줄러(배치 결정) vs 컨트롤러-매니저(상태/수량 유지) vs kubelet(실제 실행) 3자 구분은 이제 확실함.
- Pending 트러블슈팅 명령 순서(`describe pod` → Events → `describe node`)는 Q13에서 재검증 완료 —
  지난 원본 문제 2번의 오답이 정정됨.
- HPA/CA 조합에서 "한쪽만 켜졌을 때의 실패 모드"는 CA-only 케이스(Q12)로 재검증 완료. 다만 새 노드가
  유휴 상태로 낭비된다는 관찰까지는 아직 스스로 안 나옴 — 다음에 재확인 필요.
- **주어진 시나리오에 원리를 구체적으로 연결하는 것**은 이번 3차 퀴즈에서 상당히 개선됨(Q12, Q13은
  통과). 다만 여전히 반복되는 패턴 하나: **"어떤 컴포넌트가 실제로 그 작업을 하는가"를 kubelet에게
  몰아서 귀속시키는 경향**(Q1의 "스케줄러가 설치까지 명령" → Q15의 "kubelet이 iptables 등록"). kubelet은
  "실행/보고"까지만 담당하고, 네트워킹 규칙(iptables)은 kube-proxy, 배치 결정은 scheduler, 상태 반영은
  controller-manager라는 **역할 경계선**을 한 번 더 정리해보면 좋음.
- Q14의 ResourceQuota처럼, "이 설정이 존재하는 이유가 비용 때문인지 자원 경합(같은 노드 공유) 때문인지"
  구분하는 연습도 이어가면 좋음.
