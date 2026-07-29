#!/usr/bin/env bash
# 실습 환경 삭제 후 남은 과금/삭제방해 리소스 점검 (READ-ONLY — 아무것도 지우지 않음)
#
# 사용법:
#   aws-vault exec <프로필> -- .claude/skills/ordersystem-eks-env/scripts/orphan-check.sh
#
# 환경변수: REGION(기본 ap-northeast-2), CLUSTER(기본 eks-practice)

set -uo pipefail

REGION="${REGION:-ap-northeast-2}"
CLUSTER="${CLUSTER:-eks-practice}"
FOUND=0

head_() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
clean() { printf '  \033[32m✔ 없음\033[0m\n'; }
found() { FOUND=$((FOUND+1)); printf '  \033[31m✘ 남아있음\033[0m %s\n' "$*"; }
hint()  { printf '  \033[2m↳ 삭제: %s\033[0m\n' "$*"; }

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  printf '\033[31mAWS 자격증명이 없습니다.\033[0m aws-vault exec <프로필> -- 형태로 실행하세요.\n'
  exit 1
fi

printf '\033[1mEKS 실습 잔여 리소스 점검 (region=%s)\033[0m\n' "$REGION"
printf '\033[2m조회만 합니다. 삭제는 사용자 확인 후 수동으로 실행하세요.\033[0m\n'

head_ "EKS 클러스터"
OUT=$(aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  found "$OUT"
  hint "eksctl delete cluster --name <이름> --region $REGION --wait"
fi

head_ "로드밸런서 (ELB v2 / NLB·ALB) 💰"
OUT=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code,LoadBalancerArn]' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "위 로드밸런서가 계속 과금됩니다"
  hint "aws elbv2 delete-load-balancer --load-balancer-arn <ARN> --region $REGION"
fi

head_ "Classic ELB 💰"
OUT=$(aws elb describe-load-balancers --region "$REGION" \
  --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  found "$OUT"
  hint "aws elb delete-load-balancer --load-balancer-name <이름> --region $REGION"
fi

head_ "타깃 그룹"
OUT=$(aws elbv2 describe-target-groups --region "$REGION" \
  --query 'TargetGroups[].[TargetGroupName,TargetGroupArn]' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "타깃 그룹 잔존 (과금은 없지만 LB 고아의 흔적)"
  hint "aws elbv2 delete-target-group --target-group-arn <ARN> --region $REGION"
fi

head_ "미사용 EBS 볼륨 (available) 💰"
OUT=$(aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available \
  --query 'Volumes[].[VolumeId,Size,CreateTime]' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "미연결 볼륨이 GB당 과금됩니다"
  hint "aws ec2 delete-volume --volume-id <ID> --region $REGION"
fi

head_ "미연결 Elastic IP 💰"
OUT=$(aws ec2 describe-addresses --region "$REGION" \
  --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "미연결 EIP는 오히려 시간당 과금됩니다"
  hint "aws ec2 release-address --allocation-id <ID> --region $REGION"
fi

head_ "미사용 ENI (available) — 클러스터 삭제 실패의 주범"
OUT=$(aws ec2 describe-network-interfaces --region "$REGION" --filters Name=status,Values=available \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,Description]' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "ENI 잔존 — 보안그룹/서브넷 삭제를 막습니다"
  hint "aws ec2 delete-network-interface --network-interface-id <ID> --region $REGION"
fi

head_ "EKS/k8s 관련 보안그룹"
OUT=$(aws ec2 describe-security-groups --region "$REGION" \
  --query "SecurityGroups[?contains(GroupName,'eks') || contains(GroupName,'k8s') || contains(GroupName,'$CLUSTER')].[GroupId,GroupName]" \
  --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "보안그룹 잔존 (ENI 정리 후 삭제 가능)"
  hint "aws ec2 delete-security-group --group-id <ID> --region $REGION"
fi

head_ "CloudFormation eksctl 스택"
OUT=$(aws cloudformation list-stacks --region "$REGION" \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE DELETE_FAILED ROLLBACK_COMPLETE CREATE_FAILED \
  --query "StackSummaries[?starts_with(StackName,'eksctl-')].[StackName,StackStatus]" --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "eksctl 스택 잔존 — DELETE_FAILED면 이벤트 로그를 확인하세요"
  hint "aws cloudformation describe-stack-events --stack-name <이름> --region $REGION --query 'StackEvents[?ResourceStatus==\`DELETE_FAILED\`]'"
fi

head_ "Auto Scaling 그룹"
OUT=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName,'eks')].[AutoScalingGroupName,DesiredCapacity]" \
  --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "ASG 잔존 — 인스턴스가 계속 뜰 수 있습니다"
fi

head_ "실행 중 EC2 인스턴스"
OUT=$(aws ec2 describe-instances --region "$REGION" \
  --filters Name=instance-state-name,Values=running,pending \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | sed 's/^/    /'
  found "실행 중 인스턴스 💰 (실습과 무관한 것일 수도 있으니 확인 후 조치)"
fi

head_ "CloudWatch 로그그룹 (/aws/eks/*) 💰소액"
OUT=$(aws logs describe-log-groups --region "$REGION" --log-group-name-prefix /aws/eks \
  --query 'logGroups[].logGroupName' --output text 2>/dev/null)
if [ -z "$OUT" ]; then clean; else
  echo "$OUT" | tr '\t' '\n' | sed 's/^/    /'
  found "로그그룹 잔존 (보존기간 무제한이면 계속 쌓임)"
  hint "aws logs delete-log-group --log-group-name <이름> --region $REGION"
fi

head_ "ECR 리포지토리 💰소액 — ⚠️ 다음 실습 재사용 가능, 사용자 확인 후에만 삭제"
aws ecr describe-repositories --region "$REGION" \
  --query 'repositories[].[repositoryName,repositoryUri]' --output text 2>/dev/null | sed 's/^/    /'
echo "    ↳ 이미지 용량: aws ecr describe-images --repository-name <이름> --region $REGION --query 'imageDetails[].imageSizeInBytes'"

head_ "Route 53 호스팅 영역 💰 \$0.5/월 — ⚠️ 도메인 유지 중이면 지우지 말 것"
aws route53 list-hosted-zones --query 'HostedZones[].[Name,Id]' --output text 2>/dev/null | sed 's/^/    /'
echo "    ↳ NLB를 가리키던 A 레코드는 이제 깨진 상태입니다. 레코드만 정리하는 것을 권장합니다."

printf '\n'
if [ "$FOUND" -eq 0 ]; then
  printf '\033[1;32m✔ 정리 완료 — 과금되는 잔여 리소스가 없습니다.\033[0m\n'
  printf '  (단, Route 53 호스팅 영역 / ECR / 도메인 / RDS 등 의도적으로 남긴 것은 위 목록을 확인하세요)\n'
else
  printf '\033[1;31m✘ %d개 항목에 잔여 리소스가 있습니다.\033[0m 위 목록을 확인하고 삭제 여부를 결정하세요.\n' "$FOUND"
fi
