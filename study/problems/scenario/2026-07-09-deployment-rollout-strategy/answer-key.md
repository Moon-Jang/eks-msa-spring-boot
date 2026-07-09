# ⚠️ 스포일러 — 채점 루브릭 (시나리오 ②)

> "유일한 정답"이 아니라 **평가 루브릭**. `범위 밖` 항목은 못 짚어도 감점하지 않는다(짚으면 가점).

## (1) 왜 롤링 업데이트인가 — 반드시 언급 (챕터 근거)

- 챕터 근거: Deployment는 "새 Pod를 생성한 후 기존 Pod를 순차적으로 종료"하는 롤링 업데이트가 기본.
- 이 순차 교체 덕에 배포 중에도 항상 일부 Pod가 살아 요청을 처리 → 다운타임 최소화.
- "전부 내렸다 새로 올리는" 방식(=Recreate 개념)은 교체 순간 처리 가능한 Pod가 0이 되어 다운타임/5xx.
  (Recreate라는 용어를 몰라도 "전부 내리면 그 사이 요청을 못 받는다"는 논리면 정답)

### 범위 밖 (알면 가점)
- `maxUnavailable`/`maxSurge` 값 제시 + 산수. 예: replicas 6, `maxUnavailable: 0`, `maxSurge: 1`
  → 항상 6개 유지, 최대 7개까지만 떠서 노드 리소스 제약도 만족.

## (2) 리비전과 재배포 — 반드시 언급 (챕터 근거)

- (a) 이미지 태그 `v1`→`v2`: `spec.template`이 바뀌므로 **새 revision(ReplicaSet) 생성**. ✅
- (b) `replicas`만 변경: `spec.template`은 그대로이므로 **새 revision 없음**, 기존 ReplicaSet의 Pod 수만
  조정. (챕터 "spec.template의 값이 변경될 때 새 ReplicaSet 생성"에 정확히 근거)
- latest 강제 재배포: `kubectl rollout restart deployment <name>`.
  chapter 근거: "template에 변화가 없더라도 내부적으로 강제로 새 ReplicaSet을 생성 → latest 태그를
  그대로 써도 새 revision 생성."

## (3) 롤백 — 반드시 언급 (챕터 근거)

- 명령: `kubectl rollout undo deployment <name>` (chapter에 명시). `--to-revision=N` 언급 시 가점.
- 내부 동작: Deployment가 revision마다 ReplicaSet을 보관 → 이전 ReplicaSet을 다시 살리고(replicas↑)
  현재 것을 줄이는 롤링으로 되돌림. (단순 이미지 교체가 아니라 RS 전환임을 짚으면 가점)
- latest 태그 문제: 어떤 이미지가 배포됐는지 revision으로 특정 불가 → 롤백해도 같은 latest를 당겨
  버그가 재현될 수 있음. 불변 태그(커밋 SHA 등)를 써야 함.

### 범위 밖 (알면 가점)
- DB 스키마 변경 동반 시: 코드는 되돌아가도 스키마 변경은 rollout이 관리하지 않아 안 되돌아감 →
  구코드와 불호환. expand/contract(하위호환 단계 분리: nullable 추가 → 코드 배포 → backfill →
  NOT NULL 제약)로 나눴어야 코드만 안전 롤백 가능.

## 흔한 오답 / 누락 포인트
- (b) replicas 변경으로도 새 revision이 생긴다고 오답 → 챕터 정의 오독.
- rollout restart를 모르고 "Pod를 delete한다"로 답함(선언적 리소스라 재생성되지만 새 이미지 보장 아님).
- 롤백을 "이미지를 이전 걸로 다시 apply"로만 답하고 revision/RS 개념 누락.
- latest 태그 문제를 인지 못함.

## 모범 답안 예시 (하나의 예시)
> (1) 롤링 업데이트. 새 Pod를 띄운 뒤 기존 Pod를 순차 종료하므로 배포 중에도 일부가 살아 다운타임이
> 없다. 전부 내리면 그 사이 요청을 못 받아 5xx가 난다. (범위 밖: maxUnavailable 0/maxSurge 1로 6 유지)
> (2) (a) 이미지 변경은 template이 바뀌어 새 revision 생성, (b) replicas만 바꾸면 revision 안 생김.
> latest 강제 재배포는 `kubectl rollout restart`.
> (3) `kubectl rollout undo`로 이전 ReplicaSet을 되살린다. latest는 revision 특정이 안 돼 롤백 의미가
> 옅으므로 커밋 SHA 태그를 쓴다. (범위 밖: 스키마 변경 동반 시 expand/contract로 분리)
