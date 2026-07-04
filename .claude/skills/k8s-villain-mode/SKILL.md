---
name: k8s-villain-mode
description: 스터디용 "빌런 모드" 문제 출제 스킬. 실무형 쿠버네티스 매니페스트에 의도적으로 미스컨피규레이션(에러)을 1~2개 심어서, 상대방이 kubectl describe/logs 등으로 트러블슈팅하며 원인을 찾도록 하는 문제를 생성한다. "빌런모드", "빌런 문제", "villain mode" 요청 시 사용.
---

# k8s 빌런 모드 문제 출제 스킬

이 레포는 인프런 "EKS를 활용한 Spring 운영서버 배포" 강의 실습 레포다.
`contents/` 아래 강의 노트(특히 `6.쿠버네티스-주요-요소-실습.md`, `7.spring-백엔드-서버-배포.md`)와
`1.k8s_basic/` 아래 기존 실습 매니페스트가 난이도/범위의 기준이다.

## 목적

강의에서 다룬 리소스(Pod, Service, ReplicaSet, Deployment, Ingress, Secret, HPA 등)를 바탕으로
"실무에서 실제로 겪을 법한" 미스컨피규레이션을 심은 매니페스트를 만들어, 상대방이 배포 후
`kubectl describe` / `kubectl logs` / `kubectl get events` 등으로 원인을 추적하게 만든다.
목표는 "잘 만드는 능력"이 아니라 "고장났을 때 디버깅하는 능력"이다.

## 실행 절차

1. **주제 파악 (필수 질문)**: 사용자가 이미 구체적인 주제를 명시하지 않았다면, 매니페스트를 만들기 전에
   반드시 "지금 어느 부분을 공부하고 있나요?"라고 먼저 물어본다 (`contents/`의 목차를 참고 옵션으로
   제시해도 좋다: namespace/label, Pod 다중 컨테이너, Service selector, ReplicaSet, Deployment
   rolling update, Ingress 라우팅, Secret 연동, HPA 등). 대화 맥락만으로 임의 추측해서 넘어가지 않는다 —
   사용자의 답을 받은 뒤에야 2단계로 진행한다.
2. **베이스라인 매니페스트 작성**: `1.k8s_basic/` 또는 `contents/`의 예시를 참고해 그 주제 수준에 맞는,
   정상 동작하는 실무형 매니페스트를 먼저 구상한다 (예: 스프링 백엔드 서비스 하나, nginx 프록시 하나 등
   현재 레포의 맥락과 어울리는 이름/구조 사용).
3. **버그 주입 (1~2개, 반드시 "그럴듯하게")**: 아래 카탈로그에서 주제와 관련된 항목을 골라 심는다.
   절대 문법 오류(YAML 파싱 자체가 깨지는 수준)로 만들지 않는다 — `kubectl apply`는 성공하지만
   런타임에 문제가 생기는 종류여야 트러블슈팅 훈련이 된다.

   | 카테고리 | 예시 |
   |---|---|
   | 라벨/셀렉터 불일치 | Service의 `selector`와 Pod/Deployment `template.metadata.labels` 불일치 |
   | 포트 불일치 | `containerPort`와 컨테이너 실제 리스닝 포트 불일치, Service `targetPort`가 `containerPort`와 다름 |
   | 이미지/태그 문제 | 존재하지 않는 태그, 오타난 이미지 이름 → `ImagePullBackOff` |
   | 프로브 오설정 | `readinessProbe`/`livenessProbe`의 path나 port가 실제 앱과 불일치 → 무한 재시작 |
   | 리소스 미설정 | `resources.limits` 누락/과소 설정 → `OOMKilled` |
   | 네임스페이스 불일치 | Secret/ConfigMap은 A 네임스페이스, Pod는 B 네임스페이스 |
   | 환경변수/Secret 키 오타 | Deployment의 `env`가 참조하는 Secret 키 이름이 실제 Secret의 키와 다름 |
   | 롤아웃 전략 | `maxUnavailable`/`maxSurge` 설정이 트래픽 특성과 안 맞음 (0 다운타임 요구인데 maxUnavailable 과다) |
   | Ingress 라우팅 | path prefix 타입(`Exact`/`Prefix`) 오설정, host 오타, 백엔드 service 포트 번호 오설정 |
   | HPA | `targetCPUUtilizationPercentage` 대상 리소스에 `resources.requests` 미설정되어 HPA가 동작 안 함 |

4. **결과물 생성**: `study/problems/villain/<YYYY-MM-DD>-<주제-슬러그>/` 디렉토리에 아래 3개 파일을 만든다.
   - `problem.yaml`: 버그가 심어진 매니페스트 (풀이자에게 그대로 전달됨)
   - `README.md`: 실무 시나리오 형태의 상황 설명 + 재현 방법(`kubectl apply -f problem.yaml`) + 관찰된 증상
     (예: "배포는 됐는데 외부에서 502가 뜬다", "파드가 계속 재시작된다") — **버그 위치나 원인은 절대 언급하지 않는다.**
   - `answer-key.md`: 심어놓은 버그 목록, 각 버그의 정확한 위치(파일/필드), 왜 문제가 되는지, 올바른 수정본,
     실무에서 이런 실수가 왜 위험한지 한 줄 설명. 파일 맨 위에 `⚠️ 스포일러 — 문제 풀기 전에 열지 마세요` 를 명시한다.
5. **주의**: `answer-key.md`는 `.gitignore`에 의해 커밋되지 않는다 (출제자만 로컬에서 보관). 출제자에게
   "이 파일은 커밋하지 말고, 상대방에게 problem.yaml과 README.md만 공유하세요"라고 안내한다.
6. 완료 후 사용자(출제자)에게는 어떤 카테고리의 버그를 몇 개 심었는지만 요약하고, **구체적인 위치는 말하지 않는다**
   (본인이 나중에 힌트를 주고 싶을 때를 위해 스포일러를 피한다).

## 정답 확인

풀이자가 수정한 매니페스트나 원인 분석을 제출하면, `k8s-answer-checker` 에이전트에게
문제 폴더 경로와 제출 내용을 전달해 채점을 위임한다.
