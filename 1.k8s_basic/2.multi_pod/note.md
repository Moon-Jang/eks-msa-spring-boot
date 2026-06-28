## ingress-controller(nginx) 앞에 AWS NLB 두는이유
1. ingress-controller 와 ALB 는 둘 다 L7 레이어이며 역할이 충돌된다.
- L7 기능'의 중복과 자원 낭비 (기능의 중복)
    - ALB가 하는 일: "오, URL이 abc.naver.com/api네? 내부 Nginx 파드로 보내야지!" (L7 연산 수행)
    - Nginx가 하는 일: "오, 나한테 왔네? URL이 abc.naver.com/api니까 뒤에 있는 Spring Boot 파드로 보내야지!" (L7 연산 또 수행)
2. k8s 표준 방식이다.
3. NLB 사용시 앞단에 고정 IP 활용 가능
- NLB는 가용 영역(AZ)당 하나의 고정된 공인 IP를 가질 수 있습니다. 반면 ALB는 트래픽에 따라 IP가 수시로 변합니다. (외부 협력사나 방화벽 장비에 "우리 서버 IP 이거니까 화이트리스트에 등록해줘"라고 고정 IP를 줘야 할 때 NLB가 필수적입니다.)

## Route 53 설정
1. route53 -> 호스팅 영역 -> 도메인 -> 레코드 생성
2. A 레코드 -> 네트워크 로드밸런서 -> 생성된 로드밸런서 클릭 -> 저장

## ingress-nginx.yml 적용
1. 적용
```Shell
kubectl apply -f ./ingress_nginx.yml 
```
2. 확인
```Shell
kubectl get ingress -n mj-eks
```

## ingress 적용 테스트