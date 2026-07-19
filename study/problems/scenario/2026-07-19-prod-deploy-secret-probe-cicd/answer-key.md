# ⚠️ 스포일러 — 채점 루브릭 (첫 운영 배포: 22~26회차 전체 복습, 6문제)

> "유일한 정답"이 아니라 **평가 루브릭**. `범위 밖` 항목은 못 짚어도 감점하지 않는다(짚으면 가점).

## 문제 1. 인프라 자원 사전 준비 (22회차)

- (a) 디폴트 보안그룹은 **인바운드 규칙이 비어있고 아웃바운드만 전체 허용**된 상태다. EC2 위의 Pod가
  mysql(3306)로 RDS에 접근하려면 인바운드에 3306을 직접 추가해야 한다. Public Access는 포트만
  열어주면 이미 접근 가능한 **AWS 내부(EC2 등)**와 달리, 로컬 PC의 DB 툴(워크벤치 등)로 접속해 스키마를
  만드는 등 **AWS 바깥**에서 접근할 일이 있기 때문에 별도로 허용해야 한다.
- (b) Redis 서비스는 `ClusterIP` 타입이라 Ingress로 라우팅해주지 않으면 외부에서 접근이 불가능한데,
  Spring Pod만 내부적으로 Redis에 접근하면 되므로 의도적으로 Ingress 없이 둔다. Pod끼리 직접 통신하지
  않고 Service를 거치는 이유는 Pod IP가 재생성 때마다 바뀌므로 안정적인 이름(Service)으로 라우팅해야
  하기 때문.
- (c) RDS/Redis/ECR 생성은 **한 번만 만들어두면 두 번 할 일이 거의 없는 일회성 작업**이고, GitHub
  Actions로 자동화하는 이미지 빌드/push/파드 재생성은 소스코드가 바뀔 때마다 매우 **빈번하게 반복**되는
  작업이다. 이 성격 차이 때문에 전자는 수동으로, 후자만 자동화 대상이 된다.

## 문제 2. 이미지 빌드와 민감정보 분리 판단 (23회차)

- (a) `application.yaml`에 선언된 profile 값(`local` 또는 `prod`)과 각 프로필 전용 파일의
  `config.activate.on-profile` 값이 **일치해야** 해당 프로필 파일이 적용된다.
- (b) 소스코드·이미지 단계에서는 `DB_HOST`/`DB_PW`가 `${DB_HOST}` 식으로 **변수화만** 되어 있을 뿐
  실제 값이 없다. 실제 값은 Secret에 저장해두고 **Pod가 실행되는 시점**에 env로 주입한다. GitHub에
  public으로 코드가 올라가도 값이 노출되지 않게 하려는 목적.
- (c) JWT 서명 키 미시크릿화는 "덜 중요해서"가 아니라 **"위조해도 실제 사용자 데이터가 없어 피해가
  없다"는 위험 기반(risk-based) 판단**이었다는 점을 짚어야 함. 실사용자 회원가입/로그인이 생기면 JWT
  위조로 타인 계정 접근·권한 상승이 가능해져 이 전제가 깨지므로, **JWT 서명 키도 반드시 Secret화해야
  한다**는 결론이 나와야 함(키 교체 시 기존 토큰 무효화까지 언급하면 가점).

## 문제 3. Secret 운영 실습과 자격증명 관리 (24회차 Secret 파트 + 26회차)

- (a) `kubectl create secret generic myappsecret --from-literal=DB_HOST=<값>
  --from-literal=DB_PW=<값> -n <ns>` 형태. 조회 값이 원문과 다른 이유는 **암호화가 아니라 Base64
  인코딩**이기 때문(얼마든지 디코딩 가능).
- (b) 키 추가 전용 명령이 없으므로 **기존 Secret을 삭제(`kubectl delete secret myappsecret`)하고
  필요한 키를 모두 포함해 `--from-literal`로 재생성**해야 한다. env에서 끌어올 때는
  `valueFrom.secretKeyRef`의 key와, `application.yaml`에서 참조하는 `${JWT_SECRET}` 변수명이
  **정확히 일치**해야 한다.
- (c) Access Key/Secret Key는 **장기(long-lived) 자격증명**이라 유출 시 만료 전까지 계속 악용 가능,
  로테이션을 수동 관리해야 하는 부담, 어드민 권한이 있는 키라면 AWS 계정 전체가 위험해질 수 있음.

