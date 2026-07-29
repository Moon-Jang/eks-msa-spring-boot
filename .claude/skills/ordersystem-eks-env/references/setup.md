# order-system 모놀리식 — 세팅 절차 (up)

각 레벨은 **명령 제시 → 사용자 승인 → 실행 → 검증** 순서로 진행한다.
아래 명령의 `$PROFILE`, `$CLUSTER`, `$NS`, `$DOMAIN`, `$ACCOUNT` 는 SKILL.md의 "시작 전 확정할 값"에서
정한 실제 값으로 치환해 쓴다. 기본값: `CLUSTER=eks-practice`, `NS=mj-eks`, `REGION=ap-northeast-2`.

---

## L0. 사전 점검

```shell
.claude/skills/ordersystem-eks-env/scripts/preflight.sh
```

자격증명이 필요하므로 보통 이렇게 돌린다:

```shell
aws-vault exec $PROFILE -- .claude/skills/ordersystem-eks-env/scripts/preflight.sh
```

체크 항목과 없을 때의 조치:

| 항목 | 없으면 |
|---|---|
| `kubectl` | `brew install kubectl` |
| `eksctl` | `brew install eksctl` (homebrew-core에 있음 — `weaveworks/tap`은 더 이상 필요 없다. 없으면 AWS 콘솔로도 생성 가능 — `1.k8s_basic/0.eks_setting/1.eks-init.md`) |
| `aws` CLI | `brew install awscli` |
| `aws-vault` | `brew install --cask aws-vault` |
| `docker` | L5(이미지 빌드)에서만 필요 |

`aws sts get-caller-identity` 로 나온 계정 ID가 매니페스트/ECR URL의 계정 ID와 다르면
그 사실을 사용자에게 먼저 알린다 (강사 계정 값이 남아있을 가능성이 높다).

---

## L1. 클러스터 + 노드그룹

### 방법 A: eksctl (권장, 재현 가능)

레포에 `1.k8s_basic/0.eks_setting/cluster.yaml` 이 있다. **그대로 쓰기 전에 반드시 확인**한다 —
`vpc.id` / `subnets` / `iam.serviceRoleARN` / `instanceRoleARN` 이 **현재 계정의 실재하는 리소스**여야 한다.

```shell
# 현재 계정의 default VPC와 서브넷 확인
aws-vault exec $PROFILE -- aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[].VpcId' --output text --region ap-northeast-2

aws-vault exec $PROFILE -- aws ec2 describe-subnets --filters Name=vpc-id,Values=<VPC_ID> \
  --query 'Subnets[].{AZ:AvailabilityZone,Id:SubnetId}' --output table --region ap-northeast-2

# IAM 역할 존재 확인 — IAM 호출은 반드시 --no-session (SKILL.md 참고)
aws-vault exec --no-session $PROFILE -- aws iam get-role --role-name AmazonEKSClusterRole
aws-vault exec --no-session $PROFILE -- aws iam get-role --role-name AmazonEKSNodeRole
```

값이 안 맞으면 `assets/cluster.template.yaml` 을 복사해 채운 뒤 사용한다.

**생성 전에 반드시 dry-run으로 검증한다** (아무것도 만들지 않고 설정만 확인 — 오타/없는 서브넷/잘못된
버전을 15분 기다린 뒤 실패로 알게 되는 걸 막아준다):

```shell
aws-vault exec --no-session $PROFILE -- eksctl create cluster -f 1.k8s_basic/0.eks_setting/cluster.yaml --dry-run
```

출력에서 확인할 것: `vpc.id`/`subnets`가 실제 ID로 해석됐는지, `iam.serviceRoleARN`·
`instanceRoleARN`이 그대로 통과했는지, `vpc.nat.gateway: Disable`인지(NAT GW는 비싸다),
`metadata.version`이 거부되지 않았는지.

```shell
aws-vault exec --no-session $PROFILE -- eksctl create cluster -f 1.k8s_basic/0.eks_setting/cluster.yaml
```

> `--no-session` 필수. eksctl은 IAM 역할을 조회/생성하는데, aws-vault 기본 세션 토큰으로는
> IAM 호출이 `InvalidClientTokenId`로 막힌다 (SKILL.md 참고).

- **15~20분 걸린다.** 백그라운드로 돌리고 진행 상황을 주기적으로 확인한다.
- 진행 중 CloudFormation 스택(`eksctl-<cluster>-cluster`, `eksctl-<cluster>-nodegroup-*`)이 생성된다.
  실패하면 스택 이벤트에서 원인을 본다:
  `aws cloudformation describe-stack-events --stack-name eksctl-$CLUSTER-cluster`

