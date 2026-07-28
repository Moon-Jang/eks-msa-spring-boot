# ⚠️ 스포일러 — 채점 루브릭 (2026-07-28 오토스케일링·GitOps·모니터링)

이 문서는 "정답"이 아니라 **평가 루브릭**이다. 서술형 문제가 대부분이므로 아래 모범 답안은 하나의
예시일 뿐 유일한 정답이 아니다. 핵심 포인트를 근거와 함께 짚었는지를 본다.

근거 위치 표기: `S27` = `contents/video_scripts/27-pod-autoscaling-script.md` 등, `CH` =
`contents/07-spring-백엔드-서버-배포.md`.

## 배점 가이드

- 총 100점 기준 권장: 문제1 12 / 문제2 12 / 문제3 16 / 문제4 14 / 문제5 14 / 문제6 12 / 문제7 14 /
  문제8 6 (문제8은 종합 추론이므로 부분 점수 관대하게)
- `⚠ 강의 범위 밖` 항목은 **가점 전용**. 언급 없어도 감점하지 않는다.
- "명령을 쓰라"는 문항은 문법이 완벽하지 않아도 **의도와 필수 옵션(`-n`, `-f`, `-w`, `--` 등)** 이
  맞으면 정답 처리한다.

---

## 문제 1. 파드 오토스케일링 설계 (S27 0:05~13:57)

### (a) 스케일 아웃을 택하는 이유 — 반드시 두 축 모두

1. **실시간성**: 운영 중인 서버의 CPU/메모리를 물리적으로 갈아끼우는 것은 어렵다. 반면 옆에 서버를
   한 대 더 두고 로드밸런서가 트래픽을 양쪽으로 분산하게 하면 **사실상 무중단**으로 처리량을 늘릴 수
   있다.
2. **비용**: 동일 스펙 서버를 옆에 두면 비용은 정확히 산술적으로 2배가 된다. 그런데 한 대의 스펙을
   2배(16GB→32GB, 32→64, 64→128)로 올리면 특정 임계치부터 비용이 **산술급수가 아니라 기하급수적으로**
   증가할 수 있다. 따라서 대수를 늘리는 편이 비용 효율이 좋다.

- 감점: "그냥 k8s가 스케일 아웃만 지원해서"처럼 근거 없는 답. 비용 곡선의 비선형성을 언급하지 않으면
  (a) 절반만 인정.

### (b) 리소스 제한이 선행되어야 하는 이유

- 리소스 제한이 없으면 부하가 발생한 파드가 **노드(EC2)의 자원을 최대치까지 다 잡아먹는다.**
- 그러면 파드를 옆에 늘릴 여유 자원이 남지 않으므로 **파드 오토스케일 자체가 의미가 없어진다.**
  이 경우엔 파드가 아니라 **EC2(노드) 오토스케일**을 해야 한다.
- 반대로 예를 들어 노드 메모리 2GB / 파드 limit 500MB이면 파드를 4대까지 늘릴 수 있고, 그때 비로소
  파드 스케일 아웃이 의미를 갖는다.

### (c) 세 요소의 역할 분담 — HPA에 없는 기능이 핵심

| 요소 | 역할 |
| --- | --- |
| Deployment | 파드를 실제로 만들고 몇 대를 유지할지(replicas) 결정 |
| HPA | 임계치·min/max 설정을 갖고 판단해서 **Deployment에게** 파드를 늘려라/줄여라 명령 |
| metrics-server | **파드의 실시간 리소스 사용량을 모니터링**해서 HPA에 보고 |

- **핵심 포인트**: HPA에는 파드를 모니터링하는 기능이 **없다.** 임계치/min/max 같은 설정값만 들어
  있고, 실측은 metrics-server가 해서 HPA에 지속적으로 보고한다.
- metrics-server를 커스텀할 필요가 없는 이유: 설치되면 클러스터에 존재하는 HPA를 알아서 찾아
  그 HPA가 관리하는 파드들을 모니터링한다. 그래서 인터넷의 `components.yaml`을 그대로 apply한다.
  반대로 HPA는 어떤 Deployment를 볼지·몇 대까지·임계치 얼마인지가 우리 사정이므로 반드시 커스텀한다.
- 감점: HPA가 직접 CPU를 측정한다고 서술하면 이 문항 오답.

### (d) 값 설계 + 여유 세팅의 이유

- 값 자체는 정답 없음. 다만 다음이 근거로 들어가야 한다.
  - 점심·저녁 피크가 있는 서비스이므로 `minReplicas`는 평시 트래픽을 감당할 수준(2 이상), `maxReplicas`
    는 노드 용량과 함께 고려(무한정 크게 잡아도 노드가 없으면 Pending).
  - `averageUtilization`은 강의 발화 기준 **실무에서는 70~80%** 수준으로 잡는 것이 적절. 강의가 50%,
    30%로 낮춘 것은 순수하게 **테스트 목적**(부하가 안 올라가서)이라는 점을 구분했으면 가점.
- **반드시 포함**: 파드를 만드는 것은 일종의 인프라 작업이라 **파드 생성 중 CPU가 순간적으로 튄다.**
  임계치가 너무 낮고 CPU limit이 너무 타이트하면, 파드를 띄우는 중의 CPU 스파이크를 "부하가 왔다"로
  오인해 파드를 연쇄적으로 계속 만들어버릴 수 있다. 그래서 **리소스 limit을 여유롭게 잡거나, 임계치를
  여유롭게 잡거나, 둘 다** 여유롭게 세팅해야 한다.
- 감점: 임계치를 낮게 잡을수록 좋다고만 쓰면 이 문항 절반.

### (e) minReplicas vs Deployment replicas

- **HPA가 우선한다.** Deployment `replicas: 2`, HPA `minReplicas: 3`이면 파드는 **3대**가 된다.
- 실무 권장: 혼선을 막기 위해 **Deployment의 replicas와 HPA의 minReplicas를 서로 맞춰 두는 것**이 좋다.
- (문제 8-(a)에서 이 지식이 ArgoCD selfHeal 충돌 추론의 기반이 된다.)

---

## 문제 2. HPA 트러블슈팅과 부하 테스트 (S27 14:11~29:24)

### (a) `<unknown>` 해결 절차

```bash
kubectl delete -f hpa.yml                # 1. HPA 삭제
kubectl delete -f <metrics-server components.yaml>   # 2. metrics-server 삭제
kubectl apply -f <metrics-server components.yaml>    # 3. metrics-server 재설치
kubectl apply -f hpa.yml                 # 4. HPA 재적용
```