#### 범위 밖 (알면 가점)
- OIDC 기반 IAM Role 연동: 매 실행마다 단기 자격증명을 발급받아 장기 키를 저장소에 두지 않는 방식.

## 문제 4. 무중단 배포 안정성과 트러블슈팅 (24회차 Deployment 파트)

- (a) `/health`가 OK를 받아야 새 Pod가 준비됐다고 판단하고 그제서야 기존 Pod를 내리므로, 스프링이 완전히
  기동하기 전(약 10~20초) 트래픽이 새 Pod로 가는 것을 막아준다.
- (b) 미설정 시 한 Pod가 노드 자원을 최대치로 점유해 다른 Pod가 자원 부족을 겪을 수 있음. 피크 대응을
  위해 `limits`을 `requests`보다 여유 있게 두어(예: request 0.5 core/250Mi, limit 1 core/500Mi 비율)
  평소엔 적게 예약하고 피크 때 확장 사용 가능하게 함.
- (c) 배포/재시작마다 쌓이는 리비전(ReplicaSet)을 제한(예: 2)해 Argo CD 같은 배포 UI의 혼란을 줄임.
  트레이드오프는 **보관 리비전이 줄어 오래된 버전으로의 롤백 가능 범위가 축소**된다는 점.
- (d) 순서: ① `kubectl get pods -n <ns>`로 상태 확인 → ② 스케줄 자체가 안 되는 의심이면
  `kubectl describe pod`로 Events 확인 → ③ 내부 에러가 의심(강의 사례: DB 연결 실패)이면
  `kubectl logs -f`로 실시간 로그를 보고 원인(예: `unknown database`) 특정. readinessProbe가
  없었다면 **DB 연결에 실패한(=미준비) Pod가 Ready로 오인돼 기존 정상 Pod가 먼저 내려가는** 다운타임이
  발생할 수 있었다는 점까지 짚어야 만점.

## 문제 5. HTTPS 인증서 발급 (25회차)

- (a) 대칭키는 암복호화에 같은 키를 쓰므로 불특정 다수에게 나눠주면 서로 복호화가 가능해져 HTTPS엔
  구조적으로 못 씀. 비대칭키는 공개키만 나눠주고 비밀키는 서버가 보관하므로 다수에게 공개키를 뿌려도
  안전함.
- (b) 서버가 공개키/비밀키 생성 → 공개키+도메인 정보로 CSR(인증서 서명 요청) 생성 → CA 제출 → CA가
  도메인 소유권 검증 → 서명해 인증서 발급.
- (c) `ClusterIssuer`(어떤 CA·어떤 종류의 인증서를 쓸지 정의), `Certificate`(도메인 정보를 담아 발급
  요청)는 선언적 자원이고, 실제로 CA에 요청·발급받아 Secret에 저장하는 작업은 `cert-manager`가 수행.
- (d) 가장 먼저 **CA가 도메인 소유권을 확인하려고 보내는 HTTP 요청을 받아줄 Ingress 라우팅이 제대로
  안 돼 있는지**를 의심해야 함(인증서 작업 전에 http 라우팅부터 끝내둬야 한다는 강의 근거).

## 문제 6. GitHub Actions CI/CD 파이프라인 설계 (26회차)

- (a) **workflow**(하나 이상의 job을 포함하는 자동화된 프로세스 자체) → **event**(push 등 workflow를
  트리거하는 활동) → **job**(workflow 안에서 실행되는 한 단위의 작업) → **runner**(그 job이 실행되는
  가상/물리 서버)로 이어지는 계층 구조. `.github/workflows` 경로에 있어야 GitHub가 그 폴더를 스캔해
  workflow로 인식하기로 사전에 약속되어 있기 때문(파일명 자체는 중요하지 않고 yaml이면 됨).
- (b) 일회성: 인프라 사전 생성, Secret/Service/Ingress 최초 생성, cert-manager 자원 적용. 반복: 소스
  변경 → 이미지 빌드/push → `rollout restart`(파드 재생성). 이 워크플로우가 실제로 매번 반복하는 스텝은
  체크아웃 → (kubectl/AWS CLI 설치·클러스터 세팅은 가상 PC가 매번 새로 만들어지므로 이것도 매번 반복) →
  ECR 로그인 → 이미지 빌드/push → rollout restart 전체다.
