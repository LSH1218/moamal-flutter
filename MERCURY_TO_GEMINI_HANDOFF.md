# Mercury QA v2 → Gemini QA 인수인계

> 작성일: 2026-08-24 · 작성: Mercury QA v2 대화방
> 대상: Gemini QA (다중 접속 검증) 대화방

---

## 1. 왜 넘기는가

Mercury는 **안드로이드 공기계 1대**로 교사 세션 단독 기능만 검증했다.
Section 9(학생 흐름)는 학생 화면이 교사 세션에 종속되어 있어 단일 기기로는
교사 계정 로그아웃 → 코드 입력 흐름의 일부만 확인 가능하다.

Gemini는 **에뮬레이터 = 교사 / 공기계 = 학생** 2기기 구성으로 진행하므로,
학생 측 항목과 교사↔학생 상호작용을 여기서 검증한다.

---

## 2. Mercury 완료 현황 (2026-08-24 기준)

| 섹션 | 내용 | 상태 |
|---|---|---|
| 0 | 사전 준비 (SHA-1, google-services.json, whitelist, Functions URL, 빌드) | ✅ |
| 1 | 로그인 & 세션 생성 | ✅ |
| 2 | 교사 LIVE 화면 | ✅ |
| 3 | 교사 STT (PTT/토글/VAD) | ✅ VAD 버그 수정 후 |
| 4 | AI 그룹화 (GeminiGroupingEngine) | ✅ |
| 5 | OrganizeScreen 원문 탭 | ✅ |
| 6 | OrganizeScreen 승인 탭 | ✅ |
| 7 | OrganizeScreen 투표 탭 | ✅ (학생 투표는 Firebase 콘솔로 시뮬레이션) |
| 8 | OrganizeScreen 나가기 & 상태 지속 | ✅ |
| **9** | **학생 흐름** | **→ Gemini 이관** |
| 10 | 보고서 생성 및 공유 | Mercury에서 마저 진행 |
| R | 회귀 체크 | Mercury에서 마저 진행 |

---

## 3. Gemini가 검증할 Section 9 항목 (7개)

1. 코드 입력 화면(JoinScreen) — 6자리 입력 후 세션 확인 성공
2. 잘못된 코드 입력 → 오류 표시, 크래시 없음
3. 이름 입력 → StudentSessionScreen 진입
4. 발표 화면에서 뒤로 가기 → 이름 입력 화면 복귀 (블랙스크린 아님)
   - `Navigator.push`로 변경됨. 스택: 랜딩 → 코드입력 → 이름입력 → 발표
5. 교사 forceStop 발신 → 학생 화면 kRed 배너 (영구, 탭으로 닫기)
6. 교사 forceStart 발신 → kGreen 배너 + 햅틱 → 3초 후 자동 닫힘
7. 투표 시작 후 학생 화면에 승인 그룹 투표 카드 표시 → 선택 가능

### 2기기라서 새로 볼 수 있는 것 (체크리스트 밖, 권장)

- 학생이 STT로 의견 제출 → 교사 LIVE 화면 실시간 반영 지연 시간
- 학생 2명 이상 동시 접속 시 참여자 카운트 정확도
- 교사가 투표를 닫은 순간 학생 화면이 어떻게 되는가 (안내 없이 멈추는지)
- 학생이 이미 투표한 뒤 재투표 시도 시 동작 (`votes/{participantId}` 덮어쓰기)
- 학생 앱 백그라운드 → 복귀 시 Firestore 리스너 재연결 (Common-Network-01)

---

## 3-2. 화면 폭 매트릭스 테스트 (Gemini에서 신규 수행)

> Mercury는 **안드로이드 공기계 1대(논리 폭 320dp)** 로만 진행했다.
> 그 1대에서 이미 레이아웃 초과 3건이 나왔으므로(Mercury-Layout-01), 다른 폭은 전부 미검증 상태다.
> Gemini는 에뮬레이터를 쓰므로 해상도를 자유롭게 만들 수 있다 — 여기서 매트릭스를 돌린다.