- 근본 원인: metrics-server의 yaml이 선언하는 리소스 중 **이미 클러스터에 존재하는 요소와 충돌**했을 수
  있다(이전 잔여 리소스, "찌꺼기"). 선언된 리소스를 다 지우고 다시 apply하면 충돌이 풀린다.
- 순서가 뒤바뀌어도(HPA를 나중에 지우는 등) 의도가 맞으면 인정. metrics-server 재설치 없이 HPA만
  재적용하는 답은 오답.

### (b) 부하 발생 명령 순서

```bash
kubectl get pods -n bradkim
kubectl exec -it <파드명> -n bradkim -- /bin/sh
apk add --no-cache curl          # Alpine이므로 apt-get/yum이 아니라 apk
while true; do curl -s http://brad-order-backend-service/product/list; done
```

- **Alpine 반영이 핵심**: Ubuntu 계열 `apt-get`, RedHat 계열 `yum`이 아니라 경량 Alpine이므로 `apk`.
- `--` 뒤에 셸을 지정하는 문법, `-n <ns>` 누락 여부는 감점하지 않되 언급하면 가점.

### (c) 파드 IP가 아니라 Service를 호출하는 이유

- Service를 호출하면 Service가 **라운드로빈으로 로드밸런싱**하므로 뒤에 있는 파드 전체에 부하가
  공평하게 분산된다. 특정 파드만 때리면 HPA가 보는 지표(평균 사용률)가 왜곡되고, 실제 서비스 트래픽
  경로(ingress → service → pod)와도 달라진다.
- `/product/list`는 DB까지 조회하는 요청이라 부하가 잘 걸린다는 점을 언급하면 가점.

### (d) 4대까지 늘지 않은 이유

- HPA 지표는 `type: Utilization` + **`averageUtilization`, 즉 파드들의 평균 CPU 사용률**이다.
- 파드가 3대로 늘어나면 같은 총 부하가 3대로 분산되므로 **파드당 평균이 내려간다**(58% → 43%). 임계치
  50% 아래로 떨어지면 HPA는 더 늘릴 이유가 없다고 판단한다.
- 판단: **설정 오류가 아니라 정상 동작.** HPA는 "평균을 임계치 근처로 수렴시키는" 컨트롤러이므로,
  주어진 부하량으로 평균이 임계치를 넘지 못하면 그 수준에서 멈추는 것이 정상이다. 더 많이 늘리려면
  임계치를 낮추거나 **더 강한 부하 도구**를 써야 한다(강의에서 `while` + `curl`로는 70%에 도달하지
  못했다고 언급).
- 감점: "maxReplicas가 잘못 설정됐다", "metrics-server 버그"류 답변.

---

## 문제 3. 인스턴스 오토스케일링 아키텍처와 권한 (S28, S29)

### (a) maxReplicas만 올렸을 때

- 파드가 계속 늘어나다가 **노드의 물리 자원(CPU/메모리) 한계**에 도달하면 더 이상 스케줄될 수 없고,
  파드가 **`Pending` 상태**에 빠진다. 파드는 실제 CPU·메모리를 점유하므로 노드가 감당 못하면
  정상 실행되지 않는다.
- (강의는 max 4까지는 현재 노드가 감당 가능했고, 10·20으로 올려 Pending을 유도했다.)

### (b) EKS 노드그룹과 ASG

- EKS에서 노드그룹을 만들면 **AWS Auto Scaling Group(ASG)이 만들어진다.** 즉 노드(EC2) 관리 주체는
  EKS가 아니라 ASG이고, **EKS는 ASG가 만들어주는 노드를 빌려 쓰는 입장**이다.
- 노드 수를 늘리려면 ASG의 **원하는 용량 / 최소 용량 / 최대 용량**을 바꾸거나, EKS 노드그룹을 편집하면
  된다(노드그룹을 편집하면 ASG 값이 함께 바뀐다).
- ASG는 이미 "최대 N대까지 증설하는 기능"을 갖고 있지만 **요청이 오기 전까지는 늘려주지 않는다.**
  따라서 클러스터 내부 자원 부족을 감지해 ASG에 요청을 보내줄 주체가 필요하고, 그게
  cluster-autoscaler다.

### (c) cluster-autoscaler의 정확한 역할

- EKS 내 자원(특히 **자원 부족으로 Pending에 빠진 파드**)을 모니터링하다가, **ASG에게 노드 증가/감소를
  요청**하는 프로그램. 클러스터에 Pod로 띄운다.
- "노드 수를 자동 조절한다"가 부정확한 이유: **실제로 EC2를 만들고 없애는 주체는 ASG**이고,
  cluster-autoscaler는 요청만 보낸다.

### (d) ASG 태그 2개

| 키 | 값 | 의미 |
| --- | --- | --- |
| `k8s.io/cluster-autoscaler/enabled` | `true` | 이 ASG가 cluster-autoscaler의 관리 대상임을 표시 |
| `k8s.io/cluster-autoscaler/<클러스터이름>` | `owned` | 이 ASG가 **특정 클러스터**에 속하고 그 클러스터의 autoscaler가 관리함을 표시 |

- 의미 요약: **ASG에 대한 통제권을 cluster-autoscaler에게 맡긴다**는 선언. 이 태그가 있어야 ASG가
  autoscaler의 요청을 받아들인다.
- 최근 생성되는 EKS는 노드그룹 생성 시 이 태그가 **자동으로 붙는다.** 과거에는 안 붙었으므로 없으면
  수동 추가.

### (e) Pod에 IAM 역할을 부여하는 과정 — 5단계 모두 확인

1. **사용자 vs 역할**: 사용자는 (편의상) 외부의 사람/주체로 콘솔 로그인·Access Key 발급에 쓰이고,
   **역할(Role)은 AWS 자원들끼리 서로 접근할 수 있게 권한을 주는 계정**이다. 둘 다 정책(policy)의
   묶음으로 구성된다.
2. **엔터티 단위**: AWS가 역할을 부여하는 기본 단위는 **AWS 서비스(엔터티)** — EC2, RDS, S3, ASG, EKS
   등. 그런데 **Pod는 AWS 서비스가 아니라 EKS라는 서비스 안에서 돌아가는 쿠버네티스 요소**여서, 기본
   신뢰 대상이 아니다. 그래서 "이 Pod는 신뢰할 수 있는 엔터티다"라고 직접 등록해줘야 한다.
3. **OIDC 공급자 등록**: EKS 클러스터는 생성 시 **OpenID Connect 공급자 URL**을 발급받는다. EKS는 AWS
   자원이므로 이 ID 값이 **EKS가 보증하는 신원**이 된다. 이걸 IAM의 "ID 제공업체"로 등록하면
   EKS 내부 요소가 AWS의 role을 사용할 수 있게 되는 길이 열린다.
