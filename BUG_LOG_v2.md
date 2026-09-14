# Moamal Bug Log v2

> UI 전면 재설계(2026-08) 이후 버전 기준.  
> 형식: `[단계-섹션번호-컴포넌트-순번]`  
> 단계: Mercury / Gemini / Apollo / Common / Hackathon
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

> 해커톤 웹 데모 관련 결함은 이 문서의 `Hackathon` 섹션을 참조한다. Apollo 다인 QA와 구분한다.

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
- **잔여 수정 완료** (2026-08-26, Flutter UI/UX): `_YellowCta.onTap`을 `VoidCallback`→`VoidCallback?`로 완화,
  비활성 시 배경 `kInk.withValues(alpha:0.1)` + 텍스트 반투명. `_CompactBody`/`_MediumBody` 양쪽 호출부에서
  `onShare: meetingReport != null ? _share : null` 전달. 상단 AppBar 버튼과 동일한 가드 방식으로 통일
- **상태**: ✅ 해결 · **실기기 미검증**

### [Mercury-Report-04] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 최초 생성인데 버튼 라벨이 "AI 요약 **다시** 생성"
- **원인**: `report_screen.dart:384` 조건이 `meetingReport == null && groups.isNotEmpty` — 아직 한 번도 생성되지 않은 상태에서만 렌더링되는데 라벨은 재생성 문구
- **등급**: P3
- **수정** (2026-08-26, Flutter UI/UX): 라벨 "AI 요약 다시 생성" → "AI 요약 생성". 이 분기는
  `meetingReport == null`일 때만 렌더링되므로(한 번도 생성된 적 없음) "다시"라는 표현 자체가 틀렸다.
  재생성 버튼이 필요하면(`meetingReport != null`) 별도 UI로 분리해야 하며, 그 결정은 아직 없다
- **상태**: ✅ 해결 · **실기기 미검증**

### [Mercury-Report-05] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 리포트 화면 "참여 N명"이 실제 참여자 수가 아님
- **원인**: `report_screen.dart:281` — `session.votes.isNotEmpty ? session.votes.length : session.ideas.length`.
  투표가 있으면 투표 수를, 없으면 **의견 수**를 참여자 수로 표시. QA 중 "1명"은 Section 7 테스트 잔여 투표 1건이었고,
  투표가 없었다면 학생 0명인데도 "8명 참여"로 표시됐을 것
- **등급**: P2 (교사가 학교에 제출하는 리포트 수치이므로 신뢰도 문제)
- **수정 방향**: `session.participants` 기준으로 집계
- **2026-08-25 추가**: `Gemini-1-Exit-01`과 묶어서 결정해야 한다. 학생 퇴장 처리가 없어 `participants`는 **누적 입장자**를 뜻하며, LIVE 화면의 `참여`와 리포트의 `참여 N명`이 같은 정의를 써야 한다
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
- **수정** (2026-08-26): 위 세 번째 안 채택. `ReportScreen`을 `StatefulWidget`으로 전환하고
  `onGenerateReport`의 타입을 `VoidCallback` → `Future<MeetingReport?> Function()`으로 변경.
  화면이 생성 결과를 **반환값으로 직접 받아** 자기 `setState`로 갱신한다.
  `_isGenerating`도 화면 로컬 상태가 되어 버튼이 즉시 "생성 중..."으로 바뀐다.
  부모(`TeacherHomeScreen._generateReport`)도 기존대로 `_meetingReport`를 갱신하므로 재진입 시 결과가 유지된다.
  실패 시 `null`이 오며 이때는 기존 리포트를 지우지 않는다
- **파일**: `lib/screens/teacher/report_screen.dart`, `lib/screens/teacher/teacher_home_screen.dart` — `_generateReport()`
- **상태**: ✅ 코드 수정 완료 · **실기기 검증 완료** (2026-09-03, GR R-8) — "AI 요약 생성" 탭 즉시 "생성 중..."으로 버튼 전환, 화면 재진입 없이 그 자리에서 항목별 요약이 정상 표시됨. "리포트 저장/공유"도 활성화되어 네이티브 공유 시트에 리포트 본문("학급회의 요약 리포트")까지 정상 노출 확인

### [Mercury-Session-02] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 앱 재시작(핫 리스타트 포함) 후 세션에 복귀하면 **교사가 수행한 그룹 병합·이동·승인 결과가 모두 사라지고** AI가 처음부터 다시 그룹화함.
  QA 중 4개 그룹(병합된 "김치와 김치요리" 포함) → 5개 그룹으로 재생성되고 제목도 전부 바뀜
- **원인**: `GeminiGroupingEngine._cachedGroups`가 메모리에만 존재. 세션 복귀 시 Firestore의 `ideas`만 다시 읽어 재그룹화함.
  `approvedGroups`는 Firestore에 남지만 재그룹화로 그룹 id가 달라지면 매칭이 깨져 승인 표시도 소실
- **파일**: `lib/services/gemini_grouping_engine.dart` — `_cachedGroups`, `reset()`
- **등급**: **P1** — 교사가 수업 내내 정리한 결과를 앱이 한 번 죽으면 전부 잃는다. `active_teacher_session` 복귀 기능의 의미가 반감됨
- **수정 방향**: 그룹 구성(`groupId → ideaIds`, `aiTitle`)을 Firestore에 스냅샷으로 저장하고 복귀 시 복원.
  `mergeLogs` 스키마 작업과 함께 설계하는 것이 합리적
- **수정** (2026-08-26):
  - `models/group_snapshot.dart` 신설 — `GroupSnapshotEntry{groupId, aiTitle, ideaIds}`.
    `Group`과 달리 **의견 본문이 아니라 id만** 저장한다. 원문의 단일 진실은 `ideas` 하위 컬렉션이고
    스냅샷은 "어느 의견이 어느 그룹에 속하는가"만 책임진다 (`approvedGroups.idea_ids`와 같은 계약)
  - **저장 위치는 하위 컬렉션이 아니라 세션 문서 필드** `groupSnapshot`.
    `sessions` update가 이미 교사 전용이라 **보안 규칙 추가·재배포 없이 동작**하기 때문이다(백엔드 방 의존 제거).
    대가로 학생도 이 필드를 함께 내려받는다 — 수 KB 수준이라 파일럿까지는 감수
  - `GeminiGroupingEngine.onGroupsChanged` 콜백 신설 → 그룹이 바뀌는 **4개 지점 전부**
    (`_applyResult`·`moveIdea`·`mergeGroups`·`undoMerge`)에서 호출. `TeacherHomeScreen`이 받아 Firestore에 저장
  - `restoreSnapshot()` 신설 — 복원한 의견을 `_processedIds`에 등록하는 것이 **핵심**이다.
    이 표시가 없으면 `makeGroups()`가 기존 의견 전부를 버퍼에 넣어 재그룹화를 유발하고 복원 결과가 그대로 덮인다.
    스냅샷에 없는 의견(복귀 중 새로 들어온 것)은 미처리로 남아 다음 배치에서 기존 그룹에 편입된다
  - 호출 순서: 스트림 리스너에서 `restoreSnapshot()` → `makeGroups()`. **뒤바뀌면 수정이 무효가 된다**
- **저장 루프 없음**: 스냅샷 저장 → 세션 문서 변경 → 리스너 재진입 시 `_cachedGroups != null`이므로
  `restoreSnapshot()`이 즉시 false를 반환하고, `makeGroups()`는 캐시를 그대로 돌려주어 추가 쓰기가 발생하지 않는다
- **테스트**: `test/group_snapshot_restore_test.dart` 6건 — 복원·재그룹화 차단·중복 복원 방지·원문 삭제 그룹 제외·빈 스냅샷·저장 콜백
- **파일**: `lib/models/group_snapshot.dart`, `lib/services/gemini_grouping_engine.dart`,
  `lib/repositories/*` (`saveGroupSnapshot`), `lib/screens/teacher/teacher_home_screen.dart`
- **상태**: ✅ 코드 수정 완료 · **부분 실기기 검증** — 2026-09-03 Gemini G6 6-7에서 승인(approve) 시나리오 확인:
  세션 NONCNN(그룹 3개·승인 2개) 상태에서 교사 앱 `am force-stop` → 재실행 → `active_teacher_session`으로 정상 복귀,
  "그룹 3개 · 승인 2개" **소실 없이 유지됨** — 스냅샷 복원(`restoreSnapshot`)이 실기기에서 처음으로 확인됨.
  단 이번 세션은 **승인만 하고 병합(`mergeGroups`)·그룹명 수정은 하지 않은 상태**라 그 경로까지 커버하진 못했다 —
  병합 후 강제종료 시나리오는 별도로 재확인 필요

### [Mercury-Session-03] ← Section 10 QA 중 발견 (2026-08-24)
- **현상**: 앱 재시작 후 리포트의 "수업 N분" 경과 시간이 리셋됨. QA 중 39:29 → 02:05로 초기화
- **원인**: `teacher_home_screen.dart:198` `_sessionStart = DateTime.now()` — 앱 실행 시각 기준.
  `existingCode`로 기존 세션에 복귀해도 Firestore의 세션 생성 시각을 쓰지 않음
- **등급**: P2 — 교사가 학교에 제출하는 리포트 수치이므로 신뢰도 문제 (Mercury-Report-05와 동일 성격)
- **수정 방향**: 세션 문서에 `createdAt`을 저장하고 복귀 시 그 값을 `_sessionStart`로 사용
- **수정** (2026-08-26): `publishSession()`이 `createdAt: serverTimestamp()`를 기록한다.
  세션 **생성 경로에서만** 호출되므로 값이 덮이지 않는다 — 복귀(`existingCode`)는 `publishSession`을 타지 않는다.
  `SessionState.createdAt`을 추가하고, 스트림이 값을 물어오면 `_sessionStart`를 그 값으로 교체한다.
  `late DateTime _sessionStart`는 스트림이 먼저 도착해도 안전하도록 `DateTime.now()` 초기값을 갖는 일반 필드로 바꿨다
- **파일**: `lib/models/session_state.dart`, `lib/repositories/firebase_moamal_repository.dart`,
  `lib/screens/teacher/teacher_home_screen.dart`
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증**
- **한계**: 이번 수정 이전에 만들어진 세션은 `createdAt`이 없어 기존 동작(앱 실행 시각 기준)으로 폴백한다.
  검증은 **새 세션**으로 해야 한다
- **파생**: 이 수정으로 경과 시간이 정확해지자 원래 있던 두 구멍이 드러났다 → `Mercury-Session-04`

### [Mercury-Session-04] ← Mercury-Session-03 수정 후 대표 질의로 발견 (2026-08-26)
- **현상**: 교사가 수업을 **종료하지 않고 앱만 끈 뒤 다음 날 실행하면 어제 세션으로 자동 복귀**하고,
  수업 시간이 `1140:23`처럼 표시된다 (19시간을 분으로 환산한 값)
- **재현**: 8/26 15:00 세션 생성 → 종료하지 않고 앱 강제 종료 → 8/27 10:00 실행
- **원인 두 가지**:
  1. **복귀에 아무 조건이 없다.** `main.dart`가 `active_teacher_session`에 코드가 있으면
     날짜·종료 여부를 보지 않고 무조건 `TeacherHomeScreen(existingCode:)`으로 보낸다.
     `endedAt`이 없던 시절에는 종료 여부를 확인할 방법 자체가 없었다
  2. **경과 시간 표기에 시간 단위가 없다.** `_formatElapsed()`가 `분:초`만 만들어
     60분을 넘으면 분이 무한정 쌓인다
- **왜 지금 드러났나**: `Mercury-Session-03` 이전에는 앱 실행 시각부터 다시 세어 `00:00`으로 보였다.
  **숫자가 틀렸지만 멀쩡해 보였을 뿐**이고, 정확해지자 두 구멍이 함께 보이게 됐다
- **파급**: 어제 세션에 오늘 발언이 섞이면 리포트가 오염된다. `Gemini-1-Exit-03`으로 종료 상태가 생겼는데도
  **끝난 세션으로 복귀할 수 있다는 점**이 특히 문제였다
