# order-system 모놀리식 — 삭제 절차 (down)

> ⚠️ **되돌릴 수 없는 작업이다.** 각 단계 실행 전에 사용자 확인을 받는다.
> 특히 ECR 이미지 삭제, Route 53 레코드 삭제, RDS/외부 리소스는 **기본적으로 건드리지 않는다** —
> 사용자가 명시적으로 요청할 때만 지운다.

## 왜 순서가 중요한가

`eksctl delete cluster` 는 **eksctl이 만든 것만** 지운다. `kubectl`로 만든 `type: LoadBalancer`
Service(ingress-nginx)가 생성한 **NLB·타깃그룹·보안그룹은 AWS 쪽 리소스라 클러스터를 먼저 지우면
고아로 남는다.** 그러면:

- NLB가 계속 과금된다 (지워졌다고 착각하기 딱 좋은 항목).
- 그 NLB가 쓰는 보안그룹/ENI 때문에 VPC·서브넷 정리가 막힌다.
- eksctl의 CloudFormation 스택 삭제가 `DELETE_FAILED` 로 실패한다.

**따라서 k8s 리소스 → 클러스터 → AWS 잔여 순서를 지킨다.**

---

## 0-A. ★ 무엇보다 먼저: TLS 인증서 백업

**이걸 빼먹으면 다음 실습에서 Let's Encrypt 주간 한도(도메인당 5개)를 소모한다.**
한도에 걸리면 일주일간 HTTPS 실습이 막힌다. 인증서는 90일 유효하므로 백업본을 그대로 재사용한다.

```shell
aws-vault exec $PROFILE -- .claude/skills/ordersystem-eks-env/scripts/tls-backup.sh backup
```

백업 위치는 `~/.ordersystem-eks/tls-backup/` (레포 밖 — **개인키가 들어 있어 절대 커밋 금지**).
다음 세팅 때 setup.md의 `5-0` 단계에서 `restore` 하면 된다.

> 이 단계는 사용자가 "다 지워줘"라고만 해도 **묻지 말고 먼저 실행**한다. 조회·저장뿐이라 안전하고,
> 빼먹었을 때의 손해가 크다.

---

## 0-B. 현황 파악

```shell
aws-vault exec $PROFILE -- .claude/skills/ordersystem-eks-env/scripts/verify.sh
```

무엇이 떠 있는지 확인하고, **지울 범위를 사용자와 합의**한다.

| 요청 | 범위 |
|---|---|
| "앱만 내려줘" | L8~L4 (k8s 리소스만, 클러스터 유지) |
| "오늘 실습 끝났어 / 다 지워줘" | 전체 (L8 → L1 + 고아 점검) |
| "클러스터는 살려둬" | L8~L3, 노드그룹만 0으로 스케일 다운도 대안 |

> 💡 **비용만 줄이고 클러스터는 유지하고 싶다면**: 노드그룹을 0으로 줄이면 EC2 비용은 사라지지만
> **컨트롤 플레인 요금($0.10/h 수준)은 계속 나간다.** 하루 이상 안 쓸 거면 통째로 지우는 게 싸다.
> ```shell
> aws-vault exec $PROFILE -- eksctl scale nodegroup --cluster $CLUSTER --name my-worker-node \
>   --nodes 0 --nodes-min 0 --nodes-max 2
> ```

---

## 1. L8 — 모니터링

```shell
aws-vault exec $PROFILE -- kubectl delete namespace monitoring
```

## 2. L7 — ArgoCD

**ArgoCD Application부터 지운다.** `syncPolicy.automated.selfHeal: true` 라서 Application이 살아있는
동안 다른 리소스를 지우면 ArgoCD가 다시 만들어낸다.

```shell
aws-vault exec $PROFILE -- kubectl delete -f 2.ordersystem/k8s/k8s-argocd/argocd-application.yaml
aws-vault exec $PROFILE -- kubectl delete namespace argocd
```

> Application 리소스가 finalizer 때문에 `Terminating`에서 멈추면:
> `kubectl patch application <name> -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge`

## 3. L6 — 오토스케일링

```shell
aws-vault exec $PROFILE -- kubectl delete -f 2.ordersystem/k8s/k8s-ordersystem/hpa.yml
# cluster-autoscaler를 배포했다면
aws-vault exec $PROFILE -- kubectl delete -f <autoscaler.yml>
aws-vault exec $PROFILE -- kubectl delete -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

CA 실습으로 노드가 늘어난 상태면 min/max를 원복해 둔다 (안 그러면 클러스터 삭제 중 노드가 다시 뜬다):

```shell
aws-vault exec $PROFILE -- eksctl scale nodegroup --cluster $CLUSTER --name my-worker-node \
  --nodes 2 --nodes-min 2 --nodes-max 2