4. **`sts.amazonaws.com`**: STS는 **보안 토큰 서비스**로, `AssumeRole`/`AssumeRoleWithWebIdentity`
   같은 **임시 보안 자격 증명 발급**을 담당한다. 대상(audience)에 STS를 넣는다는 것은 "이 OIDC ID를
   가진 주체는 STS를 이용해 역할을 사용 요청할 수 있다"는 설정이다.
5. **요청 흐름**: Pod가 STS에 "나는 이 OIDC ID를 가진 신뢰할 수 있는 엔터티다, 역할을 쓰게 해달라"고
   요청 → STS가 임시 자격 증명 발급(허용) → Pod가 그 역할로 **ASG에 EC2 증설/감소 요청** → ASG가 EC2를
   증감.

- 감점: STS를 "로그인 서비스" 정도로만 쓰면 4번 절반. "Pod에 그냥 역할을 붙이면 된다"는 답은 2번 오답.

### (f) 신뢰 정책 Condition과 정책 3개

- `"<OIDC>:sub": "system:serviceaccount:kube-system:cluster-autoscaler"`는
  **kube-system 네임스페이스의 `cluster-autoscaler`라는 ServiceAccount를 사용하는 Pod만** 이 Role을
  assume할 수 있게 제한한다.
- 이 조건이 없으면 **같은 클러스터(같은 OIDC)의 아무 Pod/ServiceAccount나 이 역할을 가져다 쓸 수 있게**
  된다 — 즉 EKS·ASG·EC2 전체 권한이 클러스터 내 임의 워크로드에 노출되는 과도한 권한 문제. 강의 발화
  ("아무 클러스터 오토스케일러가 사용하면 안 되겠죠")와 같은 취지면 인정.
- 정책 3개와 이유:
  - `AmazonEKSClusterPolicy` — EKS 전체 자원 상황을 모니터링해 자원 부족을 인지하기 위해
  - `AutoScalingFullAccess` — ASG에 노드 증감 요청을 보내기 위해
  - `AmazonEC2FullAccess` — EC2 자원 상태(부족 여부) 확인 및 인스턴스 관련 작업을 위해 (EKS·ASG에
    포함된 개념일 수 있지만 EC2도 독립적인 AWS 서비스라서 별도로 필요)
- 가점: 실무라면 FullAccess는 과도하고 최소 권한으로 좁혀야 한다는 지적 (`⚠ 강의 범위 밖`).

---

## 문제 4. cluster-autoscaler 배포와 검증 (S30)

### (a) 반드시 수정할 3곳

1. **ServiceAccount의 `annotations`에 IAM Role ARN** — 원작자는 사용자의 AWS 계정/Role ARN을 알 수 없다.
2. **컨테이너 이미지 버전 상향 + `--cluster-name=<클러스터명>`** — 배포된 예제의 버전이 낮고(강의는
   `v1.29.0`으로 올림), 어떤 클러스터에서 돌지는 사용자마다 달라 원작자가 알 수 없다.
   `--node-group-auto-discovery`의 클러스터명도 함께 맞춰야 한다.
3. **`env`의 `AWS_REGION`** (강의는 `ap-northeast-2`) — 어떤 리전인지도 사용자마다 달라 알 수 없다.

- 공통 근거: **작성자 입장에서 알 수 없는 사용자별 값(계정/클러스터/리전)** 이라 비워둔 것.

