---
name: ordersystem-eks-env
description: 인프런 EKS 강의의 **order-system 모놀리식**(2.ordersystem) 실습 환경을 EKS에 올리고(up) 내리는(down) 스킬. 강의 22~34강 순서 그대로 클러스터·노드그룹 → mj-eks 네임스페이스 → ingress-nginx(NLB)+Route 53 → 앱 배포(ECR/Secret/redis/Deployment/Ingress, HTTP 검증) → cert-manager HTTPS → HPA/오토스케일 → ArgoCD → Prometheus·Grafana 를 세팅하고, 역순 삭제 + 잔여 과금 리소스(NLB·EBS·ENI·SG·CloudWatch) 점검까지 처리한다. "오더시스템 환경 세팅", "모놀리식 실습 환경", "실습 환경 세팅", "eks 클러스터 만들어", "인프라 올려줘", "실습 환경 삭제", "클러스터 내려", "다 지워줘", "teardown" 요청 시 사용.
---

# order-system 모놀리식 EKS 실습 환경 (up / down)

인프런 "EKS를 활용한 Spring 운영서버 배포" 강의의 **모놀리식 구간(22~34강)** 전용 스킬이다.
대상은 이 레포의 `2.ordersystem` 스프링 백엔드 하나이며, 실습은 **클러스터를 만들고 → 배포하고 →
지우는** 사이클을 반복한다. 이 스킬은 그 두 방향을 모두 담당한다.

- **up (세팅)** → `references/setup.md`
- **down (삭제)** → `references/teardown.md`

## 범위

| 포함 | 제외 |
|---|---|
| 강의 22~34강 (모놀리식 order-system) | 강의 35~40강 **MSA 전환**(api-gateway, 서비스 모듈 분리) |
| `2.ordersystem/k8s/k8s-ordersystem/*` | `1.k8s_basic/*` 의 nginx 기초 실습 (이미 끝난 단계) |
| `k8s-argocd/*`, `k8s-monitoring/*` | 강의 26강 GitHub Actions CI/CD (별도 작업) |

MSA 구간을 요청받으면 이 스킬을 억지로 적용하지 말고, 범위 밖임을 알리고 별도로 진행한다.

## 이 레포의 배포 흐름 (강의 22강 기준)

```
인프라 사전 생성(DB · ECR · Redis) → 이미지 빌드/ECR 푸시 → 쿠버네티스 자원(Deployment/Service/Ingress)
  → HTTPS 인증서 → (이후) 오토스케일 · ArgoCD · 모니터링
```

강의는 Route 53과 로드밸런서가 **이전 nginx 실습에서 이미 만들어져 있다고 전제**하지만, 클러스터를
새로 만들면 없다. 그래서 이 스킬은 L3에서 ingress-nginx(NLB)와 Route 53 레코드를 먼저 만든다 —
강의 22강도 "아무것도 없는 상태라면 호스팅 영역과 ingress 컨트롤러를 사전에 만들라"고 명시한다.

## 대원칙 (반드시 지킬 것)

1. **돈이 나가는 작업이다.** EKS 컨트롤 플레인은 클러스터가 존재하는 동안 시간당 과금되고,
   노드(t3.small×2)·NLB·EBS도 별도로 붙는다. 실습이 끝나면 **반드시 down까지 끝내야 한다.**
   세팅을 마친 뒤에는 사용자에게 "실습 끝나면 `/ordersystem-eks-env down` 하세요"를 항상 상기시킨다.
2. **생성/삭제 명령은 사용자 확인 없이 실행하지 않는다.** 각 단계마다 실행할 명령을 먼저 보여주고
   승인받은 뒤 실행한다. 특히 down의 클러스터 삭제, ECR 이미지 삭제, Route 53 레코드 삭제는
   되돌릴 수 없으므로 개별 확인을 받는다.
3. **삭제 순서가 생성 순서의 역순이어야 한다.** k8s 리소스(특히 `type: LoadBalancer` Service /
   Ingress)를 남긴 채 클러스터를 지우면 **NLB·타깃그룹·보안그룹이 AWS에 고아로 남아 계속 과금되고**,
   VPC 정리도 막힌다. teardown.md의 순서를 건너뛰지 않는다.
4. **조회(get/describe/list)는 자유롭게, 변경(apply/create/delete)은 확인 후.**
   상태 파악 목적의 read-only 명령은 먼저 돌려서 현재 어디까지 올라가 있는지 확인한 뒤 계획을 세운다.

## 시작 전 반드시 확정할 값 (추측 금지)

레포 문서마다 값이 제각각이라(강사 계정 값이 그대로 남은 파일이 많다) **하드코딩된 값을 그대로 쓰면
안 된다.** 아래 표의 값을 사용자에게 확인하거나 명령으로 탐지한 뒤 진행한다.