- **등급**: P2
- **결정** (2026-08-26, 대표): **복귀는 당일만.** '물어보기' 안도 검토했으나,
  실제로 물어보기가 이득인 경우는 어제 세션이 아니라 **같은 날 두 번째 수업**(오전 세션에 끌려가는 경우)이며
  뒤로가기 → 종료로 빠져나올 수 있으므로 파일럿에서 실제로 걸리는지 보고 나중에 얹기로 함
- **수정** (2026-08-26):
  - `models/session_meta.dart` 신설 — `canResumeAt(now)`가 **당일 + 미종료**를 함께 판정.
    `createdAt`이 없는 구 세션은 **복귀하지 않는다**(판단 근거가 없으면 안전한 쪽으로 실패)
  - `fetchSessionMeta()` — 세션 문서만 1회 조회. 하위 컬렉션을 읽지 않아 앱 시작 시 문서 read 1회
  - `main.dart` — 복귀 전 조회 후 판정. 조회 실패(오프라인 등)에도 복귀하지 않는다.
    복귀 대상이 아니면 `active_teacher_session`을 **삭제**한다(남겨두면 켤 때마다 조회만 반복).
    필요하면 슈퍼바이저 모드의 '기존 세션 재개'로 코드를 넣어 들어갈 수 있다
  - `_formatElapsed()` — 1시간 초과 시 `H:MM:SS`
- **테스트**: `test/session_resume_test.dart` 5건 (당일·어제·종료됨·`createdAt` 없음·자정 직후 경계)
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증**

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
- **상태**: ✅ 해결 (2026-08-26) — Mercury-Report-02 잔여 수정으로 실제 진입점 2곳(상단 AppBar·하단 CTA) 모두 가드 적용 완료.
  단일 헬퍼 추출은 별도 리팩터링이라 하지 않았다 — 두 곳 다 이미 `_share()` 한 함수를 공유하고 있어 로직 중복은 없었다

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
- **수정** (2026-08-26): `lib/screens/teacher/tabs/` 3개 파일 **삭제**. 격리가 아니라 삭제를 택한 이유는
  git 이력에 남아 있어 복원이 가능하고, 남겨두면 QA·버그 로그가 계속 오염되기 때문이다.
  삭제로 `display_tab` unused import 경고도 함께 사라져 `flutter analyze` 경고가 11 → 10건이 됐다
- **남은 항목**: **파급 3(교사 수동 의견 입력 UI 소실)은 그대로 미해결**이다.
  삭제로 사라진 것이 아니라 재설계 시점에 이미 끊겨 있었다. 현재 `ideas` 생성 경로는 STT 단일이며,
  복원 여부는 전략기획 판단 사항으로 남는다
- **상태**: 🟡 코드 정리 완료 (2026-08-26) · **수동 입력 복원은 미결정**

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
- **수정** (2026-08-26, Flutter UI/UX): `color: approved ? kGreen : Colors.white`로 분기 적용
- **상태**: ✅ 해결 · **실기기 미검증**

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
- **~~남은 위험~~ → 제거 완료 (2026-08-26)**: `organize_screen.dart:67`·`cluster_vote_screen.dart:152`의
  `widget.sessionStream ?? widget.repo.listenToSession(...)` 폴백을 삭제하고 `sessionStream`을
  **nullable → required**로 바꿨다. 이제 스트림을 넘기지 않는 호출부는 **컴파일 자체가 되지 않아**
  같은 버그가 재발할 수 없다. `_goToSummary()`에는 `_goToProjector()`와 같은 `_sessionStream == null` 가드를 추가했다
- **상태**: ✅ 해결 · **실기기 검증 완료** (2026-08-27, Gemini G2-5·G4에서 확인 — 마이크·투표 반복 조작해도 데이터 유지, 깜빡임 없음)

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
- **상태**: ✅ 해결 · **실기기 검증 완료** (2026-08-27, Gemini G3 3-2·3-3에서 확인 — kRed 배너, SnackBar 중복 없음, 배너 닫아도 마이크 잠금 유지)

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
- **상태**: ✅ 해결 · **실기기 검증 완료** (2026-08-27, Gemini G3 3-4·3-5에서 확인 — 발언 이력 있는/없는 학생 둘 다 [중지]→[말하기]로 정상 재개)

### [Mercury-4-Organize-01] ← 재설계 후 발견
- **현상**: OrganizeScreen 승인 탭에서 투표 진행 중 "승인하기/승인 취소" 버튼이 비활성화되지만 시각적 피드백이 없음 — 탭해도 반응 없어 학생이 버그로 오해할 수 있음
- **원인**: `canToggle = !session.voteOpen` 조건 시 `onTap: null`만 세팅. 비활성 이유 안내 없음
- **파일**: `lib/screens/teacher/organize_screen.dart:1221` — `_GroupApproveCard`
- **등급**: ~~P2~~ → **P1 상향** (2026-08-24, Section 8 QA 중 실제 데이터 유실 확인)
- **실제 발생 시나리오**: 투표 중 "승인 취소" 탭 → 반응 없음 → 교사가 "안 눌렸나?" 하고 재탭하는 습관이 생김 → 투표를 닫은 뒤(`voteOpen=false`) 같은 자리를 누르면 이번엔 실제로 `deleteApprovedGroup()` 실행 → 승인 상태 + 교사가 수정한 그룹명이 함께 소실. Section 8 테스트 중 "접근성 높은 불고기" 승인이 이 경로로 사라짐(수동 재승인으로 복구)
- **수정** (2026-08-26, Flutter UI/UX): `organize_screen.dart` — `_GroupApproveCard`의 버튼 `onTap`을
  `canToggle && !isPending ? (...) : null`(투표 중엔 완전 무반응)에서 `isPending`일 때만 null이 되도록 바꾸고,
  `_handleTap()`으로 분기: ① 투표 중(`!canToggle`)이면 SnackBar "투표 진행 중에는 변경할 수 없어요" ②
  승인 취소(`approved`)면 확인 다이얼로그(교사 종료 다이얼로그와 동일 톤 — kRed "!" 배지, "유지하기"(kGreen)/"취소"(kRed outline))
  ③ 그 외엔 바로 승인. 투표 중에도 탭에 반응이 생기므로 재탭 습관 자체가 사라지고, 승인 취소는 항상 확인을 거친다
- **상태**: ✅ 해결 · **실기기 검증 완료** (2026-08-27, Gemini G4 4-7 — "투표 진행 중에는 변경할 수 없어요" 스낵바 정상 표시)

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
- **추가 검증** (2026-08-27): `appops`로 카메라 강제 거부 후 재확인 — 다이얼로그 없이 즉시 `_CameraUnavailable`("카메라를 열 수 없어요") 노출, "코드 직접 입력하기"로 정상 이탈됨
- **파생 발견 — 미해결**: `errorBuilder`가 그리는 `_CameraUnavailable`(중앙 정렬)이 항상 그려지는 `SafeArea` 레이어의 스캔 가이드 박스·안내 문구·하단 버튼과 **같은 화면에 겹쳐 보인다.** `Stack`에서 `MobileScanner`(카메라 실패 시 `_CameraUnavailable`)와 `SafeArea` 오버레이가 항상 함께 렌더링되기 때문 — 카메라 정상일 때는 오버레이가 카메라 미리보기 위에 자연스럽게 얹히지만, 실패 시에는 검은 배경의 `_CameraUnavailable` 콘텐츠와 오버레이 텍스트·버튼이 겹쳐 "코드 직접 입력하기" 버튼이 2개로 보이는 등 시각적으로 어수선하다. 기능은 둘 다 `_fallbackToCode()`로 동일하게 동작해 실사용에 지장은 없다. 등급 P3
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
- **상태**: ✅ **해결 · 실기기 검증 완료** (2026-08-27) — 유효 코드(QWKMIV)로 딥링크 2회 전달 후 뒤로 가기 **1번**만에 랜딩 도달. 예상(3번)보다 낫다 — `popUntil`이 두 번째 딥링크 시점에도 스택을 완전히 걷어내기 때문
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

### [Gemini-1-QR-01] ← 실기기 QR 스캔 중 발견 (2026-08-28)
- **현상**: 학생 실기기(R59MA03BRCN)에서 `QR 코드 찍기`로 카메라 화면에 들어갔을 때 **카메라 프리뷰 방향이 어긋나 있었음**. 기기를 가로↔세로로 몇 번 돌리자 정상으로 돌아옴. 재진입 시 정상 여부는 확인 못 함(스크린샷 시도 중 재현이 이미 풀려 있었음)
- **원인 가설(코드 근거 있음, 미확정)**: `main.dart:23-27`의 `SystemChrome.setPreferredOrientations`가 폰에서도 `landscapeLeft`/`landscapeRight`를 열어둔다 — 주석은 "폰은 세로 고정, 실제 판단은 런타임 MediaQuery"라 되어 있지만 이는 **레이아웃만 세로로 그리는 것**이지 OS 차원의 회전 잠금이 아니다. 즉 폰이 물리적으로 기울면 실제 가로 모드 전환이 일어날 수 있다. 여기에 `AndroidManifest.xml`의 `android:configChanges="orientation|..."`가 회전 시 Activity 재시작을 막아버려, `mobile_scanner`(`join_screen.dart` `QrScanScreen`)의 CameraX 프리뷰가 **최초 진입 시 회전값을 잘못 캐시했다가 실제 회전 이벤트가 들어와야 재계산**되는 알려진 플러그인 패턴과 일치한다(`mobile_scanner` GitHub에도 유사 리포트 다수)
- **영향**: 학생이 QR 스캔 진입 직후 화면이 이상해 보여 당황하거나 스캔을 포기하고 코드 직접 입력으로 이탈할 가능성. 스스로 해소되는 경우가 많아 보이나 재현 조건이 좁혀지지 않음
- **등급**: P3 (일시적·자가 해소, 그러나 첫인상에 영향)
- **파일**: `lib/main.dart:23-27`(orientation 설정), `lib/screens/student/join_screen.dart` `QrScanScreen`(`MobileScanner` 사용부), `android/app/src/main/AndroidManifest.xml`(`configChanges`)
- **검증 필요**: 재현 조건 특정 — ① 스캔 화면 진입 직후 즉시 vs 몇 초 후, ② 자동 회전 켜짐/꺼짐 상태별 재현 여부, ③ 폰을 완전히 세로 고정(`portraitUp`만 허용)했을 때도 재현되는지. 재현되면 폰 한정으로 `landscapeLeft/Right` 허용을 제거하는 것도 후보 수정안
- **상태**: 🟡 관찰됨 · 재현 조건 미확정 · 수정 보류(자가 해소돼 QA 진행 차단 아님)

### [Gemini-7-TeacherNote-01] ← G7 7-3 교사 STT 반영 확인 중 발견 (2026-08-28)
- **현상**: 교사가 마이크로 발문("회의 시작하자.")을 말하면 `teacher_notes`에 정상 저장되고 AI 그룹화 프롬프트에도 반영되지만, **학생 화면에는 절대 표시되지 않았다.** 학생 화면엔 노란 강조선의 "질문 카드"(`_questionCard`) UI가 이미 완성되어 있었는데 항상 비어 있었음
- **원인**: `student_session_screen.dart`의 질문 카드 로직이 `state.ideas`(학생 의견 컬렉션)에서 `idea.speaker == '교사'`인 항목을 찾도록 되어 있었다. 그런데 교사 발문은 `ideas`가 아니라 완전히 다른 컬렉션인 `teacher_notes`에 저장되고(`addTeacherNote()`), `ideas.speaker`는 학생이 의견을 낼 때 **항상 `'학생'`으로 하드코딩**된다(`_submitIdea()`). `'교사'`를 넣는 코드는 애초에 어디에도 없어 이 조건은 영원히 거짓이었다 — 처음부터 한 번도 작동한 적 없는 죽은 코드
- **영향**: 학생이 교사의 발문/지시를 화면으로 확인할 방법이 없었음(마이크로 듣는 것 외엔). 기능은 다 만들어져 있었는데 배선만 잘못됨
- **등급**: P2 (기능 완전 미작동, 그러나 우회 수단 있음 — 음성으로는 전달됨)
- **파일**: `lib/screens/student/student_session_screen.dart`(`_teacherNote` 필드·`_listenTeacherNote()`), `lib/repositories/moamal_repository.dart`·`firebase_moamal_repository.dart`(`listenToLatestTeacherNote()`)
- **수정 (2026-08-28)**: `teacher_notes` 컬렉션에서 `createdAt` 내림차순 최신 1건을 실시간 구독하는 `listenToLatestTeacherNote(sessionCode)`를 레포지터리에 신설. `student_session_screen.dart`에 `_teacherNoteSub`/`_teacherNote`를 추가해 다른 실시간 구독(`_myVoteSub`, `_forceStartSub` 등)과 같은 패턴으로 `initState()`에서 구독·`dispose()`에서 해제. `state.ideas` 스캔하던 죽은 코드 제거, `_compactLayout`/`_mediumLayout`에 `Idea?` 대신 `String?`으로 넘기도록 시그니처 변경. 규칙 변경 불필요(`teacher_notes`는 이미 `allow read: if signedIn();`이라 학생도 읽을 수 있었음 — 안 읽고 있었을 뿐)
- **검증**: `flutter analyze` 0 · `flutter test` 23/23. 새 빌드로 재현 — 교사(공기계) "회의 시작하자." 발문 → 학생(에뮬) 화면에 "선생님이 물었어요 / 회의 시작하자." 카드 즉시 표시 확인
- **상태**: ✅ 해결됨 · 실기기 검증 완료

