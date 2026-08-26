# MOAMAL_SHARED_CONTEXT

> Moamal 실행 대화방이 공유하는 단일 현황판이다. 계획과 실제 구현을 구분하며, 날짜와 코드 근거를 남긴다.

## 문서 정보

- 마지막 갱신일: 2026-08-25
- 갱신한 역할: Gemini QA (진입 전 학생측 P1 3건 선수정)
- 기준 Flutter 커밋: `7c12401` (fix: temperature 제거, 그룹화 프롬프트 개선, ClusterVoteScreen 동적 업데이트)

## 1. 경영 요약

- 현재 단계: 문제 제안 교사를 디자인 파트너로 전환하기 직전의 파일럿 준비 단계. 코드 연결과 실제 교실 가치 검증은 구분한다.
- 이번 달 최우선 목표: 최초 문제를 다시 확인하고, 한 교실 시나리오의 모의 테스트와 2~4주 파일럿을 완료한다.
- 가장 큰 병목: 실제 교실 종단 간 사용·반복 사용·지불 의향이 확인되지 않았고, 학생 웹 참여도 미완성이다.
- 대표가 결정해야 할 사항: 첫 디자인 파트너 합의, 파일럿 날짜, Blaze 결제 상한 및 계속/피벗/폐기 판정일
- 다음 외부 검증 일정: 아이디어 제공 교사 재인터뷰와 모의 수업 일정을 2026-07-24까지 확정

## 2. 제품 전략

- 핵심 고객: 초등 교사를 중심으로 한 교사
- 핵심 문제: 자유 의견을 실시간으로 모으고 유사 의견을 교사가 검토한 뒤 토론·투표·기록으로 연결하기 어려움
- 핵심 가치 제안: 의견 수집 → AI 유사 그룹화 → 교사 검토·승인 → 그룹 투표 → 기록
- 현재 차별점: 일반 투표보다 교사 승인 가능한 의견 구조화와 수업 기록에 초점
- 하지 않기로 한 것: 퀴즈를 핵심 흐름으로 두기, 학생 계정 강제, 웹 참여가 완성됐다고 표현하기, 클라이언트 비밀키 구조를 운영 배포로 간주하기

### 가치 가설 우선순위

1. 교사가 타이핑·수기 정리하지 않아도 학생 발언과 입력이 즉시 수집된다.
2. 유사 의견을 AI가 묶고 교사가 승인해 전원의 의견을 빠르게 투표 대상으로 만든다.
3. 수업 종료 후 결과가 기록으로 남아 교사의 사후 정리 시간을 줄인다.

- STT는 제거하지 않는다. 단독 상품 가치가 아니라 1번 가설을 가능하게 하는 핵심 입력 수단으로 파일럿에서 사용률과 실패율을 측정한다.
- 최초 범위는 학급회의 한 종류로 고정한다. 토론 평가, 심포지엄, 입장 전환 토론, 퀴즈는 후속 검증 전 개발 동결한다.

## 2-1. 고객·BM 검증

- 최초 문제 근거: 2026년 6월 말 현직 교사 1명이 빠른 음성 기록, 유사 발언 묶기, 발표자/안건 표시, 클릭 투표를 직접 제안함. 이는 문제 존재의 정성 증거 1건이다.
- 미확인: 실제 사용, 반복 사용, 타 교사 확장성, 지불 의향, 학교 구매 절차
- 디자인 파트너: 아이디어 제공 교사 1명을 첫 디자인 파트너로 제안하되, 공동창업자나 대표 고객으로 일반화하지 않는다.
- 초기 BM 원칙: 파일럿 무료. 파일럿 종료 인터뷰에서 개인 교사 월/연 결제와 학교 연간 결제를 각각 질문하되 가격을 먼저 제시하지 않는다.

## 3. 핵심 교실 시나리오

1. 교사가 세션을 만든다. — Flutter 구현 완료
2. 학생이 QR/코드로 참여한다. — Flutter 코드 참여 구현, QR 생성 UI 확인
3. 학생이 의견을 제출한다. — **Flutter STT 제출 구현 완료 + Android 실기기 검증 완료** (Cloud Functions whisper-1 프록시)
4. AI가 유사 의견을 그룹화한다. — Flutter 클라이언트 로컬 상태로 부분 구현
5. 교사가 결과를 수정·승인한다. — **구현 완료**: ClusterVoteScreen에 "그룹 승인" 버튼, `approveGroups()` → Firestore 배치 저장
6. 참여자가 그룹 단위로 투표한다. — **구현 완료**: 학생 화면이 `approvedGroups`를 구독해 `groupId`로 투표
7. 교사가 결과와 기록을 저장한다. — 리포트 생성/표시 부분 구현, 영속 저장은 확인되지 않음

## 4. 구현 현황

| 영역 | 구현 완료 | 부분 구현 | 계획/미구현 |
|---|---|---|---|
| Flutter 앱 | Firestore 세션/의견/투표/승인그룹/참가자 repository, 코드·QR 참여, 교사 승인 UI, 학생 그룹 투표, 반응형 레이아웃(compact/medium) | 교사/학생 화면, 수동 텍스트 입력 | 세션 참여 이후 종단 간 실기기 검증 |
| AI/백엔드 | **Cloud Functions 배포 완료**: transcribeAudio, geminiProxy, kakaoVerify, naverVerify. Secret Manager: OPENAI_API_KEY, GEMINI_API_KEY. Firestore 보안 규칙 배포 완료 | — | App Check, 예산 알림, 환경 분리 |
| 로그인 | Google Sign-In (교사), 익명 (학생), 슈퍼바이저 모드 | 카카오/네이버 Flutter SDK 연동 (Functions는 준비됨) | — |

## 5. 배포·운영 현황 (2026-07-25 기준)