### (b) ServiceAccount에 Role 연결

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/autoscale-role
```

- 연결 고리: Deployment의 `spec.template.spec.serviceAccountName: cluster-autoscaler`. 이 SA를 쓰는
  Pod가 곧 위 Role을 부여받는다.
- 문제 3-(f)와의 맞물림: 신뢰 정책의 `sub` 조건이 `system:serviceaccount:kube-system:cluster-autoscaler`
  이므로, **SA의 이름과 네임스페이스가 정확히 일치해야** assume이 성공한다. 이름/네임스페이스를 바꾸면
  신뢰 정책도 같이 바꿔야 한다. (이 대응 관계를 짚으면 큰 가점)
- ARN은 IAM 역할 상세 화면에서 복사한다는 언급이면 충분.

### (c) 노드가 안 늘어난 원인

- **노드그룹(=ASG)의 최대 크기가 2로 잡혀 있었다.** 최소 2 / 원하는 2 / **최대 2**이면 autoscaler가
  요청해도 ASG가 늘릴 수 없다.
- 해결: EKS → 컴퓨팅 → 노드 그룹 → 편집에서 **최대 크기를 3(이상)으로** 상향 (강의는 2/2/3).
- 상한으로서의 의미: cluster-autoscaler는 어디까지나 ASG에게 요청하는 주체이므로 **ASG의 최대 용량이
  절대 상한**이다. HPA의 `maxReplicas`를 크게 잡아도 노드 상한에 걸리면 파드는 Pending에 머문다.

### (d) Pending 파드 진단

- `kubectl logs`가 무의미한 이유: **프로그램이 아직 실행되지 않았다.** 자원이 부족해 스케줄조차 못
  됐으므로 애플리케이션 로그가 존재하지 않는다.
- 대신:
  ```bash
  kubectl describe pod <파드명> -n bradkim
  ```
- 확인할 것: `Events` 섹션의 스케줄링 실패 메시지 —
  `0/N nodes are available: ... Insufficient memory, Insufficient cpu` 형태로 **자원 부족**이 찍혀 있다.
- 가점: `kubectl get pods -n <ns>`로 상태 확인 → `describe`로 이벤트 확인 → AWS 콘솔(EKS 컴퓨팅)에서
  노드 증설 여부 확인, 이라는 순서를 제시한 경우.

### (e) 증설은 빠르고 감축은 느린 비대칭

- 증설이 빠른 이유: **부하 상황은 즉시 대처해야 하는 문제**다. 지연되면 서비스가 실제로 못 버틴다.
  (강의에서도 즉시 노드가 생성됐다.)
- 감축이 느린 이유(10~30분): 부하가 잠깐 사라졌다고 바로 노드를 없애면 **다시 자원 부족 사태가
  반복**될 수 있다. 그래서 보수적으로 지연시킨다.
- 이 서비스에 대한 판단(정답 없음, 근거 필수):
  - 안정성 측면 **유리** — 점심 피크와 저녁 피크 사이 간격이 짧으면, 점심 후 노드가 바로 줄지 않아
    저녁 피크에 빠르게 대응할 수 있다(워밍 상태 유지).
  - 비용 측면 **불리** — 피크가 지나도 한동안 노드 비용을 계속 낸다. 피크 간격이 길다면 낭비.
  - 결론적으로 **피크 간격 대비 감축 지연 시간**을 근거로 트레이드오프를 판단했으면 만점.

### (f) 테스트 후 delete한 이유

- 이유: 이후 실습할 **ArgoCD, 프로메테우스/그라파나 같은 인프라 요소를 올릴 노드 자원이 부족할 것**
  같아서, 꼭 필요한 것만 남기고 정리한 것. **순수하게 실습 환경의 자원 절약 목적.**
- 실무에서는 안 되는 이유: HPA와 cluster-autoscaler는 **트래픽 급증 시 자동 대응의 핵심**이다. 지워두면
  피크에 파드가 Pending에 빠지거나 서비스가 부하를 못 버티고, 사람이 수동 개입해야 한다. 강의도
  "운영 서버에는 당연히 유지해야 한다"고 명시.
- (S31 21:03 근거를 가져오면 가점: autoscaler를 지워둔 탓에 ArgoCD 파드가 Pending에 빠졌고 EC2를 **수동**
  으로 늘려야 했다.)

---

## 문제 5. ArgoCD GitOps 도입 판단 (S31)

### (a) 확신할 수 있는 영역 vs 없는 영역

- **확신할 수 있는 영역: 애플리케이션 소스코드/이미지.** GitHub Actions가 GitHub의 소스를 기준으로
  빌드해 ECR에 push하는 과정이 자동화되어 있으므로, 지금 도는 이미지는 GitHub 소스 기반임이 보장된다.
- **확신할 수 없는 영역: 쿠버네티스 매니페스트(Deployment/Service/Ingress 등).** GitHub Actions에는
  `apply` 단계가 없고 `rollout restart` 정도만 자동화되어 있다. 매니페스트는 **개발자가 로컬에서 직접
  apply**하기 때문에, 클러스터의 실제 상태가 GitHub의 yaml과 같다고 보장할 수 없다.
- 감점: "둘 다 자동화되어 있다"류 답변.

### (b) 임의 apply가 만드는 문제

- **안정성**: 팀이 합의한 구성이 아니라 개별 개발자가 임의로 자원을 바꾸거나 삭제할 수 있다. GitHub에는
  replicas 2인데 클러스터는 3대가 도는 등 실제 인프라가 합의와 어긋난 상태로 운영된다.
- **이력 관리**: 그런 변경이 **어디에도 기록에 남지 않는다.** 누가 언제 왜 바꿨는지 추적 불가.

### (c) ArgoCD 도입 후

- ArgoCD가 GitHub의 매니페스트와 클러스터를 동시에 지켜보다가, 차이가 있으면 **GitHub 기준으로 강제
  sync**한다. 클러스터에 없어야 할/있어야 할 자원을 만들고, 값이 다르면 GitHub 값으로 원상복구한다.
- 개발자 작업 방식: 클러스터에 직접 apply하지 않고 **소스코드를 수정해 GitHub에 push**한다. 그러면
  ArgoCD가 알아서 적용하고, 변경은 **커밋 이력**으로 남는다(누가 언제 왜).
- 가점: GitHub Actions에 `apply` 스텝이 필요 없어진다는 언급(S31 30:12).

### (d) prune / selfHeal + ArgoCD가 하지 않는 일

- `prune: true` — **GitHub에서 삭제된 리소스는 클러스터에서도 자동 삭제.** 끄면 삭제는 반영되지 않는다.
- `selfHeal: true` — **클러스터 안에서 수동으로 변경된 리소스를 GitHub의 원래 상태로 자동 복구.**
  강의 발화대로 "GitHub + ArgoCD로 이 아키텍처를 설계한 이유"에 해당하는 핵심 옵션.
- **ArgoCD가 하지 않는 일**: **GitHub에 선언되어 있지 않은 리소스를 누가 새로 만들었다고 해서 삭제하지는
  않는다.** (있어야 할 게 없거나 값이 다른 경우만 맞춘다.)
- 사각지대: 따라서 누군가 GitHub에 없는 자원을 임의로 apply하면 **ArgoCD로는 잡히지 않고 그대로
  살아남는다.** 즉 GitOps만으로 "클러스터에 선언되지 않은 것이 없다"를 보장할 수는 없으며, 결국
  kubectl 권한 통제(RBAC)나 리뷰 프로세스가 함께 필요하다는 결론까지 가면 가점.
- 주의: `prune`이 이 사각지대를 해결한다고 답하면 오답 — prune은 "GitHub에서 삭제된 것"에만 작동한다.

### (e) Application 자원

- 필요한 이유: 인터넷의 install.yaml은 **기능만** 설치한다. ArgoCD는 "어떤 Git 저장소의 어떤 경로에 있는
  자원을 어떤 네임스페이스와 맞춰야 하는지"를 모르므로, 그 정보를 알려주는 선언이 필요하다.
- 필드:
  - `repoURL` — 바라볼 GitHub 저장소
  - `targetRevision` — 바라볼 브랜치(예: `main`). **로컬 변경이 아니라 GitHub에 push된 내용이 기준**
  - `path` — 저장소 내 매니페스트 경로(예: `4.ordersystem/k8s` / 강의 실습은 `2.ordersystem/k8s/...`).
    소스 전체가 아니라 인프라 자원이 모인 폴더로 한정
  - `destination.server` — 보통 `https://kubernetes.default.svc`(ArgoCD 자신이 설치된 클러스터 내부 주소)
  - `destination.namespace` — 동기화 대상 네임스페이스(예: `bradkim`)
- **네임스페이스 3개면 Application 3개.** Application 하나는 **한 개의 네임스페이스만** 바라보기 때문.
  (대규모 시스템에서 Application이 여러 개가 되는 이유.)

### (f) argocd 파드 Pending 핸즈온

- 원인: **노드 자원 부족.** ArgoCD는 큰 프로그램이라 redis, controller 등 여러 파드를 만들어 자원을
  많이 쓴다. 노드 2대로는 부족.
  ```bash
  kubectl get pods -A                 # Pending 확인
  kubectl describe pod <파드> -n argocd  # Insufficient cpu/memory 확인
  ```
- 해결: EKS 노드그룹의 원하는 용량을 3으로 상향(최대 3 범위 내).
- **"다시 apply해야 하는가?" → 아니다.** 자원에 대한 **선언은 이미 마스터 노드(컨트롤 플레인)에
  등록되어 있다.** 노드만 추가되면 마스터 노드가 "자원이 생겼으니 자원 부족으로 못 만들던 것들을
  만들어야겠다"고 판단해 워커 노드에 알아서 파드를 띄운다.
  → 같은 이유로 **실습을 안 할 때 EC2를 꺼둬도** 나중에 다시 켜면 재apply 없이 복구된다(비용 절약 팁).
