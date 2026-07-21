# 답안: 첫 운영 배포 — 인프라부터 CI/CD까지 (22~26회차 전체 복습)

> 문제: ./problem.md
> 출제 범위: `contents/video_scripts/22~26-*.md` (22. 인프라 자원 사전 생성, 23. 이미지 빌드/push, 24. 쿠버네티스 자원 생성, 25. HTTPS 인증서 작업, 26. GitHub Actions CI/CD)
> 풀이자: dave

---

## 문제 1. 인프라 자원 사전 준비 (22회차)

### (a) RDS 보안그룹 3306 포트 · Public Access
**묻는 것:** 디폴트 보안그룹에 `3306` 포트를 열어야 하는 이유 · Public Access를 별도로 허용해야 하는 이유(같은 AWS 내부 접근과의 차이).

**답:**

RDB는 보통 k8s 내부에 두는게 아니라 외부 클라우드 서비스를 이용하고 mysql 기본 접속 포트가 3306 이기때문에 k8s에서 외부 rdb 접근 하기 위해서는 K8s 아웃바운드 아이피를 rds 보안그룹에 3360 포트로 적용시켜야된다.

### (b) Redis를 Service(ClusterIP)로만 구성
**묻는 것:** Redis를 Pod + Service(ClusterIP)로만 두고 Ingress를 안 만든 이유 · Spring Pod가 Redis Pod와 직접 통신하지 않고 `Service`를 거쳐야 하는 이유.

Ingress 는 외부 통신을 위한건데 레디스는 클러스터 내부에서 통신하고 외부에는 노출을 안하기 때문
Pod 와 직접 소통하지 않고 서비스를 거쳐야하는 이유는 특정 레디스 Pod에 장애가 발생했을때 서비스는 해당 파드가 정상이 아니라는 것을 감지하고 라우팅을 하지 않고 정상적인 파드로만 라우팅을 해 시스템 전면 장애로 이어지지 않기 때문

### (c) 인프라 생성 작업의 성격
**묻는 것:** RDS/Redis/ECR 생성이 CI/CD와 비교해 반복 vs 일회성 중 어떤 성격인지, 왜 그런지.

**답:**

RDS/Redis/ECR 은 한번 만들어두면 지속적으로 쓰고 개선하는 용도지 매번 새로만드는 인프라 자원이 아니다.
CI/CD 는 애플리케이션 로직의 지속적인 통합과 배포를 의미함으로 반복적인 성격을 가진다.

---

## 문제 2. 이미지 빌드와 민감정보 분리 판단 (23회차)

### (a) profile 분기 메커니즘
**묻는 것:** `application.yaml`의 profile 값과 `application-local/prod.yaml`의 `config.activate.on-profile`이 어떻게 맞물려 실행 환경을 분기하는지.

**답:**
application.yaml 은 기본적인 Default 값이라 보면된다 해당 파일에 현재는 기본값이 Prod임으로 jar 파일 실행시 환경을 입력안하면 자동으로 prod로 인식한다. 만약 jar 파일 실행시 spring active profile을 local/prod 로 설정하면 application.yaml에는 있는 값들을 한번 거친후에 해당 local/prod yaml 으로 이동하여 동일한 값이 있으면 해당 환경에 값으로 덮어씌운다.

### (b) 빌드 시점에 자격증명 미포함
**묻는 것:** 빌드 시점에 `DB_HOST`/`DB_PW`가 이미지에 포함되지 않는 이유 · 실제 값은 언제·어디서 주입되는지.

**답:**
DB_HOST/ DB_PW 같은 민간정보는 컨테이너 이미지에 포함되면 안된다.(환경 분리를 위해) 대신에 실제 값은 k8s secret에 저장하고 그걸 depl.yml에서 DB_HOST를 어떤 값으로 쓸지 명시 함으로써 파드안에 컨테이너 실행시 환경변수로 주입된다.

