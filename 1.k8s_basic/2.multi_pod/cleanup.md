# 리소스 삭제 명령어 모음

## 개별 리소스 삭제

### Ingress 삭제
```shell
aws-vault exec eks-practice -- kubectl delete -f ./ingress_nginx.yml
```

### Deployment & Service 삭제
```shell
aws-vault exec eks-practice -- kubectl delete -f ./nginx_deployment.yml
```

### ReplicaSet 삭제
```shell
aws-vault exec eks-practice -- kubectl delete -f ./nginx_replicaset.yml
```

---

## 전체 삭제 (한번에)

### YAML 파일 기준 삭제
```shell
aws-vault exec eks-practice -- kubectl delete -f ./ingress_nginx.yml -f ./nginx_deployment.yml
```

### 네임스페이스 내 전체 삭제
```shell
aws-vault exec eks-practice -- kubectl delete all --all -n mj-eks
```

### 네임스페이스 자체 삭제 (하위 리소스 전부 삭제됨)
```shell
aws-vault exec eks-practice -- kubectl delete namespace mj-eks
```

---

## Ingress Controller 삭제

```shell
aws-vault exec eks-practice -- kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
```

---

## 삭제 확인

```shell
# 파드 확인
aws-vault exec eks-practice -- kubectl get pods -n mj-eks

# 서비스 확인
aws-vault exec eks-practice -- kubectl get svc -n mj-eks

# ingress 확인
aws-vault exec eks-practice -- kubectl get ingress -n mj-eks

# 전체 확인
aws-vault exec eks-practice -- kubectl get all -n mj-eks
```