- **Cloud Functions**: 5개 함수 배포 완료 (asia-northeast3)
  - `transcribeAudio`: STT 프록시, 분당 10회 rate limit. **모델: `gpt-transcribe`** (2026-08-14 `whisper-1`에서 교체 — 정확도 Highest, 비용 $0.0045/분). **v2 URL**: `https://transcribeaudio-xzj4mtcbda-du.a.run.app`
  - `geminiProxy`: Gemini AI 프록시, 분당 20회 rate limit. **v2 URL**: `https://geminiproxy-xzj4mtcbda-du.a.run.app`. allowedModels: `gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-2.0-flash-lite`
  - `openaiProxy`: OpenAI Chat Completions 프록시, 분당 20회 rate limit. **v2 URL**: `https://openaiproxy-xzj4mtcbda-du.a.run.app`. allowedModels: `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-5.6-sol`
  - `kakaoVerify`: 카카오 Custom Token 발급
  - `naverVerify`: 네이버 Custom Token 발급
- **Secret Manager**: OPENAI_API_KEY (version 3, All 권한으로 재발급 2026-08-07), GEMINI_API_KEY 등록 완료
- **Firestore 보안 규칙**: 배포 완료 (sessions, ideas, votes, approvedGroups, participants, teacher_notes, mergeLogs, openaiRateLimits, rate limit 컬렉션)
- **Firebase 요금제**: Blaze (종량제)
- **Flutter UI 반응형 리팩토링 (2026-07-22)**: compact(<600)/medium(≥600) 2단계, `lib/utils/responsive.dart` 단일 진입점
- **미완료**: 카카오/네이버 Flutter SDK 연동, App Check, 개발/운영 환경 분리, **웹 랜딩 페이지**(QR 딥링크가 `moamal://`라 앱 미설치 기기는 미대응 — Mercury-Share-01 잔여)

## 6. 주요 위험

| 위험 | 영향 | 상태 | 대응 |
|---|---|---|---|
| ~~Gemini/OpenAI 키가 클라이언트에 노출~~ | ~~높음~~ | **해결됨 2026-07-25** — Cloud Functions Secret Manager 프록시 배포 | 완료 |
| ~~Flutter 학생 투표가 `idea.id`에 저장됨~~ | ~~높음~~ | **해결됨 2026-07-17** | 완료 |
| ~~교사 승인 단계 없음~~ | ~~높음~~ | **해결됨 2026-07-17** | 완료 |
| 카카오/네이버 Flutter SDK 미연동 | 중간 | Functions 준비 완료, Flutter 앱 대화방 작업 필요 | Flutter 앱 대화방에서 SDK 연동 |
| ~~Node.js 20 지원 종료~~ | ~~중간~~ | **해결됨 2026-08-07** — Node.js 22 업그레이드 완료 | 완료 |
| 슈퍼바이저 모드 노출 | 중간 | 랜딩 로고 3탭 → PIN 1218 | 출시 전 제거 또는 숨김 처리 |
| 학생이 다른 의견을 수정 가능 | 높음 | `ideas`의 `create, update`가 모든 인증 사용자에게 허용 — **Gemini S-7에서 실검증, Apollo 진입 차단 조건** | 작성자 UID 검증 추가 필요 |

## 7. 현재 우선순위

1. 아이디어 제공 교사 재인터뷰
2. 성인 6~10명 최소 모의 수업: STT → 그룹 승인 → 투표 → 기록까지 테스트
3. 카카오/네이버 Flutter SDK 연동 (Flutter 앱 대화방)
4. 파일럿 필수 차단 요소만 수정
5. 2026-08-21 계속/피벗/폐기 판정

## 8. 대화방별 다음 행동

> 버그 상세는 `BUG_LOG_v2.md` 참조 (재설계 이후 기준). v1은 `BUG_LOG.md`.

- **STT**: ~~(P2) 교사 화면 VAD 미구현~~ → **해결 2026-08-21** (-34dBFS, 3초, Toggle 모드); VAD 임계값 교실 소음 튜닝(실제 수업 후 조정); iOS 실기기 STT 검증
- **Gemini QA (현재 단계)**: 2기기 구성 — **공기계 = 학생 / 에뮬레이터 = 교사** (1라운드). 2라운드에서 역할 스왑.
  진입 전 학생측 P1 3건 선수정 완료(2026-08-25, 커밋 `87569ce`) — 전부 **실기기 미검증**이라 G1~G3에서 우선 확인:
  Mercury-Share-01(QR 딥링크·스캐너·수신 경로) → G1, Mercury-3-Student-01(스트림 재구독) → G2, Mercury-3-Student-03(forceStart 잠금) → G3.
  진행 순서: **CORE**(G0 환경 · G1 학생 진입 · G2 발화→반영 · G3 마이크 제어 · G4 승인→실투표 · **S 보안 규칙**) → ROLE SWAP(G7) →
  STABILITY(G6, Common-Network-01) → EXTENDED(G5 다중 학생 · G8 폭 매트릭스) → REGRESSION(GR).
  **핵심 PASS는 공기계 1 + 에뮬 1의 1:1 양방향 E2E**이며, 단일 마일스톤은 **G4-3**(학생 실투표 → 교사 득표 바 실시간 갱신)이다.
  G5·G8은 확장 항목 — 장비·시간이 부족하면 `BLOCKED — 테스트 환경 부족`으로 남겨도 Gemini 실패로 간주하지 않는다.
  **S 섹션 신설** — Gemini가 익명 UID를 실제로 쓰는 첫 단계라 Firestore 보안 규칙을 여기서만 검증할 수 있다.
  `학생 A → 타인 idea/vote/participants 수정 불가`, `approvedGroups·sessions·teacher_notes 쓰기 불가`, `교사 권한 정상`을 확인하며
  결과는 **Apollo 진입 차단 조건**으로 취급한다 (§6 ‘학생이 다른 의견을 수정 가능’ 위험과 직결).
  **장비 제약**: PC에 물리 마이크가 없음(2026-08-25 확인) → 에뮬 STT 불가. 마이크는 항상 공기계에 있으므로 **1라운드=학생 STT, G7=교사 STT**로 나누어 둘 다 실기기 검증한다. 1라운드는 교사 발문(2-8) 불가, G7은 학생 의견 생성 불가(1라운드 세션 재사용으로 우회).