### (c) DB 자격증명 vs JWT 서명 키 시크릿화 판단
**묻는 것:** DB 자격증명은 Secret으로 감추면서 JWT 키는 시크릿화 안 한 판단의 논리 · 실사용자 회원가입/로그인을 받게 돼도 그 판단이 유지될 수 있는지.

**답:**
이번에는 실습이기 때문에 시크릿화 안했지만 실서비스라면 반드시 JWT 키는 시크릿화 해야된다. 만약 해당 키가 탈취 당한다면 특정 회원의 키를 임의로 생성하거나 탈취하여 조작할 수 있기때문에 심각한 보안사고를 초래한다.

---

## 문제 3. Secret 운영 실습과 자격증명 관리 (24회차 Secret 파트 + 26회차 자격증명)

### (a) Secret 생성 명령 · base64 조회
**묻는 것:** `myappsecret`에 `DB_HOST`,`DB_PW` 담는 Secret 생성 명령 · `-o yaml` 조회 시 값이 원문으로 안 보이는 이유.

**답:**
kubectl create secret generic myappsecret \
  --from-literal=DB_PW=dev-pass123 \
  -n {my-namespace}
yaml 조회시 값은 base 64로 인코딩된다.

### (b) 기존 Secret에 JWT_SECRET 추가 절차
**묻는 것:** 이미 만든 Secret에 `JWT_SECRET` 키 추가 절차(명령·순서) · Deployment `env`에서 끌어올 때 이름이 무엇과 일치해야 하는지.

**답:**

새로 시크릿을 추가할때는 기존 이름의 키들을 복사 및 삭제하고 새로운 변수를 추가해서 다시 생성한다.
env에 env.name 과 yml 에 지정한 {DB_HOST} 같은 환경변수오 일치해야된다.

### (c) GitHub Repository Secrets에 AWS 키 저장 위험
**묻는 것:** AWS Access/Secret Key를 GitHub Repository Secrets에 저장해 쓰는 방식의 실무적 위험. (+ ⚠ 범위 밖: 장기 Access Key 대안(OIDC 기반 IAM Role 연동) / 몰라도 됨)

**답:**
해당 깃헙이 계정이 해킹당하면 중요 키들이 모두 노출된다?

---

## 문제 4. 무중단 배포 안정성과 트러블슈팅 (24회차 Deployment 파트)

### (a) readinessProbe와 무중단 배포
**묻는 것:** `/health`를 10초 뒤부터 확인하고 정상 응답 후 기존 Pod를 내리는 `readinessProbe` 방식이 왜 무중단 배포에 필수인지.

**답:**

10초 는 파드가 애플리케이션을 부팅하는데 걸리는 시간이고 정상 응답을 확인해야 롤링 배포시 기존 파드개수를 유지(가용성)할 수 있기때문에 무중단 배포에는 readinessProbe가 필수다.

### (b) resources requests/limits
**묻는 것:** `resources.requests`/`limits`(cpu/memory) 미설정 시 문제 · 점심 피크가 있는 이 서비스에서 두 값을 어떻게 다르게 잡을지(근거 포함).

**답:**
해당 값을 설정 하지 않을시 트래픽 피크 발생시 오토 스케일링이 시작될텐데 그때 쓸수있는 인프라 자원대비 더 많은 리소스가 한번에 생성돼 노드에 OOM이 발생하여 노드 장애가 발생할 여지가 있다.
그래서 피크 상황에서는 노드 스펙에 맞게 cpu 와 메모리를 지정해야된다.

### (c) revisionHistoryLimit
**묻는 것:** `revisionHistoryLimit`을 기본값보다 낮게 잡는 이유 · 그로 인한 트레이드오프.

**답:**
revisionHistoryLimit 은 그동안 해포 히스토리를 저장하는 개수인데 실습환경에서는 revisionHistoryLimit가 그렇게 많이는 필요없어서 낮게 잡은것이다.
리비전히스토리가 적으면 그만큼 롤백할 수 있는 범위가 줄어듬