```

## 4. L5 — cert-manager (HTTPS)

```shell
aws-vault exec $PROFILE -- kubectl apply --dry-run=client -f 2.ordersystem/k8s/k8s-ordersystem/https.yml  # 대상 확인
aws-vault exec $PROFILE -- kubectl delete -f 2.ordersystem/k8s/k8s-ordersystem/https.yml
```

ClusterIssuer는 클러스터 스코프라 네임스페이스를 지워도 남는다 — 위 파일 기준으로 지워야 한다.

## 5. L4 — 애플리케이션

```shell
cd 2.ordersystem/k8s/k8s-ordersystem
aws-vault exec $PROFILE -- kubectl delete -f ingress.yml -f depl_svc.yml -f redis.yml
# 또는 통째로
aws-vault exec $PROFILE -- kubectl delete namespace $NS
```

> 네임스페이스를 지우면 그 안의 Secret(`my-app-secrets`)과 cert-manager가 발급한 TLS Secret도 같이
> 사라진다. **0-A 단계의 `tls-backup.sh backup`을 실행했는지 여기서 다시 확인한다.**
> 안 했다면 지금이라도 실행할 것 — 네임스페이스를 지우는 순간 인증서는 복구 불가다.

## 6. cert-manager 컨트롤러 제거

```shell
aws-vault exec $PROFILE -- kubectl delete -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
```

(설치할 때 쓴 것과 **같은 버전 URL**로 지워야 CRD까지 깨끗이 사라진다.)

## 7. L3 — ingress-nginx ★ 가장 중요

**여기서 NLB가 삭제된다. 클러스터 삭제 전에 반드시 끝내야 한다.**

```shell
aws-vault exec $PROFILE -- kubectl delete -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
```

NLB가 실제로 사라졌는지 확인 (몇 분 걸린다):

```shell
aws-vault exec $PROFILE -- kubectl get svc -A --field-selector spec.type=LoadBalancer   # 비어 있어야 함
aws-vault exec $PROFILE -- aws elbv2 describe-load-balancers --region ap-northeast-2 \
  --query 'LoadBalancers[].{Name:LoadBalancerName,State:State.Code}' --output table
```

**LoadBalancer 타입 Service가 하나도 남지 않은 것을 확인한 뒤에** 다음 단계로 간다.

## 8. L1 — 클러스터 + 노드그룹

```shell
aws-vault exec --no-session $PROFILE -- eksctl delete cluster -f 1.k8s_basic/0.eks_setting/cluster.yaml --wait
# 또는
aws-vault exec --no-session $PROFILE -- eksctl delete cluster --name $CLUSTER --region ap-northeast-2 --wait
```

> eksctl은 `--no-session` 으로 실행한다 (IAM 호출 때문 — SKILL.md 참고).

- 10~15분 걸린다. 백그라운드로 돌리고 주기적으로 확인한다.
- 콘솔로 만든 클러스터라면 eksctl로 못 지울 수 있다 → **노드그룹 먼저, 클러스터 나중** 순서로 콘솔/CLI 삭제:
  ```shell
  aws-vault exec $PROFILE -- aws eks delete-nodegroup --cluster-name $CLUSTER --nodegroup-name <NG> --region ap-northeast-2
  # 노드그룹 DELETED 확인 후
  aws-vault exec $PROFILE -- aws eks delete-cluster --name $CLUSTER --region ap-northeast-2
  ```

### 삭제가 실패하면

```shell
aws-vault exec $PROFILE -- aws cloudformation describe-stack-events --stack-name eksctl-$CLUSTER-cluster \
  --region ap-northeast-2 --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceStatusReason]' --output table
```

대부분 원인은 **남아있는 ENI / 보안그룹 / LB**다. 7단계(ingress-nginx 삭제)를 건너뛰었는지 먼저 의심한다.
해당 리소스를 수동 삭제한 뒤 `eksctl delete cluster --force` 로 재시도한다.

## 9. 잔여 리소스 점검 ★ 필수

```shell
aws-vault exec $PROFILE -- .claude/skills/ordersystem-eks-env/scripts/orphan-check.sh
```

이 스크립트는 **조회만 하고 지우지 않는다.** 출력에 뭔가 남아 있으면 사용자에게 목록과 삭제 명령을
제시하고 확인받은 뒤 지운다. 점검 대상:

| 리소스 | 과금 | 비고 |
|---|---|---|
| ELB/NLB, 타깃그룹 | 💰 | 가장 흔한 고아. 반드시 0이어야 함 |
| EBS 볼륨 (`available`) | 💰 | 노드 삭제 후 남은 볼륨 |
| Elastic IP (미연결) | 💰 | 미연결 EIP는 오히려 과금됨 |
| ENI (`available`) | - | 삭제 실패의 주범 |
| 보안그룹 (`*eks*`, `k8s-*`) | - | ENI 정리 후 삭제 가능 |
| CloudFormation `eksctl-*` 스택 | - | 남아있으면 삭제 실패 흔적 |
| CloudWatch 로그그룹 `/aws/eks/*` | 💰(소액) | 보존기간 무제한이면 계속 쌓임 |
| ECR 이미지 | 💰(소액) | **사용자 확인 후에만 삭제** — 다음 실습에 재사용 가능 |
| Route 53 호스팅 영역 | 💰 ($0.5/월) | 도메인 유지할 거면 두는 게 맞음. **레코드만 정리 제안** |

## 10. 마무리 보고

사용자에게 다음을 정리해 보고한다.

- 지운 것 / 남긴 것 (남긴 이유 포함 — 예: "ECR 리포지토리는 다음 실습 재사용 위해 유지")
- 여전히 과금되는 항목이 있다면 명시 (Route 53 호스팅 영역, 도메인, RDS 등)
- `orphan-check.sh` 최종 출력 (깨끗함을 증거로 제시)
