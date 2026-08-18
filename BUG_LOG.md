# Moamal Bug Log

> 형식: `[단계-섹션번호-컴포넌트-순번]`  
> 단계: Mercury / Gemini / Apollo / Common

---

## 결함 등급 기준

| 등급 | 기준 | 예시 |
|------|------|------|
| **P0** | 이 오류가 있으면 다음 단계 진행 불가 | 앱 크래시, 로그인 불가, 세션 생성 불가, STT 요청 불가, 의견 저장 불가, approvedGroups 저장 불가, 학생 투표 불가, Firestore 권한 오류로 핵심 흐름 중단 |
| **P1** | 수업 진행 중 큰 문제 발생 가능 | STT 자주 실패, 502/500 반복, Gemini 그룹화 자주 실패, 학생 화면에 승인 그룹 미표시, 투표 결과 미반영, 세션 재진입 시 상태 복구 실패 |
| **P2** | 불편하지만 테스트·파일럿 진행 가능 | UI overflow, 카드 점프, 키보드에 입력창 가림, 로딩 안내 부족, 에러 메시지 어색함, 긴 텍스트 표시 문제 |
| **P3** | 기능 검증·파일럿에 직접 영향 없음 | 색상, 애니메이션, 문구 미세 조정, 아이콘, 디자인 디테일 |

---

## Mercury

### [Mercury-0-Auth-01]
- **현상**: 데스크톱 이전 후 Google 로그인 시 `ApiException: 10` (DEVELOPER_ERROR)
- **원인**: debug.keystore SHA-1이 PC마다 달라 Firebase 미등록 상태
- **해결**: Firebase 콘솔에서 새 SHA-1 등록 + `google-services.json` 재다운로드
- **등급**: P0 (로그인 자체 불가)
- **상태**: ✅ 해결

### [Mercury-0-STT-01]
- **현상**: STT 버튼 탭 시 `서버 오류 502`
- **원인**: `whisper_stt_client.dart`의 `_defaultEndpoint`가 Cloud Functions v1 URL로 하드코딩 — 실제 배포는 v2 (`*.a.run.app`)
- **해결**: `_defaultEndpoint`를 `https://transcribeaudio-xzj4mtcbda-du.a.run.app` 으로 수정
- **파일**: `lib/services/whisper_stt_client.dart:11`
- **등급**: P0 (STT 요청 자체 불가)
- **상태**: ✅ 해결

### [Mercury-2-STT-UI-01]
- **현상**: STT 실시간 음성 텍스트 박스 `BOTTOM OVERFLOWED BY 22 PIXELS` — 긴 문장 입력 시 하단 22px 잘림
- **재현**: 교사 화면에서 긴 문장 발화 시 발생 확인
- **추정 원인**: 실시간 음성 영역 컨테이너 고정 높이 또는 `maxLines` 제한
- **등급**: P2 (UI overflow, 파일럿 진행 가능)
- **상태**: 🔴 미해결

### [Mercury-2-STT-02]
- **현상**: PTT 모드에서 아무 말 없이 손 떼면 Whisper가 무음 오디오를 "수업 종료" 등 그럴싸한 한국어 문장으로 환각(hallucination) 생성 → 가짜 teacher_note가 Firestore에 저장됨
- **재현**: PTT 길게 누른 후 아무 말 없이 손 떼기 → `_SttBox`에 엉뚱한 텍스트 표시 + `teacher_notes` 저장 확인
- **원인**: Whisper는 무음/저음량 오디오에서 컨텍스트 프롬프트("초·중등 수업 현장") 기반으로 텍스트를 생성하는 known behavior. 전송 전 최소 녹음 길이 또는 음량 임계값 체크 없음
- **영향**: 교사가 실수로 짧게 눌렀다 떼면 잘못된 발문이 Gemini 그룹화 컨텍스트(`recentTeacherNotes`)에 포함됨
- **등급**: P2 (파일럿 진행 가능, 단 교사 주의 필요)
- **상태**: 🔴 미해결
- **수정 방향**: `_stopAndTranscribe` 호출 전 녹음 시간이 최소 1~2초 미만이면 전송 취소