### [Common-Beam-01] ← 사용자 직접 QA 중 발견 (2026-08-28)
- **현상**: 투표를 진행하고 "투표 닫고 결과 확정"까지 마친 뒤, 교사가 정리 화면에서 승인된 그룹을 **전부 취소**하면 빔프로젝터 화면이 QR 화면으로 돌아가지 않고 **"투표 결과 · N명 참여" 헤더만 남고 그 아래가 완전히 텅 빈 화면**이 된다. 학생들이 보는 큰 화면이 아무 설명 없이 비어버리는 것
- **재현 경로**: ① 의견 제출 → AI 그룹화 → 승인 → 투표 열기 ② 학생이 투표 ③ 투표 닫고 결과 확정(`voteOpen=false`) ④ 정리 화면에서 승인된 그룹 3개를 전부 승인 취소(`deleteApprovedGroup`) ⑤ 빔프로젝터 화면 진입 → 빈 화면
- **원인**: `beam_projector_screen.dart`의 `_stageOf()`가 4단계(`joining`/`collecting`/`voting`/`results`)를 오직 `ideas.isEmpty`와 `voteOpen`과 `votes.isNotEmpty` 세 조건만으로 판단하고, **`approvedGroups`가 비어있는 경우를 전혀 고려하지 않는다.** `ideas`가 한 번이라도 생기면 `joining`(QR) 단계로는 다시 못 돌아가고, `voteOpen=false`이면서 `votes`가 남아있으면 무조건 `results` 단계로 간다. 이 상태에서 `approvedGroups`가 비어있으면 `_buildResultsPortrait/Landscape`의 `sorted` 리스트가 빈 배열이 되어 `for` 루프가 아무것도 렌더링하지 않는다 — 헤더만 남고 완전히 빈 화면이 되는 구조적 공백
- **영향**: 실제 수업에서 투표 결과 확정 후 교사가 그룹을 재검토하다 전부 취소하면(그룹명을 다시 짜려고 하거나 실수로), 빔프로젝터에 아무 안내 없이 빈 화면이 뜬다. 학생들 앞 큰 화면이라 파급력이 있음
- **등급**: P2 (드문 경로지만 재현 조건이 명확하고, 안내 문구 없이 완전히 빈 화면이라 첫인상 임팩트가 큼)
- **파일**: `lib/screens/teacher/beam_projector_screen.dart` `_stageOf()`(12-19행), `_buildResultsPortrait()`/`_buildResultsLandscape()`
- **수정 (2026-08-28)**: `_stageOf()`에서 `ideas.isEmpty` 체크 바로 다음, `voteOpen`/`votes` 판정보다 먼저 `approvedGroups.isEmpty` 체크를 추가 — 승인된 그룹이 하나도 없으면 `voteOpen`·`votes` 값과 무관하게 무조건 `collecting`(의견 수집 단계)으로 되돌린다. 기존 정상 흐름(그룹이 있는 상태에서의 투표 중/결과 확정)에는 영향 없음
- **검증**: `flutter analyze` 0 · `flutter test` 23/23. 실기기(R59MA03BRCN) 재현 조건 그대로(승인 0개·투표기록 1건·voteOpen=false) 새 빌드 설치 후 재확인 — 빈 화면 대신 "선생님 질문 / 회의 / 1명 제출 · 1명"으로 정상 폴백
- **상태**: ✅ 해결됨 · 실기기 검증 완료

### [Common-Vote-Round-01] ← 사용자 직접 QA 중 발견, 코드 분석으로 확정 (2026-08-28)
- **현상**: 학생이 한 번이라도 투표하면, 그 학생은 **세션이 끝날 때까지 투표/결과 화면에 갇힌다.** 교사가 새 질문을 던지고 싶어도 학생 화면이 말하기(발화) 화면으로 돌아갈 방법이 UI에 없다
- **근거(코드)**: `student_session_screen.dart`의 `showVote` 판정식 —
  ```dart
  final showVote =
      state.voteOpen && state.approvedGroups.isNotEmpty ||
      (!state.voteOpen && _myVote != null && state.approvedGroups.isNotEmpty);
  ```
  `_myVote != null`(한 번이라도 투표함)이고 `approvedGroups`가 하나라도 남아있으면 `voteOpen` 값과 무관하게 영원히 `true`. 이 조건을 거짓으로 되돌리는 유일한 경로는 **교사가 승인된 그룹을 전부 취소하는 것**뿐인데, 그 액션은 `Common-Beam-01`(빔프로젝터 빈 화면)을 유발한다 — 학생을 풀어주려면 교사 화면이 깨지는 이율배반 구조
- **결정적 근거**: `moamal_repository.dart`/`firebase_moamal_repository.dart`에 `clearVotes(sessionCode)` 메서드가 이미 구현되어 있으나 **앱 전체에서 이 메서드를 호출하는 UI가 단 하나도 없다**(`grep` 확인). "다음 질문으로 라운드를 새로 시작하는" 기능을 준비하다 버튼 연결 없이 남겨진 죽은 코드로 보인다. `"라운드"/"다음 질문"/"재투표"` 관련 UI 문구도 코드 전체에 존재하지 않는다
- **결론**: 모아말은 현재 **"세션 1개 = 질문 1개"**로 설계되어 있다. 한 세션 안에서 두 번째 질문을 던지고 다시 의견을 모으는 흐름 자체가 지원되지 않는다. 여러 질문을 다루려면 세션을 새로 만드는 것 외에 방법이 없다
- **영향**: 실제 수업에서 교사가 "투표 끝났으니 이번엔 다른 주제로 다시 얘기해보자"를 시도하면 학생들이 전부 투표 화면에 멈춰 있어 진행이 막힌다. 다만 이게 **버그**인지 **의도된 MVP 범위 제한**인지는 전략기획 판단이 필요 — 파일럿 전 결정 필요
- **등급**: P1 (파일럿 수업이 다중 질문/라운드를 요구하면 진행 자체가 막힘) — 단, 단일 질문 세션만 상정한 설계라면 P3(기능 요청)로 재분류
- **파일**: `lib/screens/student/student_session_screen.dart`(`showVote` 판정식), `lib/repositories/*.dart`(`clearVotes()` 미사용)
- **결정 필요 사항**: ① 다중 라운드를 정말 지원할 것인가(그렇다면 "새 라운드 시작" 버튼 신설 — `clearVotes()` + `approvedGroups` 정리 + 학생 `_myVote` 리셋을 한 액션으로 묶어야 함, `Common-Beam-01`도 같이 고쳐야 함) ② 아니면 "세션당 질문 1개"를 공식 설계로 확정하고 리포트/온보딩에 명시할 것인가
- **상태**: 🟡 설계 공백 확인 완료 · 전략기획 결정 대기 ← G1 마무리 중 발견 (2026-08-25)
- **현상**: 학생이 `나가기`로 수업에서 나가도 **교사 화면의 `참여` 수가 줄지 않는다.** 학생 1명이 나간 뒤에도 계속 `참여 1`
- **원인**: **퇴장 처리가 아예 구현되어 있지 않다.** `_ExitDialog`에서 `나가기`를 눌러도 `Navigator.pop()`만 실행되고 Firestore에는 아무 쓰기도 하지 않는다.
  `firebase_moamal_repository.dart`에 `removeParticipant`/`leaveSession` 류의 메서드가 없다(`.delete()` 호출부는 `deleteApprovedGroup` 하나뿐)
- **파급**:
  - `참여` 수치가 **"현재 접속 중"이 아니라 "한 번이라도 들어온 학생"** 을 의미하게 되는데, 라벨은 그렇게 읽히지 않는다
  - **마이크 제어 화면에 나간 학생이 계속 `대기`로 남는다.** 교사가 없는 학생에게 마이크 제어를 시도할 수 있다
  - 교실에서 25명이 들락날락하면 교사가 "다 들어왔나"를 이 숫자로 판단할 수 없다
- **등급**: P2 — 다만 **단독으로 고칠 수 없다.** 아래 설계 결정이 선행되어야 한다
- **연결**: `Mercury-Report-05`(참여자 정의 미확정 — 발언한 학생 / 접속한 학생 / 투표한 학생 중 무엇인가)와 **같은 뿌리**다.
  리포트의 "참여 N명"과 LIVE 화면의 "참여"가 같은 정의를 써야 한다
- **선택지**:
  1. **나가기 시 participants 문서 삭제** — 단순하고 직관적. 단 리포트가 참여자를 과소 집계하게 되고, 백그라운드·앱 강제 종료는 감지 못해 반쪽이다
  2. **`leftAt`/`active` 필드 추가** — 누적과 현재를 모두 보존. `참여 12 · 접속 8`처럼 분리 표시 가능. 리포트와도 정합. 구현량은 더 큼
  3. **라벨만 정정** (`참여` → `입장`) — 누적임을 명확히 하고 기능은 유지. 가장 싸지만 마이크 제어 목록 문제는 남는다
- **결정** (2026-08-25, 대표): **선택지 2 — `leftAt` 필드 추가**로 확정. 누적 입장자와 현재 접속자를 모두 보존한다
- **구현 분담** (QA 방에서 구현하지 않음 — 스키마 변경이 QA 중 데이터 모양을 바꾸고, 표시 정책이 5개 화면에 걸리기 때문):

  | 방 | 작업 |
  |---|---|
  | **앱개발** | 모델·리포지터리·퇴장 호출 (아래 명세) |
  | **Flutter UI/UX** | `참여` 타일 표시 정책 — 접속 중 / 누적 / 병기 중 택일 |
  | **전략기획** | 리포트 "참여 N명" 정의 확정 (Mercury-Report-05와 동시 결정) |
  | **AI/백엔드** | **없음** — `firestore.rules:54`가 이미 본인 문서 `update`를 허용하므로 규칙 변경·재배포 불필요 |

- **앱개발 명세**:
  1. `models/participant.dart` — `DateTime? leftAt` 추가, `bool get isActive => leftAt == null`.
     `fromFirestore`에서 `(data['leftAt'] as Timestamp?)?.toDate()`, `toFirestore`에 `'leftAt': null` 포함
     (재입장 시 `merge: true` set으로 자동 해제되도록)
  2. `models/session_state.dart` — `List<Participant> get activeParticipants => participants.where((p) => p.isActive).toList()`
  3. `moamal_repository.dart` / `firebase_moamal_repository.dart` — `Future<void> markParticipantLeft(String sessionCode, String uid)`
     → `participants/{uid}`에 `{'leftAt': FieldValue.serverTimestamp()}` merge set
  4. `student_session_screen.dart` `_ExitDialog` 확인 후 — `Navigator.pop()` **전에** `markParticipantLeft` 호출
  5. 호출부 정리 — 현재 `participants.length`를 쓰는 곳은 의미에 따라 갈라야 한다:
     - **접속 중**: LIVE 통계 타일, `mic_control_screen`(나간 학생에게 마이크 제어를 시도하게 됨), `beam_projector_screen`, `organize_screen:1309`(투표율 분모 — 나간 학생은 투표할 수 없다)
     - **누적**: 리포트 참여자 수
