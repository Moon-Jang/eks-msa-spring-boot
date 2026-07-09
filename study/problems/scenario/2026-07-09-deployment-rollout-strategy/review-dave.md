# 채점 결과 — dave (시나리오 ② Deployment 배포 전략)

> 채점일: 2026-07-09 · 대상: `answer-dave.md` · 기준: `answer-key.md` 루브릭
> 서술형 시나리오이므로 클러스터 검증 없이 정적 평가.

## 종합 판정: 부분 통과

핵심 개념의 방향은 대체로 맞으나, (2)의 강제 재배포 명령이 **존재하지 않는 문법 + 메커니즘 오설명**,
(3)의 latest 결정타 누락, (1) 범위 밖 파라미터 값의 제약조건 모순이 주요 감점 요인.

---

## (1) 왜 롤링 업데이트인가 — 충족 (핵심 통과)

**제출 요지**
> "전부 내렸다 새로 올리는 방식은 다운타임(셧다운) 발생. 롤링은 새 파드 생성·헬스체크 후 구 파드를
> 내리므로 구/신 공존 단점은 있지만 무중단. 그래서 하위호환성을 염두에 두고 배포해야 한다."
> extra: `maxUnavailable=2, maxSurge=6`

**맞은 점**
- Recreate(전부 내리기) = 다운타임, 롤링 = 순차 교체로 무중단이라는 대비를 챕터 근거대로 정확히 서술.
- "구/신 버전 공존 → 하위호환성 필요"는 루브릭이 요구하지 않은 통찰까지 나아간 부분 → **가점**.

**틀린 점 (범위 밖이라 점수 감점은 없으나 개념 교정 필요)**
- `maxSurge=6`이 문제 제약과 **정면 모순**이다. 이 문제의 핵심 제약은 "노드 리소스 여유가 적다 →
  배포 중 추가로 뜨는 파드가 스케줄 안 될 수 있다"였다.
  - `maxSurge`는 "롤아웃 중 desired(6)를 **초과해서** 임시로 더 띄울 수 있는 파드 수"다.
    `maxSurge=6`이면 롤아웃 순간 최대 `6(기존) + 6(surge) = 12`개를 띄우려 시도한다.
  - 리소스가 빡빡하면 이 6개의 추가 파드가 `Pending`에 걸리고, 그 결과 롤아웃이 진행되지 못하고
    멈춘다(바로 이 문제가 우려한 시나리오를 스스로 유발).
- `maxUnavailable=2`도 무중단 최우선과 상충한다. `maxUnavailable`은 "롤아웃 중 desired 대비 **부족해도
  되는** 파드 수"다. 2로 두면 최소 가용이 4까지 떨어지는 것을 허용하는 셈. 무중단이 최우선이면
  이 값은 낮게(0 또는 1) 잡아야 한다.
- "평소 트래픽 감당 파드 2개 → maxUnavailable=2" 도출도 논리 연결이 약하다. 최소 가용을 4로 낮추겠다는
  뜻인데 무중단 목표와 방향이 반대다.
- **올바른 방향**: 리소스 빡빡 + 무중단 최우선 → `maxUnavailable: 0`, `maxSurge: 1`.
  → 항상 6개를 유지하고(가용성 보장), 추가로는 한 번에 1개만 더 띄워(리소스 절약) 순차 교체.

---

## (2) 리비전과 재배포 — 부분 충족 (명령/메커니즘 오류)

**(a)/(b) 판정 — 맞음**
- (a) 이미지 태그 `v1→v2` 변경 → `spec.template`이 바뀜 → **새 revision(ReplicaSet) 생성**. ✅
- (b) `replicas`만 변경 → `spec.template`은 그대로 → **revision 안 생김**, 기존 RS의 파드 수만 조정. ✅
  (루브릭이 지목한 흔한 오답 "replicas 변경으로도 revision 생긴다"를 정확히 피함.)

**틀린 점 ① — 존재하지 않는 명령 문법**
- 제출: `kubectl rollout deployment -f <deployment_file_path>`
- `kubectl rollout` 뒤에 올 수 있는 서브커맨드는 **`status / history / undo / pause / resume / restart`**
  6개뿐이다. `rollout deployment`라는 형태 자체가 없어 실행하면 에러가 난다.
- **정답**: `kubectl rollout restart deployment <name>` — 여기서 핵심은 **`restart`** 서브커맨드다.
  이걸 빠뜨려 명령이 성립하지 않는다.

**틀린 점 ② — 메커니즘 오설명**
- 제출: "deployment 템플릿 이미지를 이미지저장소에서 최신화한 후, 최신화한 버전과 현재 버전을
  비교하기 때문에 새 revision이 생성된다."
- 실제 동작은 "버전 비교"가 아니다. `rollout restart`는 **pod template의 어노테이션에
  `kubectl.kubernetes.io/restartedAt: <현재시각>`을 주입**한다. → template의 내용이 바뀐 것이 되어
  template 해시가 달라지고 → **새 ReplicaSet(revision)이 생성**되며 → 파드가 재생성된다.
  → 이때 `imagePullPolicy`에 따라 `latest` 이미지를 다시 pull한다.