- cluster-autoscaler가 살아 있었다면: **애초에 Pending이 발생하지 않고** autoscaler가 자원 부족을 감지해
  ASG에 요청, 최대 노드 수까지 자동 증설했을 것이다. 강의는 앞서 autoscaler를 delete했기 때문에 수동
  증설이 필요했다.
- 감점: "ArgoCD 설치가 실패했으니 다시 apply해야 한다"는 답.

---

## 문제 6. ArgoCD 퍼블릭 대시보드와 Ingress 분기 (S32)

### (a) port-forward의 두 포트

- `8080` — **내가 로컬에서 입력할(접속할) 포트.** 8081, 8082 등으로 **자유롭게 바꿔도 된다.**
- `443` — **argocd-server Service가 열어둔 포트.** 서비스가 여는 포트만 써야 하므로 **`443` 또는 `80`**
  중 하나여야 한다(그 Service는 80과 443 두 개를 열어두고 둘 다 Pod의 8080을 타깃으로 한다).
- `svc/`는 대상이 Service임을 명시하는 것이며 생략 가능하다는 언급이면 가점.

### (b) 공용으로 못 쓰는 이유 + 실무 불편

- 이 명령은 내 PC에서 실행한 것이고, 내 PC에는 `kubectl`과 `aws configure`(클러스터 접근) 세팅이 되어
  있다. **환경 세팅이 안 된 다른 사람은 이 명령을 가져가도 의미가 없고**, `localhost:8080`은 애초에 내
  로컬 주소다.
- 실무 불편: 새로운 자원이 클러스터에 적용될 때 ArgoCD가 재시작되면 **port-forward가 무효화**되어
  매번 다시 실행해야 한다. 터미널 창을 닫으면 접속이 끊긴다.

### (c) HTTPS-to-HTTPS 문제 — 4요소 모두

1. **Ingress가 하는 일**: 사용자가 HTTPS로 보낸 **암호문을 Ingress 단에서 복호화**한다. 암호화는 통신
   구간에만 적용되고, Ingress를 지난 뒤 백엔드로는 평문이 전달된다.
2. **Spring 서버에서 문제가 없던 이유**: 우리 Spring 서버 Pod는 HTTPS 인증 처리가 되어 있지 않다.
   평문을 받을 준비가 된 서버였으므로 Ingress가 복호화해 넘겨줘도 정상 동작했다.
3. **암호문을 그대로 넘기는 대안이 불가한 이유**: ArgoCD 서버 Pod는 **내부적으로 HTTPS로 동작**해서
   암호문을 받아 스스로 복호화할 준비를 하고 있다. 하지만 우리가 쓰는 Ingress는 **nginx 기반**이고,
   **암호화된 데이터를 그대로 백엔드로 넘기는 HTTPS→HTTPS 라우팅을 지원하지 않는다.**
4. **해결**: `argocd-server` Deployment의 컨테이너 `args`에 **`--insecure`** 한 줄을 추가해 Pod가
   HTTPS가 아닌 HTTP로 뜨게 한다.
   ```yaml
   containers:
   - args:
     - /usr/local/bin/argocd-server
     - --insecure
   ```
   보안상 문제가 없는 이유: **사용자~Ingress 구간은 이미 HTTPS로 인증 처리되어 있다.** 그 뒤 클러스터
   내부 구간은 이미 인증된 레벨이라, 중간에 데이터가 노출돼도 실질적 위협이 되지 않는다.
   그리고 Ingress에서 `argocd-server` Service의 **80** 포트로 보내면 80 → Pod 8080으로 전달된다.
- 감점: `--insecure`만 쓰고 "왜 안전한지"를 못 쓰면 절반. Spring 서버 대비 차이(2번)를 못 짚으면 절반.

### (d) `kubectl edit`을 쓴 이유

- 우리는 이 스크립트를 **다운로드해서 관리한 것이 아니라** 인터넷 URL을 그대로 `apply`했기 때문에,
  로컬에 수정할 파일이 없다. 그래서 **클러스터에 이미 적용된 자원을 직접 수정**하는
  `kubectl edit deployment argocd-server -n argocd`를 사용한다.
- 저장 후: 변경이 즉시 반영되어 **argocd-server가 rollout(재시작)되고 새 파드가 만들어진다.**
- 가점: 실무라면 이 yaml도 저장소에 가져와 관리(=GitOps 대상)하는 편이 옳다는 지적. 강의도 "실무에
  있으면 당연히 가져와서 커스텀해야 한다"고 언급.

### (e) 동일한 ADDRESS와 도메인 기반 분기

- 그 주소의 정체: 앞서 **Ingress Controller를 적용했을 때 생성된 (네트워크) 로드밸런서 주소.** 두
  Ingress가 같은 ingress-controller/LB를 공유하므로 ADDRESS가 동일하다.
- 흐름: 사용자가 `argo.<도메인>` 입력 → Route 53이 LB로 라우팅 → **ingress-controller가 Host 헤더를
  보고 어느 Ingress 규칙인지 분기** → 그 Ingress가 지정한 Service(`argocd-server`) → Pod.
  `server.<도메인>`이면 같은 LB를 타고 오더 시스템 Ingress → 오더 백엔드 Service → Spring Pod.
- 서브도메인 추가 시 필요한 것: **Ingress 1세트 + Certificate(+Secret) 1세트 + Route 53 A 레코드 1개.**
  HTTPS 인증은 도메인 기반이므로 **도메인마다 인증서를 따로 발급**해야 한다(강의는 직관적 이해를 위해
  따로 발급; 한꺼번에 받는 방법도 있다고 언급). `Certificate`의 `dnsName`은 Ingress의 `host`와
  **반드시 일치**해야 하고, `Certificate`의 `secretName`은 Ingress `tls.secretName`과 일치해야 한다.
  `ClusterIssuer`는 **재사용 가능**하다.
- Route 53 설정: 호스팅 영역에서 레코드 생성 → 서브도메인 입력 → **A 레코드 + 별칭(Alias)** → 엔드포인트
  는 네트워크 로드밸런서(서울 리전) 선택 → 약 60초 전파 대기.
- 감점: 서브도메인마다 로드밸런서가 하나씩 더 필요하다고 답하면 오답.

### (f) OutOfSync 판단