- (c) Deployment yaml이 자주 바뀐다면 워크플로우에 **매 실행마다 `kubectl apply -f <deployment 파일>`
  스텝을 추가**해야 리소스/env/probe 변경이 재배포마다 반영된다(강의에서 "DPL이 자주 수정된다면 이것도
  같이 넣어주면 된다"고 명시).

#### 범위 밖 (알면 가점)
- Blue-Green/Canary 확장: 트래픽 가중치 분기 라우팅, 두 버전 동시 유지 자원, 버전별 모니터링·자동
  롤백 트리거 등이 추가로 필요.

## 흔한 오답 / 누락 포인트
- Public Access 허용 이유를 "EC2에서도 접근이 안 돼서"로 잘못 답함(실제로는 AWS 내부는 포트만 열면
  이미 접근 가능).
- JWT 미적용을 "덜 중요해서"로만 답하고 위험 기반 판단 근거를 놓침.
- Secret 값을 "암호화"라고 착각(실제로는 Base64 인코딩).
- readinessProbe 부재 시 문제를 "느려진다" 정도로만 답하고 "기존 정상 Pod가 먼저 내려가는" 다운타임
  시나리오를 놓침.
- resources를 requests=limits로 동일하게 답해 피크 대응 버스트 여지를 고려하지 않음.
- Certificate Ready=False 원인을 "CA 문제"로만 답하고 Ingress 라우팅 선행 조건을 놓침.
- CI/CD 반복 작업에 인프라 사전 생성까지 포함시켜 구분을 잘못함.
- workflow/event/job/runner를 뭉뚱그려 "다 같은 뜻"이라고 답함.

## 모범 답안 예시 (하나의 예시)
> **문제 1**: 디폴트 보안그룹은 인바운드가 비어있어 3306을 열어야 하고, AWS 내부는 포트만 열면
> 접근되지만 로컬 DB 툴 사용을 위해 Public Access를 추가로 연다. Redis는 Spring Pod만 접근하면 되므로
> Ingress 없이 ClusterIP로 둔다. 인프라 생성은 일회성, CI/CD의 이미지 빌드/재배포는 반복 작업이다.
>
> **문제 2**: profile 값과 `on-profile` 값이 일치하는 파일이 적용된다. 이미지에는 DB_HOST/DB_PW가
> 변수화만 되어 있고 Pod 실행 시점에 Secret에서 주입된다. JWT 키는 "위조해도 피해가 없다"는 위험 판단
> 이었는데, 실사용자가 생기면 위조 시 계정 탈취가 가능해지므로 Secret화해야 한다.
>
> **문제 3**: `--from-literal`로 Secret을 만들고, 조회값은 Base64라 디코딩 가능하다. 키 추가는 삭제 후
> 재생성하며, env의 secretKeyRef key와 야믈 변수명이 일치해야 한다. GitHub Secrets의 장기 AWS 키는
> 유출 시 계속 악용될 위험이 있다(범위 밖: OIDC).
>
> **문제 4**: readinessProbe 없이 배포하면 DB 연결 실패 Pod도 Ready로 오인돼 기존 정상 Pod가 먼저
> 내려가 다운타임이 생길 수 있다. resources는 피크 대응을 위해 limits를 여유 있게 둔다.
> revisionHistoryLimit을 낮추면 롤백 가능 리비전이 줄어든다. 트러블슈팅은 get pods → describe/logs
> 순으로 좁혀간다.
>
> **문제 5**: 비대칭키는 공개키를 다수에게 나눠줘도 안전해서 쓰며, 서버가 키쌍을 만들어 CSR을 CA에
> 제출해 검증받고 인증서를 발급받는다. Certificate가 Ready=False면 먼저 Ingress http 라우팅부터
> 확인한다.
>
> **문제 6**: workflow는 event로 트리거되고 job이 runner에서 실행된다. 이미지 빌드/push/재배포는
> 반복 작업이고 인프라·Secret·Ingress 생성은 일회성이며, Deployment가 자주 바뀐다면 파이프라인에
> apply 스텝을 추가해야 한다.