### [Mercury-2-VAD-01]
- **현상**: Toggle 모드에서 VAD 침묵 자동 종료 미작동 — 3초 침묵 후에도 녹음이 계속됨. 침묵 구간의 숨소리가 Whisper에 의해 한국어 텍스트로 오인식됨
- **재현**: Toggle 탭으로 녹음 시작 후 말하지 않고 방치 → 자동 종료 없이 계속 녹음 → 수동 종료 시 숨소리 전사
- **원인**: `teacher_home_screen.dart`에 VAD(`amplitudeStream`) 구독 코드 없음. VAD는 `student_session_screen.dart`에만 구현됨
- **파일**: `lib/screens/teacher/teacher_home_screen.dart`
- **등급**: P2 (Toggle 모드 사용 시 교사가 수동으로 꼭 종료해야 함 — 파일럿은 PTT로 우회 가능)
- **상태**: 🔴 미해결

### [Mercury-1-Session-01]
- **현상**: 세션 코드에 O(알파벳)와 0(숫자)가 혼용 가능 — 육안으로 구분 어려움
- **재현**: 코드 `JO1F8Z` 등에서 O와 0 혼동 가능
- **등급**: P2 (파일럿 진행 가능, 학생이 코드 잘못 입력할 가능성)
- **수정 방향**: 세션 코드 생성 시 혼동 문자(O, 0, I, 1, l) 제외
- **상태**: 🔴 미해결

### [Mercury-Session-01]
- **현상**: 수업 시간 타이머가 ClusterVoteScreen·ReportScreen 진입 중에도 계속 흘러서 실제 수업 진행 시간보다 길게 표시됨
- **원인**: `_elapsedTimer`가 `TeacherHomeScreen`에서 계속 작동. 서브 화면 진입 시 일시정지 없음
- **등급**: P3 (수업 기록 정확도 영향, 파일럿 진행 가능)
- **상태**: 🔴 미해결

### [Mercury-Report-02]
- **현상**: 리포트 미생성 상태에서 "저장/공유" 버튼 활성 → "아직 리포트가 없습니다." 텍스트가 공유 시트에 노출됨
- **원인**: `ReportScreen` 공유 버튼이 `_meetingReport == null` 상태를 체크하지 않음
- **등급**: P2 (교사 혼란 유발, 파일럿 진행은 가능)
- **수정 방향**: `_meetingReport == null`일 때 공유 버튼 비활성화 또는 "AI 요약 먼저 생성하세요" 안내
- **담당**: Flutter UI/UX 대화방
- **상태**: 🔴 미해결

### [Mercury-Report-01]
- **현상**: 리포트 생성 실패 `AI 요청 실패 (400)` — `geminiProxy` invalid_model 에러
- **원인**: `ai_api_client.dart:11` `_defaultEndpoint`가 v1 URL(`cloudfunctions.net`) → 이전 배포 버전 호출됨. 이전 버전엔 `gemini-2.5-flash`가 allowedModels에 없음
- **파일**: `lib/services/ai_api_client.dart:11`
- **해결 방향**: Firebase 콘솔에서 geminiProxy 실제 v2 URL(`*.run.app`) 확인 후 교체 (STT와 동일한 패턴)
- **담당**: 백엔드 대화방
- **등급**: P1 (리포트 생성 및 Gemini 그룹화 전체 불가)
- **상태**: ✅ 해결 (geminiProxy URL 교체 완료) → 이후 AI 클라이언트 자체를 openaiProxy로 전환 (2026-08-14)

### [Mercury-Report-03]
- **현상**: 리포트 생성 실패 `AI 요청 실패 (502)` — openaiProxy 전환 후 발생
- **재현**: 수업 종료 → "AI 요약 다시 생성" 탭 → 502 에러 스낵바
- **원인**: `gpt-5.6-luna`는 `temperature` 파라미터를 기본값(1) 외 지원 안 함 — `temperature: 0.1~0.4` 값 전달 시 OpenAI가 HTTP 400 반환 → openaiProxy가 502로 래핑해 클라이언트에 전달
- **해결**: `ai_api_client.dart` 내 `temperature` 파라미터 전체 제거 (groupBody, briefingBody, reportBody 모두)
- **파일**: `lib/services/ai_api_client.dart`
- **등급**: P1 (리포트 생성 및 GPT 그룹화 전체 불가)
- **상태**: ✅ 해결 (2026-08-18)