- **한계 (명시해 둘 것)**: 명시적 `나가기`만 감지한다. 앱 강제 종료·백그라운드 장기 이탈은 잡히지 않는다.
  완전한 접속 상태가 필요하면 heartbeat(주기적 `lastSeenAt` 갱신)가 별도로 필요하며, 이는 Firestore 쓰기 비용이 늘어난다 — 파일럿 이후 판단
- **구현 완료** (2026-08-26, 앱개발 방) — 명세대로 1~5 전부:
  1. `Participant.leftAt` + `isActive`. `toFirestore()`에 `'leftAt': null`을 **명시적으로 포함** —
     재입장 시 `joinSession()`의 merge set만으로 퇴장 표시가 자동 해제된다
  2. `SessionState.activeParticipants` — `participants`는 누적, 이쪽이 접속 중
  3. `markParticipantLeft(sessionCode, uid)` — 문서를 **삭제하지 않고** `leftAt`만 merge set
  4. `_ExitDialog` 확인 후 `Navigator.pop()` **전에** 호출. 교사 종료로 이탈할 때도 같은 경로를 탄다
  5. 호출부 분리 — **접속 중**(`activeParticipants`): 교사 LIVE 통계 타일 2곳, `beam_projector_screen` 5곳,
     `mic_control_screen` 로스터 + 전체 음소거/해제 대상, `organize_screen:1309` 투표율 분모.
     **누적**(`participants`): 리포트 — 단 리포트의 참여자 수치는 아직 `votes`/`ideas` 기반이라
     `Mercury-Report-05` 결정 전까지 손대지 않았다
  - 퇴장 기록 실패는 예외를 삼킨다 — 학생의 이탈 자체를 막아선 안 된다
- **테스트**: `test/participant_left_test.dart` 6건 (`leftAt` 왕복·`leftAt: null` 계약·`activeParticipants` 분리)
- **보안 규칙**: 예상대로 **변경 없음**. `firestore.rules:54`의 본인 문서 update 권한으로 충분
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** — G1 재현 절차(학생 나가기 → 교사 `참여` 1 → 0)로 확인 필요

### [Gemini-1-Exit-02] ← 위 항목 확인 중 사진에서 발견 (2026-08-25)
- **현상**: 학생 나가기 확인 다이얼로그에서 **`계속 참여하기` 글자가 버튼 밖으로 삐져나와 두 줄로 깨진다** (`계속 참여하` / `기`)
- **원인**: 320dp 기준 계산 —
  `Dialog` 기본 `insetPadding` 40×2 → 240dp, 내부 `Padding` 22×2 → **196dp**.
  `나가기` 버튼이 `horizontal: 18`×2 + 글자 ≈ **81dp**를 고정으로 점유하고 간격 10dp를 빼면
  `계속 참여하기`에 **105dp**만 남는데, 15px w700 6글자는 들어가지 않는다
- **파일**: `lib/screens/student/student_session_screen.dart` — `_ExitDialog`
- **등급**: P3
- **비고**: `Mercury-Layout-01`의 세션 선택 다이얼로그와 **동일한 유형**이다 — 좁은 폭에서 고정 크기 버튼이 가로를 소진하는 경우. 그때 세운 대응(좁으면 세로 배치)을 그대로 적용했다
- **수정** (2026-08-25):
  - `insetPadding`에 `dialogInsetH(context)` 적용 — 360dp 미만에서 좌우 여백 40 → 16dp
  - `context.isNarrow`면 두 버튼을 **전체 폭 세로 배치**, 아니면 기존 가로 배치 유지
  - 버튼을 `_ExitAction` 위젯으로 분리해 두 배치가 같은 모양을 공유하고 `maxLines: 1`로 잘림을 즉시 드러나게 함
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증**

### [Gemini-1-Exit-03] ← G1 나가기 흐름 검토 중 발견 (2026-08-25)
- **현상**: **교사가 수업을 종료해도 학생 화면에는 아무 변화가 없다.** 종료 안내도, 자동 이탈도 없다. 학생은 수업이 끝난 줄 모른 채 계속 `말하기`를 누를 수 있고, 그 발언이 Firestore `ideas`에 계속 쌓인다
- **원인**: **세션에 종료 상태 개념이 없다.** `sessionEnded`/`isEnded`/`closedAt` 류의 필드가 모델·Firestore 어디에도 존재하지 않는다(`grep`으로 확인). 교사의 `종료`는 교사 화면을 리포트로 넘기고 `active_teacher_session`을 지울 뿐, 세션 문서에 아무것도 남기지 않는다
- **파급**:
  1. **학생에게 정상 종료 경로가 없다.** 학생이 수업에서 벗어나는 유일한 방법이 `나가기` 버튼이며, 따라서 이 버튼을 없애거나 마찰을 크게 높일 수 없다
  2. **리포트 데이터 오염** — 수업 종료 후 발언이 같은 세션에 섞인다
  3. `Gemini-1-Exit-01`(퇴장 미반영)과 겹쳐, 교사 화면 `참여` 수가 수업이 끝난 뒤에도 그대로 남는다
- **등급**: P2 — 실제 교실에서는 교사가 구두로 "끝"이라고 하므로 즉시 사고가 나지는 않으나, 기록의 신뢰도와 학생 UX 설계 전반이 여기에 묶여 있다
- **왜 지금 기록하나**: `나가기` 버튼의 목적지(이름 입력 화면 vs 랜딩)를 정하려다 발견했다.
  **이 항목이 해결되면 그 논쟁의 중요도가 크게 낮아진다** — 정상 종료가 생기면 `나가기`는 예외 경로가 되기 때문이다.
  따라서 **나가기 목적지는 이 항목 이후로 미룬다**(2026-08-25 대표 판단: 수업 중 실수 이탈이 수업 흐름을 끊는 위험이 상태 명확성보다 크다)
- **수정 방향** (앱개발 방):
  - 세션 문서에 `endedAt: Timestamp?` 추가, 교사 `종료` 시 기록
  - 학생 화면이 `endedAt`을 구독 → 종료 시 마이크 잠금 + "수업이 끝났어요" 안내 → 확인 시 랜딩으로 이동
  - `ideas` 보안 규칙에 종료 후 쓰기 차단을 넣을지는 백엔드 방과 별도 판단(클라이언트 차단만으로 충분할 수 있음)
- **연결**: `Gemini-1-Exit-01`(leftAt), `Mercury-Report-05`(참여자 정의), `Mercury-Session-03`(세션 경과 시간) — 모두 **세션 라이프사이클** 문제다. SHARED_CONTEXT §8 전략기획의 "세션 시작/종료 라이프사이클 재설계"와 동일 사안
- **구현 완료** (2026-08-26, 앱개발 방) — 네 건을 한 덩어리로 설계했고 **이 항목이 기준선**이다:
  - **스키마**: `sessions/{code}.endedAt: Timestamp?` (+ `createdAt`은 Mercury-Session-03). `null`이면 진행 중.
    `SessionState.endedAt` / `isEnded` 추가
  - **교사 쓰기 지점**: 뒤로가기 → 종료 확인 다이얼로그 → `_endSession()`.
    `endSession()`은 `endedAt`과 함께 `voteOpen: false`도 쓴다 — 종료된 수업에 투표가 열린 채로 남지 않게 한다.
    기록에 실패해도 교사는 화면을 벗어날 수 있어야 하므로 예외를 삼키고 로컬 복귀 상태(`active_teacher_session`)만 정리한다
  - **학생 반응**: 이미 구독 중인 세션 스트림에 `isEnded`가 실려오면 `_handleSessionEnded()` 실행 —
    ① VAD·녹음·되돌리기 타이머 중단 ② **확정 대기 중이던 초안 폐기**(종료 후 제출은 리포트를 오염시킨다)
    ③ `_sessionEnded` 플래그로 마이크 탭/롱프레스·`_submitIdea`·`_castVote`·`forceStart` 수신을 전부 잠금
    ④ `_markLeft()`로 퇴장 기록 ⑤ `_SessionEndedDialog` 안내 ⑥ 확인 시 `popUntil(isFirst)` → 랜딩
  - 다이얼로그는 `barrierDismissible: false`에 닫기 경로가 하나뿐이다 — 종료는 선택이 아니라 통보다
  - `_endedHandled` 플래그로 스트림이 여러 번 emit해도 안내는 1회만 뜬다
- **보안 규칙**: 변경 없음. 종료 후 `ideas` 쓰기 차단은 **클라이언트 잠금만** 적용했다.
  규칙으로 막으려면 `ideas` create에 세션 문서 `get()`이 필요해 읽기 비용이 의견 1건마다 발생한다 —
  악의적 우회가 아니라 실수 방지가 목적이므로 클라이언트로 충분하다고 판단. 필요 시 백엔드 방 별건
- **~~남은 설계 결정~~ → 완료 (2026-08-26)**: 하단 독 `종료` 버튼이 리포트 화면으로 이동만 하고
  세션을 끝내지 않아 라벨·동작이 어긋나 있던 문제. UI/UX 방이 결정하고 앱개발 방이 구현했다.
  - **UI/UX 방**: `teacher_dock.dart` — `종료`(kRed) → `수업기록`(중립색, 아이콘 `Icons.assignment_outlined`)으로 라벨 교체.
    `_DockSlot`의 `isEnd` 분기 제거 — "종료"라는 이름과 빨간색은 실제로 끝내는 동작 하나에만 쓰기로 확정
  - **앱개발 방**: `report_screen.dart`에 실제 종료 CTA 신설. 확정된 흐름은
    `수업 중 → [수업기록](이동만) → 리포트 작성·공유 → [수업 끝내기](신규) → 랜딩`.
    - `_EndSessionCta` — kRed 아웃라인, 기존 kYellow 저장/공유 CTA 아래 별도 줄(병합하지 않음)
    - `_EndSessionDialog` — `barrierDismissible: false`, "되돌릴 수 없다"를 명시. `_onWillPop()`과 같은 원칙
    - 확인 시 `ReportScreen.onEndSession`(=`TeacherHomeScreen._endSession`) 호출 → `endedAt`+`voteOpen:false` 기록 →
      `Navigator.popUntil((route) => route.isFirst)`로 랜딩까지 복귀.
      교사 홈의 `PopScope` 경로(뒤로가기 1번)와 달리 리포트는 랜딩에서 2단계 깊이라 `popUntil`을 썼다
    - `_isEnding` 로컬 상태로 버튼이 로딩 표시 + 중복 탭 방지. 실패해도 버튼을 되살려 재시도 가능
  - 학생 쪽은 이미 `endedAt`을 구독하고 있어 **추가 작업이 없었다** — 어느 경로로 `endedAt`이 찍히든 동일하게 반응한다
- **파일**: `lib/screens/teacher/report_screen.dart`, `lib/screens/teacher/teacher_home_screen.dart`, `lib/widgets/teacher_dock.dart`
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증** — 재현: 리포트 화면 → `수업 끝내기` → 확인 → 랜딩 복귀,
  학생 화면에 "수업이 끝났어요" 안내가 뜨는지 확인

### [Gemini-1-Exit-04] ← 위 검토 중 발견 (2026-08-25)
- **현상**: 나가기 다이얼로그의 안내와 실제 동작이 다르다.
  문구는 **"다시 코드를 넣어야 들어올 수 있어요"** 인데, 실제로는 `나가기` 후 이름 입력 화면(`StudentProfileScreen`)으로 돌아가며 **코드 재입력 없이 `들어가기`만 누르면 재입장된다**
- **원인**: `student_session_screen.dart` `onPopInvokedWithResult`가 `Navigator.of(context).pop()` 1회만 수행 → 직전 화면인 `StudentProfileScreen`으로 복귀. 그 화면은 `sessionCode`와 `sessionTitle`을 그대로 보유
- **등급**: P3
- **수정 방향**: 목적지 변경은 `Gemini-1-Exit-03` 이후로 미뤘으므로, **문구를 현재 동작에 맞춘다.**
  예: "다시 코드를 넣어야 들어올 수 있어요" → "나가면 선생님 화면에서 빠져요"
