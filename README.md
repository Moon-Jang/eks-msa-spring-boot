# EKS DevOps 실습 저장소

> 인프런 강의 **"EKS를 활용한 Spring 운영서버 배포 (feat. DevOps의 모든것)"** 를 기반으로 한 실습 레포지토리입니다.  
> 강의 링크: https://www.inflearn.com/course/eks-%EB%8D%B0%EB%B8%8C%EC%98%B5%EC%8A%A4%EC%A0%84%EB%B0%98

## 학습 내용

- Docker를 활용한 Spring Boot 애플리케이션 컨테이너화
- AWS EKS 클러스터 구축 및 운영
- Pod, Deployment, Service, Ingress 등 Kubernetes 핵심 리소스 실습
- GitHub Actions + ArgoCD를 활용한 CI/CD 자동화 파이프라인
- HPA/CA 기반 Pod 및 EC2 오토스케일링
- Prometheus + Grafana 모니터링 구성
- 모놀리식 → MSA(마이크로서비스) 아키텍처 전환 실습

## 실습 구조

```
1.k8s_basic/
├── 0.eks_setting/   # EKS 클러스터 초기 세팅
├── 1.pod_basic/     # Pod, Service 기본 실습
└── 2.multi_pod/     # Deployment, Ingress nginx 실습
```

## 목표

평소 접하기 어려웠던 클라우드 인프라와 컨테이너 오케스트레이션 환경을 직접 구축하고 운영하며,  
이론으로만 알던 DevOps 사이클을 손으로 익히는 것에 의의를 둡니다.
