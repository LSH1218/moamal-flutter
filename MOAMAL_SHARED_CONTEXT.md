# MOAMAL_SHARED_CONTEXT

> Moamal 실행 대화방이 공유하는 단일 현황판이다. 계획과 실제 구현을 구분하며, 날짜와 코드 근거를 남긴다.

## 문서 정보

- 마지막 갱신일: 2026-08-07
- 갱신한 역할: STT (iOS 마이크 권한 추가)
- 기준 Flutter 커밋: `76496aa` (feat(stt): 교사 학생 마이크 원격 시작(forceStart) 기능 추가)

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

- **Cloud Functions**: 4개 함수 배포 완료 (asia-northeast3)
  - `transcribeAudio`: STT 프록시, 분당 10회 rate limit. **모델: `whisper-1`** (2026-08-07 `gpt-4o-mini-transcribe`에서 교체)
  - `geminiProxy`: Gemini AI 프록시, 분당 20회 rate limit
  - `kakaoVerify`: 카카오 Custom Token 발급
  - `naverVerify`: 네이버 Custom Token 발급
- **Secret Manager**: OPENAI_API_KEY (version 3, All 권한으로 재발급 2026-08-07), GEMINI_API_KEY 등록 완료
- **Firestore 보안 규칙**: 배포 완료 (sessions, ideas, votes, approvedGroups, participants, teacher_notes, rate limit 컬렉션)
- **Firebase 요금제**: Blaze (종량제)
- **Flutter UI 반응형 리팩토링 (2026-07-22)**: compact(<600)/medium(≥600) 2단계, `lib/utils/responsive.dart` 단일 진입점
- **미완료**: 카카오/네이버 Flutter SDK 연동, App Check, 개발/운영 환경 분리

## 6. 주요 위험

| 위험 | 영향 | 상태 | 대응 |
|---|---|---|---|
| ~~Gemini/OpenAI 키가 클라이언트에 노출~~ | ~~높음~~ | **해결됨 2026-07-25** — Cloud Functions Secret Manager 프록시 배포 | 완료 |
| ~~Flutter 학생 투표가 `idea.id`에 저장됨~~ | ~~높음~~ | **해결됨 2026-07-17** | 완료 |
| ~~교사 승인 단계 없음~~ | ~~높음~~ | **해결됨 2026-07-17** | 완료 |
| 카카오/네이버 Flutter SDK 미연동 | 중간 | Functions 준비 완료, Flutter 앱 대화방 작업 필요 | Flutter 앱 대화방에서 SDK 연동 |
| ~~Node.js 20 지원 종료~~ | ~~중간~~ | **해결됨 2026-08-07** — Node.js 22 업그레이드 완료 | 완료 |
| 슈퍼바이저 모드 노출 | 중간 | 랜딩 로고 3탭 → PIN 1218 | 출시 전 제거 또는 숨김 처리 |
| 학생이 다른 의견을 수정 가능 | 높음 | `ideas`의 `create, update`가 모든 인증 사용자에게 허용 | 작성자 UID 검증 추가 필요 |

## 7. 현재 우선순위

1. 아이디어 제공 교사 재인터뷰
2. 성인 6~10명 최소 모의 수업: STT → 그룹 승인 → 투표 → 기록까지 테스트
3. 카카오/네이버 Flutter SDK 연동 (Flutter 앱 대화방)
4. 파일럿 필수 차단 요소만 수정
5. 2026-08-21 계속/피벗/폐기 판정

## 8. 대화방별 다음 행동

- **STT**: VAD 임계값(-40 dBFS, 3초) 실제 교실 소음 튜닝 (파일럿 전 확인)
- **Flutter UI/UX**: 실시간 음성 텍스트 박스 BOTTOM OVERFLOWED 22px 레이아웃 수정
- **AI/백엔드**: App Check 적용, 개발/운영 환경 분리
- **App 개발**: `flutter analyze` 후 오류 수정; 실기기 통합 테스트
- **Flutter UI/UX**: 카카오/네이버 로그인 버튼 UI, 학생 입장 이름 입력 화면
- **전략기획**: 파일럿 교사 섭외 및 일정 확정

## 9. 최근 변경 기록

| 날짜 | 역할 | 변경 내용 |
|---|---|---|
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

- ~~Android 실기기 STT 엔드투엔드~~ — **검증 완료 2026-08-07** (whisper-1, OpenAI 크레딧 충전 후 정상 동작)
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

### 현재 AI 그룹화 동작 (코드 기준, 실기기 미검증)

- 의견 3개 이상 또는 2.5초 경과 시 Gemini 호출 (IdeaChunkBuffer)
- 호출 전까지 Jaccard 폴백(임계값 0.34)으로 즉시 표시
- 기존 그룹 + 새 배치를 incremental로 Gemini에 전달
- 세션 주제가 그룹화 프롬프트 첫 줄에 포함됨
- 교사 승인 시 엔진 freeze → 이후 새 의견은 그룹 변경 없이 무시
- 실패 시 조용히 폴백 유지 (교사 화면에 실패 상태 미표시 — 추후 개선 필요)

### 남은 AI 관련 위험

| 위험 | 영향 | 상태 |
|---|---|---|
| Gemini 실패 시 교사 화면에 상태 미표시 | 낮음 | 계획/미구현 — 폴백이 작동하므로 파일럿 후 대응 |
| Jaccard 폴백 → Gemini 전환 시 그룹 목록 갑작스러운 재배열 | 낮음 | 미관 문제, 후순위 |
| 브리핑 maxOutputTokens 256 — 긴 제목/그룹에서 절단 가능성 | 낮음 | 모니터링 |
