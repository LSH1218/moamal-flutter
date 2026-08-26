# Moamal Bug Log v2

> UI 전면 재설계(2026-08) 이후 버전 기준.  
> 형식: `[단계-섹션번호-컴포넌트-순번]`  
> 단계: Mercury / Gemini / Apollo / Common  
> v1(`BUG_LOG.md`)에서 해결된 항목은 하단 **v1 해결 이력**에 요약.

---

## 결함 등급 기준

| 등급 | 기준 | 예시 |
|------|------|------|
| **P0** | 이 오류가 있으면 다음 단계 진행 불가 | 앱 크래시, 로그인 불가, 세션 생성 불가, STT 요청 불가, 의견 저장 불가, Firestore 권한 오류로 핵심 흐름 중단 |
| **P1** | 수업 진행 중 큰 문제 발생 가능 | STT 자주 실패, Firestore 구독 누수, 학생 화면 데이터 갱신 불안정, 세션 재진입 시 상태 복구 실패 |
| **P2** | 불편하지만 테스트·파일럿 진행 가능 | UI 어색함, 배너 색상 불일치, 피드백 없음, 에러 메시지 어색함 |
| **P3** | 기능 검증·파일럿에 직접 영향 없음 | 색상, 문구 미세 조정, 아이콘, 디자인 디테일 |

---

## Mercury

### [Mercury-2-STT-02]
- **현상**: PTT 모드에서 아무 말 없이 손 떼면 Whisper가 무음 오디오를 그럴싸한 한국어 문장으로 환각(hallucination) 생성 → 가짜 teacher_note가 Firestore에 저장됨
- **재현**: PTT 길게 누른 후 아무 말 없이 손 떼기 → Draft 시트에 엉뚱한 텍스트 표시 + `teacher_notes` 저장 확인
- **원인**: Whisper는 무음/저음량 오디오에서 컨텍스트 프롬프트("초·중등 수업 현장") 기반으로 텍스트를 생성하는 known behavior. 전송 전 최소 녹음 길이 또는 음량 임계값 체크 없음
- **영향**: 잘못된 발문이 GPT 그룹화 컨텍스트(`recentTeacherNotes`)에 포함됨
- **등급**: P2
- **수정 방향**: `_stopAndTranscribe` 호출 전 녹음 시간이 1초 미만이면 전송 취소 (`_recordingStartTime` 필드 이미 존재)
- **파일**: `lib/screens/teacher/teacher_home_screen.dart` — `_stopAndTranscribe()`
- **상태**: 🔴 미해결

### [Mercury-2-VAD-01]
- **현상**: Toggle 모드에서 VAD 침묵 자동 종료 미작동 — 3초 침묵 후에도 녹음이 계속됨
- **재현**: Toggle 탭으로 녹음 시작 후 말하지 않고 방치 → 자동 종료 없음
- **원인**: `teacher_home_screen.dart`에 VAD(`amplitudeStream`) 구독 코드 없음. VAD는 `student_session_screen.dart`에만 구현됨
- **파일**: `lib/screens/teacher/teacher_home_screen.dart`
- **등급**: P2 (Toggle 모드 사용 시 교사가 수동으로 꼭 종료해야 함 — PTT로 우회 가능)
- **상태**: ✅ 해결 (2026-08-21)
- **해결**: `_startVAD()` / `_stopVAD()` 구현 + `_onMicTap`, `_cancelRecording`, `dispose`에 연결. silence threshold `-40dB`로 설정했으나 실 기기 ambient noise floor가 -37~-39dBFS로 threshold보다 높아 미작동 → `-34dB`로 조정 후 정상 동작 확인 (logcat에서 silence=3037ms 트리거 확인)

### [Mercury-1-Session-01]
- **현상**: 세션 코드에 O(알파벳)와 0(숫자), I와 1, l 혼용 가능 — 육안 구분 어려움
- **등급**: P2 (학생이 코드 잘못 입력할 가능성)
- **수정 방향**: 세션 코드 생성 시 혼동 문자(O, 0, I, 1, l) 제외
- **상태**: 🔴 미해결

### [Mercury-Session-01]
- **현상**: 수업 시간 타이머가 OrganizeScreen·ReportScreen 진입 중에도 계속 흘러서 실제 수업 진행 시간보다 길게 표시됨
- **원인**: `_elapsedTimer`가 `TeacherHomeScreen`에서 계속 작동. 서브 화면 진입 시 일시정지 없음
- **등급**: P3 (수업 기록 정확도 영향, 파일럿 진행 가능)
- **상태**: 🔴 미해결

### [Mercury-Report-02]
- **현상**: 리포트 미생성 상태에서 공유 버튼이 활성 → "아직 리포트가 없습니다." 텍스트가 공유 시트에 노출됨
- **원인**: `ReportScreen` 공유 버튼이 `_meetingReport == null` 상태를 체크하지 않음
- **등급**: P2
- **수정**: `meetingReport == null`일 때 `onTap: null`, 버튼 배경 `kInk.withValues(alpha:0.18)`, 텍스트 반투명으로 비활성화 표시 (2026-08-24)
- **파일**: `lib/screens/teacher/report_screen.dart:69` — AppBar actions GestureDetector
- **상태**: ⚠️ **부분 해결** — 상단 AppBar 버튼만 가드 적용. **하단 CTA `리포트 저장 / 공유 ↗`는 여전히 무방비**
  (`report_screen.dart:165` `_YellowCta(onTap: onShare)` — null 체크 없음). 2026-08-24 Section 10 QA에서
  두 버튼 모두 공유 시트가 열리고 "아직 리포트가 없습니다."가 노출되는 것을 재확인.
  ※ 상단 버튼까지 눌린 이유는 실행 중이던 빌드가 수정 전 버전이었기 때문(수정은 미커밋 상태). 핫 리스타트 후 재검증 필요
- **잔여 수정**: `_CompactBody`/`_MediumBody`의 `_YellowCta`에도 `meetingReport == null` 가드 추가.
  `_YellowCta`가 `VoidCallback`(non-nullable)을 받으므로 `VoidCallback?`로 완화하고 비활성 배경색 분기 필요

### [Mercury-Report-04] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 최초 생성인데 버튼 라벨이 "AI 요약 **다시** 생성"
- **원인**: `report_screen.dart:384` 조건이 `meetingReport == null && groups.isNotEmpty` — 아직 한 번도 생성되지 않은 상태에서만 렌더링되는데 라벨은 재생성 문구
- **등급**: P3
- **수정 방향**: 라벨을 "AI 요약 생성"으로. 재생성이 필요하면 `meetingReport != null`일 때 별도 버튼을 두는 구조로 분리
- **상태**: 🔴 미해결

### [Mercury-Report-05] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 리포트 화면 "참여 N명"이 실제 참여자 수가 아님
- **원인**: `report_screen.dart:281` — `session.votes.isNotEmpty ? session.votes.length : session.ideas.length`.
  투표가 있으면 투표 수를, 없으면 **의견 수**를 참여자 수로 표시. QA 중 "1명"은 Section 7 테스트 잔여 투표 1건이었고,
  투표가 없었다면 학생 0명인데도 "8명 참여"로 표시됐을 것
- **등급**: P2 (교사가 학교에 제출하는 리포트 수치이므로 신뢰도 문제)
- **수정 방향**: `session.participants` 기준으로 집계
- **상태**: 🔴 미해결