| 값 | 이 환경의 값 | 확인 방법 |
|---|---|---|
| aws-vault 프로필 | `eks-practice` (계정 831926604059, `user/eks-practice`) | `aws-vault list` |
| 리전 | `ap-northeast-2` | 고정 |
| 클러스터 이름 | `eks-practice` (cluster.yaml) | `aws eks list-clusters` |
| 네임스페이스 | `mj-eks` | 강사 파일 잔재 `bradkim` 이 남아있는지 확인 |
| ECR | `831926604059.dkr.ecr.ap-northeast-2.amazonaws.com/ordersystem-backend` | `aws ecr describe-repositories` |
| 도메인 | `server.balance-eat.com` (호스팅 영역 `balance-eat.com`) | `aws route53 list-hosted-zones` |
| DB | **AWS RDS 아님.** 외부 Aiven Postgres (`${DB_HOST}:15210/defaultdb?ssl=require`) | `application-prod.yml`, 접속정보는 사용자에게 |

> 강의는 RDS MySQL + 스키마 `ordersystem`을 쓰지만 이 레포는 Aiven Postgres로 갈아탔다.
> 계정에 RDS가 없는 게 정상이므로 AWS에서 DB를 찾으려 하지 말 것.

프로필이 확정되면 이후 모든 명령은 `aws-vault exec <프로필> -- <명령>` 형태로 실행한다.
장시간 작업(클러스터 생성 15~20분)은 자격증명 만료를 피하려면
`aws-vault exec <프로필> --duration=12h -- zsh` 로 서브셸을 띄워 쓰는 편이 낫다.

### ⚠ IAM을 건드리는 명령은 `--no-session` 이 필요하다

aws-vault의 기본 동작은 `sts:GetSessionToken` 으로 임시 자격증명을 만드는 것인데, **MFA 없이 만든
GetSessionToken 자격증명으로는 IAM/STS API를 호출할 수 없다** (`GetCallerIdentity` 제외).
그래서 `aws iam get-role` 같은 호출이 "권한 없음"이 아니라 아래 에러로 실패한다:

```
An error occurred (InvalidClientTokenId) ... The security token included in the request is invalid
```

이 에러가 나오면 **역할이 없다고 단정하지 말고** `--no-session` 으로 다시 확인한다:

```shell
aws-vault exec --no-session <프로필> -- aws iam get-role --role-name AmazonEKSClusterRole
```

`eksctl` 은 클러스터/노드그룹 생성 과정에서 IAM 역할을 조회·생성하므로 **eksctl 명령은
`--no-session` 으로 실행한다.** (장기 자격증명을 그대로 쓰므로 세션 만료 문제도 같이 사라진다.)

## 레포 지뢰 (세팅 전 반드시 점검)

`2.ordersystem/k8s/` 매니페스트는 일부만 본인 값으로 고쳐져 있고 나머지는 강사 값이 그대로다.
apply 전에 이 불일치를 먼저 잡는다.

| 파일 | 상태 (2026-07-29 기준) |
|---|---|
| `k8s-ordersystem/depl_svc.yml` | ✅ ns `mj-eks`, image `831926604059/ordersystem-backend:latest` |
| `k8s-ordersystem/redis.yml` | ✅ ns `mj-eks` |
| `k8s-ordersystem/hpa.yml` | ✅ ns `mj-eks` |
| `k8s-ordersystem/ingress.yml` | ✅ ns `mj-eks`, host `server.balance-eat.com` |
| `k8s-ordersystem/https.yml` | ✅ ns `mj-eks`, 도메인·이메일 교체 완료 |
| `k8s-argocd/*` | ⚠ **강사 값 그대로** — host `argo.bradkim197.shop`, repoURL이 강사 GitHub. L7 진입 전 교체 |
| `k8s-monitoring/*` | ns `monitoring` (독립적이라 그대로 사용 가능) |

L1~L5 매니페스트는 정리됐지만, **매번 apply 전에 위 표를 실제 파일과 대조**한다
(`grep -rn "bradkim\|346903264902" 2.ordersystem/k8s/`). 강의 영상을 따라가다 원본을 되돌리는 일이 잦다.

또한 `depl_svc.yml`이 참조하는 Secret **`my-app-secrets`(DB_HOST/DB_USERNAME/DB_PW)는 레포에 매니페스트가
없다.** `kubectl create secret generic` 으로 직접 만들어야 하며, 이게 없으면 파드가
`CreateContainerConfigError`로 뜨지 않는다.

> 참고: 강의(24강)의 Secret 이름은 `myappsecret`이고 키는 `DB_HOST`/`DB_PW` 2개뿐이다
> (username을 `admin` 고정으로 썼기 때문). 이 레포는 `my-app-secrets` + 키 3개이므로
> **레포 기준을 따른다.** 강의 영상과 이름이 다르다고 고치지 말 것.