- 발생 이유: ArgoCD가 GitHub의 스크립트 전체를 읽어 클러스터 상태와 비교하는데, **쿠버네티스가 의미
  없는 설정을 적용 시 빼버리거나 기본값을 채워 넣는 경우**가 있어 실제로는 차이가 없는데 차이로
  잡히기도 한다. `DIFF` 버튼으로 어느 부분이 다른지 확인할 수 있다.
- 따라서 **OutOfSync = 무조건 장애가 아니다.** DIFF를 보고 중요도를 판단하면 된다.
- 크리티컬한 예: **replicas가 다른 경우**(GitHub 2대인데 클러스터 3대) — 실제 가용성/비용에 직결.
  또는 이미지 태그·env/Secret 참조·resources 값 차이 등 서비스 동작에 영향을 주는 차이.

---

## 문제 7. 프로메테우스 · 노드 익스포터 · 그라파나 (S33, S34)

### (a) 모니터링 대상의 차이

- HPA(+metrics-server)와 ArgoCD로 본 것은 전부 **파드/쿠버네티스 자원 차원**이었다. 파드 CPU 점유율,
  파드 개수, 어떤 Service/Ingress/Deployment가 적용되어 있는지 등.
- 프로메테우스/그라파나로 새로 보는 것은 **노드(물리 컴퓨팅 자원) 차원** — 노드의 CPU 사용률, 메모리,
  디스크, 커널/하드웨어 상태.
- **한 번도 물리 컴퓨팅 자원을 모니터링해본 적이 없었고**, 그것은 전문 프로그램(익스포터+수집기+
  대시보드)의 도움이 필요한 영역이다.

### (b) 데이터 흐름과 책임

- **노드 익스포터**: 각 노드(인스턴스)에서 **하드웨어/OS 리소스 정보를 실시간 수집**해 프로메테우스가
  읽을 수 있는 형태로 노출.
- **프로메테우스**: 각 노드 익스포터에 **접근해 정보를 가져오고(pull), 정제**한다. 그라파나가 요구하는
  형태로 가공.
- **그라파나**: 프로메테우스를 데이터 소스로 삼아 **UI 대시보드로 시각화**. 자체적으로 수집하지 않는다.
- 다른 익스포터와도 연결 가능하다는 의미: 프로세스를 보려면 process-exporter, nginx를 보려면
  nginx-exporter를 붙인다. 즉 **프로메테우스는 수집 대상별 익스포터를 갈아끼우는 확장 구조**이고,
  대상마다 데이터 형식이 다르므로 그라파나 대시보드 템플릿도 대상별로 따로 있다(S34).

### (c) DaemonSet

- `DaemonSet`은 **클러스터 내 모든 노드에 파드를 하나씩 자동으로 배포**해주는 kind다. 노드가 3대면
  apply만으로 3대에 각각 1개씩 뜬다.
- 적합한 이유: 노드 익스포터는 **각 노드의 하드웨어 정보를 그 노드 안에서** 수집해야 한다. Deployment로
  replicas를 지정하면 어느 노드에 몇 개가 뜰지 보장되지 않아 특정 노드를 놓칠 수 있다. 노드가
  오토스케일로 추가돼도 DaemonSet이 자동으로 따라붙는다는 점을 언급하면 가점.

### (d) Service 대신 hostPort — 핵심 문항

- Service를 쓰면 안 되는 이유: Service는 기본적으로 **라운드로빈으로 로드밸런싱**한다. 프로메테우스는
  **모든 노드 익스포터 파드 각각의 정보가 전부 필요한데**, Service를 거치면 요청이 세 파드 중 하나로만
  라우팅되어 특정 파드의 데이터만 얻게 된다.
- `hostPort`가 하는 일: **컨테이너 포트를 노드 자체의 포트로 직접 노출.** 각 노드는 고유 IP를 갖고
  있으므로 `<노드IP>:9100`으로 호출하면 그 노드 안의 노드 익스포터 파드에 직접 도달할 수 있다.
  (Service 없이도 파드가 고립되지 않게 하는 수단.)
- 쌍을 이루는 설정: 프로메테우스는 쿠버네티스 노드를 자동 탐색할 때 노드에 붙은 `__address__` 라벨을
  쓰고, **기본 포트가 `10250`**이다. 하지만 10250으로 접근하면 노드 익스포터에 닿을 수 없으므로,
  정규표현식으로 `...:10250`을 잡아 **`:9100`으로 `replace`** 한다. 즉
  "노드 익스포터는 9100을 호스트 포트로 노출한다" ↔ "프로메테우스는 노드IP:9100으로 찾아간다"로
  양쪽 설정을 맞춘 것.
- 감점: hostPort를 NodePort Service와 혼동한 답. 라운드로빈 문제를 언급하지 않으면 절반.

### (e) `/proc`, `/sys`, `/` 마운트

- 이유: 하드웨어/OS 정보는 **호스트의 리눅스 파일시스템에 쌓인다.** 반면 파드는 컨테이너로서
  **자기만의 운영체제와 파일 경로**를 갖는다. 따라서 호스트 경로를 컨테이너 내부(`/host/proc`,
  `/host/sys` 등)로 마운트해 **호스트의 정보를 파드 안으로 가져와야** 노드 익스포터가 읽을 수 있다.
- 경로별 수집 정보:
  - `/proc` — **CPU, 메모리, 프로세스** 등 실시간 정보
  - `/sys` — **커널(운영체제) 상태, 디바이스/하드웨어** 정보
  - `/` (루트) — **디스크 사용량**
- `readOnly: true`: 노드 익스포터는 **오직 읽기만** 하면 되고, 호스트 파일시스템을 쓰기 가능하게
  마운트할 이유가 없다(모니터링 도구가 호스트를 변경할 위험 차단).

### (f) ConfigMap 분리

- ConfigMap vs Secret: **Secret은 (민감 정보를) 인코딩해 저장**하는 자원, **ConfigMap은 key-value 형태로
  일반 설정을 저장**하는 자원. (24회차 Secret 파트와 연결)
- 구조: ConfigMap에 `prometheus.yml`을 저장 → Deployment에서 `volumes`로 그 ConfigMap을 가져오고
  `volumeMounts`로 파드 내부 `/etc/prometheus`에 올림 → 컨테이너 `args`에서 그 파일을 읽어 동작.
  (`volumes` = 어디서 무엇을 가져올지, `volumeMounts` = 가져온 것을 어디에 올려 쓸지)
- 이점: 설정만 바꿀 때 **이미지를 다시 빌드할 필요가 없고**, 설정과 워크로드 정의가 분리되어 관리·
  버전 관리(GitOps 대상)가 쉽다. 같은 설정을 여러 워크로드가 재사용할 수 있다.