### [Mercury-3-Group-01]
- **현상**: 의견 4개 추가 시 Gemini 그룹화 미작동 — 각 의견이 별도 그룹으로 표시됨. 그룹 제목이 "가장·김치찌개가" 등 텍스트 앞 단어 조각으로 나옴 (Jaccard 폴백 상태)
- **재현**: `ideas` 컬렉션에 4개 의견 추가 → 누적 요약 패널에 4개 각각 표시, Gemini 생성 제목 없음
- **원인 분석 (Logcat)**:
  - GPT 자체는 정상 작동 ("젊은 세대 떡볶이", "외국인 인기 불고기" 등 양질의 제목 반환)
  - `IdeaChunkBuffer`: 3개 도달 시 즉시 플러시(배치1), 이후 1개가 2.5초 후 플러시(배치2) — 두 배치가 거의 동시에 GPT 호출 시작됨
  - **Race condition**: 배치2가 시작될 때 배치1 GPT 응답이 아직 안 왔으므로 `_cachedGroups == null` → 배치2 snapshot이 빈 배열 → GPT가 기존 그룹 모르고 1개 그룹만 반환 → 배치1의 3개 그룹을 덮어씀
  - 빈 텍스트 의견이 GPT에 전달되어 "의견 없음" 그룹 생성
- **해결**:
  1. `_callGemini` → `_processQueue` 분리: GPT 호출을 순차 처리 (두 번째 배치는 첫 번째 완료 후 실행, snapshot에 이전 결과 반영)
  2. 빈 텍스트 의견은 GPT에 보내지 않고 즉시 processed 처리
  3. `prompt_config.dart` 시스템 프롬프트에 "기존 그룹 모두 포함 반환" 규칙 추가 (방어적 개선)
- **파일**: `lib/services/gemini_grouping_engine.dart`, `lib/services/prompt_config.dart`
- **등급**: P2 (그룹화가 핵심 기능이지만 폴백으로 표시는 됨)
- **상태**: ✅ 해결 (2026-08-18)

### [Mercury-3-UI-01]
- **현상**: 누적 요약 패널에 스크롤 없음 — 그룹 4개 이상 시 FAB 뒤로 잘려 마지막 항목 안 보임. BOTTOM OVERFLOWED BY 47 PIXELS
- **재현**: `ideas` 4개 추가 시 4번 그룹이 FAB(마이크 버튼)에 가려져 확인 불가
- **원인**: `_buildCompactBody()` 초록 컨테이너 bottom padding이 `viewPaddingOf.bottom + 76`으로 시스템 인셋을 이중 계산 → 패널 공간이 불필요하게 좁아짐
- **파일**: `lib/screens/teacher/teacher_home_screen.dart` — `_buildCompactBody()`
- **해결**: bottom padding을 `92` 고정값으로 변경 (FAB 64px + margin 16px + 여유 12px)
- **등급**: P2 (파일럿에서 의견 많을수록 심각)
- **상태**: ✅ 해결 (2026-08-15)

---

## Gemini

_(다중 기기 테스트 시작 후 기록)_

---

## Apollo

_(실제 수업 흐름 테스트 시작 후 기록)_

---

## Common

### [Common-Network-01]
- **현상**: 앱 백그라운드 전환 후 복귀 시 Firestore 리스너 재연결 미검증
- **최초 발견**: Mercury (알려진 위험 항목)
- **확인 필요**: `AppLifecycleListener` 또는 `WidgetsBindingObserver` 재구독 로직
- **등급**: P1 (세션 재진입 시 상태 복구 실패 가능)
- **상태**: 🟡 미재현 (Mercury 단계에서 테스트 필요)