- 즉 "새 revision이 생긴다"의 원인은 **어노테이션 주입에 의한 template 변경**이지 이미지 버전 비교가
  아니다. (루브릭 근거: "template에 변화가 없더라도 내부적으로 강제로 새 RS 생성")

---

## (3) 롤백 — 부분 충족

**맞은 점**
- `kubectl rollout undo` 서브커맨드를 롤백 명령으로 지목 ✅.
- "여러 개의 ReplicaSet 중 정해진 revision의 RS로 파드를 생성한다"고 서술 → 롤백이 단순 이미지 재apply가
  아니라 **RS 전환**이라는 루브릭 핵심을 잡음(가점).

**틀린 점 ① — 명령 문법 혼용**
- 제출: `kubectl rollout undo deployment -f <deployment_file_path>`
- `undo`는 리소스를 `deployment/<name>` 또는 `deployment <name>`으로 지정하거나 `-f FILENAME`을 쓰는데,
  제출은 **이름 없는 `deployment`와 `-f`를 뒤섞어** 어색하다.
- **정답**: `kubectl rollout undo deployment <name>` (직전으로) / `--to-revision=N` (특정 리비전).

**틀린 점 ② — 롤백 대상 revision 개념 미확립**
- 제출: "바로 직전 revision으로 가는 건지, 특정 번호를 알아야 하는지 확신이 안 선다."
- **정답**: 인자 없이 `undo`만 실행하면 **기본이 직전(previous) revision**이다. 특정 리비전으로 가려면
  `--to-revision=N`을 붙인다. (`kubectl rollout history`로 리비전 목록/번호 확인 가능.)

**틀린 점 ③ — latest 문제의 결정타 누락**
- 제출: "latest 태그를 쓰면 현재 어떤 버전인지 식별할 수 없다. 그래서 항상 revision 번호를 식별해야 하는
  단점이 있을 것 같다." → **식별 어려움**까지만 지적.
- 루브릭의 핵심은 그다음이다: latest는 **가변 태그**라 각 revision이 어떤 이미지였는지 특정할 수 없고,
  `undo`로 이전 RS를 되살려도 그 RS 역시 `latest`를 가리키므로 **같은 (버그 있는) 이미지를 다시 pull해
  버그가 그대로 재현**된다 → 롤백이 사실상 무의미해진다. 그래서 **불변 태그(커밋 SHA 등)**를 써야 한다.
- 이 "롤백해도 버그 재현" 결정타와 불변 태그 대안을 놓쳤다.

---

## 범위 밖 (DB 스키마 동반 배포) — 시도 양호 (가점)

**제출 요지**
> "롤링 중 구/신 공존. DDL은 즉시 반영되므로 컬럼 추가 시 먼저 DDL을 반영하고, 신버전은 신규 컬럼을
> 쓰고 구버전은 인지 못하지만 안 쓰므로 문제없다. 롤백 시엔 파드가 다 롤백되면 그때 컬럼 제거 DDL 실행."

**평가**
- 👍 expand/contract의 방향(먼저 nullable하게 컬럼 추가 → 신버전만 사용 → 구버전은 무시)을 스스로
  도출한 점은 좋다.
- △ 다만 문제가 명시한 **`NOT NULL` 컬럼 추가** 케이스의 핵심을 비껴갔다. NOT NULL이면 그 컬럼을 채우지
  않는 **구버전의 INSERT가 제약 위반으로 깨진다**. 그래서 반드시 `nullable로 추가 → 신코드 배포 →
  backfill → 마지막에 NOT NULL 제약 추가`처럼 단계를 분리해야 한다. "일단 DDL 반영"으로 넘어가면
  NOT NULL 케이스에서 구버전이 죽는다.
- ⚠️ 롤백 시 "컬럼 제거 DDL 실행"은 그 순간 그 컬럼에 쌓인 데이터를 버리는 것이라 **데이터 유실 위험**.
  실무에선 신중해야 하는 파괴적 작업.

---

## kubectl 문법 정정 요약

| 제출 표현 | 판정 | 정정 |
|---|---|---|
| `kubectl rollout deployment -f <path>` | 오류(존재하지 않음) | `kubectl rollout restart deployment <name>` |
| `kubectl rollout undo deployment -f <path>` | 어색/혼용 | `kubectl rollout undo deployment <name>` (직전) / `--to-revision=N` |

## 복습 포인트
1. `rollout restart`의 실제 메커니즘: 어노테이션 주입 → template 변경 → 새 revision. 이미지 재pull은 별개.
2. latest 태그 롤백 함정: 같은 이미지 재pull로 버그 재현 → 불변 태그(SHA) 사용.
3. 범위 밖 심화: maxSurge/maxUnavailable가 "무중단 + 리소스 빡빡" 제약과 어떻게 상호 제약되는지 산수로.