- **Flutter UI/UX (진행 중)**: ~~Mercury-3-Student-02 forceStop 배너~~ ✅ 코드 수정 2026-08-24(실기기 미검증 — Gemini G3); ~~Mercury-Layout-01 320dp 다이얼로그~~ ✅ 코드 수정 2026-08-24(실기기 미검증 — Gemini G8); 다음 예정 — `join_screen` 반응형 적용, Mercury-4-Organize-01(투표 중 승인 변경 피드백)·Organize-04(kGreen 배경 위 kGreen 스피너), 리포트 batch는 앱개발 방 Mercury-Report-06 수정 후
- **Flutter UI/UX**: (P2) `_SummaryPanel` 스크롤 추가 — 의견 4개 이상 시 FAB에 가려지는 오버플로우 수정 (`teacher_home_screen.dart`); (P2) `_SttBox` BOTTOM OVERFLOWED 22px 수정; (P2) 공유 버튼 `_meetingReport == null` 시 비활성화; (P2) 세션 코드 생성 시 혼동 문자(O, 0, I, 1, l) 제외; 카카오/네이버 로그인 버튼 UI (~~학생 입장 이름 입력 화면~~ — `StudentProfileScreen` 구현 완료)
- **AI 의견구조화**: 브리핑 UI 설계 및 프롬프트 개선 (UI 개편 완료 후 진행 예정); 그룹화 프롬프트 추가 설계 (실제 수업 테스트 후 반복 조정 필요)
- **AI/백엔드**: App Check 적용, 개발/운영 환경 분리
- **App 개발**: ~~`flutter analyze` 후 오류 수정~~ → 2026-08-25 실행, **오류 0건**(경고·info 11건: 미사용 선언 4, 스타일 7);
  Common-Network-01 백그라운드 복귀 Firestore 리스너 재검증 → Gemini G6;
  **미해결 P1** — Mercury-Report-06(리포트 화면 미갱신), Mercury-Session-02(재시작 시 병합·승인 결과 소실), Mercury-4-Organize-01(승인 취소 확인 다이얼로그).
  Gemini 중에는 우회 가능하나 Apollo 전 수정 필요.
  **잠재 재발 지점**: `organize_screen.dart:67`·`cluster_vote_screen.dart:152`의 `?? repo.listenToSession(...)` 폴백 —
  현재 호출부가 항상 `sessionStream`을 넘겨 미발현이나, 넘기지 않는 호출부가 생기면 Mercury-3-Student-01이 재발
- **전략기획**: 파일럿 교사 섭외 및 일정 확정; 세션 시작/종료 라이프사이클 재설계 (수업 시간 타이머 서브 화면 진입 시 동작 정의); **iOS 지원 범위 결정** — `ios/` 폴더는 있으나 개발 환경이 Windows라 빌드 불가, 아이폰·아이패드 실행 이력 전무. 맥 장비 확보 / 클라우드 빌드 도입 / 파일럿 안드로이드 한정 중 택일 필요 (2026-08-24 Section R QA 중 확인)
- **Flutter UI/UX (반응형)**: 반응형 미적용 — `join_screen`, `beam_projector_screen`, `mic_control_screen`, `pending_approval_screen`. **`facilitator_tab`·`student_tab`·`display_tab`(합 1,129줄)은 UI 재설계 후 어느 화면에서도 참조되지 않는 사재 코드**(2026-08-25 확인) — QA 순회 대상에서 제외, 삭제 여부는 앱개발 방 판단. `student_tab`에 있던 **교사 수동 의견 입력 UI도 함께 끊겼다** — 현재 의견 생성 경로는 STT 단일이다. 브레이크포인트가 600/900 두 개뿐이라 **좁은 폭(320dp) 하한 미대응** → Mercury-Layout-01 발생. 폭 매트릭스 테스트는 Gemini 단계에서 수행 (`MERCURY_TO_GEMINI_HANDOFF.md` 3-2절)

## 9. 최근 변경 기록