### 방법 B: AWS 콘솔

`1.k8s_basic/0.eks_setting/1.eks-init.md`(클러스터) → `2.node-init.md`(노드그룹) 순서.
노드그룹: t3.small / 20GB / min·max·desired = 2/2/2, IAM은 권장 역할(EC2).

> ⚠ 콘솔로 만들면 클러스터를 만든 IAM 주체만 초기 접근 권한을 갖는다. **아래 kubeconfig 단계에서
> 쓸 프로필과 같은 IAM 주체로 만들어야** `kubectl`이 바로 붙는다.

### 검증

```shell
aws-vault exec $PROFILE -- aws eks describe-cluster --name $CLUSTER --region ap-northeast-2 \
  --query 'cluster.status' --output text     # ACTIVE
```

---

## L2. kubeconfig + 네임스페이스

```shell
aws-vault exec $PROFILE -- aws eks update-kubeconfig --region ap-northeast-2 --name $CLUSTER
aws-vault exec $PROFILE -- kubectl get nodes            # Ready 2개
aws-vault exec $PROFILE -- kubectl create namespace $NS
aws-vault exec $PROFILE -- kubectl get ns
```

> `mj-eks` 는 기본 제공 네임스페이스가 아니다. 이걸 빼먹고 매니페스트를 apply하면
> `namespaces "mj-eks" not found` 로 실패한다 — 가장 흔한 실수.

---

## L3. ingress-nginx (NLB) + Route 53

```shell
aws-vault exec $PROFILE -- kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
```

- 이 매니페스트는 `ingress-nginx` 네임스페이스에 컨트롤러를 만들고,
  **`type: LoadBalancer` Service를 통해 AWS NLB를 자동 생성**한다 → **여기서부터 LB 과금 시작**.
- NLB를 앞에 두는 이유(ALB와 L7 역할 중복 회피, 고정 IP)는 `1.k8s_basic/2.multi_pod/note.md` 참고.

```shell
# NLB 주소가 뜰 때까지 대기 (1~3분)
aws-vault exec $PROFILE -- kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

### Route 53 A 레코드

호스팅 영역 → 레코드 생성 → **A 레코드 / 별칭(Alias) / Network Load Balancer** 선택 → 위에서 생성된
NLB 지정. 서브도메인은 실습에 쓸 것 전부(`server.<도메인>`, `argo.<도메인>` 등) 만들어 둔다.

```shell
# 전파 확인
dig +short server.$DOMAIN
```

---

## L4. 애플리케이션 배포 (HTTP까지 검증)

> **순서 주의**: 강의(24강 → 25강)는 **앱 + Ingress를 먼저 올려 HTTP로 동작을 확인한 뒤**,
> 그다음에 cert-manager로 HTTPS를 붙인다. `ingress.yml`에 `tls:` 블록과
> `cert-manager.io/cluster-issuer` 어노테이션이 이미 들어 있어도 cert-manager가 없으면
> **그냥 무시될 뿐 에러가 나지 않는다** — HTTP는 정상 동작한다.
> TLS부터 붙이면 앱이 죽었는지 인증서가 안 나온 건지 원인 분리가 어려워지므로 이 순서를 지킨다.

### 4-1. 이미지 빌드 & ECR 푸시

절차와 트러블슈팅은 `1.k8s_basic/0.eks_setting/4.docker-image-build.md` 에 이미 정리돼 있다. 요약:

```shell
# ECR 리포지토리가 없으면 먼저 생성
aws-vault exec $PROFILE -- aws ecr create-repository --repository-name ordersystem-backend --region ap-northeast-2

cd 2.ordersystem
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/ordersystem-backend:latest .

aws-vault exec $PROFILE -- aws ecr get-login-password --region ap-northeast-2 \
  | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com

docker push $ACCOUNT.dkr.ecr.ap-northeast-2.amazonaws.com/ordersystem-backend:latest
```

- **`--platform linux/amd64` 필수** (노드가 t3.small=amd64, 로컬이 Apple Silicon).
- 로그인 URL은 레지스트리 도메인까지만 (리포지토리 경로 제외).

### 4-2. Secret 생성 (레포에 매니페스트 없음)

```shell
aws-vault exec $PROFILE -- kubectl create secret generic my-app-secrets -n $NS \
  --from-literal=DB_HOST='<RDS 엔드포인트>' \
  --from-literal=DB_USERNAME='<사용자>' \
  --from-literal=DB_PW='<비밀번호>'