## 단계(레벨) 구조

실습 진도에 따라 필요한 만큼만 올린다. 사용자가 레벨을 지정하지 않으면
**"어디까지 올릴까요?"를 물어보고** 진행한다 (전부 올리면 그만큼 과금된다).

| L | 구성요소 | 강의 범위 |
|---|---|---|
| 0 | 사전 점검 (CLI/프로필/계정) | - |
| 1 | 클러스터 + 노드그룹 | ch.05 |
| 2 | kubeconfig + 네임스페이스 | ch.05 |
| 3 | ingress-nginx(NLB) + Route 53 A 레코드 | ch.06 |
| 4 | 앱 배포 (ECR 이미지 + Secret + redis + Deployment/Service + Ingress) — **HTTP까지 검증** | ch.22~24 |
| 5 | cert-manager + ClusterIssuer/Certificate (HTTPS) | ch.25 |
| 6 | metrics-server + HPA, cluster-autoscaler | ch.27~30 |
| 7 | ArgoCD | ch.31~32 |
| 8 | Prometheus + Grafana | ch.33~34 |

> **L4 → L5 순서를 뒤집지 말 것.** 강의는 앱과 Ingress를 먼저 올려 HTTP 200을 확인한 뒤
> cert-manager를 설치한다. cert-manager의 HTTP-01 검증은 CA가 우리 도메인으로 실제 HTTP 요청을
> 보내는 방식이라 **앱이 HTTP로 뜨는 게 선행 조건**이고, 원인 분리도 쉬워진다.

> ⚠ **L7(ArgoCD)과 L8(모니터링)은 t3.small×2에서 공존하지 못한다.** 강의도 33강 시작에서
> ArgoCD의 ingress·application·namespace를 **먼저 삭제하고** Prometheus/Grafana로 넘어간다.
> 둘 다 보려면 노드를 늘리거나(t3.medium 또는 3대 이상), 하나를 내리고 다른 하나를 올린다.

down은 **L8 → L1 역순**으로 지운 뒤, 마지막에 AWS 고아 리소스를 점검한다.

## 실행 절차

1. 사용자의 요청이 up인지 down인지 판별한다. 애매하면 물어본다.
2. `scripts/preflight.sh` 로 현재 상태를 먼저 확인한다 (설치된 CLI, 프로필, 이미 떠 있는 클러스터).
   **이미 클러스터가 떠 있는데 up 요청이면** 새로 만들지 말고 그 사실을 먼저 알리고, 어느 레벨부터
   이어서 올릴지 확인한다.
3. up → `references/setup.md`, down → `references/teardown.md` 를 읽고 그 절차를 따른다.
4. 각 레벨이 끝날 때마다 `scripts/verify.sh` 로 검증한다. **검증 없이 "완료"라고 말하지 않는다.**
5. down 완료 후에는 **반드시** `scripts/orphan-check.sh` 를 돌려 잔여 과금 리소스를 확인하고
   결과를 사용자에게 보고한다.

## 스크립트

모두 read-only이며, 자격증명이 환경에 들어있다고 가정한다 (`aws-vault exec <프로필> -- <스크립트>`).

| 스크립트 | 역할 |
|---|---|
| `scripts/preflight.sh` | CLI 설치 여부, AWS 계정/프로필, 기존 클러스터·kubeconfig 상태 점검 |
| `scripts/verify.sh` | 노드/파드/Ingress/HPA/LB 상태 한 번에 조회 (레벨별 검증) |
| `scripts/orphan-check.sh` | 삭제 후 남은 NLB·타깃그룹·EBS·ENI·SG·CFN 스택·로그그룹 조회 + 삭제 명령 제안 |
| `scripts/tls-backup.sh` | **TLS 인증서 백업/복원** (`backup`/`restore`/`list`) — 유일하게 쓰기를 하는 스크립트 |

> ★ **클러스터를 지우기 전에 반드시 `tls-backup.sh backup`.** Let's Encrypt는 도메인당 주 5개
> 제한이라, 클러스터를 여러 번 재생성하면 금방 걸려 일주일간 HTTPS 실습이 막힌다. 인증서는 90일
> 유효하므로 백업본을 `restore`로 재사용하면 한도를 소모하지 않는다. teardown 0-A 단계 참고.

`assets/cluster.template.yaml` 은 다른 AWS 계정에서 새로 만들 때 쓰는 eksctl 설정 템플릿이다
(레포의 `1.k8s_basic/0.eks_setting/cluster.yaml` 은 특정 계정의 VPC/서브넷/IAM ARN이 박혀 있다).