| 날짜 | 역할 | 변경 내용 |
|---|---|---|
| 2026-08-25 | Gemini QA 선수정 | **Gemini 진입 전 학생측 P1 3건 수정**(실기기 미검증). ① `student_session_screen.dart`: `listenToSession()`을 `build()`→`initState`로 이관, `_sessionStream` 필드 신설 — setState마다 Firestore 5개 구독이 끊겼다 재생성되던 문제(Mercury-3-Student-01). ② QR 딥링크(Mercury-Share-01): `deep_link_service.dart`에 `buildJoinUri()`/`parseScanned()` 추가, QR 생성 6곳을 `moamal://join/{code}`로 교체, **앱 내 스캐너의 `length==6` 판정도 함께 교체**(안 하면 기존 QR 참여가 깨짐). `main.dart` 수신 경로도 수정 — 이름 입력 화면 건너뛰던 것을 `StudentProfileScreen` 경유로, 세션 존재 확인 추가, `pushReplacement`→`push`, `codeStream()` 구독을 분기 앞으로 이동. ③ `_handleForceStart()`: 잠금 해제를 early-return 앞으로 이동 — 발언 완료(`done`) 학생은 교사가 [시작]을 눌러도 마이크가 영구 잠기던 문제(Mercury-3-Student-03, **P2→P1 상향**). `flutter analyze` 신규 오류 0건 |
| 2026-08-24 | Flutter UI/UX | **Mercury-3-Student-02 · Mercury-Layout-01 코드 수정**(실기기 미검증). `student_session_screen.dart`: forceStop 배너 kInk→kRed, 닫기(×) 추가, 중복 SnackBar 제거, `_forceStopBannerVisible`(배너)와 `_forceStopped`(마이크 잠금) 상태 분리 — 배너 닫기가 교사 강제중지를 무력화하지 않도록. `responsive.dart`: 좁은 폭 하한 신설(`AppBreakpoints.narrow=360`, `isNarrow`, `dialogInsetH()`). `landing_screen.dart`: PIN 패드 고정 60dp→LayoutBuilder 역산(44~60dp), 코드입력·제목 다이얼로그 `scrollable: true`, 세션 선택 다이얼로그 전체 폭 세로 버튼 전환. 신규 발견 Mercury-3-Student-03(P2, forceStart early-return으로 마이크 잠금 미해제 가능) |
| 2026-08-24 | Mercury QA v2 | **Mercury QA v2 종료.** Section 10(보고서)·R(회귀) 완료. Section 9(학생 흐름)는 2기기 필요로 Gemini 이관(`MERCURY_TO_GEMINI_HANDOFF.md` 신규 작성). 신규 P1 3건: Mercury-Share-01(QR에 딥링크 미인코딩 → 학생이 QR 스캔해도 앱 미실행), Mercury-Session-02(앱 재시작 시 교사 병합·승인 결과 전부 소실), Mercury-Report-06(리포트 생성 버튼 무반응 — `ReportScreen`이 StatelessWidget이라 부모 setState로 리빌드 안 됨). 그 외 P2 4건·P3 3건. 리포트 화면 설계 미확정 4건과 반응형·iOS 범위는 QA 밖 결정 사항으로 분리 |
| 2026-08-24 | Mercury QA v2 | Section 8(OrganizeScreen 나가기 & 상태 지속) 전체 통과 — ← 복귀, 복귀 후 broadcast stream 실시간 반영(발언 7→8), 이동/병합 결과 유지, 진입↔복귀 3회 반복 크래시·상태 오염 없음. 테스트 중 승인 그룹 1건("접근성 높은 불고기") 소실을 발견해 원인 규명 — 코드 자동 삭제 경로 없음(`deleteApprovedGroup`은 `_unapprove` 단일 호출), 그룹 id 불일치라면 고아 문서가 남아야 하나 Firestore엔 `group1` 하나뿐 → 실제 탭으로 확인. **Mercury-4-Organize-01 P2 → P1 상향**: 투표 중 무반응에 따른 재탭 습관이 투표 종료 후 실삭제로 이어지고 교사 수정 그룹명까지 함께 소실. 승인 취소 확인 다이얼로그 필요 |
| 2026-08-24 | Mercury QA v2 | Section 6 완료 (6-8 병합 카운트 실시간 갱신 ✅, 6-10 빈 이름 병합 시 소스 이름 유지 ✅). Section 7 전체 완료 (투표 탭 승인 0개 빈 상태, 투표 시작/닫기, 실시간 득표 바 kYellow 강조, 투표 중 승인 비활성 재확인). `gemini_grouping_engine.dart`: `_mergeSnapshot` 필드 추가, `mergeGroups()` 호출 전 스냅샷 저장, `undoMerge()` 추가 — 병합 직후 5초 SnackBar "되돌리기" 기능 구현. `organize_screen.dart` `_doMerge()`: `ScaffoldMessenger`로 되돌리기 SnackBar 표시. 병합 시트 안내 문구 "병합은 승인 전까지 되돌릴 수 있어요" → "병합 직후 되돌리기 가능"으로 수정 |
| 2026-08-24 | Mercury QA v2 | `report_screen.dart`: `meetingReport == null`일 때 공유 버튼 비활성화 — `onTap: null`, 배경 반투명, 텍스트 반투명 처리 (Mercury-Report-02 해결) |
| 2026-08-24 | AI/백엔드 | `mergeLogs` 하위 컬렉션 Firestore 보안 규칙 추가 (교사만 읽기/쓰기) → 배포 완료. 병합 이력 저장·되돌리기 Flutter 구현은 플러터 앱 대화방에서 진행 |
| 2026-08-22 | Mercury QA v2 | `grouping_engine.dart`: `ideas: []` → `<Idea>[]` + `List<Idea>.from()` — `moveIdea()` `List<dynamic>` 런타임 타입 에러 수정(P0, 그룹 전부 사라지는 증상). `gemini_grouping_engine.dart`: `moveIdea()`, `mergeGroups()` 동일 패턴 적용. `organize_screen.dart` `_MergeGroupSheet`: `ConstrainedBox(88%) + SingleChildScrollView` — BOTTOM OVERFLOWED 55px 수정. `_showRenameDialog()`: `ctrl.dispose()` 제거 — 다이얼로그 exit 애니메이션 중 `_dependents.isEmpty` assertion 크래시 수정(P0). `firebase_moamal_repository.dart` + `moamal_repository.dart`: `deleteApprovedGroup()` 추가. `_unapprove()`: `deleteApprovedGroup()` 직접 호출로 변경 — `approveGroups()`는 삭제 없이 set만 해서 승인 취소 미작동(P1) |
| 2026-08-21 | Mercury QA v2 | `teacher_home_screen.dart`: `_startVAD()/_stopVAD()` 구현, threshold -34dBFS, 3초 침묵 시 자동 `_stopAndTranscribe()` 호출 — Toggle 모드 VAD 미구현 수정(P2). `gemini_grouping_engine.dart` `onGroupUpdate` 콜백 + `_OrganizeScreenState.initState` 연결 — 그룹 이동/병합 후 UI 즉시 반영 |
| 2026-08-18 | AI 의견구조화 | `gpt-5.6-luna` temperature 미지원으로 파라미터 전체 제거 (502→400 에러 원인). `_stableGroupId()` clamp(2,1) 크래시 수정 → clamp(1,1). `ClusterVoteScreen` AI 그룹화 완료 시 동적 반영 (`onGroupUpdate` 콜백 + `cachedGroups` getter). 그룹화 시스템 프롬프트 개선 (수업 주제 맥락 활용, 재배치 허용, 기존 그룹 모두 반환). 디버그 print 3개 제거. BUG_LOG Mercury-Report-03 원인 수정 |
| 2026-08-15 | AI/백엔드 | `transcribeAudio` 무음 400 → 빈텍스트 정상처리, `openaiProxy` 에러 본문 detail 포함, 재배포 완료 |
| 2026-08-14 | STT | `transcribeAudio` STT 모델 `whisper-1` → `gpt-transcribe` 전환 (정확도 Average → Highest, 비용 $0.006 → $0.0045/분, 25% 절감). 동일 엔드포인트(`v1/audio/transcriptions`) 유지. 무음/짧은 녹음 시 OpenAI 400 응답 → 빈 텍스트 정상 처리. `whisper_stt_client.dart` 빈 전사 결과 throw 제거 → 빈 문자열 반환. 교사/학생/MicButton 호출부 빈 결과 무시 처리 추가 |
| 2026-08-13 | Flutter UI/UX | 슈퍼바이저 모드에 기존 세션 재개 기능 추가 — PIN 1218 후 "새 세션 시작" / "기존 세션 재개" 선택. 재개 시 코드 입력 → Firestore 기존 데이터 그대로 로드 (`landing_screen.dart`, `teacher_home_screen.dart`: `existingCode` 파라미터 추가) |
| 2026-08-13 | AI/백엔드 | `ai_api_client.dart` `_defaultEndpoint` v1 URL → v2 URL 교체 (`https://geminiproxy-xzj4mtcbda-du.a.run.app`) — 리포트 생성·Gemini 그룹화 400 에러 원인 해결 |
| 2026-08-14 | AI 의견구조화 | `ai_api_client.dart` Gemini → GPT-5.6 Luna 교체: 엔드포인트 openaiProxy, OpenAI Chat Completions 포맷 적용, `_stripMarkdown()` 제거, timeout 30초, 브리핑 max_tokens 512 (§14 갱신) |
| 2026-08-14 | AI/백엔드 | `openaiProxy` Cloud Function 추가 배포 (Chat Completions 프록시, 분당 20회, allowedModels: gpt-5.6-luna/terra/sol). `openaiRateLimits` Firestore 규칙 추가 |
| 2026-08-13 | AI/백엔드 | `gemini-2.5-flash` allowedGeminiModels 추가 후 Functions 재배포 완료 |
| 2026-08-13 | QA | Mercury QA 단계 완료 (단일 기기, 교사 세션). 핵심 흐름 통과. 발견 버그 8건 `BUG_LOG.md` 기록 — P1 2건(geminiProxy URL·Firestore 리스너), P2 5건(UI overflow·VAD·PTT 환각·세션코드·공유버튼), P3 1건(타이머) |
| 2026-08-12 | STT | 교사 STT 파이프라인 점검 완료: 전사 loss 없음, 학생 IdeaChunkBuffer·submitIdea()와 완전 분리 확인, addTeacherNote() 구현 정상 확인 |
| 2026-08-12 | STT | `teacher_home_screen.dart` `_SttBox` 학생 아이디어 fallback 제거 — 교사 발화 없을 때 마지막 학생 아이디어가 "실시간 음성" 박스에 표시되던 버그 수정 |
| 2026-08-11 | AI 의견구조화 | `GeminiApiClient` → `AiApiClient` 이름 변경 (`gemini_api_client.dart` → `ai_api_client.dart`), 프로바이더 교체 대비 |
| 2026-08-11 | AI 의견구조화 | Gemini 모델 `gemini-2.0-flash` → `gemini-2.5-flash` 업그레이드, `functions/index.js` allowedModels 추가 |
| 2026-08-11 | AI 의견구조화 | 교사 발문 컨텍스트 강화: `groupIdeas()` + `generateReport()`에 `teacherNotes` 파라미터 추가, 그룹화 프롬프트에 최근 지시 1개 포함, 리포트에 지시 타임라인 섹션 추가 (§14 참조) |
| 2026-08-11 | AI 의견구조화 | `getAllTeacherNotes()` 레포지터리 추가 — Firestore `teacher_notes` 전체 시간순 조회 |
| 2026-08-07 | AI/백엔드 | Firestore 보안 규칙에 `teacher_notes` 하위 컬렉션 추가 (읽기: 인증 사용자, 쓰기: 교사만) → 배포 완료 |
| 2026-08-07 | STT | iOS Info.plist에 `NSMicrophoneUsageDescription` 추가 — record 패키지 마이크 권한 필수 항목 (미추가 시 iOS에서 녹음 불가) |
| 2026-08-07 | STT | Android 실기기 STT 엔드투엔드 검증 완료. 전사 샘플: "다들 학급회의 시작할 건데 급식 문제에 대해서 의견 좀 말해보자." 정확 인식. OpenAI 크레딧 미충전이 429 원인이었음 → 충전 후 해결. 미해결: 실시간 음성 박스 BOTTOM OVERFLOWED 22px (Flutter UI/UX 대화방 이관) |
| 2026-08-07 | AI/백엔드 | Node.js 20 → 22 업그레이드 (`firebase.json`, `functions/package.json`) 및 재배포 완료 |
| 2026-08-07 | AI/백엔드 | Firestore 보안 규칙 수정: `participants` update에 `isOwner` 조건 추가 (교사가 `forceStop` 필드 쓰기 가능하도록) → 웹 콘솔 배포 완료 |
| 2026-08-07 | AI/백엔드 | `transcribeAudio` STT 모델 `gpt-4o-mini-transcribe` → `whisper-1` 교체 후 재배포 완료 (401 에러 해결 목적) |
| 2026-08-07 | STT | Android 실기기 502 에러 원인 분석: 구 OPENAI_API_KEY(Last used: Never, Restricted 권한) 발견 → All 권한 새 키 발급 → Secret Manager version 3 재등록 → Functions 재배포. 여전히 502 발생 → `gpt-4o-mini-transcribe` 모델 티어 미지원 의심, `whisper-1` 교체를 백엔드 대화방에 이관 |
| 2026-08-07 | STT | 교사 학생 마이크 원격 시작(forceStart) 기능 추가 (§11 5단계 확장) |
| 2026-07-30 | STT | 교사 마이크 Toggle+PTT 하이브리드 적용 (teacher_home_screen.dart) |
| 2026-07-30 | AI 의견구조화 | Gemini 타임아웃(10초) + 마크다운 래퍼 제거 (§13 참조) |
| 2026-07-30 | AI 의견구조화 | 그룹화 품질 개선 4건 (§13 참조) |
| 2026-07-30 | STT | 2계층 동적 Whisper prompt 구현 (아래 §12 참조) |
| 2026-07-30 | AI/백엔드 | transcribeAudio Functions에 req.query.prompt 처리 추가 및 재배포 완료 |
| 2026-07-29 | STT | Flutter STT MVP 6단계 구현 (아래 §11 참조) |
| 2026-07-25 | AI/백엔드 | Cloud Functions 4개 배포(transcribeAudio, geminiProxy, kakaoVerify, naverVerify), Firestore 보안 규칙 배포, Secret Manager 설정 완료 |
| 2026-07-22 | Flutter UI/UX | 전체 UI 반응형 리팩토링 (compact/medium 2단계, responsive.dart 신규) |
| 2026-07-20 | Flutter UI/UX | Flutter Android 실기기 1차 실행 성공: 랜딩 화면 정상 렌더링, 학생 참여 화면 전환 확인 |
| 2026-07-18 | AI/백엔드 | STT 서버 프록시 코드 구현, Blaze 업그레이드 결정 |
| 2026-07-17 | App 개발 | ApprovedGroup 모델, approveGroups(), ClusterVoteScreen 승인 버튼, 학생 그룹 투표 연결 |

