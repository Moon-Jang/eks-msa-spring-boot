#!/usr/bin/env bash
# EKS 실습 환경 사전 점검 (read-only)
#
# 사용법:
#   aws-vault exec <프로필> -- .claude/skills/ordersystem-eks-env/scripts/preflight.sh
#
# 환경변수: CLUSTER(기본 eks-practice), REGION(기본 ap-northeast-2), NS(기본 mj-eks)

set -uo pipefail

CLUSTER="${CLUSTER:-eks-practice}"
REGION="${REGION:-ap-northeast-2}"
NS="${NS:-mj-eks}"

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✘\033[0m %s\n' "$*"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

head_ "CLI 설치 확인"
for c in kubectl aws docker; do
  if command -v "$c" >/dev/null 2>&1; then ok "$c $(command -v "$c")"; else bad "$c 없음"; fi
done
if command -v eksctl >/dev/null 2>&1; then
  ok "eksctl $(eksctl version 2>/dev/null)"
else
  warn "eksctl 없음 — 'brew install eksctl' 또는 AWS 콘솔로 클러스터 생성"
fi
if command -v aws-vault >/dev/null 2>&1; then ok "aws-vault"; else warn "aws-vault 없음 (aws configure 프로필로도 가능)"; fi

head_ "AWS 프로필 목록"
if command -v aws-vault >/dev/null 2>&1; then
  aws-vault list 2>/dev/null | sed 's/^/  /'
else
  grep -E '^\[' ~/.aws/config 2>/dev/null | sed 's/^/  /'
fi

head_ "현재 자격증명"
if IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null); then
  ACCOUNT=$(echo "$IDENTITY" | sed -n 's/.*"Account": *"\([^"]*\)".*/\1/p')
  ARN=$(echo "$IDENTITY" | sed -n 's/.*"Arn": *"\([^"]*\)".*/\1/p')
  ok "Account=$ACCOUNT"
  ok "Arn=$ARN"
  echo "  ↳ 매니페스트/ECR URL의 계정 ID와 같은지 확인할 것 (강사 계정 값이 남아있을 수 있음)"
else
  bad "자격증명 없음 — 'aws-vault exec <프로필> -- 이 스크립트' 형태로 실행하세요"
  exit 1
fi

head_ "EKS 클러스터 (region=$REGION)"
CLUSTERS=$(aws eks list-clusters --region "$REGION" --query 'clusters[]' --output text 2>/dev/null)
if [ -z "$CLUSTERS" ]; then
  ok "클러스터 없음 (깨끗한 상태 — up 진행 가능)"
else
  for c in $CLUSTERS; do
    STATUS=$(aws eks describe-cluster --name "$c" --region "$REGION" --query 'cluster.status' --output text 2>/dev/null)
    warn "이미 존재: $c ($STATUS) — 💰 과금 중"
    aws eks list-nodegroups --cluster-name "$c" --region "$REGION" --query 'nodegroups[]' --output text 2>/dev/null \
      | tr '\t' '\n' | sed 's/^/      nodegroup: /'
  done
fi

head_ "kubeconfig / 클러스터 접속"
CTX=$(kubectl config current-context 2>/dev/null)
if [ -z "$CTX" ]; then
  warn "현재 컨텍스트 없음 — 'aws eks update-kubeconfig --region $REGION --name $CLUSTER' 필요"
else
  ok "context: $CTX"
  if kubectl get nodes >/dev/null 2>&1; then
    kubectl get nodes -o wide 2>/dev/null | sed 's/^/  /'
    echo
    if kubectl get ns "$NS" >/dev/null 2>&1; then ok "namespace $NS 존재"; else warn "namespace $NS 없음 — 'kubectl create namespace $NS' 필요"; fi
  else
    warn "kubectl이 클러스터에 붙지 못함 (kubeconfig 갱신 또는 권한 확인 필요)"
  fi
fi

head_ "IAM 역할 (eksctl cluster.yaml 참조 대상)"
for role in AmazonEKSClusterRole AmazonEKSNodeRole; do
  ERR=$(aws iam get-role --role-name "$role" 2>&1 >/dev/null)
  if [ -z "$ERR" ]; then
    ok "$role"
  elif echo "$ERR" | grep -q 'InvalidClientTokenId'; then
    warn "$role 확인 불가 (IAM 호출 거부) — 역할이 없는 게 아니라 자격증명 문제일 가능성이 큼"
    echo "      ↳ aws-vault의 GetSessionToken 임시 자격증명은 MFA 없이 IAM API를 호출할 수 없다."
    echo "        재확인: aws-vault exec --no-session <프로필> -- aws iam get-role --role-name $role"
  else
    warn "$role 없음 — cluster.yaml의 ARN 수정 필요"
  fi
done

head_ "Default VPC / 서브넷"
VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --region "$REGION" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ "$VPC" != "None" ] && [ -n "$VPC" ]; then
  ok "default VPC: $VPC"
  aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC" --region "$REGION" \
    --query 'Subnets[].{AZ:AvailabilityZone,Subnet:SubnetId}' --output text 2>/dev/null | sed 's/^/      /'
  echo "  ↳ cluster.yaml의 vpc.id / subnets 값과 일치하는지 확인할 것"
else
  warn "default VPC 없음 — cluster.yaml에 VPC/서브넷을 직접 지정해야 함"
fi

head_ "ECR 리포지토리"
aws ecr describe-repositories --region "$REGION" --query 'repositories[].repositoryUri' --output text 2>/dev/null \
  | tr '\t' '\n' | sed 's/^/  /' || warn "조회 실패 또는 리포지토리 없음"

head_ "Route 53 호스팅 영역"
aws route53 list-hosted-zones --query 'HostedZones[].Name' --output text 2>/dev/null \
  | tr '\t' '\n' | sed 's/^/  /' || warn "조회 실패 또는 없음"

printf '\n\033[1m점검 완료.\033[0m 위 결과를 바탕으로 어느 레벨부터 진행할지 결정하세요.\n'