```

이 레포의 `application-prod.yml`은 **AWS RDS가 아니라 외부 관리형 Postgres(Aiven)** 를 본다:
`jdbc:postgresql://${DB_HOST}:15210/defaultdb?ssl=require`. 계정에 RDS가 없는 게 정상이므로
DB 엔드포인트를 AWS에서 찾으려 하지 말고 사용자에게 받는다.

> 🔐 **비밀번호는 대화창에 받지 말 것.** 사용자에게 프롬프트에서 `!` 접두사로 직접 실행하도록 안내한다
> (`! kubectl create secret ...`). 그러면 값이 대화 기록에 남지 않는다.
> 파일로 만들 거라면 `.gitignore` 확인 후 진행.

### 4-3. 매니페스트 적용

강의 순서대로 **redis → depl_svc → ingress**. redis를 먼저 올려야 스프링이 기동 중
`redis-service`를 찾을 수 있다.

```shell
cd 2.ordersystem/k8s/k8s-ordersystem
aws-vault exec $PROFILE -- kubectl apply -f redis.yml
aws-vault exec $PROFILE -- kubectl apply -f depl_svc.yml     # image를 본인 ECR로 고친 뒤
aws-vault exec $PROFILE -- kubectl apply -f ingress.yml      # namespace/host를 고친 뒤
```

### 검증 — 여기서는 아직 인증서가 없다 (HTTPS는 L5에서)

```shell
aws-vault exec $PROFILE -- kubectl get pods,svc,ingress -n $NS
curl -s -o /dev/null -w '%{http_code}\n' http://server.$DOMAIN/health   # 308
curl -skL http://server.$DOMAIN/health                                   # ok1  ← 실제 검증
```

> ⚠ **`ingress.yml`에 `tls:` 블록이 있으면 nginx가 HTTP를 HTTPS로 강제 리다이렉트(308)한다**
> (`ssl-redirect` 기본 동작). 그래서 강의처럼 "HTTP 200"이 바로 나오지 않는다.
> 이 단계에서는 인증서가 아직 nginx 기본 자체서명(`CN=Kubernetes Ingress Controller Fake Certificate`)
> 이므로 **`-k`(검증 생략) + `-L`(리다이렉트 추종)** 으로 확인한다. `-k` 없이 하면 curl이 000으로 실패한다.
> 순수 HTTP 200을 보고 싶다면 `ingress.yml`의 `tls:` 블록을 잠시 주석 처리하면 된다.

강의는 Postman으로 `/health` → 로그인 → `/product/create` → `/order/create` 까지 확인한다.
파드가 `READY 1/1`이 되어야 readinessProbe(`/health`)가 통과한 것이다.

| 증상 | 원인 |
|---|---|
| `CreateContainerConfigError` | Secret `my-app-secrets` 없음/키 이름 불일치 |
| `ImagePullBackOff` | ECR URL 계정 불일치, 태그 없음, 노드 IAM에 ECR 읽기 권한 없음 |
| `exec format error` | `--platform linux/amd64` 없이 arm64로 빌드함 |
| 파드가 계속 재시작 + 로그에 DB 에러 | **DB 스키마 미생성/오타.** 강의에서도 `unknown database ordersystem`으로 5회 재시작했다. 스프링 JPA는 테이블은 만들어도 **스키마(데이터베이스)는 안 만든다** |
| `READY 0/1` 인데 Running | readinessProbe `/health` 미통과 — 스프링 기동 실패 또는 기동 지연 |
| Ingress 503 | Service 셀렉터 불일치, 또는 readinessProbe 실패로 엔드포인트 0개 |
| `UnknownHostException: <Aiven 호스트>` | DNS 네거티브 캐시. **호스트가 없다고 단정하지 말 것** — `dig @8.8.8.8 <호스트>`로 교차 확인하고, NOERROR면 몇 분 뒤 저절로 풀린다 |
| `FATAL: remaining connection slots...` (SQLState 53300) | **Aiven 무료 플랜 커넥션 한도 초과.** 아래 참고 |