## 11. STT Flutter MVP (2026-07-29)

### 확정된 설계 결정

- STT 엔진: **Whisper API Batch** (스트리밍 아님 — Partial/Ring Buffer 설계 제외)
- 발화 확정 UX: **Toggle(탭) + PTT(길게 누르기) 하이브리드**
- 전사 후 흐름: **학생 편집 초안 화면 → 수정 or 재녹음 → 제출** (자동 즉시 제출 없음)

### 구현 완료 (코드 반영, 실기기 검증 전)

| 단계 | 파일 | 내용 |
|------|------|------|
| 1. STT 호출 완성 | `whisper_stt_client.dart` | `language: 'ko'` + `prompt`(수업 키워드 10개) 쿼리 파라미터 추가. 재시도: 최대 3회, 지수 백오프(1→2초). 5xx·네트워크 오류만 재시도, 4xx 즉시 실패. 30초 타임아웃. 파일은 재시도 전 과정 후 단 1회 삭제. |
| 2. 편집 초안 화면 | `widgets/draft_sheet.dart`, `student_session_screen.dart` | STT 완료 후 바로 제출 대신 바텀시트 표시. 학생이 텍스트 수정 후 [제출] or [다시 녹음] 선택. `_lastTranscript`는 초안이 아닌 실제 제출 텍스트로 갱신. |
| 3. Toggle + PTT 하이브리드 | `student_session_screen.dart`, `teacher_home_screen.dart` | 탭=토글, 길게 누르기=PTT. 학생·교사 동일 적용. `_isToggleMode` 플래그로 모드 분기. `_SpeakCard` 힌트: 상태·모드별 3종. |
| 4. VAD Silence Auto-Pause | `whisper_stt_client.dart`, `student_session_screen.dart` | `amplitudeStream`(200ms 간격, dBFS) 노출. 토글 모드 전용. -40 dBFS 미만 3초 지속 시 자동 종료. PTT 모드는 VAD 미적용. |
| 5. Teacher 마이크 강제 제어 | `moamal_repository.dart`, `firebase_moamal_repository.dart`, `student_session_screen.dart`, `student_tab.dart` | Firestore `participants/{uid}/forceStop: bool`, `forceStart: bool`. 교사 화면: "학생 마이크 제어" 패널 + [시작] [중지] 버튼. 학생 앱: forceStart → Toggle 모드 자동 녹음 시작 + VAD. forceStop → VAD 중단 → 녹음 취소 → 스낵바. 각 처리 후 플래그 초기화. |
| 6. 편집 초안 화면 (학생용) | 위 2단계와 동일 | —  |