### [Mercury-Report-06] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 리포트 화면에서 "AI 요약 생성"을 눌러도 **아무 반응이 없음**. 버튼이 "생성 중..."으로 바뀌지 않고, GPT 응답이 와도 화면이 그대로. 뒤로 나갔다 재진입하면 그제서야 요약이 표시됨
- **원인**: `ReportScreen`은 `StatelessWidget`이고, `Navigator.push` 시점의 `_meetingReport` / `_isGeneratingReport` 값을 **복사해서** 생성자로 전달받음 (`teacher_home_screen.dart:432-433`).
  `_generateReport()`가 `setState`를 호출해도(`teacher_home_screen.dart:171`) 이미 스택에 올라간 route의 `MaterialPageRoute` builder는 재실행되지 않으므로 ReportScreen이 리빌드되지 않음
- **파일**: `lib/screens/teacher/teacher_home_screen.dart:423-438`, `lib/screens/teacher/report_screen.dart:10`
- **등급**: **P1** — 기능은 정상 동작하나 교사 입장에서는 "생성 버튼이 고장났다"로 보임. 반복 탭을 유발하고 GPT 비용도 중복 발생
- **수정 방향** (택1):
  - ReportScreen을 `StatefulWidget`으로 바꾸고 리포트 생성/상태를 화면 내부로 이관
  - 또는 `ValueListenableBuilder` / 상태 관리 객체를 전달해 부모 상태 변화를 구독
  - 또는 `onGenerateReport`를 `Future<MeetingReport?>`를 반환하도록 바꿔 ReportScreen이 결과를 직접 받아 setState
- **검증**: 2026-08-24 — 생성 후 재진입 시 요약 정상 표시(`제목 → 핵심 인용`), 상단 저장/공유 활성화, 공유 시트에 리포트 본문 노출 확인. 생성 자체는 성공
- **상태**: 🔴 미해결

### [Mercury-Session-02] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 앱 재시작(핫 리스타트 포함) 후 세션에 복귀하면 **교사가 수행한 그룹 병합·이동·승인 결과가 모두 사라지고** AI가 처음부터 다시 그룹화함.
  QA 중 4개 그룹(병합된 "김치와 김치요리" 포함) → 5개 그룹으로 재생성되고 제목도 전부 바뀜
- **원인**: `GeminiGroupingEngine._cachedGroups`가 메모리에만 존재. 세션 복귀 시 Firestore의 `ideas`만 다시 읽어 재그룹화함.
  `approvedGroups`는 Firestore에 남지만 재그룹화로 그룹 id가 달라지면 매칭이 깨져 승인 표시도 소실
- **파일**: `lib/services/gemini_grouping_engine.dart` — `_cachedGroups`, `reset()`
- **등급**: **P1** — 교사가 수업 내내 정리한 결과를 앱이 한 번 죽으면 전부 잃는다. `active_teacher_session` 복귀 기능의 의미가 반감됨
- **수정 방향**: 그룹 구성(`groupId → ideaIds`, `aiTitle`)을 Firestore에 스냅샷으로 저장하고 복귀 시 복원.
  `mergeLogs` 스키마 작업과 함께 설계하는 것이 합리적
- **상태**: 🔴 미해결

### [Mercury-Session-03] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 앱 재시작 후 리포트의 "수업 N분" 경과 시간이 리셋됨. QA 중 39:29 → 02:05로 초기화
- **원인**: `teacher_home_screen.dart:198` `_sessionStart = DateTime.now()` — 앱 실행 시각 기준.
  `existingCode`로 기존 세션에 복귀해도 Firestore의 세션 생성 시각을 쓰지 않음
- **등급**: P2 — 교사가 학교에 제출하는 리포트 수치이므로 신뢰도 문제 (Mercury-Report-05와 동일 성격)
- **수정 방향**: 세션 문서에 `createdAt`을 저장하고 복귀 시 그 값을 `_sessionStart`로 사용
- **상태**: 🔴 미해결

### [Mercury-Share-01] ← Section R 회귀 체크 중 발견 (2026-08-24)
- **현상**: QR 코드에 딥링크가 아닌 **평문 세션 코드**만 인코딩됨. 학생이 폰 카메라로 QR을 스캔해도 앱이 열리지 않고 "KBZ5A2" 같은 텍스트만 표시됨 → 결국 코드를 수동 입력해야 하므로 QR의 기능이 사실상 없음
- **원인**: `teacher_home_screen.dart:1386` `QrImageView(data: code, ...)`.
  `DeepLinkService._parseCode()`는 `moamal://join/XXXXXX` 형식만 인식(`deep_link_service.dart:34-38`)하므로 형식 불일치
- **파일**: `lib/screens/teacher/teacher_home_screen.dart:1386`, `_QrFullScreen`도 동일 여부 확인 필요
- **등급**: **P1** — 학생 참여 진입점의 핵심 기능. 교실에서 QR을 띄우는 시나리오 전체가 무효화됨
- **수정** (2026-08-25, Gemini 선수정) — QR을 바꾸면 읽는 쪽도 같이 바뀌어야 해서 3개가 한 묶음이다:
  1. `deep_link_service.dart`에 `buildJoinUri(code)` / `parseScanned(raw)` 추가.
     `parseScanned`는 **딥링크와 평문 6자리를 모두 허용** — 이전에 인쇄·배포된 QR도 계속 동작해야 한다
  2. QR 생성 6곳 전부 `DeepLinkService.buildJoinUri(...)`로 교체 —
     `teacher_home_screen.dart`(QR 시트·전체화면), `beam_projector_screen.dart`(2곳), `display_tab.dart`, `facilitator_tab.dart`
  3. 앱 내 스캐너(`join_screen.dart` `QrScanScreen.onDetect`)가 `code.length == 6`만 통과시키고 있었다.
     **QR만 바꿨다면 지금 정상 동작하던 앱 내 QR 참여가 깨졌을 것** → `DeepLinkService.parseScanned()`로 교체
