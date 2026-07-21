# 시나리오: 첫 운영 배포 — 인프라부터 CI/CD까지 (22~26회차 전체 복습)

> 출제 범위: `contents/video_scripts/22~26-*.md` (22. 인프라 자원 사전 생성, 23. 이미지 빌드/push,
> 24. 쿠버네티스 자원 생성, 25. HTTPS 인증서 작업, 26. GitHub Actions CI/CD) — `contents/7.spring-백엔드- 서버-배포-1차.md`는 보조 참고
> 형식: 아키텍처 의사결정 서술형 + 핸즈온 트러블슈팅. 각 문제는 해당 회차 스크립트 하나(또는 밀접한
> 두 개)를 통째로 커버하도록 구성했다 — 개수를 먼저 정하지 않고, 5개 회차의 실제 분량에 맞춰 문제
> 6개로 자연스럽게 나눴다.
> ※ `⚠ 강의 범위 밖` 표시가 붙은 항목은 22~26회차에 나오지 않은 내용이다. 아는 선에서 서술하면 되고,
> 몰라도 감점 없음(알면 가점).

## 배경

이 레포의 `2.ordersystem` 스프링 백엔드를 **처음으로 EKS 운영 환경에 배포**하는 담당자다. RDS/Redis/ECR
같은 인프라 자원을 사전에 만들고, 이미지를 빌드해 ECR에 올리고, Secret·Deployment·Service·Ingress를
구성하고, HTTPS 인증서를 붙이고, 마지막으로 GitHub Actions로 CI/CD를 자동화하는 전체 파이프라인을
한 번씩 다 겪었다. 이 서비스는 아직은 테스트 목적이라 실제 회원 개인정보가 없지만, 곧 실사용자를
받을 계획이고, 점심 시간대에 트래픽이 튀는 특성이 있다.

## 문제 1. 인프라 자원 사전 준비 (22회차)

- (a) 손쉬운 생성으로 RDS를 만들면 잡히는 디폴트 보안그룹은 인바운드 규칙이 비어 있다. 왜 3306 포트를
  열어줘야 하는지, 그리고 별도로 Public Access까지 허용해야 하는 이유(같은 AWS 내부 접근과 무엇이
  다른지)를 서술하라.
- (b) Redis를 Pod + Service(ClusterIP)로만 구성하고 별도 Ingress를 만들지 않은 이유, 그리고 Spring
  Pod가 Redis Pod와 직접 통신하지 않고 Service를 거쳐야 하는 이유를 서술하라.
- (c) RDS/Redis/ECR을 만드는 이 작업들이 나중에 배울 GitHub Actions CI/CD와 비교했을 때 어떤 성격의
  작업(반복 vs 일회성)인지, 왜 그런지 서술하라.

## 문제 2. 이미지 빌드와 민감정보 분리 판단 (23회차)

- (a) `application.yaml`의 profile 값과 `application-local.yaml`/`application-prod.yaml`의
  `config.activate.on-profile` 값이 어떻게 맞물려 실행 환경을 분기하는지 서술하라.
- (b) 이미지를 빌드하는 시점에 `DB_HOST`/`DB_PW` 값이 이미지 안에 포함되지 않는 이유와, 실제 값은
  언제·어디서 주입되는지 서술하라.
- (c) 같은 맥락에서 DB 자격증명은 Secret으로 감추면서 JWT 서명 키는 "실제 사용자 데이터가 없어 토큰이
  조작당해도 위협이 크지 않다"는 이유로 시크릿화하지 않았다. 이 판단의 논리를 설명하고, 이 서비스가
  곧 실사용자 회원가입/로그인을 받게 됐을 때도 그 판단이 유지될 수 있는지 서술하라.

## 문제 3. Secret 운영 실습과 자격증명 관리 (24회차 Secret 파트 + 26회차 자격증명)

- (a) `myappsecret`이라는 이름으로 `DB_HOST`, `DB_PW` 두 키를 담은 Secret을 생성하는 명령을 쓰고,
  `kubectl get secret ... -o yaml`로 조회했을 때 값이 원문 그대로 보이지 않는 이유를 서술하라.