### 미검증 플랫폼

- ~~Android 실기기 STT 엔드투엔드~~ — **검증 완료 2026-08-14** (gpt-transcribe, 전사 및 무음 처리 정상 동작)
- iOS: `NSMicrophoneUsageDescription` **추가 완료 2026-08-07**. 실기기 빌드 및 STT 엔드투엔드 미검증.
- VAD 침묵 임계값(-40 dBFS, 3초): 실제 교실 소음에서 튜닝 필요

### Firestore 변경: participants 스키마

```
sessions/{sessionCode}/participants/{uid}
  forceStart: bool  ← 신규 추가 (2026-08-07)
  forceStop: bool   ← 신규 추가 (2026-07-29)
             true  = 교사가 강제 중지 요청
             false = 학생이 처리 완료(acknowledge)
```

### 프록시 측 추가 작업 — 완료 (2026-07-30)

`transcribeAudio` Functions에 `req.query.prompt`를 읽어 Whisper API FormData에 추가하는 코드 반영 및 재배포 완료.

### STT VAD 튜닝 파라미터 위치

`student_session_screen.dart`
- `_silenceThresholdDb = -40.0` — 교실 소음이 크면 -30 ~ -35로 조정
- `_silenceSec = 3` — 학생 발화 간격 보고 조정