> 🔴 **롤링 업데이트 중 DB 커넥션 교착 (이 환경 고유의 함정)**
> HikariCP는 파드당 기본 10개 커넥션을 미리 연다. 레플리카 2개면 20개인데, 롤링 업데이트 중에는
> 구 파드 2 + 신 파드 1 = **30개**가 되어 Aiven 무료 플랜 한도(~20)를 넘긴다. 그러면
> **신 파드는 커넥션이 없어 못 뜨고, 구 파드는 신 파드가 Ready가 아니라 안 내려가는 교착**에 빠진다.
>
> **→ 2026-07-29에 `application-prod.yml`에 아래를 넣어 해결했다** (2파드=10, 서지 포함 15).
> ```yaml
> spring.datasource.hikari:
>   maximum-pool-size: 5
>   minimum-idle: 2
> ```
> 이 설정이 빠진 이미지로 돌아가면 교착이 재현되므로, **이미지를 재빌드했는지 확인**할 것.
> 교착이 발생했을 때의 즉시 해소법: 멈춘 구 파드를 지우거나
> `kubectl scale --replicas=1` 후 다시 `--replicas=2`.

---

## L5. cert-manager + HTTPS 인증서

**L4에서 HTTP가 200으로 확인된 뒤에** 진행한다.

### 5-0. 백업된 인증서가 있으면 먼저 복원한다 ★

Let's Encrypt는 **동일 도메인 주당 5개** 제한이 있다. 클러스터를 자주 지웠다 만드는 이 실습에서는
금방 걸리고, 걸리면 일주일을 기다려야 한다. **발급받은 인증서는 90일짜리이므로 재사용이 정답이다.**

```shell
aws-vault exec $PROFILE -- .claude/skills/ordersystem-eks-env/scripts/tls-backup.sh list
aws-vault exec $PROFILE -- .claude/skills/ordersystem-eks-env/scripts/tls-backup.sh restore
```

복원해두면 cert-manager는 **유효한 Secret이 이미 있음을 확인하고 재발급하지 않는다**
(`renewBefore` 시점에만 갱신). 즉 한도를 소모하지 않는다. 만료된 백업은 스크립트가 거부한다.

백업이 없으면(최초 발급) 그냥 아래로 진행하고, **teardown 전에 반드시 `backup`을 실행**한다.

```shell
aws-vault exec $PROFILE -- kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
aws-vault exec $PROFILE -- kubectl get pods -n cert-manager   # 3개 Running
```

> 강의(25강)는 `kubectl create namespace cert-manager` → CRDs yaml → 본체 yaml 순으로 나눠 적용한다.
> 위의 단일 `cert-manager.yaml`은 **네임스페이스와 CRD를 모두 포함**하므로 한 번에 끝난다.
> 단 네임스페이스 이름 `cert-manager`는 매니페스트에 박혀 있어 **바꾸면 안 된다.**

그다음 `2.ordersystem/k8s/k8s-ordersystem/https.yml` 을 적용한다. **적용 전에 반드시 수정**:

