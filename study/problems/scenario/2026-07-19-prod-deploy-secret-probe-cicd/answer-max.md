# 답안: 첫 운영 배포 — 인프라부터 CI/CD까지 (22~26회차 전체 복습)

> 문제: study/problems/scenario/2026-07-19-prod-deploy-secret-probe-cicd/problem.md
> 출제 범위: `contents/video_scripts/22~26-*.md` (22.인프라 자원 사전 생성 ~ 26.GitHub Actions CI/CD)
> 풀이자: max

---

## 문제 1. 인프라 자원 사전 준비 (22회차)

### (a) 3306 포트 · Public Access 허용 이유

**묻는 것:** 디폴트 보안그룹에 `3306` 포트를 열어야 하는 이유 · Public Access를 별도로 허용해야 하는 이유(AWS 내부 접근과의 차이).

**답:**

ec2 안에 떠있는 pod 가 db에 연결되려면 3306 포트를 열어줘야함. public access를 허용한 이유는 외부에서 접근할 db툴을 연결해서 사용하기 위함. (데이터그립이나 워크벤치 등등)

### (b) Redis 구성에서 Ingress 미사용 · Service 경유 이유

**묻는 것:** Redis를 Pod+Service(ClusterIP)만으로 구성하고 별도 `Ingress`를 만들지 않은 이유 · Spring Pod가 Redis Pod와 직접 통신하지 않고 `Service`를 거쳐야 하는 이유.

**답:**

레디스는 외부에서 접근할 필요가 없기때문에 굳이 ingress를 만들지 않았고 pod끼리 서로 통신할때는 ip로 통신해야하는데 pod는 언제든 다시 생성되거나 할수 있기때문에 ip 가 변경되게 되므로 안정적인 서비스 이름으로 서비스를 통해 통신하기 위함.

### (c) 인프라 자원 생성 vs CI/CD, 반복 vs 일회성

**묻는 것:** RDS/Redis/ECR 생성 작업과 GitHub Actions CI/CD를 비교했을 때 반복 vs 일회성 성격 차이와 그 이유.

**답:**

RDS/Redis/ECR을 만드는 이 작업들은 한번만 작업해두면 되는 일회성 작업들이다. GitHub Actions CI/CD는 코드가 계속 변경되고 자주 배포되면서 반복되는 작업이다.

---

## 문제 2. 이미지 빌드와 민감정보 분리 판단 (23회차)

### (a) profile 값과 on-profile의 실행 환경 분기

**묻는 것:** `application.yaml`의 profile 값과 `application-local/prod.yaml`의 `config.activate.on-profile` 값이 맞물려 실행 환경을 분기하는 방식.

**답:**

`application.yaml`은 공통 설정이기 때문에 스프링부트가 `application.yaml`를 먼저 로드함. 따로 프로필이 지정되어 있지 않으면 profile.default 값과 매칭되는 yaml 파일이 활성화 된다.

### (b) DB_HOST/DB_PW가 이미지에 포함되지 않는 이유 · 주입 시점

**묻는 것:** 이미지 빌드 시점에 `DB_HOST`/`DB_PW`가 이미지에 포함되지 않는 이유 · 실제 값이 언제·어디서 주입되는지.

**답:**

민감한 정보가 외부에 노출되지 않도록 하기 위함이고 실제 값은 secret에 따로 저장해두고있다. pod가 실행될때 yaml에 한번 주입된다.

### (c) DB 자격증명 vs JWT 서명 키의 시크릿화 판단

**묻는 것:** DB 자격증명은 Secret화하고 JWT 서명 키는 시크릿화하지 않은 판단의 논리 · 실사용자 회원가입/로그인이 생겨도 그 판단이 유지될 수 있는지.

**답:**

조작당해도 위협받을게 없기때문. 학습용이라 민감데이터가 있는것도 아님. 실사용자에게 오픈한 서비스라면 절대 노출되면 안됨.

---

## 문제 3. Secret 운영 실습과 자격증명 관리 (24회차 Secret 파트 + 26회차 자격증명)

### (a) Secret 생성 명령 · 원문이 안 보이는 이유

**묻는 것:** `myappsecret`에 `DB_HOST`/`DB_PW`를 담아 생성하는 명령 · `kubectl get secret ... -o yaml` 조회 시 값이 원문으로 안 보이는 이유.

**답:**

인코딩되어 저장되기 때문.

### (b) Secret에 키 추가하는 절차 · env 이름 일치 대상

**묻는 것:** 기존 Secret에 `JWT_SECRET` 키를 추가하는 절차(명령 순서) · Deployment `env`에서 값을 끌어올 때 이름이 일치해야 하는 대상.

**답:**

새로 키를 추가하고 싶다면 그냥 싹 지우고 키를 추가한다음 다시 생성한다. kubectl delete secret secret-name -n namespace, kubectl create secret generic secret-name -n namespace \ --from -literal=key=value 명령어 실행. env에서 JWT_SECRET 값을 가져올때는 key 가 JWT_SECRET이고 name과 ${변수명} 을 같게 해서 코드상에서 불러온다.

### (c) AWS 키를 GitHub Repository Secrets에 그대로 쓰는 방식의 위험

**묻는 것:** AWS Access Key/Secret Key를 GitHub Repository Secrets에 그대로 저장해 쓰는 방식의 실무적 위험. (+ ⚠ 범위 밖: 장기 Access Key 대신 쓸 수 있는 방식(예: OIDC 기반 IAM Role) / 몰라도 됨)