---

## 12. STT 2계층 동적 Whisper Prompt (2026-07-30)

### 설계 결정

교사 추가 입력 없이 세션 제목에서 수업 유형(Layer 1)과 수업 주제(Layer 2)를 자동 추출해 Whisper prompt를 동적으로 조합한다.

- **Layer 1 (수업 유형)**: 제목 키워드 감지 → 발화 스타일 힌트
- **Layer 2 (수업 주제)**: 제목 원문을 prompt에 직접 삽입 → 어휘 도메인 힌트

### 유형 감지 규칙 (`buildWhisperPrompt` in `whisper_stt_client.dart`)

| 제목 키워드 | context 문장 |
|---|---|
| 토론 / 토의 | 찬성, 반대, 주장, 근거, 반론 등 |
| 발표 / 조사 | 조사, 발표, 자료, 첫째, 결론 등 |
| 회의 | 안건, 동의, 표결 등 |
| 심포지엄 | 연구, 발표, 질문, 답변 등 |
| (없음) | 초·중등 수업 현장의 학생 발화 음성 |

최종 prompt 예시 (`"한국의 전통음식 조사 발표"` 제목):
```
학생들의 주제 발표 및 조사 내용 공유 음성입니다. 조사, 발표, 자료, 첫째, 결론 등의 단어가 사용됩니다. 수업 주제: "한국의 전통음식 조사 발표"
```

### 적용 범위

| 파일 | 변경 내용 |
|---|---|
| `whisper_stt_client.dart` | `buildWhisperPrompt(String sessionTitle)` 추가. `stopAndTranscribe(String prompt)` 파라미터화 |
| `student_session_screen.dart` | `_sessionTitle` 캐싱 후 STT 호출 시 `buildWhisperPrompt(_sessionTitle)` 전달 |
| `mic_button.dart` | `prompt` 파라미터 추가 (기본값 `''`) |
| `student_tab.dart` | `MicButton`에 `buildWhisperPrompt(session.title)` 전달 |
| `teacher_home_screen.dart` | `buildWhisperPrompt(_session.title)` 전달 |
| `functions/index.js` | `req.query.prompt` 읽어 Whisper FormData에 추가 (500자 제한) |

### 미검증

- 실제 교실에서 유형 감지 키워드가 제목에 포함되지 않는 경우 fallback 동작 확인 필요
- prompt 길이 500자 제한이 긴 제목에서 잘리는지 실측 필요

---

## 10. Firestore approvedGroups 스키마 계약

```
sessions/{sessionCode}/approvedGroups/{groupId}
  groupId: String          — 문서 ID와 동일
  title: String            — AI 생성 또는 폴백 제목
  idea_ids: String[]       — 원문 ideas 하위 컬렉션 문서 ID 배열
  approvedAt: Timestamp
  approvedBy: String       — 교사 ownerUid
  revision: Number         — 현재 항상 1; 재승인 시 증가 예정
```

보존 조건:
- `idea_ids`의 모든 ID는 `ideas` 하위 컬렉션 원문을 참조한다.
- 승인 후 투표 중인 revision의 `groupId`는 바꾸지 않는다.
- AI 재그룹화 초안과 승인본을 분리한다 (초안은 로컬 메모리, 승인본은 Firestore).
- 학생 투표 문서(`votes/{participantId}.groupId`)는 승인본의 `groupId`만 참조한다.

---

## 13. AI 의견구조화 품질 개선 (2026-07-30)

### 변경 내용 4건

| # | 파일 | 변경 내용 | 이유 |
|---|---|---|---|
| 1 | `gemini_api_client.dart` | `maxOutputTokens` 512 → 1024 (그룹화·리포트) | 의견 20개+ 에서 응답이 중간에 잘려 JSON 파싱 실패 방지 |
| 2 | `gemini_grouping_engine.dart` | `_stableGroupId()` 임계값 `> 0` → `>= ceil(ideas.length/2).clamp(2, ideas.length)` | 1개만 겹쳐도 ID 재사용하던 버그 수정 — 투표 집계 오류 방지 |
| 3 | `gemini_api_client.dart`, `gemini_grouping_engine.dart`, `teacher_home_screen.dart` | 그룹화 요청에 `sessionTitle` 추가 (`수업 주제: ...` 첫 줄) | AI가 주제 맥락 없이 그룹화하던 문제 해결 — 제목·분류 품질 향상 |
| 4 | `gemini_grouping_engine.dart`, `cluster_vote_screen.dart` | `freeze()` 메서드 추가, 승인 성공 시 호출 | 승인 후 새 의견이 들어와도 그룹 재편 차단 — 투표 집계 안정성 보장 |
| 5 | `gemini_api_client.dart` | `http.post`에 `.timeout(Duration(seconds: 10))` 추가 | 교실 Wi-Fi 불안정 시 무한 대기 방지 — 타임아웃 시 폴백 유지 |
| 6 | `gemini_api_client.dart` | `_stripMarkdown()` 추가 — ` ```json...``` ` 래퍼 전처리 | Gemini가 마크다운 래퍼를 붙일 때 jsonDecode 실패 방지 |

### 현재 AI 그룹화 동작 (2026-08-18 기준)