### (d) 핸즈온 — Running 0/1 트러블슈팅
**묻는 것:** Pod가 `Running 0/1`로 안 올라올 때 원인 좁히는 명령 순서 · 강의에서 겪은 원인(스키마 이름 오타 → DB 연결 실패) 패턴 예시 · readinessProbe가 없었다면 벌어졌을 일.

**답:**
kubectl get pods -n {namespace}
kubectl decribe pods -n {namespace}
kubectl logs {pod_name} -n {namespace}

---

## 문제 5. HTTPS 인증서 발급 (25회차)

### (a) 비대칭키를 쓰는 이유
**묻는 것:** HTTPS에 대칭키가 아니라 비대칭키 방식이 쓰이는 구조적 이유.

**답:**
클라이언트(브라우저)에는 공개키를 주고 인증서를 관리하는 서버는 개인키를 가지고 있는 구족가 브라우저의 키가 탈취되어도 안전 하기 때문


### (b) 인증서 발급 흐름
**묻는 것:** 공개키/비밀키 생성부터 인증서 발급까지의 흐름(CSR, CA 검증 포함)을 순서대로.

**답:**
검증된 인증기관 (CA)를 통해 인증서를 발급하면 해당 인증기관으로부터 공개키와/비밀키를 발급 받고
해당 키들을 통해서 브라우저와 TLS 핸드셰이크 과정을 거친다.


### (c) cert-manager / ClusterIssuer / Certificate
**묻는 것:** `cert-manager`, `ClusterIssuer`, `Certificate` 세 자원의 역할 구분.

**답:**
ClusterIssuer: 어떤 CA에게, 어떤 방식으로 인증서를 받을지 정의


### (d) Certificate Ready=False 원인
**묻는 것:** `Certificate`의 `Ready`가 계속 `False`일 때 강의 근거로 가장 먼저 의심할 원인.

**답:**

지속적으로 false가 뜬다면 이건 외부에서 접근이 불가능한지 먼저 의심해봐야된다.
즉 Ingress 설정 이 잘되어있는지 확인해본다.
---

## 문제 6. GitHub Actions CI/CD 파이프라인 설계 (26회차)

### (a) workflow/event/job/runner · .github/workflows 경로
**묻는 것:** workflow/event/job/runner 개념 구분 · workflow 스크립트가 반드시 `.github/workflows`에 있어야 하는 이유.

**답:**
event: 실제 워크플로우가 실행되는 계기
workflow: 여러 작업들을 묶어 놓은 플로우
job: 워크플로우에서 실제 진행될 작업의 단위
runner: job이 실행될 환경

`.github/workflows`에 있어야 하는 이유: 깃헙에서 규격임으로?

### (b) 반복 vs 최초 1회 작업
**묻는 것:** 파이프라인에서 반복 실행돼야 할 작업 vs 최초 1회 작업 구분 · 이 워크플로우가 매번 반복하는 스텝이 무엇인지.

**답:**
인프라 작업은 최초 1회 진행
반복 되는 작업은 CI/CD 작업 즉 애플리케이션에 변경사항에 대한 지속적인 통합과 배포를 자동화 한것

### (c) Deployment yaml이 자주 바뀔 때 워크플로우 보강
**묻는 것:** Deployment yaml(`resources`/`env` 등)이 자주 바뀔 예정일 때 현재 워크플로우(체크아웃→kubectl/AWS CLI 설치→ECR 로그인→빌드/push→rollout restart)에 무엇을 추가해야 하는지. (+ ⚠ 범위 밖: Blue-Green/Canary 배포로 확장 시 추가로 필요한 것 / 몰라도 됨)

**답:**

resources 는 파드가 인프라 리소스를 설정하는거고 env는 환경변수를 담당하는데 이게 자주바뀔때 어떻게 해야할지는 모르겠음
---

> 제약(참고): 점심 피크에도 배포로 인한 5xx 없어야 함 · 시크릿/인증키/AWS 자격증명이 소스·Git 히스토리에 노출 금지 · GitHub 레포 public 유지 · 롤백은 빠르고 예측 가능해야 함.