- **함께 발견·수정한 수신 경로 결함** (`main.dart`) — QR을 고쳐도 이게 남으면 딥링크 참여가 사실상 실패한다:
  - `_joinWithCode()`가 **이름·번호 입력 화면을 건너뛰고** 바로 `StudentSessionScreen`으로 보냄 →
    `participants` 등록이 누락되어 교사 화면 참여자 수·학생 마이크 제어 대상에 잡히지 않음.
    → 코드 직접 입력과 동일하게 `fetchSessionTitle()` 확인 → `StudentProfileScreen` 경유로 변경
  - 세션 존재 확인 없이 진입 → 잘못된/종료된 코드도 그대로 통과. → `title == null`이면 SnackBar 안내 후 중단
  - `Navigator.pushReplacement`로 랜딩을 스택에서 제거 → 뒤로 가기 시 블랙스크린
    (UI_REDESIGN_LOG #2에서 고쳤던 것과 동일한 문제). → `Navigator.push`로 변경
  - `codeStream()` 구독이 "초기 링크 없음 + 교사 세션 복귀 없음"일 때만 등록됨 →
    교사 세션 복귀 시 앱이 켜져 있는 동안 들어오는 딥링크를 아예 못 받음. → 분기보다 **앞에서 항상 구독**하도록 이동
- **남은 설계 결정**: `moamal://`는 **앱이 설치된 기기에서만** 열린다. 앱 미설치 학생이 폰 카메라로 찍으면 여전히 아무 일도 없다.
  웹 랜딩 URL을 인코딩하려면 그 웹페이지를 새로 만들어야 하므로 파일럿 전 별도 판단 (2026-08-25 현재 웹 미구축)
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** (Gemini G1에서 확인)

### [Mercury-Share-02] ← Section R 회귀 체크 중 발견 (2026-08-24)
- **현상**: QR 시트에 **시스템 공유 시트를 여는 버튼이 없음**. 체크리스트 R-4 "QR 공유 버튼 → 시스템 공유 시트 표시 (딥링크 URL 포함)" 항목의 기능이 미구현
- **원인**: `_QrSheet`의 액션은 코드 복사 / 전체 화면으로 보기 / 빔프로젝터 화면 열기 3개뿐 (`teacher_home_screen.dart:1419-1443`).
  `share_plus.Share.share`는 앱 전체에서 리포트 텍스트 공유 2곳에만 사용됨
- **등급**: P2 (미구현 기능 — 버그가 아니라 누락)
- **수정 방향**: QR 시트에 "참여 링크 공유" 버튼 추가, `Share.share('moamal://join/$code')` 또는 웹 URL 공유. Mercury-Share-01과 함께 결정
- **상태**: 🔴 미해결

### [Mercury-Report-07] ← Section R 회귀 체크 중 발견 (2026-08-24)
- **현상**: 리포트 공유 진입점이 **세 곳**인데 null 가드가 제각각. `facilitator_tab.dart:567-575`에도 동일한
  `meetingReport?.toPlainText(...) ?? '아직 리포트가 없습니다.'` 패턴이 가드 없이 존재
- **파일**: `lib/screens/teacher/tabs/facilitator_tab.dart:571`
- **범위 정정 (2026-08-25)**: `facilitator_tab`은 UI 재설계 후 **호출되지 않는 사재 코드**로 확인됨(Mercury-Redesign-01). 따라서 실제 공유 진입점은 **3곳이 아니라 2곳**(`report_screen` 상단 AppBar · 하단 CTA)이다
- **등급**: P2
- **수정 방향**: 공유 로직을 단일 헬퍼로 추출하고 `meetingReport == null`이면 호출 자체를 막는 구조로 통일 (Mercury-Report-02와 함께 수정)
- **상태**: 🔴 미해결

### [Mercury-Redesign-01] ← 2026-08-25 Gemini 선수정 중 코드 확인으로 발견
- **현상**: UI 재설계로 대체된 구 탭 3종이 **어느 화면에서도 참조되지 않는 사재 코드**로 남아 있다.
  `lib/screens/teacher/tabs/` — `facilitator_tab.dart`(621줄), `student_tab.dart`(277줄), `display_tab.dart`(231줄), 합 1,129줄.
  `grep -rn "StudentTab|FacilitatorTab|DisplayTab" lib/`가 정의부 외에는 아무것도 잡지 못한다
- **파급 1 — QA 낭비**: `MERCURY_TO_GEMINI_HANDOFF.md` 3-2절이 `facilitator_tab`·`student_tab`을
  "반응형 미적용 화면"으로 G8 폭 매트릭스 순회 대상에 넣어두었다. 실재하지 않는 화면이라 시간만 버린다
- **파급 2 — 버그 로그 오염**: `Mercury-Report-07`이 `facilitator_tab.dart:571`을 리포트 공유 진입점 3곳 중 하나로 지목했으나,
  해당 경로는 실행되지 않으므로 **실제 진입점은 2곳**이다
- **파급 3 — 기능 소실 (중요)**: `student_tab`에 있던 **교사 수동 의견 입력 UI**
  (발표자 이름 + 발표 내용 TextField + "의견 추가" 버튼)가 함께 끊겼다.
  현재 앱에서 `ideas`를 생성하는 경로는 **STT 단일**이다.
  마이크가 불가한 환경이거나 말하기를 어려워하는 학생은 **의견을 제출할 방법이 없다**
- **등급**: P2 (사재 코드 자체는 무해) — 단 **파급 3은 제품 결정 사항**. 수동 입력을 재설계 UI에 되살릴지 판단 필요
- **수정 방향**:
  - 사재 파일 3개 삭제 또는 `legacy/`로 격리 (앱개발 방)
  - 인수인계 문서·`Mercury-Report-07` 범위 정정 → **2026-08-25 반영 완료**
  - 교사/학생 수동 텍스트 입력 복원 여부 → 전략기획 판단
- **상태**: 🟡 문서 정정 완료 · 코드 정리와 수동 입력 복원은 미결정

### [Mercury-Vote-01] ← Section R 회귀 체크 중 발견 (2026-08-24)
- **현상**: 득표수가 동점인데 한 그룹만 1위(kYellow)로 강조됨. QA 중 두 그룹 모두 1표·50%인 상태에서
  "김치와 김치요리"만 노란 카드, "불고기 대중성"은 일반 카드로 표시
- **원인**: 최다 득표 판정이 첫 번째 일치 항목만 1위로 처리하는 것으로 추정 (`beam_projector_screen.dart` 득표 정렬/강조 로직)
- **등급**: P3 — 다만 교실에서 학생이 결과에 이의를 제기할 수 있는 지점
- **수정 방향**: 최다 득표가 복수일 때 동시 강조하거나 "동점" 표기. 투표 탭(OrganizeScreen)의 1위 강조도 동일한지 확인 필요
- **상태**: 🔴 미해결

### [Mercury-Layout-01] ← Section R 회귀 체크 중 발견 (2026-08-24)
- **현상**: 좁은 화면(논리 폭 320dp, 예: SM-A305N)에서 랜딩 화면의 다이얼로그 3종이 모두 레이아웃 초과
  1. 슈퍼바이저 PIN 키패드 — `RIGHT OVERFLOWED BY 6.0 PIXELS`
  2. 세션 코드 입력 다이얼로그 — 키보드 표시 시 `BOTTOM OVERFLOWED BY 84 PIXELS`
  3. 세션 선택 다이얼로그 — "새 세션 시작" 라벨이 버튼 밖으로 삐져나옴
- **원인**:
  - PIN 패드(`landing_screen.dart:640-665`)가 키를 고정 크기로 배치.
    키 1개 = `width:60` + `margin:3`×2 = 66dp, 3개 = 198dp.
    사용 가능 폭 = 320 − `insetPadding` 40×2 − `padding` 24×2 = 192dp → **정확히 6dp 초과**
  - 코드 입력 다이얼로그(`landing_screen.dart:97-117`)가 기본 `AlertDialog` — 키보드가 올라오면 세로 공간 부족, 스크롤 불가
  - 세션 선택 다이얼로그(`landing_screen.dart:75-88`) `actions`의 두 버튼이 320dp에서 가로로 안 들어감
- **파일**: `lib/screens/common/landing_screen.dart:75-88, 97-117, 640-665`
- **등급**: P2 — 디버그 빌드에서만 노란 줄무늬가 보이고 릴리스에서는 조용히 잘리지만, 좁은 기기에서 버튼이 눌리지 않는 실사용 문제로 이어질 수 있음
- **수정 방향**:
  - PIN 패드: 고정 `width: 60` → `Flexible`/`Expanded` 또는 화면 폭 기반 계산
  - 코드 입력: `AlertDialog` `content`를 `SingleChildScrollView`로 감싸기
  - 세션 선택: `actions` 대신 세로 배치, 또는 `OverflowBar`가 세로로 접히도록 보장
- **비고**: 재설계 QA가 이 기기 1대로만 진행되어 **다른 화면 폭은 미검증**. Gemini 단계(에뮬레이터+공기계)에서 폭이 다른 조합으로 재확인 필요
- **수정** (2026-08-24, Flutter UI/UX):
  - `lib/utils/responsive.dart`: 좁은 쪽 하한 브레이크포인트 신설 — `AppBreakpoints.narrow = 360`,
    `context.isNarrow`, `dialogInsetH(context, {tabletFactor})`. 기존 600/900은 "넓어질 때"만 다뤄
    좁은 폭 대응 지점이 없었던 것이 세 증상의 공통 원인
  - PIN 패드: 고정 `width: 60` → `LayoutBuilder`로 폭에서 역산
    (`keyW = maxWidth/3 - margin*2 - 0.5`, 44~60dp clamp / `keyH` 44~50dp clamp).
    44dp 하한은 터치 타깃 최소 크기. 빈 슬롯도 같은 크기로 계산
  - 코드 입력·수업 제목 다이얼로그: `scrollable: true` — 키보드가 올라와도 세로 스크롤 가능
  - 세션 선택 다이얼로그: `actions` 가로 배치 폐기 → `content`에 전체 폭 세로 버튼 2개
    (새 세션 시작 = ElevatedButton/kGreen, 기존 세션 재개 = OutlinedButton). 폭과 무관하게 라벨이 잘리지 않음
  - 다이얼로그 좌우 여백: 360dp 미만에서 40dp → 16dp (내부 폭 48dp 확보)
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** (Gemini 폭 매트릭스에서 320/360dp 재확인)

### [Mercury-4-Organize-04] ← Section R 회귀 체크 중 발견 (2026-08-24)
- **현상**: "승인하기"를 누르면 버튼 글자만 사라지고 로딩 표시가 보이지 않음. "승인 취소"를 누를 때는 정상적으로 보임
- **원인**: `organize_screen.dart:1241` 스피너 색이 `kGreen` 고정인데, 버튼 배경은 상태에 따라 바뀜
  - 승인 전(`approved == false`) 배경 = `kGreen` → **초록 배경 위 초록 스피너로 사실상 비가시**
  - 승인 후(`approved == true`) 배경 = `kCardBg` → 초록 스피너가 정상적으로 보임
- **파일**: `lib/screens/teacher/organize_screen.dart:1236-1244`
- **등급**: P3 — 기능은 정상이나 교사가 "눌렸는지" 확인할 수 없음. Mercury-4-Organize-01(재탭 유발 → 데이터 유실)과 같은 성격의 피드백 부재
- **수정 방향**: 스피너 색을 배경과 반대로 분기 — `color: approved ? kGreen : Colors.white`
- **상태**: 🔴 미해결

---

## 리포트 화면 — 설계 미확정 항목 (버그 아님)

> 2026-08-24 Section 10 QA 중 확인. 설계가 정해지지 않아 수정 방향을 확정할 수 없는 항목.
> 별도 설계 논의 후 재QA 필요.

1. **공유 버튼 이중화** — 상단 AppBar와 하단 CTA가 동일한 `_share()`를 호출. 두 개를 둘 이유가 정의되지 않음
2. **리포트 자동 생성 여부** — "수업 종료 리포트" 화면에 진입해도 요약이 비어 있고 교사가 버튼을 눌러야 생성됨. 화면 이름과 동작이 불일치
3. **리포트의 최종 산출물 형태** — 하단 CTA 라벨이 compact는 "리포트 저장 / 공유 ↗", medium은 "PDF 내보내기 / 학교 시스템 연동"인데 실제 동작은 양쪽 다 텍스트 공유(`share_plus`). PDF·학교 시스템 연동은 미구현
4. **참여자 정의** — 발언한 학생 / 접속한 학생 / 투표한 학생 중 무엇을 "참여"로 볼지 미정 (Mercury-Report-05와 연결)

### [Mercury-3-Student-01] ← 재설계 후 발견
- **현상**: `StudentSessionScreen` StreamBuilder에서 `_repo.listenToSession()`을 `build()` 내에 직접 호출 — `setState` 발생마다 Firestore 구독이 취소·재생성됨
- **원인**: `StreamBuilder`는 `stream:` 파라미터가 바뀌면 재구독함. `listenToSession()`은 호출마다 새 `StreamController`를 반환(내부에서 `stopListening()` 선행)하므로 호출할 때마다 기존 구독이 끊김
- **재현**: 학생 화면에서 투표 탭 / 마이크 탭 등 `setState` 유발 인터랙션 → Firestore 구독이 반복 재생성됨. 투표 결과 갱신이 느리거나 깜빡일 수 있음
- **영향**: Firebase 읽기 횟수 증가, 학생 화면 데이터 갱신 불안정
- **파일**: `lib/screens/student/student_session_screen.dart:351`
- **등급**: P1
- **수정** (2026-08-25, Gemini 선수정): `_sessionStream` 필드 신설 → `initState`에서 `_repo.listenToSession()` 1회 호출 후 저장,
  `StreamBuilder(stream: _sessionStream)`으로 전달. TeacherHomeScreen과 동일 패턴
- **남은 위험**: `organize_screen.dart:67`과 `cluster_vote_screen.dart:152`에 `widget.sessionStream ?? widget.repo.listenToSession(...)`
  폴백이 있다. 현재는 호출부가 항상 `sessionStream`을 넘겨서 발현하지 않지만, 넘기지 않는 호출부가 생기면 같은 버그가 재발한다
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** (Gemini G2·G4에서 확인)

### [Mercury-3-Student-02] ← 재설계 후 발견
- **현상**: forceStop 수신 시 UI가 명세와 다름
  1. **색상 불일치**: `_forcedStopBanner()` 배경색이 `kInk`(검정). 재설계 명세는 kRed
  2. **SnackBar 중복**: `_handleForceStop()`에서 배너 + SnackBar가 동시에 표시됨
  3. **닫기 없음**: 배너를 탭으로 닫을 수 없어 화면에 영구 잔류
- **파일**: `lib/screens/student/student_session_screen.dart` — `_handleForceStop()`, `_forcedStopBanner()`
- **등급**: P2
- **수정** (2026-08-24, Flutter UI/UX):
  - 배너 배경색 `kInk` → `kRed`, 우측에 닫기(×) 아이콘 추가
  - `_handleForceStop()`의 SnackBar 제거 — 배너와 중복 안내였음
  - 배너 전체를 `GestureDetector(behavior: opaque)`로 감싸 탭하면 닫힘
  - **상태 분리**: `_forceStopped`가 배너 표시와 마이크 잠금을 동시에 담당하고 있었다
    (`_onTap`/`_onLongPressStart`의 `if (_forceStopped) return`). 그대로 두고 탭 닫기를 붙이면
    학생이 배너를 닫는 순간 마이크 잠금까지 풀려 교사의 강제 중지가 무력화된다.
    → `_forceStopBannerVisible`(배너, 학생이 닫기 가능)과 `_forceStopped`(잠금, 교사 forceStart로만 해제)로 분리.
    배너를 닫아도 `_micArea()`가 kDisabled 마이크 + "마이크 꺼짐" + "선생님이 마이크를 잠시 껐어요"로
    잠금 상태를 계속 보여주므로 학생이 이유를 알 수 있다
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** (Gemini QA Section 9-5에서 확인)

### [Mercury-3-Student-03] ← 2026-08-24 Student-02 수정 중 코드 확인으로 발견
- **현상**: 교사가 forceStop → forceStart를 보내도 학생 마이크 잠금이 풀리지 않을 수 있음
- **원인**: `_handleForceStart()`가 `if (_micStatus != _MicStatus.idle) return;`으로 **먼저 반환**한 뒤에야
  `_forceStopped = false`를 세팅하는 구조. 학생이 마지막 전사를 끝낸 `done` 상태에서 교사가 forceStop을 보내면
  `_handleForceStop()`은 `recording`일 때만 상태를 `idle`로 되돌리므로 `_micStatus`가 `done`으로 남는다.
  이 상태에서 forceStart가 오면 early-return → 잠금(`_forceStopped`)이 해제되지 않아 학생 마이크가 계속 잠긴다
- **파일**: `lib/screens/student/student_session_screen.dart` — `_handleForceStart()`, `_handleForceStop()`
- **등급**: ~~P2(추정)~~ → **P1 상향** (2026-08-25, 코드 경로 확정). `_confirmSubmit()`이 `_micStatus = done`으로 두고
  **학생이 마이크를 다시 누를 때까지 done이 유지된다**(`_onTap`의 293~296줄에서만 idle 복귀).
  즉 **한 번이라도 발언한 학생**에게 교사가 [중지]→[시작]을 하면 잠금이 영구히 풀리지 않는다.
  학생 본인도 `_onTap`/`_onLongPressStart`의 `if (_forceStopped) return` 가드에 막혀 해제 불가 → 앱 재시작 외 탈출 경로 없음
- **수정** (2026-08-25, Gemini 선수정):
  - 잠금 해제·배너·햅틱을 early-return **앞으로** 이동 — 마이크 상태와 무관하게 항상 실행
  - 자동 녹음 시작 조건을 `_onTap`과 동일하게 정렬 — `idle` 또는 `done`에서 시작하되 `done`이면 `idle`로 리셋 후 녹음.
    기존 `!= idle` 조건만 유지했다면 잠금은 풀려도 교사가 기대한 자동 녹음은 여전히 안 걸렸다
- **재현 방법**: 학생이 1회 발언 후 초안 제출 완료(`done` 상태) → 교사 [중지] → 교사 [시작] → 학생 마이크가 눌리는지 확인
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** (Gemini G3에서 확인)

### [Mercury-4-Organize-01] ← 재설계 후 발견
- **현상**: OrganizeScreen 승인 탭에서 투표 진행 중 "승인하기/승인 취소" 버튼이 비활성화되지만 시각적 피드백이 없음 — 탭해도 반응 없어 학생이 버그로 오해할 수 있음
- **원인**: `canToggle = !session.voteOpen` 조건 시 `onTap: null`만 세팅. 비활성 이유 안내 없음
- **파일**: `lib/screens/teacher/organize_screen.dart:1221` — `_GroupApproveCard`
- **등급**: ~~P2~~ → **P1 상향** (2026-08-24, Section 8 QA 중 실제 데이터 유실 확인)
- **실제 발생 시나리오**: 투표 중 "승인 취소" 탭 → 반응 없음 → 교사가 "안 눌렸나?" 하고 재탭하는 습관이 생김 → 투표를 닫은 뒤(`voteOpen=false`) 같은 자리를 누르면 이번엔 실제로 `deleteApprovedGroup()` 실행 → 승인 상태 + 교사가 수정한 그룹명이 함께 소실. Section 8 테스트 중 "접근성 높은 불고기" 승인이 이 경로로 사라짐(수동 재승인으로 복구)
- **수정 방향**:
  - 투표 중 탭 시 "투표 진행 중에는 변경할 수 없어요" SnackBar 또는 버튼 위 안내 문구
  - 승인 취소에 확인 다이얼로그 추가 — 교사가 수정한 그룹명이 함께 사라지므로 파괴적 액션에 해당
- **상태**: 🔴 미해결

### [Mercury-4-Organize-02] ← 재설계 후 발견
- **현상**: 원문 탭에서 "새 그룹"으로 의견 이동 시 생성된 그룹에 AI 제목이 없음 (`aiTitle: null`) → Jaccard 폴백이 의견 텍스트 전체를 그룹 제목으로 사용 → 매우 긴 제목 표시
- **원인**: `moveIdea()` 내 새 그룹 생성 시 `aiTitle: null` 하드코딩
- **파일**: `lib/services/gemini_grouping_engine.dart:105`
- **등급**: P3
- **수정 방향**: 새 그룹 aiTitle을 `'새 그룹'`으로 초기화하거나, 이동 직후 간단한 이름 입력 다이얼로그 제공
- **상태**: 🔴 미해결

### [Mercury-5-Move-01] ← 재설계 후 발견
- **현상**: 그룹 이동 버튼 탭 시 이동이 적용되지 않음. 첫 이동 시도 후 그룹이 전부 사라지는 증상("분류가 다 풀려버리네")
- **원인**: `GroupingEngine.makeGroups()`에서 `ideas: []`(= `List<dynamic>`) 타입으로 그룹 생성 → `moveIdea()`에서 `[...g.ideas]` spread 시 `List<dynamic>` 생성 → `Group.copyWith(ideas: List<Idea>?)` 타입 미스매치 → exception 발생 → `_cachedGroups = []` (빈 리스트)로 세팅되어 그룹 전부 소멸
- **재현**: OrganizeScreen 원문·승인 탭에서 의견 이동 버튼 탭 → 이동 안 됨 또는 그룹 전부 사라짐
- **파일**: `lib/services/grouping_engine.dart:26`, `lib/services/gemini_grouping_engine.dart` — `moveIdea()`, `mergeGroups()`
- **등급**: P0 (그룹 이동 기능 완전 미작동 + 데이터 소실)
- **수정**: `grouping_engine.dart`: `ideas: []` → `ideas: <Idea>[]`, `List<Idea>.from()` 적용. `gemini_grouping_engine.dart` `moveIdea()`, `mergeGroups()` 전체 리스트 생성 코드에 `List<Idea>.from()` 래핑 (2026-08-22)
- **상태**: ✅ 해결

### [Mercury-5-Merge-01] ← 재설계 후 발견
- **현상**: 그룹 병합 시트 BOTTOM OVERFLOWED BY 55 PIXELS — 그룹 수가 많을 때 시트 컨텐츠가 화면을 벗어남
- **원인**: `_MergeGroupSheet`가 `Column(mainAxisSize: min)` 사용. 소스 카드 + 그룹 목록(max 220) + TextField + 안내문 + 버튼 합산 시 화면 높이 초과
- **파일**: `lib/screens/teacher/organize_screen.dart` — `_MergeGroupSheetState.build()`
- **등급**: P2
- **수정**: `ConstrainedBox(maxHeight: 화면 88%) + SingleChildScrollView` 래핑으로 해결 (2026-08-22)
- **상태**: ✅ 해결

### [Mercury-6-Unapprove-01] ← 재설계 후 발견
- **현상**: 승인 취소 버튼 탭 시 카드가 "AI 제안" 배지로 복원되지 않음 — 승인 상태 유지
- **원인**: `_unapprove()`가 `approveGroups(newList)`를 호출했으나 `approveGroups`는 `batch.set`만 수행 (삭제 없음) → 제외한 그룹의 Firestore 문서가 그대로 남아 StreamBuilder가 여전히 "승인됨"으로 읽음
- **파일**: `lib/repositories/firebase_moamal_repository.dart` — `approveGroups()`, `lib/screens/teacher/organize_screen.dart` — `_unapprove()`
- **등급**: P1 (승인 취소 기능 미작동)
- **수정**: `deleteApprovedGroup(sessionCode, groupId)` 메서드 추가, `_unapprove()`에서 직접 해당 문서 삭제로 변경 (2026-08-22)
- **상태**: ✅ 해결

### [Mercury-6-Rename-01] ← 재설계 후 발견
- **현상**: 그룹 이름 수정 다이얼로그에서 취소/저장 탭 시 앱 크래시 — `_dependents.isEmpty: is not true` assertion
- **원인**: `_showRenameDialog()`에서 `showDialog` await 직후 `ctrl.dispose()` 호출 → 다이얼로그 exit 애니메이션 중 TextField가 아직 트리에 존재하는 상태에서 controller 강제 dispose → `InheritedElement.unmount()` assertion 실패
- **파일**: `lib/screens/teacher/organize_screen.dart` — `_showRenameDialog()` line 889
- **등급**: P0 (크래시)
- **수정**: `ctrl.dispose()` 제거 — 로컬 변수로 GC 처리, 다이얼로그 위젯 unmount 시 TextField가 listener 자동 해제 (2026-08-22)
- **상태**: ✅ 해결

### [Mercury-5-Merge-02] ← 재설계 후 발견
- **현상**: 그룹 병합 방향이 UX 기대와 반대 — "작은 그룹"의 병합 버튼을 눌러 "큰 그룹"을 선택하면, 큰 그룹이 작은 그룹에 흡수됨 (사용자 기대: 작은 그룹이 큰 그룹에 흡수되길 기대)
- **원인**: `mergeGroups(sourceGroupId, targetGroupIds)` 설계상 병합 버튼을 누른 그룹(source)이 기준이 됨
- **파일**: `lib/services/gemini_grouping_engine.dart` — `mergeGroups()`
- **등급**: P3 (기능은 동작하나 UX 직관과 다름)
- **수정 방향**: 병합 시트에서 방향을 명확하게 표시("선택한 그룹들을 이 그룹으로 흡수") 또는 선택한 그룹이 surviving group이 되도록 방향 반전
- **상태**: 🔴 미해결

---

## Gemini

### [Gemini-1-Join-01] ← G1 진행 중 발견 (2026-08-25)
- **현상**: 랜딩 학생 영역의 **QR 아이콘 버튼을 눌러도 QR 스캐너가 열리지 않는다.** `코드 입력` 버튼과 완전히 똑같이 코드 입력 화면(`JoinScreen`)으로 이동하며, 거기서 `QR 코드 찍기`를 **한 번 더** 눌러야 스캐너가 뜬다
- **원인**: `landing_screen.dart:198-199` — `onCodeEntry`와 `onQr`이 **동일한 콜백**이다
  ```dart
  onCodeEntry: () => _joinAsStudent(context),
  onQr:        () => _joinAsStudent(context),   // 같은 함수
  ```
  QR 버튼이 사실상 장식이며, 별도 버튼을 둔 의미가 없다
- **영향**: 학생이 QR로 들어오는 경로가 2탭이 된다. 교실에서 교사가 QR을 띄워놓고 "QR 눌러"라고 안내했을 때 학생이 스캐너를 못 찾는다. 학생 진입은 수업 시작 직후 30초 안에 전원이 통과해야 하는 구간이라 1탭 차이가 크다
- **파일**: `lib/screens/common/landing_screen.dart:199`
- **등급**: P2
- **수정** (2026-08-25): `JoinScreen`에 `autoScan` 파라미터 신설. `initState`에서 `addPostFrameCallback`으로 `_scanQr()` 호출. 랜딩은 `onQr: () => _joinAsStudent(context, autoScan: true)`. 스캔을 취소해도 코드 입력 화면에 그대로 남아 수동 입력으로 이어간다
- **상태**: ✅ **해결** — 2026-08-25 실기기(SM-A305N) 확인. 럜딩 QR 버튼 → 카메라 즉시 진입

### [Gemini-1-Join-02] ← G1 진행 중 발견 (2026-08-25)
- **현상**: 코드 입력 화면(`JoinScreen`)에서 **앱 자체 키패드가 화면을 과점유**해 정작 입력해야 할 **6자리 코드 칸과 `QR 코드 찍기` 버튼이 화면 밖으로 밀린다.** 진입 직후 보이는 것은 제목과 키패드뿐이고, 코드 칸을 보려면 스크롤해야 한다
- **원인**: `join_screen.dart:115-127` — 최상위 `Column`이
  `헤더(고정) + Expanded(스크롤 콘텐츠) + 다음 버튼(고정) + 키패드(고정)` 구조다.
  키패드가 **고정 높이**(`_Key`의 `padding: vertical 11` + `fontSize 17` × 4행 + 간격)로 약 225dp를 항상 차지하고,
  남은 높이를 콘텐츠가 가져가므로 **화면이 좁을수록 코드 칸이 먼저 밀려난다**
- **재현**: SM-A305N(320dp)에서 랜딩 → `코드 입력` → 코드 칸이 보이지 않음
- **영향**: 이 화면의 **유일한 목적이 코드 입력인데 입력란이 안 보인다.** QR 버튼도 가려져 Gemini-1-Join-01과 겹쳐 학생이 QR 경로를 아예 발견하지 못한다
- **파일**: `lib/screens/student/join_screen.dart` — `build()`, `_buildKeyboard()`, `_Key`
- **등급**: P2 (기능은 동작 — 스크롤하면 입력 가능)
- **비고**: 시스템 키보드가 아니라 **앱이 직접 그리는 키패드**다. 따라서 `resizeToAvoidBottomInset`이나 포커스 제어로는 해결되지 않으며, 키 높이를 화면에서 역산해야 한다. `Mercury-Layout-01`의 PIN 패드와 **같은 성격**(고정 크기가 좁은 화면을 소진)이며, 그때는 가로 폭이 문제였고 이번엔 세로 높이다
- **1차 수정 실패** (2026-08-25): `build()`를 `LayoutBuilder`로 감싸 키패드 상한을 가용 높이의 34%로 잡았으나 **실기기에서 체감 변화가 없었다**. SM-A305N은 1080×2340 / density 오버라이드 540 → **320×693dp**이고, 34% 예산을 넣으면 `padV`가 **10.2**로 나와 기존 11과 0.8dp 차이에 그친다. 예산을 너무 헐렚하게 잡았다
- **실측 분석**: SafeArea 가용 높이 ≈ 620dp vs 필요 높이 ≈ 690dp — **70dp 부족**. 내역은 헤더 46 + 콘텐츠 363 + 다음 버튼 70 + 키패드 211. 가장 큰 낙수는 **제목이 3줄로 쌓이는 것**(fontSize 30 × height 1.3 × 3줄 = 117dp)으로, 320dp 폭에서 `6자리 코드를 넣어요`가 한 줄에 들어가지 않아 `요` 한 글자가 줄 하나를 차지한다
- **2차 수정** (2026-08-25): 키패드만 줄여서는 부족하므로 `context.isNarrow`(360dp 미만)로 묶어 처리 — 제목 30→24dp(3줄→2줄, ≈ 55dp 절약), 섹션 간격 18→12dp(×3), 콘텐츠 상하 여백 22/18→14/12, 다음 버튼 세로 패딩 19→15dp, 키패드 예산 34%→30%. 넓은 화면은 기존 값을 그대로 쓴다
- **상태**: ✅ **해결** — 2026-08-25 실기기 확인. 320dp에서 제목 2줄, 코드 칸 6개·`QR 코드 찍기` 모두 첫 화면에 노출

### [Gemini-1-Join-03] ← Gemini-1-Join-01 수정 후 파생 (2026-08-25)
- **현상**: QR 스캐너에서 **인식이 안 될 때 빠져나갈 길이 사실상 없다.** 화면에 있는 탈출 경로는 좌상단 38dp 화살표 하나뿐이고, 카메라 권한이 거부되거나 카메라를 열 수 없는 기기에서는 **아무 안내 없이 검은 화면**만 표시된다(`MobileScanner`에 `errorBuilder` 미지정)
- **왜 지금 중요해졌나**: Gemini-1-Join-01을 고치면서 랜딩 QR 버튼이 **스캐너로 직행**하게 됐다. 즉 이 화면이 **학생이 보는 첫 화면**이 될 수 있다. 이전에는 코드 입력 화면을 한 번 거쳤으므로 실패해도 자연스럽게 코드 입력으로 이어졌지만, 지금은 학생이 카메라 화면 앞에서 멈춘다
- **교실 맥락**: 인식 실패는 흔하다 — 프로젝터 반사, 화면 밝기, 뒷자리 거리, 저가형 기기 카메라 초점. 수업 시작 직후 전원이 30초 안에 들어와야 하는 구간이라 한 명이 막히면 교사가 개입해야 한다
- **파일**: `lib/screens/student/join_screen.dart` — `_QrScanScreenState`
- **등급**: P2
- **수정** (2026-08-25):
  - 하단에 **`코드 직접 입력하기`** 버튼 상시 배치 — 좌상단 화살표만으로는 학생이 대안을 인지하지 못한다
  - **8초간 미인식 시** 안내 문구를 "잘 안 읽히면 아래에서 코드로 들어갈 수 있어요"로 바꾸고 버튼을 kYellow로 강조. 처음부터 강조하면 QR을 시도해보기도 전에 코드 입력으로 유도된다
  - `errorBuilder` 추가 → 카메라를 열 수 없으면 `_CameraUnavailable`(이유 + 동일 버튼) 표시. 검은 화면 제거
  - 좌상단 화살표도 같은 `_fallbackToCode()`를 타도록 통일, 타이머는 dispose·인식 성공 시 취소
- **상태**: ✅ **해결** — 2026-08-25 실기기 확인. 하단 버튼 상시 표시, 8초 경과 시 문구 전환·kYellow 강조 동작
### [Gemini-1-Join-04] ← G1 재확인 중 발견 (2026-08-25)
- **현상**: 코드 입력 화면의 `다음` 버튼이 **불필요하게 한 단계를 더 요구한다.** 세션 코드는 길이가 정확히 6자리로 고정이므로 마지막 글자가 들어온 시점에 확인할 수 있는데, 학생이 키패드 위 `다음`을 한 번 더 눌러야 진행된다
- **일관성 문제**: **QR 경로는 이미 자동 진행한다.** `_scanQr()`가 스캔 성공 시 `_verify()`를 직접 호출하므로 버튼을 거치지 않는다. 같은 화면의 두 진입 방식이 서로 다르게 동작했다
- **부수 효과**: 비활성 상태의 회색 버튼이 키패드 바로 위에 상주해 **약 70dp를 점유**했다. Gemini-1-Join-02(좁은 화면에서 콘텐츠가 밀림)의 원인 중 하나이기도 하다
- **파일**: `lib/screens/student/join_screen.dart` — `_addChar()`, `build()`, `_buildNextButton()`
- **등급**: P3 (기능은 정상. 조작 단계와 화면 공간의 문제)
- **수정** (2026-08-25):
  - `_addChar()`에서 `_chars.length == 6`이면 `_verify()` 자동 호출 — QR 경로와 동작을 일치시켰다
  - `_buildNextButton()` 제거 (메서드·`canNext` 변수까지 삭제, 사재 코드로 남기지 않는다)
  - 확인 중 표시는 원래 버튼 안의 스피너가 담당했으므로 **부제 자리로 이관** — `_isVerifying`이면 13dp 스피너 + "코드를 확인하고 있어요"(kGreen, bold), 아니면 기존 안내 문구
- **오입력 우려**: 마지막 자리를 잘못 눌러도 즉시 오류 카드가 뜨고 `⌫`·`지우기`로 되돌릴 수 있다. `다음`을 눌러 틀린 코드를 보내던 것과 결과가 같으며, 인증번호 입력의 일반적인 동작과도 일치한다
- **상태**: ✅ **해결** — 2026-08-25 실기기 확인. 6자리 입력 즉시 진행, 버튼 없이도 정상 동작
### [Gemini-1-Deeplink-01] ← G1 1-3 검증 중 확인 (2026-08-25)
- **현상**: 교사 화면의 QR을 **폰 기본 카메라 앱**으로 촬영해도 **아무 반응이 없다.** 앱이 열리지도, 텍스트가 표시되지도 않는다
- **원인 — 앱 결함이 아니라 플랫폼 제약**:
  - QR 페이로드는 정상이다. `teacher_home_screen.dart:1388, 1475`가 `DeepLinkService.buildJoinUri()`로 `moamal://join/{code}`를 인코딩한다
  - 인텐트 필터도 정상이다. `adb shell am start -a android.intent.action.VIEW -d "moamal://join/7ZHVN7"`로 직접 발사했을 때
    logcat에 `D/com.llfbandit.app_links: Handled intent: action: android.intent.action.VIEW / data: moamal://join/7ZHVN7`가 찍히고 앱이 실제로 반응했다
  - **삼성 기본 카메라의 QR 인식이 커스텀 스킴을 처리하지 않는다.** `http`/`https`·WiFi·연락처 등 표준 형식만 배너로 띄우고,
    앱 전용 스킴은 무시한다. 따라서 **클라이언트 코드로는 해결 불가능**하다
- **영향**: 체크리스트 G1 1-3(폰 기본 카메라 → 앱 실행)은 **웹 랜딩 URL 없이는 원리적으로 달성할 수 없다.**
  다만 학생 참여 자체는 앱 내 스캐너(1-2)와 코드 입력(1-1)으로 충분히 커버된다
- **등급**: 버그 아님 — **제약 사항**. QA 항목을 실패로 기록하지 않고 조건 정정
- **정리**:
  - `moamal://` 딥링크는 **참여 링크 공유**(카카오톡 등으로 링크 전달 → 탭 시 앱 실행)에서 실질 가치가 있다. Mercury-Share-02와 연결
  - 폰 카메라 경로까지 원하면 웹 랜딩 페이지가 선행되어야 한다 (Mercury-Share-01의 남은 설계 결정)
- **상태**: ✅ 원인 규명 완료 · 체크리스트 1-3 조건 정정

### [Gemini-1-Deeplink-02] ← Deeplink-01 검증 중 발견 (2026-08-25)
- **현상**: 앱이 실행 중일 때 딥링크가 들어오면 **화면이 계속 쌓인다.** 딥링크를 2번 보낸 뒤 뒤로 가기를 눌러보니
  **4번을 눌러야 랜딩에 도착**했다 (정상이라면 3번: 랜딩 → 코드입력 → 이름입력)
- **재현**: 앱 실행 중 `moamal://join/{code}`를 2회 전달 → 이름 입력 화면이 겹겹이 push됨.
  화면이 동일해 보여서 **겉으로는 아무 일도 안 일어난 것처럼 보인다** — 이 때문에 1-5를 실패로 오판할 뻔했다
- **원인**: `main.dart` `_joinWithCode()`가 현재 스택 상태와 무관하게 `Navigator.push`만 한다
- **영향**: 학생이 QR을 두 번 스캔하거나 공유 링크를 연달아 누르면 뒤로 가기 횟수가 계속 늘어난다.
  교실에서 학생이 "뒤로 가도 안 나가져요"라고 할 수 있다
- **등급**: P3 (참여 자체는 정상)
- **수정** (2026-08-25): `Navigator.popUntil(context, (route) => route.isFirst)`로 스택을 랜딩까지 걷어낸 뒤 push.
  딥링크는 **항상 랜딩 위에 한 겹만** 쌓인다
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** (딥링크 2회 전달 후 뒤로 가기 3번에 랜딩 도달하는지)
### [Gemini-1-Profile-01] ← G1 1-4 진행 중 발견 (2026-08-25)
- **현상**: 이름·번호 입력 화면에서 **포커스된 입력 칸에만 테두리가 두 겹**으로 그려진다. 바깥은 우리가 그린 kGreen 2px, 안쪽에 같은 초록 테두리가 하나 더 생겨 네모 안에 네모가 든 모양이 된다. 포커스가 없는 칸은 정상(한 겹)
- **원인**: `app_theme.dart:61-67`의 `inputDecorationTheme`에 **`focusedBorder`(kGreen, 2px)** 가 정의돼 있다.
  두 필드는 `InputDecoration(border: InputBorder.none)`만 지정했는데, **Flutter는 포커스 상태에서 `border`가 아니라 `focusedBorder`를 사용한다.**
  따라서 커스텀 `Container` 테두리 안쪽에 테마 테두리가 추가로 렌더링된다
- **재현**: 번호 또는 이름 칸을 탭 → 해당 칸만 테두리 2겹
- **파일**: `lib/screens/student/join_screen.dart` — `_buildNumberField()`, `_buildNameField()`
- **등급**: P3 (기능 정상, 시각 결함)
- **범위 확인**: `border: InputBorder.none`만 지정한 곳은 앱 전체에서 이 두 곳뿐이다.
  `organize_screen.dart:866, 1979`와 `draft_sheet.dart:139`는 `focusedBorder`를 직접 지정해 두어 영향이 없다
- **수정** (2026-08-25): 두 필드에 `enabledBorder: InputBorder.none`, `focusedBorder: InputBorder.none` 추가.
  테마를 건드리면 테마에 의존하는 다이얼로그 입력칸(랜딩 코드 입력·수업 제목, 그룹명 수정)의 모양이 함께 바뀌므로 필드 단위로 막았다
- **상태**: ✅ **해결** — 2026-08-25 실기기 확인. 번호·이름 두 칸 모두 포커스 시 테두리 한 겹

### [Gemini-1-Profile-02] ← G1 1-4 진행 중 발견 (2026-08-25)
- **현상**: `들어가기` 버튼이 **글자 크기만큼만 오므라든 작은 사각형**으로 화면 가운데 뜬다. 코드 입력 화면의 전체 폭 CTA와 모양이 어긋나고, 학생이 눌러야 할 주 버튼치고 타깃이 작다
- **원인**: `StudentProfileScreen`의 최상위 `Column`에 `crossAxisAlignment`가 지정되지 않아 기본값 **`center`** 로 동작한다.
  버튼은 `Padding → GestureDetector → Container(width 미지정)` 구조라 가로 제약을 받지 못하고 자식(Text) 크기로 축소된다.
  본문 영역은 안쪽 `Column`에 `stretch`가 있어 정상이었고, 키패드는 `Row + Expanded` 구조라 폭을 채워서 **버튼만 티가 났다**
- **참고**: 코드 입력 화면의 구 `다음` 버튼도 동일한 이유로 작게 나왔다. 그 버튼은 Gemini-1-Join-04에서 제거됐다
- **파일**: `lib/screens/student/join_screen.dart` — `_StudentProfileScreenState.build()`
- **등급**: P3
- **수정** (2026-08-25): 최상위 `Column`에 `crossAxisAlignment: CrossAxisAlignment.stretch` 지정
- **비고**: 이름 칸에는 이미 `onSubmitted: (_) => _enter()`가 있어 **키보드의 `완료`로도 입장할 수 있다.** 번호·이름은 길이가 가변이라 코드처럼 자동 제출은 불가하므로 버튼 자체는 유지한다
- **상태**: ✅ **해결** — 2026-08-25 실기기 확인. `들어가기`가 화면 폭 전체로 렌더링
### [Gemini-1-Join-05] ← G1 1-4 통과 확인 (2026-08-25)
- **내용**: 딥링크·QR·코드 세 경로 모두 `StudentProfileScreen`을 거쳐 `participants` 등록까지 정상 완료되는 것을 확인했다
- **근거**: 학생(1번 김철수) 입장 후 교사 화면 상단 통계가 **참여 1**로 갱신됨.
  Mercury QA 전 구간에서 이 수치는 **항상 0**이었고(실제 학생 접속이 없어 검증 불가), Gemini에서 처음 실측됨
- **의미**: `Mercury-Share-01`의 수신 경로 수정(이름 입력 경유)이 실제로 동작함을 입증한다.
  이전 구현이었다면 딥링크로 들어온 학생은 참여자로 잡히지 않았을 것
- **상태**: ✅ G1 1-1 · 1-2 · 1-4 · 1-5 · 1-9 통과

---

## Apollo

_(실제 수업 흐름 테스트 시작 후 기록)_

---

## Common

### [Common-Network-01]
- **현상**: 앱 백그라운드 전환 후 복귀 시 Firestore 리스너 재연결 미검증
- **최초 발견**: Mercury v1
- **확인 필요**: `WidgetsBindingObserver` 재구독 로직 또는 Firebase 자체 재연결 동작
- **등급**: P1 (세션 재진입 시 상태 복구 실패 가능)
- **상태**: 🟡 미재현 (Mercury QA v2에서 재확인 필요)

---

## v1 해결 이력 (BUG_LOG.md → v2로 이월하지 않은 항목)

| ID | 내용 | 해결 |
|----|------|------|
| Mercury-0-Auth-01 | Google 로그인 ApiException: 10 — SHA-1 미등록 | ✅ Firebase 콘솔 SHA-1 등록 + google-services.json 재배포 |
| Mercury-0-STT-01 | STT 502 — v1 URL 하드코딩 | ✅ `_defaultEndpoint` v2 URL로 교체 |
| Mercury-Report-01 | GPT 그룹화/리포트 400 — v1 URL + 모델 불일치 | ✅ openaiProxy URL 및 모델 전환 |
| Mercury-Report-03 | 리포트 502 — temperature 파라미터 거부 | ✅ temperature 전체 제거 |
| Mercury-3-Group-01 | AI 그룹화 race condition — 배치 2가 배치 1 결과 덮어씀 | ✅ 순차 처리 큐(`_calling` + `_pendingBatches`) 구현 |
| Mercury-3-UI-01 | 누적 요약 패널 BOTTOM OVERFLOWED 47px | ✅ bottom padding 92 고정값으로 수정 |
| Mercury-2-STT-UI-01 | STT 박스 BOTTOM OVERFLOWED 22px | 🔴 v2에서 재확인 필요 (UI 재설계로 구조 변경됨) |
| _stableGroupId RangeError | ideas.length==1 시 clamp(2,1) 크래시 위험 | ✅ `clamp(1, ideas.length)`로 수정 (v2 코드 확인됨) |
| _processQueue debug prints | `print()` 3개 잔류 | ✅ 모두 제거됨 (v2 코드 확인됨) |
| Mercury-1-Session-Restore-01 | 앱 재시작 시 진행 중 교사 세션 복귀 불가 — 랜딩 화면으로 이동 | ✅ SharedPreferences `active_teacher_session` 키로 세션 코드 저장·복귀 구현. `Navigator.push`(pushReplacement 아님)로 랜딩 스택 유지 |
| Mercury-2-Organize-EmptyIdeas-01 | OrganizeScreen 진입 시 의견 0건 표시 | ✅ broadcast stream 새 구독자는 과거 이벤트를 받지 못하는 문제. `StreamBuilder(initialData: widget.initialSession)`으로 해결 |
| Mercury-2-EmptyText-01 | 빈 text 필드 의견이 화면에 표시됨 | ✅ `_buildState()`에서 `.where((idea) => idea.text.trim().isNotEmpty)` 필터 추가 |
| Mercury-2-VAD-Threshold-01 | VAD threshold -40dB — 실 기기 ambient noise(-37~-39dBFS)가 threshold보다 높아 "speech"로 판정, 침묵 타이머 리셋 반복 | ✅ threshold를 `-34dB`로 상향. 창문 열린 실내 환경에서 silence=3037ms 정상 트리거 확인 |
| Mercury-TeacherDock-FAB-01 | 마이크 버튼이 독 위로 떠오르는 FAB 형태 — 교사가 의도한 플랫 5버튼 레이아웃과 다름 | ✅ Stack/Transform.translate 제거, `Row(mainAxisAlignment: spaceEvenly)` 인라인 배치로 전환 |