- 의견 3개 이상 또는 2.5초 경과 시 GPT 호출 (IdeaChunkBuffer → openaiProxy)
- 호출 전까지 Jaccard 폴백(임계값 0.34)으로 즉시 표시
- 기존 그룹 + 새 배치를 incremental로 GPT에 전달 (순차 처리 — race condition 수정 완료)
- 세션 주제 + 교사 최근 지시가 프롬프트 맥락으로 포함됨
- 교사 승인 시 엔진 freeze → 이후 새 의견은 그룹 변경 없이 무시
- 실패 시 조용히 폴백 유지 (교사 화면에 실패 상태 미표시 — 추후 개선 필요)
- `ClusterVoteScreen` 진입 후에도 AI 그룹화 결과 실시간 반영됨 (`onGroupUpdate` 콜백)

### 그룹화 시스템 프롬프트 (2026-08-18 개선)

```
1. 수업 주제와 교사 지시를 맥락으로 삼아 의견의 의미를 해석하고 그룹화
2. 의미가 비슷한 의견을 같은 그룹으로 묶기
3. 각 그룹에 한국어 짧은 제목(2~4단어) 생성
4. 하나의 의견은 하나의 그룹에만 속함
5. 새 의견은 기존 그룹에 배정하거나 새 그룹 생성 — 필요하면 기존 그룹 간 의견 재배치 가능
6. 기존 그룹도 변경 여부와 관계없이 모두 반환
7. 텍스트가 비어있는 의견은 무시
8. 반드시 유효한 JSON만 반환
```

### 남은 AI 관련 위험

| 위험 | 영향 | 상태 |
|---|---|---|
| Gemini 실패 시 교사 화면에 상태 미표시 | 낮음 | 계획/미구현 — 폴백이 작동하므로 파일럿 후 대응 |
| Jaccard 폴백 → Gemini 전환 시 그룹 목록 갑작스러운 재배열 | 낮음 | 미관 문제, 후순위 |
| 브리핑 maxOutputTokens 256 — 긴 제목/그룹에서 절단 가능성 | 낮음 | 모니터링 |

---

## 14. AI 의견구조화 컨텍스트 강화 (2026-08-11)

### 변경 내용

| # | 파일 | 변경 내용 | 이유 |
|---|---|---|---|
| 1 | `ai_api_client.dart` (구 `gemini_api_client.dart`) | `GeminiApiClient` → `AiApiClient` 이름 변경, 파일명 변경 | 향후 OpenAI 등 다른 프로바이더로 교체 시 혼란 방지 |
| 2 | `ai_api_client.dart`, `functions/index.js` | 모델 `gemini-2.0-flash` → `gemini-2.5-flash` | 2.0-flash deprecated(2026-06-01 이후), 2.5-flash로 업그레이드 |
| 3 | `ai_api_client.dart`, `gemini_grouping_engine.dart`, `teacher_home_screen.dart` | `groupIdeas()`에 `teacherNotes` 파라미터 추가, 프롬프트 첫 줄에 교사 최근 지시 1개 포함 | 교사 발문 맥락이 있으면 그룹화 제목·분류 품질 향상 |
| 4 | `ai_api_client.dart`, `teacher_home_screen.dart` | `generateReport()`에 `teacherNotes` 파라미터 추가, 리포트에 교사 지시 타임라인 섹션 포함 | '교사 지시 → 학생 반응' 흐름이 리포트에 반영 |
| 5 | `moamal_repository.dart`, `firebase_moamal_repository.dart` | `getAllTeacherNotes(sessionCode)` 추가 — `teacher_notes` 전체 시간순 조회 | 리포트 생성 시 세션 재시작 후에도 전체 타임라인 복원 가능 |

### 현재 교사 발문 처리 흐름

```
교사 발화 → gpt-transcribe STT → _latestTranscript
  ├─ Firestore teacher_notes/{id} 저장 (addTeacherNote)
  ├─ _teacherNotes 로컬 리스트에 추가
  └─ groupingEngine.recentTeacherNotes = 최근 2개
       └─ 다음 GPT 그룹화 요청 시 프롬프트에 포함 (openaiProxy)

리포트 생성 시
  └─ _teacherNotes(메모리) 또는 Firestore getAllTeacherNotes()로 전체 조회
       └─ generateReport(teacherNotes: allNotes) → 타임라인 섹션 포함
```

### 프롬프트 구조 예시

**그룹화:**
```
수업 주제: 2학기 체험학습 | 교사 최근 지시: '자연이나 역사 체험 위주로 아이디어를 제출해 주세요'
```

**리포트:**
```
[교사 지시 타임라인]
1. "도서관 이용 규칙에 대해 의견을 말해보세요"
2. "안전 관련 의견도 포함해보세요"
```

### AI 클라이언트 구조 (프로바이더 교체 대비)

- 상위 인터페이스(`groupIdeas`, `generateReport`, `generateBriefing`)는 프로바이더 무관
- `_buildGroupBody`, `_buildBriefingBody`, `_buildReportBody`만 포맷 의존
- 교체 시 body builder + `_call()` 내부만 수정, 엔진·화면 코드는 무변경

### 현재 AI 클라이언트 설정 (2026-08-18 기준)

| 항목 | 값 |
|---|---|
| 모델 | `gpt-5.6-luna` |
| 엔드포인트 | `https://openaiproxy-xzj4mtcbda-du.a.run.app` |
| 환경변수 | `AI_PROXY_URL` |
| 포맷 | OpenAI Chat Completions (`messages`, `response_format: json_object`) |
| timeout | 30초 |
| temperature | **미지원** (gpt-5.6-luna 기본값 1 고정, 파라미터 전송 시 400 에러) |
| 그룹화 max_completion_tokens | 1024 |
| 브리핑 max_completion_tokens | 512 |
| 리포트 max_completion_tokens | 1024 |