- **비고**: 반대로 문구에 맞춰 랜딩까지 보내는 안은 보류됐다. 수업 중 학생이 실수로 나갔을 때 코드를 다시 받느라 **수업 흐름이 끊기는 비용**이 상태 명확성의 이득보다 크다는 판단(2026-08-25). 학생측 세션 복귀 수단이 없다는 점도 근거 — 교사에게는 `active_teacher_session` 복귀가 있으나 학생에게는 대응 기능이 없다
- **2026-08-26 갱신**: `Gemini-1-Exit-03`이 해결되어 **정상 종료 경로가 생겼다.**
  이제 `나가기`는 예외 경로이므로 목적지 논쟁의 중요도가 낮아졌다(문서에 적어둔 예상대로).
  종료로 이탈할 때는 랜딩까지 되돌리고, `나가기`는 기존대로 이름 입력 화면에 남는다 — 의도적으로 다르게 두었다.
  남은 것은 **문구 정정 하나**이며 UI/UX 방 항목이다
- **수정** (2026-08-26, Flutter UI/UX): 문구를 "다시 코드를 넣어야 들어올 수 있어요" →
  "나가면 선생님 화면에서 빠져요"로 교체. 목적지는 그대로 `StudentProfileScreen`(이름 입력 화면)이며
  이번엔 문구만 실제 동작에 맞췄다
- **상태**: ✅ 해결 · **실기기 미검증**

### [Gemini-2-Summary-01] ← G2 첫 실기기 발언 테스트 중 발견 (2026-08-27)
- **현상**: 교사 홈 "요약" 탭의 **"AI 누적 요약" 카드가 항상 빈 흰 박스로만 보인다.** 참여·발언·AI 그룹 숫자는 정확히 올라가고(`1/1/1`), `정리`(organize_screen) 화면과 `브리핑` 탭에는 같은 데이터가 정상 표시되는데, 딱 이 카드만 테두리도 글자도 없이 통짜 배경색만 그려진다
- **재현**: 학생이 발언 1건 제출(5초 되돌리기 유예 후 확정) → 교사 화면 "요약" 탭 → 카드 자리가 비어 있음. 시간을 아무리 기다려도, 다른 화면을 갔다 와도 그대로
- **원인 — Flutter 프레임워크 제약**: `GroupCard`가 `BoxDecoration`에 **면마다 다른 색의 `Border`**(왼쪽만 `kYellow`, 나머지 3면 `kBorder`)와 **`borderRadius`를 동시에** 지정하고 있었다. Flutter는 "테두리 색이 균일하지 않으면 둥근 모서리를 그릴 수 없다"는 제약이 있어 `paint()` 단계에서 `A borderRadius can only be given on borders with uniform colors.` 예외를 던진다.
  **이 예외는 build 단계가 아니라 paint 단계에서 나기 때문에, Flutter의 기본 빨간 에러 화면(`ErrorWidget`)이 뜨지 않고 그 카드만 조용히 아무것도 안 그려진다** — `flutter analyze`·`flutter test`로도 잡히지 않고, 앱을 눈으로 보기 전엔 알 방법이 없다
- **진단 경로**: 정적 코드 분석(색상값 대조, 픽셀 샘플링으로 테두리·글자색 완전 부재 확인)으로는 원인을 좁히지 못해, 실행 중인 앱에 `flutter attach -d <device>`로 직접 붙어 Dart 콘솔의 실시간 예외 로그(`Another exception was thrown: A borderRadius can only be given on borders with uniform colors.`)를 확인해 확정했다
- **파일**: `lib/widgets/group_card.dart`
- **등급**: P1 — 크래시는 없지만, 이 카드가 **교사가 수업 중 가장 먼저·가장 자주 보는 AI 요약 화면**이라 사실상 핵심 기능 하나가 통째로 안 보이는 것과 같다
- **수정** (2026-08-27): 좌측 강조띠를 `Border`에서 분리해 `ClipRRect(borderRadius) > Container(border: Border.all(kBorder, 균일색)) > Stack([좌측 4px kYellow Positioned, 본문 Padding])` 구조로 변경. 둥근 모서리는 이제 균일한 `kBorder` 하나에만 걸리고, 노란 강조띠는 별도 위젯으로 그 위에 얹는다
- **검증**: 재빌드·재설치 후 실기기(에뮬레이터)에서 "급식 잔반 줄이기 · 1건 · 급식에서 먹을 만큼만 받으면 잔반이 줄어들 것 같아요." 카드가 테두리·강조띠·본문 모두 정상 표시되는 것을 스크린샷으로 확인
- **비고**: 같은 문제가 다른 곳에도 잠복해 있을 수 있다는 우려대로, **`lib/screens/teacher/report_screen.dart`의 `_QuoteCard`(리포트 인용문 카드)에서 동일 패턴을 하나 더 찾았다** — `border: Border(left: BorderSide(color: kGreen, width: 3))` + `borderRadius: BorderRadius.circular(10)` 조합. 같은 방식(ClipRRect+Stack)으로 함께 수정. `grep -rn "border: Border("` 전수 조사로 이 2건 외 나머지는 전부 단일 면(top만)이고 `borderRadius`가 없어 안전함을 확인했다. **QuoteCard 쪽은 이번 세션 리포트에 인용문이 생성되지 않아(의견 1건뿐) 실기기 시각 확인은 못 했다** — 코드 패턴이 GroupCard와 동일하고 `flutter analyze`·`flutter test` 통과만 확인. 다음에 의견이 여러 건 쌓인 세션의 리포트를 열 때 실제로 카드가 보이는지 확인할 것
- **상태**: ✅ 해결 · GroupCard 실기기 검증 완료, **QuoteCard는 시각 확인 대기**

### [Gemini-2-Mic-01] ← G2 실기기 2-2(PTT) 검증 중 발견 (2026-08-27)
- **현상**: 학생 마이크의 **길게 누르기(PTT)가 `말하기`(idle) 상태에서는 정상 동작하는데, 한 번 말한 뒤 `다시 말하기`(done) 상태에서는 길게 눌러도 아무 반응이 없다.** 같은 상태에서 짧게 탭하면(토글 모드) 정상적으로 녹음이 시작된다
- **재현**: 학생 화면에서 1) 최초 상태(`말하기`)에서 길게 누르기 → 정상 녹음·전사. 2) 제출 후 `다시 말하기` 상태에서 길게 누르기 → **무반응**. 3) 같은 `다시 말하기` 상태에서 짧게 탭 → 정상 녹음 시작
- **원인**: `_onLongPressStart()`가 `if (_micStatus != _MicStatus.idle) return;`로 **`idle` 상태만 허용**한다. 반면 `_onTap()`은 `_micStatus == _MicStatus.idle || _micStatus == _MicStatus.done` 둘 다 허용하고, `done`이면 `_lastTranscript`를 지우고 `idle`로 되돌린 뒤 녹음을 시작하는 별도 처리가 있다 — **이 done→idle 전환 로직이 tap 경로에만 있고 long-press 경로엔 없었다.**
  `_handleForceStart()`(Mercury-3-Student-03에서 이미 고친 동일 유형의 idle/done 병행 처리)와 비교하면 이번 것만 놓친 것이 드러난다
- **영향**: PTT는 **"누르는 동안만 말한다"는 명확한 사용성 때문에 저학년 학생에게 권장되는 방식**인데, 두 번째 발언부터 막히면 학생이 "고장났다"고 오인해 토글 모드로 전환하거나 교사에게 도움을 요청하게 된다 — 첫 발언만 되는 버그라 QA에서도 초기 상태만 확인하면 놓치기 쉽다
- **파일**: `lib/screens/student/student_session_screen.dart` — `_onLongPressStart()`
- **등급**: P2
- **수정** (2026-08-27): `_onLongPressStart()`가 `idle`뿐 아니라 `done`도 허용하도록 조건을 넓히고, `_onTap()`과 동일하게 `done`일 때 `_micStatus`를 `idle`로, `_lastTranscript`를 `null`로 되돌린 뒤 녹음을 시작하도록 맞췄다
- **상태**: ✅ 해결 · **실기기 검증 완료** (2026-08-27, "다시 말하기" 상태에서 길게 누르기 정상 동작 확인)

### [Gemini-2-VAD-01] ← G2 실기기 2-3(VAD 자동 종료) 검증 중 발견 (2026-08-27)
- **현상**: 토글 모드로 녹음 중 3초간 침묵해도 **자동 종료(VAD)가 걸리지 않는다.** Mercury 때 같은 물리 기기(SM-A305N)를 교사 역할로 썼을 땐 정상 동작했었다
- **원인**: 학생 화면의 침묵 임계값이 `-40dBFS`로, 교사 화면(`-34dBFS`)보다 **훨씬 엄격하다(더 조용해야 침묵으로 인식).** `db > threshold`일 때 "아직 말하는 중"으로 타이머를 리셋하는 로직이라, 임계값이 낮을수록(더 음수일수록) 일반적인 방 소음도 계속 "말하는 중"으로 오인해 3초 침묵이 절대 채워지지 않는다. 이 위험은 사실 체크리스트에 미리 적어뒀던 것이다(gemini_qa.html 2-3: "학생측 임계값은 -40dBFS로 교사측(-34)과 다르다. 실기기에서 안 걸리면 교사와 동일 튜닝 필요") — 예상이 그대로 들어맞았다
- **파일**: `lib/screens/student/student_session_screen.dart` — `_silenceThresholdDb`
- **등급**: P2 — 토글 모드에서 학생이 수동으로 다시 눌러 종료할 수 있어 진행은 막히지 않지만, "말 끝나면 자동으로 넘어간다"는 설계 의도가 무력화된다
- **수정** (2026-08-27): `_silenceThresholdDb`를 `-40.0` → `-34.0`으로 변경, 교사 화면(Mercury에서 실기기 검증된 값)과 동일하게 맞췄다. 로직 자체는 두 화면이 완전히 동일해 임계값만 정렬하면 된다
- **상태**: ✅ 해결 · **실기기 검증 완료** (2026-08-27, 3초 침묵 후 자동 종료 정상 확인)

### [Gemini-4-Vote-01] ← G4 실기기 4-6(빔 프로젝터 실시간 반영) 재검증 중 발견 (2026-08-27)
- **현상**: 교사가 투표를 **닫았다가 다시 열어도**, 이미 한 번 투표한 학생은 화면엔 "투표가 열렸어요"가 뜨는데 **다른 그룹을 눌러도 반응이 없다.** 버튼엔 "투표 완료"라고만 뜬다
- **재현**: 학생 투표 → 교사 [투표 닫고 결과 확정] → 교사 [다시 열기] → 학생이 다른 그룹 탭 → 아무 일도 안 일어남
- **원인**: 학생 화면의 "내가 투표했는가"(`_myVote`)가 **서버 값과 전혀 동기화되지 않는 순수 로컬 변수**였다. `_castVote()` 성공 시 딱 한 번 세팅되고 이후 앱이 재시작되기 전까진 절대 안 바뀐다. 그 결과:
  - **같은 앱 세션 안에서는 투표를 한 번 하면 그 뒤로 절대 못 바꾼다** — `voteOpen`이 계속 켜져 있어도 마찬가지. (오전에 4-4에서 "재투표가 잘 된다"고 확인했던 건, 그 사이 여러 번 있었던 앱 재설치로 `_myVote`가 우연히 초기화돼 있었기 때문이었다 — 진짜 같은 세션 내 재투표가 확인된 게 아니었다)
  - **반대로 나갔다 재입장하면 `_myVote`가 초기화돼 다시 투표 가능해진다** — 이건 재투표를 막아야 할 때 오히려 열려있는 구멍이었다
  - 확인 버튼(`onTap`)도 `_myVote == null`일 때만 눌리게 되어 있어, 옵션을 다시 고를 수 있게 고쳐도 확인 버튼 자체가 막혀 있었다(수정 시 같이 발견)