### (g) RBAC 3자원의 관계

- `ClusterRole` — **클러스터 전체 범위의 권한(권한 묶음)** 정의. 여기서는 `nodes` 리소스에 대해
  `get`/`list`/`watch`.
- `ServiceAccount` — **Pod에 권한을 부여할 때 쓰는 계정(kind).** Deployment의 `serviceAccountName`으로
  연결된다. 그 자체에는 아무 권한 정의가 없다.
- `ClusterRoleBinding` — **ClusterRole을 ServiceAccount에 묶어주는 자원**(`roleRef` ↔ `subjects`).
- ServiceAccount에 직접 권한을 정의할 수 없는 이유: 구조적으로 불가능하다. 권한은 Role/ClusterRole에
  정의하고, **여러 Role을 하나의 ServiceAccount에 바인딩해 조합**하는 구조다. 프로메테우스는 그렇게
  만들어진 ServiceAccount 계정을 가져다 쓴다.
- 이 권한이 대응하는 것: `kubectl get nodes`, `kubectl get nodes --watch`에 해당하는 **노드 조회 권한**.
  프로메테우스가 노드를 자동 탐색해 각 노드의 노드 익스포터에 접근하려면 필요하다.
- IAM과의 층위 비교(가점 포인트):
  - **쿠버네티스 내부 권한(RBAC)** — 클러스터 API 자원(nodes, pods…)에 대한 접근 제어.
    ServiceAccount + ClusterRole + Binding으로 클러스터 안에서 완결된다.
  - **AWS 자원 권한(IAM Role)** — 클러스터 밖의 AWS 서비스(ASG, EC2, EKS)에 대한 접근 제어.
    Pod는 AWS 엔터티가 아니므로 OIDC/STS를 거쳐 Role을 assume해야 한다.
  - 둘의 접점이 **ServiceAccount**다: cluster-autoscaler는 SA에 `eks.amazonaws.com/role-arn`
    애노테이션을 달아 두 층위를 연결했고, 프로메테우스는 SA에 ClusterRole만 바인딩했다(AWS 권한 불필요).
    이 대비를 짚으면 큰 가점.

### (h) 그라파나 연동 핸즈온

```bash
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# 브라우저 localhost:3000 → 초기 계정 admin / admin (비밀번호 변경은 skip 가능)
```

- 데이터 소스 URL: **`http://prometheus-service:9090`** (또는 프로메테우스 Service에 지정한 이름, 강의
  화면상 `prometheus-dashboard-service` 계열 이름). → Connections → Data Sources → Add data source →
  Prometheus → URL 입력 → Save & Test.
- 그 주소로 도달 가능한 이유: 그라파나와 프로메테우스가 **같은 클러스터, 같은 monitoring 네임스페이스에
  있는 파드**이고 프로메테우스 앞에 **Service가 만들어져 있으므로**, 클러스터 내부 DNS로 Service 이름
  + 포트만으로 통신할 수 있다.
- 대시보드 구성: Dashboards → **Import** → 템플릿 ID 입력 → Load → 데이터 소스로 Prometheus 선택 →
  Import.
- 템플릿 ID: **1860** (Node Exporter 대시보드). 숫자를 확인한 곳: grafana.com의 대시보드 목록에서
  원하는 대시보드(Node Exporter)를 클릭했을 때 **상단 URL에 있는 고유 ID 값**. 익스포터마다 데이터
  형식이 다르므로 대시보드도 따로 있다(ArgoCD, RabbitMQ 등).
- 노드 익스포터가 2대만 Running이면: 대시보드 상단의 **`node name` 선택 목록에 2개 노드만** 나오고,
  **2대 노드의 정보만 조회**된다. 강의는 이 상태로도 실습이 충분히 가능하다고 안내했다(단
  프로메테우스/그라파나 자체가 안 뜨면 실습 불가).

### (i) 포트 3개

- 노드 익스포터 **9100** / 프로메테우스 **9090** / 그라파나 **3000**

---

## 문제 8. 통합 설계 (종합 추론)

정답이 하나로 정해지지 않는다. **강의에서 배운 각 자원의 동작 규칙으로 추론했는지**를 본다.

### (a) HPA ↔ ArgoCD selfHeal 충돌

- 반드시 도출해야 할 결론: **HPA가 부하에 따라 replicas를 5대로 늘려도, ArgoCD가 클러스터(5)와
  GitHub(2)의 차이를 감지해 GitHub 기준으로 되돌려버린다.** 즉 selfHeal이 HPA의 스케일 아웃을 취소해
  피크에 파드가 줄어드는, 정확히 원하지 않는 동작이 발생한다.
  - 근거 조합: (문제 1-e) HPA가 Deployment replicas보다 우선한다 + (문제 5-d) selfHeal은 클러스터가
    GitHub과 다르면 GitHub 기준으로 강제 복구한다.
  - S32에서 ArgoCD UI에 삭제했던 HPA가 남아 있고 replicas 차이가 크리티컬한 OutOfSync 예로 언급된 점을
    끌어오면 가점.
- 부분 점수: "충돌한다"까지만 말하고 어느 쪽이 이기는지/무엇이 문제인지 못 쓰면 절반.
- `⚠ 강의 범위 밖` 가점: 매니페스트에서 `replicas` 필드를 제거해 HPA에 위임하기, ArgoCD
  `ignoreDifferences`로 `/spec/replicas` 차이를 무시하기 등. **몰라도 감점 없음.**

### (b) 자원 경합 설계

- 강의 범위 안 수단으로 다음 정도가 나오면 충분(조합과 근거가 중요):
  - **노드그룹 최소/최대 용량을 넉넉히** 잡는다. 특히 **최대 용량이 cluster-autoscaler의 절대 상한**
    이므로(문제 4-c), 인프라 도구 + 서비스 파드 + 피크 시 HPA 최대치를 모두 감당할 수 있는 값이어야
    한다. 인프라 도구만으로도 노드 2대가 부족했던 경험(S31, S33)이 근거.
  - **모든 워크로드에 `resources.requests/limits`를 지정**한다. 하나의 파드가 노드 자원을 독점하면
    다른 파드가 스케줄되지 못한다(문제 1-b의 논리를 인프라 도구에도 적용).
  - **HPA `maxReplicas`를 노드 용량 대비 현실적으로** 잡는다. 무한정 크게 잡아도 노드 상한에 걸려
    Pending만 쌓인다.
  - **cluster-autoscaler를 상시 유지**한다(문제 4-f). 그래야 Pending이 자동 해소된다.
  - 프로메테우스/그라파나로 노드 자원 여유를 관찰하며 위 값들을 조정한다(문제 7-a).