**답:**

시크릿에 넣어두고 사용하는건 기본적으로 만료기간이 길다는건데 한번 유출되면 위험이 커짐. 특히 만약 어드민 권한이 있으면 ㅈ됨.

강의 범위 밖: 모름.

---

## 문제 4. 무중단 배포 안정성과 트러블슈팅 (24회차 Deployment 파트)

### (a) readinessProbe가 무중단 배포에 필수인 이유

**묻는 것:** `readinessProbe`가 시작 10초 후부터 `/health`를 확인하고 정상 응답 후에야 기존 Pod를 내리는 방식이 무중단 배포에 필수인 이유.

**답:**

pod는 running 중이더라도 어플리케이션이 동작하는 중이 아닐수 있기때문.

### (b) requests/limits 미설정 문제 · 점심 피크 대응 값 설정

**묻는 것:** `resources.requests`/`limits`(cpu/memory)를 설정하지 않으면 생기는 문제 · 점심 피크가 있는 이 서비스에서 두 값을 어떻게 다르게 잡아야 하는지(근거 포함).

**답:**

pod 하나가 리소스를 다 잡아먹을 수 있음. 

### (c) revisionHistoryLimit을 낮게 설정하는 이유와 트레이드오프

**묻는 것:** `revisionHistoryLimit`을 기본값보다 낮게 설정하는 이유와 트레이드오프.

**답:**

불필요한 오브젝트 누적 방지, 오래된 이력은 의미가 별로 없음. 가시성이 좋음. 트레이드오프는 롤백 범위 축소

### (d) **핸즈온** Running 0/1 트러블슈팅

**묻는 것:** Pod가 `Running 0/1`로 안 올라올 때 원인을 좁혀가는 명령 순서 · 강의에서 겪은 원인(스키마 이름 오타로 DB 연결 실패)과 같은 패턴 예시 · readinessProbe가 없었다면 벌어졌을 일.

**답:**

kubectl get pod -n namespace, kubectl logs -f podname -n namespace 명령어로 빠르게 오류 확인. 만약 readinessProbe 설정이 없었다면 오류발생 상황에서 계속 트래픽을 받았을것이다.

---

## 문제 5. HTTPS 인증서 발급 (25회차)

### (a) 대칭키 대신 비대칭키를 쓰는 구조적 이유

**묻는 것:** HTTPS 통신에 대칭키가 아니라 비대칭키 방식이 쓰이는 구조적 이유.

**답:**

잘모름

### (b) 공개키/비밀키 생성부터 인증서 발급까지의 흐름

**묻는 것:** 공개키/비밀키 생성부터 인증서 발급까지의 흐름(CSR, CA 검증 포함)을 순서대로.

**답:**

잘모름

### (c) cert-manager · ClusterIssuer · Certificate 역할 구분

**묻는 것:** `cert-manager`, `ClusterIssuer`, `Certificate` 세 자원의 역할 구분.

**답:**

잘모름

### (d) Certificate Ready=False일 때 먼저 의심할 원인

**묻는 것:** `Certificate`의 `Ready`가 계속 `False`일 때 가장 먼저 의심해야 할 원인.

**답:**

잘모름

---

## 문제 6. GitHub Actions CI/CD 파이프라인 설계 (26회차)

### (a) workflow/event/job/runner 구분 · .github/workflows 경로 필수 이유

**묻는 것:** GitHub Actions의 workflow/event/job/runner 개념 구분 · workflow 스크립트가 `.github/workflows` 경로에 있어야 하는 이유.

**답:**

workflow는 자동화 프로세스를 정의하는 단위, event 는 workflow를 실행하는 트리거, job은 실제 작업단위, runner는 실제로 job을 실행하는 실행 환경 , workflows 스크립트가 반드시 지정된 폴더에 있어야하는 이유는 workflows 폴더에 yaml 파일로 정의하도록 약속이 되어있기 때문.

### (b) 반복 작업 vs 최초 1회 작업 구분 · 실제 반복 스텝

**묻는 것:** 이 파이프라인에서 "반복 실행돼야 하는 작업"과 "최초 1회만 하면 되는 작업" 구분 · 실제로 매번 반복 실행되는 스텝.

**답:**

일회성 작업은 인프라 리소스 생성(eks, ecr, ec2 등등), 반복작업은 소스코드 변경으로 이미지 빌드/푸시, 파드 재생성. 실제로 workflow가 매번 반복하는 작업은 가상환경 생성, 필요한 프로그램 설치, ecr 로그인, 이미지 build/push, kubectl rollout restart 로 pod 재생성.

### (c) Deployment yaml이 자주 바뀔 때 워크플로우에 추가할 것

**묻는 것:** Deployment yaml(`resources`/`env` 등)이 자주 바뀔 예정이라면 지금 워크플로우에 무엇을 추가해야 하는지. (+ ⚠ 범위 밖: Blue-Green/Canary 배포로 확장 시 추가로 필요한 것 / 몰라도 됨)

**답:**

kubectl apply -f deployment.yaml

강의 범위 밖: 모름

---

> 제약(참고): 점심 피크 5xx 무발생 · 시크릿/자격증명 미노출 · 레포 public 유지 · 롤백은 빠르고 예측 가능해야 함.