- **파일**: `lib/screens/student/student_session_screen.dart`, `lib/repositories/moamal_repository.dart`, `lib/repositories/firebase_moamal_repository.dart`
- **등급**: P2 — 데이터가 잘못 집계되진 않지만(`votes/{participantId}` 단일 문서라 항상 안전), "재투표를 허용할지"의 기준이 뒤집혀 있었다
- **수정 방향 결정** (2026-08-27, 대표): "나갔다 재입장하면 투표가 초기화되어야 하는가"를 고민하다가, 기준을 **"투표함이 지금 열려있는가"** 하나로 통일하기로 결정. 열려있는 동안은 언제든 다시 고를 수 있고, 닫히면 그 순간부터 전원 잠긴다
- **수정**: `_myVote`를 로컬 변수 대신 학생 자신의 `votes/{내 uid}` 문서를 실시간 구독(`listenToMyVote` 신설)해 항상 서버와 동기화. 옵션 탭 조건을 `voteOpen && _myVote == null` → `voteOpen`만으로 완화, 확인 버튼의 `onTap`·라벨·강조 조건도 `_pendingVoteId` 유무 기준으로 일괄 정리. `votes/{uid}` 문서는 이미 본인 read 권한이 있어(`firestore.rules:50-51`) **규칙 변경·백엔드 작업 불필요**
- **검증**: `flutter analyze` 0건, `flutter test` 23/23 통과. 실기기: 재입장 시 서버에 저장된 이전 투표가 정확히 복원되는 것 확인 → 투표 닫았다 다시 연 상태에서 다른 그룹으로 재투표 → 이전 표(1→0)·새 표(0→1) 정상 전환, 참여·완료 인원수 그대로 유지(중복 집계 없음) 확인
- **비고**: "학생이 잔꾀를 부려 투표를 조작할 수 있는가"는 이 수정으로 오히려 개선됐다 — `votes/{uid}`가 참여자당 문서 하나뿐이라 몇 번을 바꿔도 항상 최종 선택 하나만 집계되고, 나갔다 재입장하는 뒷구멍도 서버 동기화로 막혔다
- **상태**: ✅ 해결 · 실기기 검증 완료

### [Gemini-6-Session-01] ← G6 6-5(강제 종료 → 재실행) 검증 중 확인 (2026-09-03)
- **현상**: 학생 앱을 강제 종료(`am force-stop`) 후 재실행하면 진행 중이던 세션 화면으로 돌아가지 못하고 **교사/학생 선택 랜딩 화면**으로 초기화된다. 6자리 코드와 이름을 처음부터 다시 입력해야 세션에 복귀할 수 있다
- **재현**: 학생이 세션 참여 중 → `adb shell am force-stop com.moamal.prototype` → 앱 재실행 → 랜딩 화면(교사/학생 선택) 표시, 세션 정보 없음
- **원인**: 교사 쪽은 `active_teacher_session`을 통해 마지막 세션으로 자동 복귀하는 로직이 `teacher_home_screen.dart`·`main.dart`에 있지만, **학생 쪽에는 대응하는 저장·복귀 로직이 전혀 없다.** 전체 `lib/` 검색에서 `active_teacher_session`/`active_student_session` 패턴이 교사 파일 2곳에만 존재
- **참고**: `Gemini-1-Exit-04`(2026-08-25)에서 이미 "학생측 세션 복귀 수단이 없다"는 점을 나가기 다이얼로그 문구 결정의 근거로 언급한 바 있음 — 이번 G6 테스트로 실제 강제종료 시나리오에서 그 부재를 직접 재현·확인
- **영향**: 실제 교실에서 학생 기기가 메모리 부족으로 백그라운드 앱이 강제 종료되거나, 학생이 실수로 최근 앱 목록에서 스와이프하거나, 기기를 재시작하는 경우 — 세션 코드를 다시 받아 처음부터 재입장해야 한다. Firebase 익명 인증 자체는 로컬에 유지되므로(같은 uid로 재입장 가능, `pm clear`가 아닌 한) 데이터 유실보다는 **번거로움과 수업 흐름 끊김**에 가깝다
- **등급**: P2~P3 후보 — 교사가 코드를 다시 보여주면 복구 가능하고 데이터 손상은 없으나, 저학년 학생 다수가 참여하는 실사용 환경에서는 빈도가 낮지 않을 수 있어 등급 확정은 전략기획 판단 필요
- **수정 방향(제안)**: 교사의 `active_teacher_session`과 동일한 패턴 — 로컬 저장소(SharedPreferences 등)에 `sessionCode`+참여 uid를 저장해두고, 앱 시작 시 해당 세션이 아직 `endedAt == null`이면 자동으로 재진입 화면을 건너뛰고 세션 화면으로 복귀
- **파일**: `lib/screens/student/student_session_screen.dart`, `lib/screens/student/*`(참여 진입 관련 화면), 참고용 `lib/screens/teacher/teacher_home_screen.dart`
- **상태**: 🟡 미해결 · 설계 결정 대기

### [Gemini-R-Supervisor-01] ← GR R-1·R-7 검증 중 발견 (2026-09-03)
- **현상**: 슈퍼바이저 PIN(`1218`) → **"기존 세션 재개"**로 다른 기기(다른 교사 계정)가 만든 세션 코드에 진입하면, 화면은 정상적인 교사 UI로 뜨지만 **교사 전용 쓰기 동작이 전부 조용히 실패한다.** 실기기 재현: 물리기기가 슈퍼바이저로 에뮬레이터가 만든 세션(NONCNN)에 "기존 세션 재개"로 진입 → 토글 모드로 발문 녹음 → 전사 텍스트는 화면에 뜨지만 곧이어 `[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.` 원시 예외 문구가 스낵바로 노출됨. PTT(꾹 눌러 말하기)는 초안 시트만 띄우고 즉시 저장을 안 해서 같은 문제를 겉으로는 감춘다(시트에서 저장을 눌렀다면 동일하게 실패했을 것)
- **원인**: `landing_screen.dart` `_showSupervisorPad()`가 PIN 통과 후 `auth.signInAnonymously()`로 **새 익명 UID**를 발급하고, "기존 세션 재개" 선택 시 그 코드로 `TeacherHomeScreen(existingCode: code)`에 그냥 진입시킨다 — **세션 소유권(`ownerUid`) 재할당·검증 로직이 전혀 없다.**
  `firestore.rules`의 `isOwner(sessionCode)`는 `sessions/{code}.ownerUid == request.auth.uid`만 확인하는데, 슈퍼바이저의 새 익명 UID는 원래 세션을 만든 교사(Google/Kakao/Naver 로그인 또는 다른 익명 세션)의 UID와 절대 같을 수 없다. 그 결과 `teacher_notes`·`approvedGroups`·`mergeLogs`·세션 문서 수정·참가자 강제제어 등 `isOwner` 게이트가 걸린 모든 쓰기가 막힌다. 읽기는 대부분 `signedIn()`만 요구해 정상 작동하므로, **화면은 완전히 정상으로 보이다가 액션을 취하는 순간에만 실패가 드러난다**
- **영향**: "기존 세션 재개"가 실질적으로 **"내가(같은 UID로) 이전에 슈퍼바이저로 만든 세션을 재개"할 때만** 동작한다. 다른 교사·다른 기기의 진행 중인 수업을 슈퍼바이저 권한으로 이어받거나 참관하는 용도로는 쓸 수 없다 — 코드만 알면 들어가지지만 아무것도 할 수 없다. 에러 메시지도 Firebase 원시 예외 문자열이라 사용자가 원인을 알 수 없다
- **참고**: README.md에 슈퍼바이저 모드 자체가 "출시 전 제거 또는 숨김 처리" 대상으로 이미 표시되어 있어(디버그/QA 우회용) 심각도는 제한적이나, QA 중 실기기로 실제 재현되었고 에러 메시지 품질도 나쁘므로 기록
- **파일**: `lib/screens/common/landing_screen.dart` (`_showSupervisorPad`, `_showSessionModeDialog`), `firestore.rules` (`isOwner`)
- **등급**: P2 — 슈퍼바이저 모드가 출시 전 제거/숨김 예정 기능이라 파일럿에 직접 영향 없음. 다만 QA·디버깅 중 "권한 문제인지 로직 버그인지" 혼동을 유발할 수 있어 기록
- **추가 확인** (2026-09-03, 형 요청으로 호기심 테스트): 슈퍼바이저 세션을 **두 기기에서 동시에** 같은 코드로 열어봄 — 공기계(슈퍼바이저 세션 A)와 에뮬(슈퍼바이저 세션 B, 서로 다른 익명 UID) 둘 다 같은 세션(NONCNN)에 진입. 결과:
  - **동시 접속 자체는 막혀 있지 않다.** 두 세션이 같은 데이터를 실시간으로 동일하게 구독(참여·발언·그룹 내용 완전 일치)
  - 에뮬 쪽에서 승인 취소를 시도하니 **동일한 `permission-denied`가 재현**되고, 이번엔 `organize_screen.dart`가 원시 예외를 그대로 노출하지 않고 **"승인 취소 실패: [에러]"로 접두어를 붙여 표시** — `student_session_screen.dart`(원시 예외만 표시, `Gemini-R-Supervisor-01` 최초 재현 지점)보다 에러 메시지 품질이 낫다. 화면마다 에러 표시 방식이 다르다는 뜻이므로 언젠가 통일하면 좋을 사소한 비일관성
  - **쓰기 실패는 로컬 상태·상대 기기 어디에도 영향을 주지 않는다.** 그룹 상태는 그대로 유지, 물리기기 화면도 전혀 변화 없음 — 소유권 없는 쪽은 사실상 "읽기 전용 관전자"로 안전하게 동작한다(데이터 오염·충돌 없음). 여러 교사 기기가 실수로 같은 세션에 동시 접속해도 위험하지 않다는 뜻이라 오히려 안심할 수 있는 특성
- **수정 방향(제안)**: ① "기존 세션 재개"를 정말 지원하려면 세션 문서에 `ownerUid` 대신/추가로 감독 가능한 UID 목록을 두거나, 슈퍼바이저 전용 별도 규칙 분기 필요 ② 아니면 문서화만 하고 슈퍼바이저 모드 자체를 출시 전 제거(기존 계획대로)하며 이 이슈도 함께 소멸
- **상태**: 🟡 확인됨 · 슈퍼바이저 모드 제거 시 자동 해소 예정

### [Gemini-9-Report-01] ← "리포트 기능" 방 구현분 코드 리뷰 중 발견 (2026-09-04)
- **현상**: 학생별 출석/발언 기록의 화면 표시와 PDF·CSV·공유 텍스트 간에 두 가지 사소한 불일치가 있다
  1. "참석 N명 · 접속 M명" 문구에서 접속 인원 라벨이 다르다 — 화면(`report_screen.dart:764`)은 **"현재 접속"**, PDF·`toPlainText()`(`meeting_report.dart:98`, `report_pdf_exporter.dart:63`)는 **"종료 시점 접속"**. 계산되는 값은 동일(`Participant.isActive` 기준)하지만 문구가 달라 교사가 화면과 PDF를 같이 보면 혼동할 수 있다
  2. 화면(`report_screen.dart:781`)엔 있는 "작성자 미상 발언 N건 (구버전 기록)" 안내가 `toPlainText()`·PDF·CSV 세 곳 전부에서 조용히 빠진다 — `authorUid`가 없는 구버전 발언은 이 세 출력물에서 아무 흔적 없이 그냥 사라진다