### 현재 반응형 구현 상태 (2026-08-24 코드 기준)

- `lib/utils/responsive.dart`에 브레이크포인트 존재: **600dp 미만 = compact**, **900dp 이상 = tablet**
- `sheetConstraints(maxWidth: 520)` — 태블릿에서 시트·다이얼로그 과폭 방지
- **미적용: `join_screen`(학생 첫 화면), `beam_projector_screen`(태블릿·프로젝터가 주 대상인데 미적용), `mic_control_screen`, `pending_approval_screen`.**
  ~~`facilitator_tab`, `student_tab`~~ — 2026-08-26 확인 결과 UI 재설계 후 어디서도 참조되지 않는
  사재 코드였다(`Mercury-Redesign-01`). 실행되지 않는 화면이므로 순회 대상에서 제외, 파일 자체도 삭제됨
- **브레이크포인트가 "넓어질 때"만 다룸** — 좁아질 때의 하한이 없음. Mercury-Layout-01이 정확히 이 경우(320dp)
- 고정 px 지정은 다수 존재하나 대부분 아이콘·배지 크기라 정상. **고정 크기가 `Row`에 나란히 놓여 가로 폭을 소진하는 경우만 실제 위험**

### 테스트 방법

디버그 빌드는 레이아웃이 넘치면 **노란/검정 줄무늬와 "OVERFLOWED BY N PIXELS"** 를 자동 표시한다.
폭별 AVD를 만들고 주요 화면을 순회하며 줄무늬가 뜨는지만 보면 된다.

| 폭 | 대표 기기 | 비고 |
|---|---|---|
| 320dp | 아이폰 SE, 갤럭시 A 저가형 | **Mercury에서 3건 발견된 폭** |
| 360dp | 갤럭시 S 시리즈 | 국내 최다 |
| 411dp | 픽셀, 대화면 안드로이드 | |
| 600dp | 소형 태블릿 · 폰 가로 모드 | compact↔tablet 경계 |
| 834dp | 아이패드 세로 | 900dp 미만이라 **compact 레이아웃이 적용됨** — 적절한지 확인 |
| 1194dp | 아이패드 가로 | |

### 순회할 화면 (우선순위)

1. 랜딩 — 슈퍼바이저 PIN 패드 / 세션 선택 / 세션 코드 입력 (이미 320dp에서 3건 발견)
2. `join_screen` — 반응형 미적용 + 학생 첫 화면
3. `beam_projector_screen` — 반응형 미적용 + 태블릿·프로젝터가 주 사용처
4. `organize_screen` — 고정 width 지정이 가장 많음(43곳), 탭 3개 모두
5. `teacher_home_screen` 하단 독 — 버튼 5개가 `Row`에 나란히 배치되어 좁은 폭에서 위험
6. `report_screen` — compact/medium 두 레이아웃이 각각 정상인지

### 세로 방향도 함께

가로뿐 아니라 **세로 초과**도 확인한다. Mercury에서 나온 `BOTTOM OVERFLOWED BY 84 PIXELS`는
키보드가 세로 공간을 먹은 경우였다. 텍스트 입력이 있는 모든 다이얼로그·시트에서 키보드를 띄운 채 확인할 것.

### iOS는 이 매트릭스에 포함되지 않음

`ios/` 폴더는 존재하나 **개발 환경이 Windows라 빌드 자체가 불가능**하다.
아이폰·아이패드에서는 지금까지 단 한 번도 실행된 적이 없다.
이는 QA로 해결할 문제가 아니라 **프로젝트 범위 결정**이므로 별도 판단이 필요하다:

- 맥 장비 확보, 또는
- 클라우드 빌드(Codemagic 등) 도입, 또는
- **파일럿을 안드로이드로 한정**한다는 명시적 결정

---

## 4. 학생 측 알려진 미해결 버그 — Gemini에서 우선 재현 확인