- (b) 이미 만든 Secret에 `JWT_SECRET` 키를 새로 추가하고 싶다. 강의에서 다룬 절차(어떤 명령을 어떤
  순서로 쓰는지)를 서술하고, Deployment의 `env`에서 이 값을 끌어올 때 무엇과 이름이 일치해야 하는지도
  함께 서술하라.
- (c) GitHub Actions는 AWS Access Key/Secret Key를 GitHub Repository Secrets에 저장해두고 그대로
  가져다 쓴다. 이 방식의 실무적 위험을 서술하라.
  `⚠ 강의 범위 밖`: 장기 Access Key 대신 쓸 수 있는 방식(예: OIDC 기반 IAM Role 연동)을 안다면
  덧붙여라. (몰라도 감점 없음)

## 문제 4. 무중단 배포 안정성과 트러블슈팅 (24회차 Deployment 파트)

- (a) `readinessProbe`가 `/health`로 컨테이너 시작 10초 뒤부터 확인하고, 정상 응답을 받아야 기존
  Pod를 내리는 방식이 왜 무중단 배포에 필수인지 서술하라.
- (b) `resources.requests`/`limits`(cpu/memory)를 설정하지 않으면 생기는 문제와, 점심 피크가 있는
  이 서비스에서 두 값을 어떻게 다르게 잡아야 하는지 근거와 함께 서술하라.
- (c) `revisionHistoryLimit`을 기본값보다 낮게 설정하는 이유와 그로 인한 트레이드오프를 서술하라.
- (d) **핸즈온**: 배포 후 Pod가 `Running 0/1` 상태로 몇 분째 안 올라온다. 원인을 좁혀가는 명령 순서를
  쓰고, 강의에서 실제로 겪은 원인(스키마 이름 오타로 인한 DB 연결 실패)과 같은 패턴을 예로 들어
  설명하라. 만약 이때 readinessProbe 자체가 없었다면 어떤 일이 벌어졌을지도 서술하라.

## 문제 5. HTTPS 인증서 발급 (25회차)

- (a) HTTPS 통신에 대칭키가 아니라 비대칭키 방식이 쓰이는 구조적인 이유를 서술하라.
- (b) 공개키/비밀키 생성부터 인증서 발급까지의 흐름(CSR, CA 검증 포함)을 순서대로 서술하라.
- (c) `cert-manager`, `ClusterIssuer`, `Certificate` 세 자원의 역할을 구분해 설명하라.
- (d) `Certificate` 자원의 `Ready` 상태가 계속 `False`일 때, 강의 내용에 근거해 가장 먼저 의심해야 할
  원인을 서술하라.

## 문제 6. GitHub Actions CI/CD 파이프라인 설계 (26회차)

- (a) GitHub Actions의 workflow/event/job/runner 개념을 구분해 설명하고, workflow 스크립트가 반드시
  `.github/workflows` 경로에 있어야 하는 이유를 서술하라.
- (b) 이 파이프라인에서 "반복적으로 실행돼야 하는 작업"과 "최초 1회만 하면 되는 작업"을 구분하고,
  실제로 이 워크플로우가 매번 반복 실행하는 스텝이 무엇인지 서술하라.
- (c) 만약 이 서비스의 Deployment yaml(`resources`/`env` 등)이 앞으로 자주 바뀔 예정이라면, 지금의
  워크플로우(체크아웃 → kubectl/AWS CLI 설치 → ECR 로그인 → 이미지 빌드/push → rollout restart)에
  무엇을 추가해야 하는지 서술하라.
  `⚠ 강의 범위 밖`: 이 CI/CD를 Blue-Green이나 Canary 배포로 확장하려면 무엇이 추가로 필요한지 아는
  선에서 서술하라. (몰라도 감점 없음)

## 제약 조건

- 점심 피크 시간대에도 배포로 인한 5xx가 발생하면 안 된다.
- 시크릿·인증키·AWS 자격증명이 소스코드나 Git 히스토리에 노출되면 안 된다.
- GitHub 레포는 public으로 유지해야 한다.
- 롤백은 빠르고 예측 가능해야 한다.