- **원인**: 학생별 기록 조인 로직(발언을 `authorUid`로 묶기, 참석자를 번호순 정렬, 투표 대상 그룹명 찾기)이 `_StudentRecordsPanel`(화면)·`MeetingReport.toPlainText()`·`report_pdf_exporter.dart`·`report_csv_exporter.dart` **네 곳에 독립적으로 중복 구현**되어 있다. `report_pdf_exporter.dart`의 문서 주석은 "`toPlainText()`와 같은 조인 규칙을 그대로 쓴다"고 적혀 있지만 실제로는 `toPlainText()`를 호출하지 않고 로직을 다시 작성한 것이라, 문구를 한쪽만 수정하면 바로 어긋난다
- **영향**: 기능은 넷 다 정상 동작(실기기 검증 완료, 2026-09-04). 데이터가 틀리거나 유실되는 건 아니고 표기·완전성만 약간 어긋나는 수준
- **등급**: P3 — 화면·PDF·CSV 각각은 정상이고 교사 업무에 지장 없음. 다만 report.md에 스스로 적어둔 "화면과 공유 텍스트가 일치해야 한다"는 설계 원칙과는 어긋남
- **수정 방향(제안)**: 조인 로직을 공용 헬퍼(예: `StudentRecord` 모델 + 빌더 함수)로 뽑아 네 소비처가 전부 그걸 호출하게 하면, 문구·완전성이 자동으로 맞춰지고 향후 드리프트도 막힌다. 급한 리팩터링은 아니며 다음에 이 영역을 다시 만질 때 같이 하면 됨
- **파일**: `lib/screens/teacher/report_screen.dart`, `lib/models/meeting_report.dart`, `lib/services/report_pdf_exporter.dart`, `lib/services/report_csv_exporter.dart`
- **상태**: 🟡 확인됨 · 우선순위 낮음, 리팩터링 시점은 보류

### [Gemini-9-Report-02] ← 대표가 실사용 중 발견 (2026-09-04)
- **현상**: 리포트 화면에서 "AI 요약 생성"으로 리포트를 만든 뒤 학생이 투표해도, **리포트 화면을 나가지 않고 그대로 보고 있으면 투표 결과가 반영되지 않는다.** "참여" 인원수도 마찬가지로 갱신되지 않는다
- **원인**: `TeacherHomeScreen._goToReport()`가 `Navigator.push()`할 때 `ReportScreen`에 그 순간의 `SessionState` **스냅샷**을 값으로 한 번만 넘겼다. `OrganizeScreen`·`BeamProjectorScreen`·`ClusterVoteScreen`은 이미 교사 홈의 `_sessionStream`(broadcast)을 받아 `StreamBuilder`/구독으로 실시간 갱신하는데, 리포트 화면만 이 패턴이 빠져 있었다. 리포트 화면이 애초에 "실시간으로 바뀌는 걸 보여줘야 할 것"이 거의 없었던 기존 설계라 안 드러나다가, 오늘 학생별 투표 표시(§8 리포트 기능)를 추가하면서 처음 노출됨
- **등급**: P2 — 리포트 화면을 나갔다 다시 들어가면(`_goToReport()` 재호출) 최신 값을 받아오므로 완전히 막히지는 않으나, 교사가 리포트를 띄운 채로 투표 진행 상황을 지켜보는 것이 이 기능의 실사용 시나리오라 체감 임팩트가 크다
- **수정 (2026-09-04)**:
  - `report_screen.dart`: `ReportScreen`에 `sessionStream`(`Stream<SessionState>`) 파라미터 추가, `_ReportScreenState`가 `initState()`에서 구독해 `_session` 필드를 계속 갱신(`dispose()`에서 해제). `_exportPdf()`·`_exportCsv()`·`build()` 전부 `widget.session`(고정값) 대신 `_session`(최신값) 참조로 교체
  - `teacher_home_screen.dart`: `_goToReport()`가 기존 `_sessionStream`(재구독 없이 재사용 — `Mercury-3-Student-01` 교훈 그대로 적용)을 전달하도록 수정, 스트림 준비 전 진입 방지 가드 추가(다른 `_goTo*`와 동일 패턴)
  - `flutter analyze` 신규 이슈 0(기존 10건 그대로) · `flutter test` 39/39 통과
- **상태**: ✅ **해결됨** — 실기기 검증 완료(2026-09-04). 에뮬레이터(교사)에서 리포트 화면을 띄운 채로 실기기(학생, SM A305N)가 투표 → **화면을 한 번도 벗어나지 않고** "9번 이상호 · 투표: 어린이대공원 소풍"이 실시간으로 반영되는 것을 직접 확인

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
- **2026-09-03 Gemini G6 실기기 검증** (공기계 R59MA03BRCN=학생, 에뮬레이터=교사, 세션 NONCNN):
  - **6-1** 학생 30초 백그라운드 → 복귀: 정상, 크래시·프리징 없음
  - **6-2** 학생 백그라운드 중 교사가 투표 시작 → 학생 복귀 시 즉시 반영
  - **6-3** 학생 비행기 모드 ON → OFF (`adb shell cmd connectivity airplane-mode`): OFF 중 Firestore WatchStream이 `ENETUNREACH`로 끊기는 것 확인, 재연결 후 교사의 "투표 닫기"가 학생 화면에 실시간 반영되는 것까지 확인해 재연결이 실제로 동작함을 검증
  - **6-6** 교사 15초 백그라운드 → 복귀: LIVE 타이머·통계 정상 유지
  - `WidgetsBindingObserver` 재구독이든 Firebase SDK 자체 재연결이든, **결과적으로 재연결은 정상 동작**한다
- **상태**: ✅ **재현 안 됨 · 정상 동작 확인** (2026-09-03, adb 기반 lifecycle/network 시나리오 4종)

### [Common-Rules-01] ← 백엔드 규칙 점검 중 발견 (2026-08-26)
- **현상**: `ideas` 하위 컬렉션의 `create`, `update`가 `signedIn()`만 요구 → **다른 학생은 물론 그 세션에 참여하지도 않은 익명 사용자가 남의 의견 텍스트를 덮어쓸 수 있음**. 임의 세션 코드에 의견을 주입하는 것도 가능
- **원인**: 규칙만의 문제가 아니라 스키마 문제. `ideas` 문서에 작성자 식별 필드가 없어(`speaker`는 `'학생'` 하드코딩 문자열) 규칙에서 "본인"을 판별할 방법이 없었음
- **등급**: **P1** — Gemini QA S-7에서 실검증 예정. 수정 가능으로 나오면 Apollo 진입 차단 조건
- **수정 (2026-08-26)**:
  - `firebase_moamal_repository.dart` `submitIdea()` — 문서에 `authorUid`(현재 로그인 UID) 기록. 의견 쓰기 경로가 이 메서드 하나뿐이라 레포지터리에서 채움
  - `firestore.rules` `ideas` — `create`는 `request.resource.data.authorUid == request.auth.uid`, `update`는 교사 또는 작성자 본인만 + `authorUid` 변경 금지
  - `authorUid`가 없는 구 문서(기존 8건)는 교사만 수정 가능
- **상태**: ✅ **해결됨** — 2026-08-27 배포 완료. 2026-08-28 두 단계로 실기기·규칙 양쪽 검증: ① 학생 실기기(R59MA03BRCN)에서 의견 1건 실제 제출 → 교사 정리 화면 정상 도착·AI 자동분류까지 확인(로그캣 `PERMISSION_DENIED` 없음), ② Firestore 에뮬레이터 테스트(S-7)로 타인 `idea` 수정 시도·`authorUid` 변조 시도 둘 다 거부 확인. Apollo 진입 차단 조건 충족
- **배포 시점 확정 (2026-08-26)**: 앱개발 방 미구현 3건이 끝난 빌드를 두 기기에 설치한 직후, **Gemini S 섹션 직전**에 배포한다. G0~G4는 현재 빌드로 진행해도 무방하다(이 규칙은 해당 경로에 영향이 없다). 배포 이후로는 구 빌드로 QA를 이어가면 안 된다 — 되돌아갈 수 없는 지점이다. 상세는 현황판 §15

### [Common-Rules-02] ← 백엔드 규칙 점검 중 발견 (2026-08-26)
- **현상**: 교사가 투표를 닫은(`voteOpen=false`) 뒤에도 학생 클라이언트가 자기 `votes/{uid}` 문서를 계속 쓰거나 바꿀 수 있음. 규칙에 투표 개폐 조건이 없음
- **재현 경로(악의 없는 경우)**: 학생 기기가 오프라인일 때 투표 → 큐에 쌓인 쓰기가 투표 종료 후 서버에 도달 → 확정된 결과 수치가 뒤늦게 바뀜
- **영향**: 교사가 "결과 확정"을 선언한 뒤에도 득표가 변할 수 있음. 빔프로젝터 화면은 실시간 구독이라 학생들 눈앞에서 숫자가 바뀜
- **등급**: P1 (Gemini QA S-8 점검 항목)
- **수정 방향**: `votes` 규칙에 세션 문서 조회를 추가해 `voteOpen == true`일 때만 쓰기 허용. 투표 1건당 규칙 내부 읽기 1회가 추가됨(학급 25명 기준 25 read)
- **상태**: 🔴 미해결 — **보류 판단 유지 (2026-08-26 재확인)**. 투표는 Gemini 단일 마일스톤(G4-3)이 지나는 경로라, QA 도중 새 거부 조건을 얹으면 실패 원인이 규칙인지 앱인지 분간이 어려워진다. Gemini 종료 후 `endedAt` 차단과 **한 번의 `get()`으로 묶어** 적용한다(세션 문서 1회 조회로 `voteOpen`·`endedAt`을 함께 판정). S-8에서는 "닫힌 뒤에도 본인 표가 써진다"를 **재현 여부만 기록**하고 실패로 세지 않는다. **2026-08-28**: Firestore 에뮬레이터 + `@firebase/rules-unit-testing`으로 실제 `firestore.rules`를 로드해 S-1~S-10 전체 재현 테스트 진행 중 이 결함도 그대로 재현됨(`voteOpen=false` 이후 본인 vote 쓰기 성공) — 예상대로이며 Gemini QA는 정상 종료, 수정은 여전히 Gemini 이후로 보류

### [Common-Rules-03] ← 백엔드 규칙 점검 중 발견 (2026-08-26)
- **현상**: `match /sessions/{sessionCode} { allow read: if signedIn(); }`은 get과 **list를 모두 허용**. 익명 사용자가 `sessions` 컬렉션을 통째로 조회해 **모든 교사의 세션 코드·제목·ownerUid를 열람**할 수 있음
- **영향**: Common-Rules-01과 합쳐지면 임의 수업에 의견 주입이 가능했음. Rules-01 수정 후에도 세션 코드 유출 경로는 남음
- **등급**: P1 (파일럿 전 필수, QA 차단 아님)
- **수정 (2026-08-26)**: `firestore.rules` `sessions` — `allow read` → `allow get: if signedIn(); allow list: if false;`. 앱 전체에서 `sessions` 컬렉션 쿼리는 없고 `collection('sessions').doc(code)` 단건 접근뿐임을 확인(`collectionGroup` 사용도 없음)
- **상태**: ✅ **해결됨** — 2026-08-27 Common-Rules-01과 함께 배포 완료. 2026-08-28 Firestore 에뮬레이터 테스트(S-10)로 `sessions` list 조회 거부·단건 `get` 정상 동작 둘 다 확인

### [Common-Rules-04] ← 백엔드 규칙 점검 중 발견 (2026-08-26)
- **현상**: 학생은 `votes` 컬렉션 목록 조회 권한이 없는데(본인 문서만), 학생 화면은 `state.votes`로 득표를 계산 → **투표 종료 후 학생 화면 결과 막대가 항상 0**
- **원인**: 규칙 버그가 아니라 **계약 미정의**. `firebase_moamal_repository.dart`가 권한 오류를 빈 값으로 삼켜 오류 표시도 없음
- **등급**: P2
- **선택지**: ① 교사 앱이 투표 종료 시 `sessions/{code}.voteTally`에 집계를 기록(비밀투표 유지, [Flutter 앱개발] 작업) ② `votes` list 개방(학생이 서로의 투표를 열람 — 비권장) ③ 학생 화면에서 결과 표시를 없애고 빔프로젝터로만 공개([UI/UX] 작업)
- **대표 결정 (2026-08-26)**: **③ 확정** — 학생 화면에서 득표 표시를 없애고, 결과는 **빔프로젝터 화면으로만 공개**한다. 근거는 ⓐ 새 필드·새 쓰기 경로가 없어 MVP에서 변경이 가장 적고, ⓑ 결과 공개 시점을 교사가 통제하는 편이 수업 진행과 맞으며, ⓒ ①은 교사 앱 쓰기가 하나 늘고 집계 시점과 실제 표가 어긋날 여지가 생기기 때문. 파일럿에서 "개인 화면에서도 결과를 보고 싶다"는 요구가 실제로 나오면 그때 ①로 승격한다(`voteTally` 스키마는 현황판 §15에 보존)
- **후속 작업**:
  - [UI/UX] 학생 투표 화면에서 득표 막대·비율 표시 제거, 투표 후 상태를 "투표 완료 · 결과는 앞 화면에서 확인해요"로 대체 (`student_session_screen.dart` `_voteView()`)
  - [Flutter 앱개발] 학생 화면이 `state.votes`에 의존하지 않게 되므로, 학생 경로에서 득표 집계 계산을 걷어낸다. `votes` 구독 자체는 교사 화면이 그대로 쓰므로 레포지터리는 손대지 않는다
  - **백엔드 후속 없음** — 보안 규칙 변경도, 새 스키마도 필요 없다. 학생이 `votes`를 못 읽는 현재 규칙이 그대로 정답이 된다(비밀투표 유지)