| ID | 등급 | 현상 |
|---|---|---|
| **Mercury-3-Student-01** | P1 | `StudentSessionScreen` StreamBuilder 재구독 버그 — 화면 전환 후 스트림이 중복 구독되거나 끊김 |
| **Mercury-3-Student-02** | P2 | forceStop 배너 색상이 `kInk`(검정), 명세는 kRed. SnackBar 중복 표시. 탭으로 닫기 불가 |
| **Common-Network-01** | P1 | 백그라운드 복귀 후 Firestore 리스너 재연결 미검증 |

> Section 9의 5번(forceStop 배너) 항목은 Mercury-3-Student-02가 미해결이므로
> **실패가 예상된다**. 배너가 검정으로 뜨고 SnackBar가 같이 뜨면 기존 버그 재확인으로 기록.

---

## 5. 교사 측에서 Gemini가 추가로 봐야 할 것

Mercury는 학생이 없어 검증하지 못한 교사 기능:

- 교사 LIVE 화면 **참여 카운트** — Mercury 내내 `0`이었음 (실제 학생 접속 없음)
- 교사가 특정 학생에게 forceStart/forceStop을 보내는 UI 경로 전체
- 학생 실제 투표에 따른 득표 바 갱신 (Mercury는 콘솔 수동 문서 추가로만 확인)
- 빔 프로젝터 화면에서 학생 투표 실시간 반영

---

## 6. 인수 시점 Firestore 상태 (세션 `IPIWT3`)

```
sessions/IPIWT3
  ownerUid: y5tyMsemSKVmf1OBfOr2c5UYHut1
  sessionCode: "IPIWT3"
  sessionType: "class_meeting"
  title: "우리나라를 대표하는 음식은 무엇일까요?"
  voteOpen: false
  ├─ ideas/           8건
  ├─ approvedGroups/  2건 (김치와 김치요리 / 접근성 높은 불고기)
  ├─ votes/           1건 (test_uid_1 → group1, 테스트 잔여 문서)
  └─ teacher_notes/
```

현재 AI 그룹 4개: 김치와 김치요리(3) · 세계적 인지도(2) · 매운 음식(2) · 불고기 대중성(1)

> **Gemini 시작 전 권장**: `votes/test_uid_1` 문서 삭제. 실제 학생 투표와 섞이면
> 득표 수 판독이 어렵다. 세션을 새로 만들어 진행해도 무방하다.

---

## 7. Mercury에서 발견했으나 아직 안 고친 것 (전체)

| ID | 등급 | 요약 |
|---|---|---|
| Mercury-4-Organize-01 | **P1** ↑ | 투표 중 승인/취소 비활성 시 시각 피드백 없음 → 재탭 습관 → 투표 종료 후 실삭제로 승인·그룹명 소실 |
| Mercury-3-Student-01 | P1 | StudentSessionScreen StreamBuilder 재구독 |
| Common-Network-01 | P1 | 백그라운드 복귀 리스너 재연결 미검증 |
| Mercury-3-Student-02 | P2 | forceStop 배너 색상·중복·닫기 불가 |
| Mercury-2-STT-02 | P2 | PTT 무음 환각 |
| Mercury-1-Session-01 | P2 | 세션 코드 혼동 문자 (0/O, 1/I) |
| Mercury-4-Organize-02 | P3 | 새 그룹 `aiTitle: null` → 긴 Jaccard 제목 |
| Mercury-5-Merge-02 | P3 | 병합 방향 UX |

상세는 `BUG_LOG_v2.md` 참조.

---

## 8. 미완 기능 (QA 대상 아님, 별도 방 진행)

- **병합 완전 되돌리기** — 현재는 병합 직후 5초 SnackBar로만 되돌릴 수 있다.
  승인 후에도 되돌리려면 Firestore `mergeLogs` 기반 이력이 필요.
  보안 규칙은 배포 완료(2026-08-24), Flutter 구현은 앱 개발 방에서 진행 예정.
- `organize_screen.dart` `_doMerge()`가 `mergeGroups()`의 반환값 `MergeLog?`를
  아직 사용하지 않는다 — 이력 저장 연결 시 함께 처리.