- `⚠ 강의 범위 밖` 가점: 인프라 도구 전용 노드그룹 분리, taint/toleration, nodeSelector/affinity,
  PriorityClass(cluster-autoscaler 매니페스트의 `system-cluster-critical`을 근거로 언급하면 특히 가점),
  PodDisruptionBudget 등. **몰라도 감점 없음.**

### (c) 관측 — 도구별 역할 구분

| 도구 | 확인 가능한 것 | 명령/경로 |
| --- | --- | --- |
| HPA | 시점별 CPU 사용률(%)과 replicas 변화, min/max | `kubectl get hpa <이름> -n <ns> -w`, `kubectl describe hpa` |
| Pod/노드 상태 | Pending 여부와 그 사유(Insufficient cpu/memory), 재시작 횟수 | `kubectl get pods -n <ns>`, `kubectl describe pod <파드>`, `kubectl get nodes` |
| cluster-autoscaler | 노드 증감 요청 이력(`--v=4` 로그) / AWS EKS 컴퓨팅·ASG 활동 이력 | `kubectl logs deploy/cluster-autoscaler -n kube-system` |
| ArgoCD UI | 자원 현황·배포 이력·Sync 상태와 DIFF(누가 언제 무엇을 바꿨는지) | 대시보드 / `argo.<도메인>` |
| 그라파나 | **노드 차원**의 CPU/메모리/디스크 시계열 — 시간 범위를 조정해 새벽 구간의 스파이크 확인 | `port-forward svc/grafana` |

- 조사 순서 예시(근거가 붙으면 순서 자체는 자유): **① 파드 상태·이벤트(`describe`)로 재시작 사유 확인
  → ② HPA 이력으로 스케일 아웃이 원인이었는지 확인 → ③ 그라파나로 그 시각 노드 자원이 실제로 고갈됐는지
  교차 검증 → ④ cluster-autoscaler 로그/ASG 활동으로 노드 증감 타이밍 확인 → ⑤ ArgoCD DIFF·배포 이력으로
  같은 시각 매니페스트 변경(또는 selfHeal 되돌림)이 있었는지 확인**.
- 가점: (a)의 충돌을 근거로 "새벽에 배치성 부하 → HPA가 늘림 → ArgoCD가 되돌림 → 반복"이라는 가설을
  세워 ArgoCD 이력을 확인하겠다고 연결한 경우.
- 감점: `kubectl logs`만으로 Pending/스케줄링 문제를 진단하겠다는 답(문제 4-d와 모순).

### (d) 마이그레이션 도입 순서

- 순서는 하나가 아니지만, **의존 관계**가 맞아야 한다. 모범 예:
  1. **Deployment에 `resources` requests/limits 설정** — 이게 없으면 파드가 노드 자원을 독점해 **HPA가
     의미를 잃는다**(문제 1-b). 다음 단계의 전제.
  2. **metrics-server 설치 → HPA 적용** — metrics-server 없이는 HPA가 CPU를 `<unknown>`으로 보고 판단
     자체를 못 한다(문제 1-c, 2-a). 여기까지가 "파드 차원 자동 확장".
  3. **ASG 태그 + OIDC/IAM Role + cluster-autoscaler 배포, 노드그룹 최대 용량 상향** — HPA만 있으면
     노드 한계에서 파드가 Pending에 걸려 멈춘다(문제 3-a). 노드그룹 최대 용량을 올리지 않으면
     autoscaler를 띄워도 노드가 늘지 않는다(문제 4-c).
  4. **ArgoCD 도입(Application 자원 + prune/selfHeal)** — 여러 사람이 kubectl로 손대는 상태를 GitHub
     기준으로 통제하고 이력을 남긴다(문제 5). 단 이 단계에서 (a)의 HPA replicas 충돌을 반드시 정리해야
     한다. 이 정리를 언급하면 큰 가점.
  5. **프로메테우스 + 노드 익스포터 + 그라파나** — 앞 단계들이 실제로 노드 자원을 얼마나 쓰는지
     관측해야 1~3단계의 값(limits, 임계치, min/max, 노드 용량)을 근거 있게 조정할 수 있다. 관측 없이는
     "여유롭게 세팅하라"를 감으로 하게 된다.
- 온프레미스 대비 무엇이 대체되는지 매핑하면 가점: 수동 서버 증설 → HPA + cluster-autoscaler,
  사람 모니터링 → 프로메테우스/그라파나, 수동 배포 → GitHub Actions + ArgoCD.
- 감점: 순서만 나열하고 "건너뛰면 왜 무의미해지는지"를 한 건도 설명하지 않은 경우.

---

## 자주 나오는 오답·누락 정리

1. **HPA가 직접 파드를 모니터링한다** → metrics-server의 역할(문제 1-c).
2. **리소스 limit 없이도 HPA가 잘 동작한다** → 파드가 노드 자원을 독점해 스케일 아웃이 무의미(1-b).
3. **Deployment replicas가 HPA minReplicas보다 우선한다** → HPA가 우선(1-e). 문제 8-(a) 추론이 무너진다.
4. **cluster-autoscaler가 직접 EC2를 만든다** → ASG가 만들고 autoscaler는 요청만(3-c).
5. **Pod에 IAM Role을 바로 붙일 수 있다** → Pod는 AWS 엔터티가 아니라 OIDC/STS 경유 필요(3-e).
6. **Pending 파드를 `kubectl logs`로 진단** → 프로그램이 실행조차 안 됐으므로 `describe`(4-d).
7. **노드 추가 후 자원을 다시 apply해야 한다** → 선언은 마스터 노드에 이미 있어 자동 스케줄(5-f).
8. **prune이 "GitHub에 없는데 누가 만든 자원"도 지운다** → 지우지 않는다(5-d).
9. **Ingress가 HTTPS→HTTPS 패스스루를 지원한다** → nginx 기반 Ingress에서 미지원, `--insecure`로 해결
   (6-c).
10. **노드 익스포터를 Service로 노출** → 라운드로빈 때문에 파드별 수집 불가, `hostPort` 사용(7-d).
11. **`10250`이 노드 익스포터 포트다** → 프로메테우스의 노드 탐색 기본 포트이고, 9100으로 replace(7-d).
12. **ServiceAccount에 권한을 직접 적는다** → ClusterRole + ClusterRoleBinding 필요(7-g).
13. **OutOfSync는 항상 장애다** → DIFF로 판단, 무의미한 차이도 잡힌다(6-f).