- **구현** (2026-08-26, Flutter UI/UX): `student_session_screen.dart` `_voteView()` —
  카드별 `LinearProgressIndicator`(항상 0표 표시)를 완전히 제거. 투표가 닫히면 하단 바를
  "투표 완료 · 결과는 앞 화면에서 확인해요"(투표했을 때) / "투표가 마감됐어요 · 결과는 앞 화면에서 확인해요"
  (안 골랐을 때)로 대체 — 기존엔 `voteOpen=false`가 되는 순간 하단 바 자체가 사라져 학생에게
  아무 안내도 남지 않았다. `state.votes` 기반 집계 코드(`counts`/`maxVotes`)도 함께 제거 —
  학생 권한으로는 항상 빈 값이라 죽은 계산이었다. `[Flutter 앱개발]` 협조 항목(학생 경로 득표 집계 로직 제거)은
  이번 변경으로 UI 쪽 소비처가 없어졌으므로 남은 작업이 없어 보이나, 레포지터리·모델 레벨 정리 여부는 그쪽 판단
- **상태**: ✅ 해결 · **실기기 검증 완료** (2026-08-27, Gemini G4 4-5 — 0표 막대 없이 "투표 완료 · 결과는 앞 화면에서 확인해요" 정상 표시)

### [Common-Auth-01] ← 백엔드 인증 점검 중 발견 (2026-08-26)
- **현상**: `AuthService.signInAnonymously()`가 `currentUser`가 있으면 **그 계정을 그대로 반환**. Mercury에서 교사 기기로 쓴 공기계를 학생 기기로 재사용하면 학생이 **교사 UID로 입장**
- **영향**: `participants/{교사uid}`·`votes/{교사uid}`가 학생 것처럼 생성되고, 규칙상 `isOwner()`가 참이라 **권한 오류가 전혀 나지 않음** → 잘못된 데이터가 조용히 쌓이고 Gemini QA S 섹션 결과 전체가 무효가 될 수 있음
- **등급**: **P1** (QA 유효성 기준으로는 P0 성격)
- **회피(코드 수정 없이)**: 학생 역할 기기의 앱 데이터 삭제 또는 로그아웃 후 QA 시작. 입장 직후 `participants` 문서 ID가 교사 UID가 아닌지 확인
- **수정 방향**: 학생 입장 경로에서 익명이 아닌 계정이면 `signOut()` 후 익명 로그인 ([Flutter 앱개발] 범위)
- **수정** (2026-08-27, Flutter 앱개발): `auth_service.dart` `signInAnonymously()` —
  기존 로그인이 `isAnonymous`면 그대로 재사용(같은 학생 재입장 시 참여 기록 유지),
  아니면 그 세션만 지우고 새 익명 세션을 발급하도록 변경. 호출부 3곳
  (`join_screen.dart`, `main.dart` 딥링크·교사 복귀 경로)은 수정하지 않았다 —
  교사 복귀 경로(`main.dart:111`)는 `currentUid == null`일 때만 이 함수를 부르므로
  바뀐 분기(`current != null`)를 애초에 타지 않는다
  - **로그아웃 범위는 의도적으로 좁혔다**: `FirebaseAuth.signOut()`만 호출하고
    구글/카카오/네이버 SDK까지 끊는 전체 `signOut()`은 쓰지 않았다. 학생 입장은
    수업 시작 직후 빠르게 통과해야 하는 구간이라 불필요한 외부 SDK 호출로
    지연·실패 위험을 더하지 않기 위함. 기기에 남은 외부 로그인 상태 자체는
    건드리지 않는다
  - **의도적으로 남겨둔 것**: 같은 기기를 여러 학생이 번갈아 쓰는 경우(교실 공용
    태블릿 로테이션)는 이 수정으로 해결되지 않는다. 첫 학생이 받은 익명 세션이
    `isAnonymous`이므로 두 번째 학생도 그대로 재사용한다 — 이건 "교사 신분 도용"과
    다른 문제이며, 별도 논의 필요(2026-08-26 대표 논의에서 인지, 오늘 범위 밖으로 보류)
  - 테스트: `FirebaseAuth` 목킹 의존성이 프로젝트에 없어(화면 위젯 테스트 인프라도
    없음, `Mercury-Report-06` 커밋과 동일 사유) 단위 테스트는 추가하지 않았다
- **파일**: `lib/services/auth_service.dart`
- **검증**: `flutter analyze` 오류 0(기존 경고 10건 그대로), `flutter test` 23건 전원 통과
- **상태**: ✅ 코드 수정 완료 · **실기기 미검증**. 재현: 기기에서 구글 로그인(교사) →
  로그아웃 없이 랜딩에서 학생 코드 입장 → `participants` 문서 ID가 새 익명 UID인지 확인
  (교사 UID가 아니어야 정상). **회피책(학생 기기 앱 데이터 삭제)은 검증 전까지 유지**

### [Common-Rules-05] ← 백엔드 방 대화 중 발견 (2026-09-14)
- **발견 경위**: 대표가 "교사 이메일로 아무렇게나 로그인해도 통과되냐"고 질문 → 로그인 화면(`sign_in_screen.dart`)에는 텍스트 입력창이 없어 그 경로는 성립하지 않음을 확인하는 과정에서, 교사 판별 자체가 **클라이언트에서만** 이뤄지고 있음을 발견
- **현상**: `AuthService.checkTeacherAccess()`(이메일 도메인·`whitelisted_teachers` 대조)는 Flutter 앱 코드에만 있고, **Firestore 보안 규칙은 이 판정을 전혀 참조하지 않는다.** `sessions` 생성 규칙은 `signedIn() && request.resource.data.ownerUid == request.auth.uid`만 요구 — 로그인만 되어 있으면 익명 계정(=학생용)도 임의 세션 문서를 만들고 그 세션의 `ownerUid`가 되어 교사 권한(승인·투표 개폐·`forceStart`/`forceStop`·`mergeLogs` 기록)을 전부 행사할 수 있다
- **영향 범위**: 앱 UI로만 쓰면 마주칠 일이 없다(그런 버튼 자체가 없음). Firestore SDK를 직접 호출할 수 있는 사용자(리버스 엔지니어링 또는 웹 클라이언트 직접 조작)에게만 해당
- **원인**: "교사 승인" 개념이 화이트리스트 대조 → UI 라우팅 분기로만 구현되어 있고, 이 대조 결과를 서버(Firestore 규칙)에 전달하는 경로가 없음. `whitelisted_teachers` 컬렉션은 클라이언트에서 읽기만 가능(`allow write: if false`)하지만, 규칙이 `sessions.create` 시점에 이 컬렉션을 조회하지 않음
- **등급**: P1 (파일럿 규모에서 실사용 악용 가능성은 낮으나, 여러 학교로 확장 시 필수 수정)
- **수정 방향(아직 미착수)**: `sessions` 생성 규칙에 `get(/databases/$(database)/documents/whitelisted_teachers/$(request.auth.token.email))` 또는 uid 기반 대조 조건 추가. 이메일 도메인 화이트리스트(`_allowedDomains`/`.es.kr` 등 정규식)는 클라이언트 상수라 규칙에서 재구현하거나 Custom Claims로 옮겨야 함 — 후자가 더 안전하지만 카카오/네이버 커스텀 토큰 발급(`kakaoVerify`/`naverVerify`)에도 claim 부여 로직 추가가 필요해 별도 설계 필요
- **파일**: `firestore.rules`(`sessions` match 블록), `lib/services/auth_service.dart` `checkTeacherAccess()`, `functions/index.js` `kakaoVerify`/`naverVerify`
- **상태**: 🔴 미해결 · **기록만, 대표 판단으로 지금은 착수하지 않음** (2026-09-14)

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


## Hackathon

### [Hackathon-Demo-Vote-01] 혼자 체험할 때 학생 투표를 진행할 수 없음
- **발견**: 2026-09-14 공개 데모 검토. 예시 학생 5명은 접속 클라이언트가 아니므로 교사가 투표를 열어도 0표 상태에서 체험 동선이 끊긴다.
- **등급**: P2 — 심사자 단독 체험의 완주 문제.
- **수정**: 교사 인증과 분리된 이름 있는 Firebase 앱의 익명 체험 학생을 연결하고, 본인 참가자·투표 문서를 일반 권한으로 기록. 투표 탭에 데모 전용 창 추가. 새 데모에 `isJudgeDemo: true` 표시.
- **검증**: 로컬 웹 + 실제 Firebase에서 후보 승인 → 투표 열기 → 체험 학생 한 표 → 교사 득표 → 수업기록 확인. 재진입 시 인원 6명·투표 1표 유지, 이후 교사 마감 권한 정상. 기존 테스트 46개 통과.
- **파일**: `lib/services/judge_demo_seeder.dart`, `lib/services/demo_student_client.dart`, `lib/screens/teacher/demo_vote_panel.dart`, `lib/screens/teacher/organize_screen.dart`.
- **상태**: 해결·2026-09-14 Hosting 배포. 공개 소개 페이지와 사용자 배포 확인 완료. 에이전트의 공개 URL 전체 투표 재실행은 미실시. 최초 연결 실패는 아래 별도 미해결 항목으로 유지.

### [Hackathon-Demo-Connect-01] 체험 학생 최초 연결 실패 1회
- **발견**: 2026-09-14 로컬 웹에서 데모 후보 승인·투표 시작 후 ‘학생으로 한 표 넣어보기’를 처음 눌렀을 때 연결 실패 안내.
- **원인**: 미확정. 당시 구체적인 예외를 확보하지 못했으며 일시적 네트워크 문제로 단정하지 않는다.
- **영향**: 심사자가 학생 투표 체험에 바로 진입하지 못할 수 있음.
- **등급**: P2 (잠정) — 재로드 후 성공. 재현 빈도에 따라 재평가.
- **후속 확인**: 진단 로그 추가 빌드에서 같은 세션 재연결 성공, 투표·기록 반영 정상, 창 재진입 정상. 실패 시 다시 연결 버튼 제공.
- **상태**: 미해결·추가 재현 필요. 새 브라우저 상태에서 첫 연결 및 느린 네트워크 조건을 확인할 것.
- **파일**: `lib/screens/teacher/demo_vote_panel.dart`, `lib/services/demo_student_client.dart`.

### [Hackathon-Demo-Result-01] 교사가 투표를 닫으면 득표 수치가 숨겨짐
- **발견**: 2026-09-14 데모 한 표 전송 후 교사 ‘투표 닫고 결과 확정’ 실행.
- **현상**: 투표 중 1표·100%였던 후보가 마감 후 ‘—’와 빈 막대로 바뀌고 상태는 투표 대기로 표시된다. 수업기록에는 선택이 정상 보존된다.
- **원인**: 기존 `_VoteTab`과 `_VoteStatRow`가 `voteOpen`일 때만 수치·막대를 표시한다.
- **등급**: P2 — 데이터 유실은 아니나 ‘결과 확정’ 직후 결과를 보기 어려움.
- **상태**: 미해결·UI 개선 검토. 이번 학생 체험 추가에서 일반 교사 투표 동작은 변경하지 않았다.
- **파일**: `lib/screens/teacher/organize_screen.dart`.
