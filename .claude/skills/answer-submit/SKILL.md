---
name: answer-submit
description: 스터디 문제(k8s-practice-scenario/k8s-villain-mode로 만든 시나리오)에 대한 풀이 답안을 정해진 파일/브랜치 컨벤션으로 커밋하고 main에 PR을 올리는 스킬. "답안 제출", "문제 제출", "풀이 제출", "answer submit", "PR 올려" 요청 시 사용.
---

# k8s 스터디 답안 제출 스킬

풀이자가 작성한 답안을 **파일명 컨벤션**에 맞춰 문제 폴더에 두고, **브랜치 컨벤션**에 맞춰
브랜치를 만들어 커밋·푸시한 뒤 **main으로 PR**을 올린다. 답안 내용 자체는 자유 서식이다.

## 3대 컨벤션 (반드시 지킴)

### 1. 답안 파일 — 파일명만 컨벤션, 내용은 자유

- 위치: 대상 문제 폴더 안. 즉 `study/problems/scenario/<YYYY-MM-DD>-<주제-슬러그>/`
- 파일명: **`answer-<핸들>.md`** (예: `answer-dave.md`, `answer-mj.md`)
  - `<핸들>`은 풀이자의 스터디 닉네임/핸들(git username과 달라도 됨).
  - 내용은 **자유 서식** — 번호별 서술, 명령/매니페스트, "잘 모르겠다" 메모 등 무엇이든 허용.
- ⚠ 예약 파일명 금지: **`answer-key.md`** 는 채점 루브릭 전용이며 `.gitignore`로 커밋 제외됨.
  답안 파일명이 여기에 겹치지 않도록 한다. (`answer-<핸들>.md` 는 gitignore 대상이 아니라 정상 커밋됨)

### 2. 브랜치 — `answer/<YYMMDD>-<핸들>`

- 형식: `answer/<YYMMDD>-<핸들>` (예: `answer/260709-dave`)
- `<YYMMDD>` 는 **제출 시점(오늘) 날짜** 2자리 연·월·일. (문제 폴더 날짜와 다를 수 있음)
- `<핸들>` 은 답안 파일의 핸들과 동일하게 맞춘다.
- 항상 최신 `main`에서 분기한다.

### 3. main으로 PR

- base=`main`, head=위 브랜치로 `gh pr create`.
- PR 제목/본문에 어느 회차·어느 시나리오 풀이인지 명시하고 문제/답안 파일 경로를 링크한다.

## 실행 절차

1. **입력 확인**: (a) 대상 문제 폴더, (b) 풀이자 핸들 을 파악한다. 사용자가 답안 파일을 이미
   작성해 뒀는지(예: 열려 있는 `answer-*.md`) 먼저 확인하고, 없으면 어디에 무슨 내용으로 만들지 묻는다.
   임의로 답안 내용을 지어내지 않는다(내용은 풀이자 소유).
2. **답안 파일 배치**: `study/problems/scenario/<문제폴더>/answer-<핸들>.md` 가 존재하는지 확인.
   이미 있으면 그대로 사용, 없고 사용자가 내용을 줬으면 그 내용으로 생성.
   `git check-ignore` 로 이 파일이 실수로 무시되지 않는지 확인(무시되면 파일명 재점검).
3. **브랜치 생성 & 커밋**: 오늘 날짜로 `answer/<YYMMDD>-<핸들>` 브랜치를 `main`에서 분기 →
   답안 파일만 스테이징 → 커밋. 커밋 메시지 예:
   `Add answer for <회차/주제> scenario` + 본문에 문제 폴더 경로.
   (커밋 메시지 말미에 저장소 규칙상 요구되는 Co-Authored-By 라인 포함)
4. **푸시 & PR**: `git push -u origin <브랜치>` 후 `gh pr create --base main --head <브랜치>`.
   PR 본문에 회차/시나리오, 문제·답안 파일 경로, 풀이가 다룬 항목 요약을 적는다.
5. **결과 보고**: 브랜치명, 커밋 해시, PR URL을 사용자에게 알린다. 현재 작업 트리가 답안 브랜치로
   이동했음을 안내한다(main 복귀는 `git checkout main`).

## 채점 연계 (선택)

제출 후, 원하면 `k8s-answer-checker` 에이전트에게 **문제 폴더 경로 + 제출된 답안 파일**을 넘겨
`answer-key.md` 루브릭 기반 채점을 위임할 수 있다. 채점 결과를 PR 코멘트로 남길지 여부는 사용자에게 확인.

## 참고 예시 (2026-07-09 dave 제출)

- 답안 파일: `study/problems/scenario/2026-07-09-deployment-rollout-strategy/answer-dave.md`
- 브랜치: `answer/260709-dave`
- PR: base `main` ← head `answer/260709-dave`