- `Certificate`의 `namespace` → `$NS` (ClusterIssuer는 클러스터 스코프라 namespace 불필요)
- `email:` → 본인 이메일 (Let's Encrypt가 실제로 존재 여부를 검증한다)
- `commonName` / `dnsNames` → `server.$DOMAIN`
- **`Certificate`의 `secretName` 과 Ingress의 `tls.secretName` 이 반드시 같아야 한다** — 강의에서
  가장 강조하는 지점이다. 다르면 인증서는 발급돼도 Ingress가 못 찾아 HTTPS가 안 붙는다.

```shell
aws-vault exec $PROFILE -- kubectl apply -f 2.ordersystem/k8s/k8s-ordersystem/https.yml
aws-vault exec $PROFILE -- kubectl get certificate -n $NS    # READY=True 까지 1~3분
aws-vault exec $PROFILE -- kubectl get secret -A | grep tls  # 인증서 Secret 생성 확인
curl -i https://server.$DOMAIN/health
```

> `READY=False`가 계속되면 `kubectl describe certificate` → `challenge` 리소스를 본다.
> 대부분 **Route 53 A 레코드가 아직 전파되지 않아** HTTP-01 검증이 실패하는 경우다.
> ClusterIssuer가 `solvers.http01.ingress.class: nginx` 이므로 **L3가 먼저 떠 있어야 하고**,
> CA가 우리 도메인으로 실제 HTTP 요청을 보내므로 **L4의 HTTP 200이 선행 조건**이다.

---

## L6. 오토스케일링

### metrics-server + HPA

> **최신 eksctl(0.229+)은 클러스터 생성 시 `metrics-server`를 EKS 애드온으로 자동 설치한다**
> (생성 로그: `default addons kube-proxy, coredns, metrics-server, vpc-cni ... will install them as EKS addons`).
> 먼저 확인하고, 이미 있으면 아래 apply는 건너뛴다 — 중복 설치하면 충돌한다.
> ```shell
> aws-vault exec $PROFILE -- kubectl get deploy metrics-server -n kube-system
> aws-vault exec $PROFILE -- aws eks list-addons --cluster-name $CLUSTER --region ap-northeast-2
> ```

```shell
# 위 확인에서 없을 때만
aws-vault exec $PROFILE -- kubectl apply -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
aws-vault exec $PROFILE -- kubectl top nodes    # 값이 나오면 정상 (1~2분 소요)

# hpa.yml 의 namespace 를 $NS 로 고친 뒤
aws-vault exec $PROFILE -- kubectl apply -f 2.ordersystem/k8s/k8s-ordersystem/hpa.yml
aws-vault exec $PROFILE -- kubectl get hpa -n $NS -w
```

> HPA의 `TARGETS`가 `<unknown>`이면 metrics-server가 아직 안 떴거나, Deployment에
> `resources.requests`가 없는 것이다 (`depl_svc.yml`에는 있음).

### cluster-autoscaler (노드 오토스케일)

`cluster.yaml`의 노드그룹은 min=max=2로 고정이라 **그대로면 노드가 늘어나지 않는다.**
CA 실습을 하려면 먼저 ASG의 max를 올려야 한다.

```shell
aws-vault exec $PROFILE -- eksctl scale nodegroup --cluster $CLUSTER --name my-worker-node \
  --nodes 2 --nodes-min 2 --nodes-max 5
```

그리고 노드 IAM 역할에 ASG 조작 권한(`autoscaling:DescribeAutoScalingGroups`,
`SetDesiredCapacity`, `TerminateInstanceInAutoScalingGroup` 등)을 붙인 뒤 cluster-autoscaler를
배포한다 (강의 ch.29~30). ASG에는 다음 태그가 있어야 CA가 대상 그룹을 찾는다:

```
k8s.io/cluster-autoscaler/enabled = true
k8s.io/cluster-autoscaler/<CLUSTER> = owned
```

---

## L7. ArgoCD

```shell
aws-vault exec $PROFILE -- kubectl create namespace argocd
aws-vault exec $PROFILE -- kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
aws-vault exec $PROFILE -- kubectl get pods -n argocd
```

> 파드가 `Pending`으로 멈추면 **노드 리소스 부족**이다(t3.small×2에 ArgoCD는 빡세다).
> 노드를 늘린 뒤 `kubectl delete pod`로 실패한 파드를 재스케줄시킨다.

nginx Ingress 뒤에 둘 것이므로 argocd-server를 HTTP로 띄운다:

```shell
aws-vault exec $PROFILE -- kubectl edit deployment argocd-server -n argocd
# containers[].args 에 "--insecure" 추가
```

그 후 `2.ordersystem/k8s/k8s-argocd/` 의 `argocd-service.yml`, `https.yml`, `argocd-ingress.yml` 를
**도메인(`argo.$DOMAIN`)과 repoURL을 본인 것으로 고친 뒤** 적용한다.

```shell
# 초기 admin 비밀번호
aws-vault exec $PROFILE -- kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

`argocd-application.yaml` 의 `repoURL`(강사 레포로 되어 있음)과 `destination.namespace`(bradkim)를
반드시 본인 값으로 바꾼다. 안 바꾸면 **강사 레포 상태를 내 클러스터에 sync**한다.

---

## L8. Prometheus + Grafana

```shell
aws-vault exec $PROFILE -- kubectl create namespace monitoring
cd 2.ordersystem/k8s/k8s-monitoring
aws-vault exec $PROFILE -- kubectl apply -f prometheus-rbac.yml -f prometheus-config.yml \
  -f prometheus-depl_svc.yml -f node_exporter.yml -f grafana-depl_svc.yml
aws-vault exec $PROFILE -- kubectl get pods -n monitoring
```

접속은 포트포워딩으로 한다 (별도 Ingress 없음):

```shell
aws-vault exec $PROFILE -- kubectl port-forward -n monitoring svc/grafana-service 3000:3000
# http://localhost:3000  (admin/admin)
```

---

## 세팅 완료 후

1. `scripts/verify.sh` 결과를 사용자에게 보여준다.
2. **비용 안내**: 지금부터 EKS 컨트롤 플레인 + 노드 2대 + NLB가 시간당 과금된다.
   "실습 끝나면 `/ordersystem-eks-env down`" 을 명시적으로 안내한다.
3. 이번 세팅에서 수정한 매니페스트(네임스페이스/도메인/ECR)는 커밋 대상인지 사용자에게 확인한다.
