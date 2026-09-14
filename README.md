# Moamal — 교사 중심 실시간 의견 구조화 서비스

Flutter 기반 참여형 수업 도구. 학생 의견을 AI가 정리하고, 교사가 검토·승인한 뒤 학생 투표와 수업 기록으로 연결한다. 토론·심포지엄 지원을 목표로 하며, 현재 학급회의 MVP로 기반 흐름을 검증한다.

## 현재 공개 데모와 문서

- 공개 주소: https://moamal-1e601.web.app/ (2026-09-14 웹 소개 및 학생 투표 체험 배포)
- 진행 현황·일정: [HACKATHON_PREP.md](HACKATHON_PREP.md)
- 데모 검증 결과·한계: [DEMO_VOTE_QA.md](DEMO_VOTE_QA.md)
- 공통 현황: [MOAMAL_SHARED_CONTEXT.md](MOAMAL_SHARED_CONTEXT.md), UI 이력: [UI_REDESIGN_LOG.md](UI_REDESIGN_LOG.md), 결함: [BUG_LOG_v2.md](BUG_LOG_v2.md)
- 체험 순서: 학급회의 체험하기 → 정리 → 후보 승인 → 투표 시작 → 학생으로 한 표 넣어보기 → 교사 화면 복귀 → 수업기록.
- 예시 학생 5명·의견 8개로 시작한다. 별도 익명 계정의 체험 학생 1명이 본인 표를 저장하며, 교사 인증은 유지된다. 수업기록에는 ‘체험 학생’의 선택이 표시된다.
- 새 데모만 `sessions/{code}.isJudgeDemo: true`를 갖는다. 이전 데모로 자동 복귀하면 수업을 끝내고 새 데모를 시작해야 한다. 이 표시는 UI 구분용이며 서버 권한 판정 수단이 아니다.
- 최초 학생 연결 실패 1회는 원인 미확정이다. 일반 수업의 마감 후 쓰기 및 교사 권한 관련 규칙 문제도 별도 미해결 상태다.

---

## 아키텍처 개요

```
[Flutter 앱]
  ├── 교사: Google Sign-In (Firebase Auth)
  └── 학생: 익명 로그인 (Firebase Auth Anonymous)

[Firestore]
  └── sessions/{sessionCode}
        ├── ideas/{ideaId}
        ├── votes/{participantId}
        ├── approvedGroups/{groupId}
        └── participants/{uid}

[Cloud Functions v2 — asia-northeast3]
  ├── transcribeAudio  → OpenAI gpt-transcribe STT 프록시
  ├── openaiProxy      → OpenAI GPT 그룹화·리포트 프록시 (현재 사용)
  └── geminiProxy      → Gemini AI 프록시 (대기)

[Secret Manager]
  ├── OPENAI_API_KEY
  └── GEMINI_API_KEY
```

---

## Firebase 프로젝트

- **프로젝트 ID**: `moamal-1e601`
- **리전**: `asia-northeast3` (서울)
- **요금제**: Blaze (종량제)

---

## 주요 파일

| 파일 | 역할 |
|------|------|
| `functions/index.js` | Cloud Functions — STT·GPT·Gemini 프록시, rate limit |
| `firestore.rules` | Firestore 보안 규칙 |
| `firebase.json` | Firebase 배포 설정 |
| `lib/models/participant.dart` | 학생 참가자 모델 |
| `lib/models/approved_group.dart` | 교사 승인 그룹 모델 |
| `lib/models/session_state.dart` | 세션 전체 상태 |
| `lib/repositories/firebase_moamal_repository.dart` | Firestore 읽기/쓰기, 5개 스트림 구독 |
| `lib/services/ai_api_client.dart` | GPT/AI 프록시 호출 — 그룹화·리포트·브리핑 (키 없음, Firebase 토큰 사용) |
| `lib/services/whisper_stt_client.dart` | STT 프록시 호출 (키 없음, Firebase 토큰 사용) |
| `lib/services/deep_link_service.dart` | `moamal://join/{code}` 생성·파싱 — QR 인코딩과 스캔 판독의 단일 진입점 |
| `lib/services/prompt_config.dart` | Firebase Remote Config 기반 AI 프롬프트 관리 |

---

## Firestore 데이터 구조

### sessions/{sessionCode}
```
sessionCode:    String
title:          String
voteOpen:       bool
ownerUid:       String    ← 교사 UID
updatedAt:      Timestamp
createdAt:      Timestamp?  ← 세션 복귀 판정용 (Mercury-Session-03/04, 2026-08-26)
endedAt:        Timestamp?  ← 교사 종료 시 기록, null이면 진행 중 (Gemini-1-Exit-03)
groupSnapshot:  List<Map>?  ← 그룹 구성 스냅샷(하위 컬렉션 아닌 필드), idea id만 저장 (Mercury-Session-02)
groupSnapshotAt: Timestamp?
```

### teacher_notes/{noteId}
```
text:      String    ← 교사 발화 전사 텍스트
type:      String    ← "instruction" 등
createdAt: Timestamp
```

### ideas/{ideaId}
```
id:        String
text:      String
speaker:   String
source:    String    ← "stt" 등
authorUid: String    ← 작성자 UID, 규칙이 create 시 강제(Common-Rules-01, 2026-08-27 배포)
createdAt: Timestamp
```

### votes/{participantId}
```
participantId: String
groupId:       String   ← approvedGroups의 groupId 참조
createdAt:     Timestamp
```

### approvedGroups/{groupId}
```
title:       String
idea_ids:    List<String>
approvedAt:  Timestamp
approvedBy:  String   ← 교사 UID
revision:    int
```

### participants/{uid}
```
number:   int        ← 입장 순번 (1번, 2번...)
name:     String     ← 학생 입력 이름
joinedAt: Timestamp
leftAt:   Timestamp?  ← 퇴장 시각, null이면 접속 중 (Gemini-1-Exit-01, 2026-08-26)
```
`activeParticipants`(접속 중, `leftAt == null`)와 `participants` 전체(누적)를 용도에 따라 구분해서 쓴다 — 전자는 LIVE 통계·마이크 제어·투표율 분모, 후자는 리포트.

---

## Cloud Functions

### transcribeAudio
- **v2 URL**: `https://transcribeaudio-xzj4mtcbda-du.a.run.app`
- **인증**: `Authorization: Bearer {Firebase ID Token}`
- **Content-Type**: `audio/mp4` (최대 10MB)
- **쿼리 파라미터**: `?language=ko&prompt=수업키워드` (prompt 최대 500자, 없으면 생략)
- **Rate limit**: 분당 10회 (uid 기준)
- **모델**: `gpt-transcribe` (2026-08-14 교체)
- **응답**: `{ "text": "..." }`

### openaiProxy ← 현재 AI 그룹화·리포트에 사용
- **v2 URL**: `https://openaiproxy-xzj4mtcbda-du.a.run.app`
- **인증**: `Authorization: Bearer {Firebase ID Token}`
- **허용 모델**: `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-5.6-sol`
- **Rate limit**: 분당 20회 (uid 기준)
- **요청 body**: `{ "model": "gpt-5.6-luna", "messages": [...], "temperature": 0.1, ... }`
- **응답**: `{ "text": "..." }` (`choices[0].message.content`)

### geminiProxy ← 대기 중 (현재 Flutter 클라이언트 미사용)
- **v2 URL**: `https://geminiproxy-xzj4mtcbda-du.a.run.app`
- **인증**: `Authorization: Bearer {Firebase ID Token}`
- **허용 모델**: `gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-2.0-flash-lite`
- **Rate limit**: 분당 20회 (uid 기준)
- **요청 body**: `{ "model": "gemini-2.5-flash", ...geminiBody }`
- **응답**: `{ "text": "..." }`

### kakaoVerify
- **엔드포인트**: `POST https://asia-northeast3-moamal-1e601.cloudfunctions.net/kakaoVerify`
- **인증**: 없음 (로그인 전 호출)
- **요청 body**: `{ "accessToken": "카카오SDK에서받은토큰" }`
- **응답**: `{ "customToken": "..." }`
- **이후**: `FirebaseAuth.instance.signInWithCustomToken(customToken)`
- **Firebase UID 형식**: `kakao:{카카오유저ID}`

### naverVerify
- **엔드포인트**: `POST https://asia-northeast3-moamal-1e601.cloudfunctions.net/naverVerify`
- **인증**: 없음 (로그인 전 호출)
- **요청 body**: `{ "accessToken": "네이버SDK에서받은토큰" }`
- **응답**: `{ "customToken": "..." }`
- **이후**: `FirebaseAuth.instance.signInWithCustomToken(customToken)`
- **Firebase UID 형식**: `naver:{네이버유저ID}`

---

## 보안 규칙 요약

**2026-08-27 배포 기준** (`Common-Rules-01`·`Common-Rules-03` 반영):

| 경로 | 읽기 | 쓰기 |
|------|------|------|
| sessions | 단건 조회만(`get`) — **목록 조회(`list`) 차단** | 교사(ownerUid) |
| ideas | 로그인 사용자 | 생성: **본인 UID를 `authorUid`로 기록해야 함**. 수정: 교사 또는 작성자 본인만(`authorUid` 변경 불가) |
| votes | 교사 또는 본인 | 본인만. ⚠ **투표 마감 후에도 본인 쓰기 가능**(`Common-Rules-02`, 의도적 미해결 — Gemini 종료 직후 적용 예정) |
| approvedGroups | 로그인 사용자 | 교사만 |
| participants | 교사 또는 본인 | 본인 또는 교사 (`leftAt` 포함) |
| teacher_notes | 로그인 사용자 | 교사만 |
| mergeLogs | 교사만 | 교사만 |
| sttRateLimits | 차단 | 차단 (Functions Admin SDK만) |
| geminiRateLimits | 차단 | 차단 (Functions Admin SDK만) |
| openaiRateLimits | 차단 | 차단 (Functions Admin SDK만) |

학생은 `votes`·`participants` 전체 목록은 조회할 수 없고 본인 문서만 읽을 수 있다 — 비밀투표 유지 목적(`Common-Rules-04`, 결과는 빔프로젝터로만 공개).

---

## 배포 명령어

```bash
# Functions 배포
firebase deploy --only functions

# Firestore 규칙 배포
firebase deploy --only firestore:rules

# 전체 배포
firebase deploy
```

---

## 개발 환경 변수 (dart-define)

API 키가 아니라 **프록시 URL 오버라이드**용 (개발 시에만 사용):

```bash
flutter run \
  --dart-define=STT_PROXY_URL=http://localhost:5001/moamal-1e601/asia-northeast3/transcribeAudio \
  --dart-define=AI_PROXY_URL=http://localhost:5001/moamal-1e601/asia-northeast3/openaiProxy
```

---

## 클라이언트 구현 현황

### 빌드 환경 (Android)

| 항목 | 버전 |
|------|------|
| Flutter | 3.44.6 |
| Dart | 3.12.2 |
| Android Gradle Plugin | 8.7.3 (9.0.1에서 다운그레이드 — OOM 이슈) |
| Gradle Wrapper | 8.10.2 |
| Kotlin | 2.0.21 |
| JVM Heap | `-Xmx4096m -XX:MaxMetaspaceSize=512m -XX:+UseG1GC` |

> **AGP 9.0.1 사용 금지**: D8 dex 머지 단계에서 OutOfMemoryError / 무한 대기 발생. 8.7.3이 안정.

`android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=512m -XX:+UseG1GC
org.gradle.daemon=true
org.gradle.parallel=true
android.useAndroidX=true
android.builtInKotlin=false
android.newDsl=false
```

`android/app/build.gradle.kts` — `defaultConfig`에 추가:
```kotlin
multiDexEnabled = true
```

---

### 화면 구성

| 화면 | 파일 | 설명 |
|------|------|------|
| 랜딩 | `lib/screens/common/landing_screen.dart` | 교사/학생 역할 선택, 슈퍼바이저 모드 |
| 학생 참여 | `lib/screens/student/join_screen.dart` | 코드 입력·QR 스캔·이름 번호 입력(`StudentProfileScreen`) |
| 교사 홈 | `lib/screens/teacher/teacher_home_screen.dart` | 세션 생성·관리, QR 공유, AI 누적 요약 |
| 학생 세션 | `lib/screens/student/student_session_screen.dart` | 의견 제출, 투표 |
| 정리(원문·승인·투표) | `lib/screens/teacher/organize_screen.dart` | 의견 이동·병합, 그룹 승인, 투표 시작/마감 |
| 마이크 제어 | `lib/screens/teacher/mic_control_screen.dart` | 학생별 [끄기]/[켜기]/[말하기] 원격 제어 (2026-08-27 켜기·말하기 분리) |
| 빔 프로젝터 | `lib/screens/teacher/beam_projector_screen.dart` | 학급 전체 공유 화면 — 투표 후보·최종 결과 표시 |
| 리포트 | `lib/screens/teacher/report_screen.dart` | AI 요약 생성, 수업 끝내기 |

---

### 슈퍼바이저 모드

랜딩 화면 상단 "모아말" 로고를 **3회 연속 탭** → PIN 키패드 → `1218` 입력 → Google 로그인 없이 교사 화면 진입.

- Firebase `signInAnonymously()`로 익명 UID 발급 → Firestore 소유권 규칙 충족
- 4자리 점 표시 + 숫자 키패드 (3×4), 오입력 시 빨간 점으로 표시
- PIN 확인 후 **"새 세션 시작" / "기존 세션 재개"** 선택 가능 (2026-08-13 추가)
  - 기존 세션 재개: 코드 입력 → `TeacherHomeScreen(existingCode: code)` — 세션 생성 없이 기존 Firestore 데이터 로드
- `landing_screen.dart` → `_LandingScreenState._onLogoTap()` / `_PinDialog`

---

### 학생 QR 참여

`lib/screens/student/join_screen.dart`

학생 진입 경로는 **세 가지**이며 세 경로 모두 `JoinScreen`→`StudentProfileScreen`(이름·번호)→`StudentSessionScreen` 흐름을 탄다.
**이름 입력 화면을 건너뛰면 `participants` 등록이 빠져 교사 화면에 참여자로 잡히지 않는다.**

| 경로 | 진입 |
|---|---|
| 코드 직접 입력 | 랜딩 `코드 입력` → 자체 키패드 6자리 → **자동 확인**(버튼 없음) |
| 앱 내 QR | 랜딩 QR 버튼 → **스캐너 직행** → 자동 참여 |
| 딥링크 | `moamal://join/{code}` → `main.dart` `_joinWithCode()` |

- 코드 직접 입력 (자체 키패드 6자리) 또는 **"QR 코드 찍기"** 버튼
- QR 스캔: `mobile_scanner` 패키지, `QrScanScreen` (전체화면 카메라 + 안내 프레임)
- 스캔 성공 시 `DeepLinkService.parseScanned()`로 세션 코드 추출 → 자동 참여
- 스캔 실패 대비: 하단 `코드 직접 입력하기` 상시 배치, **8초 미인식 시** 문구 전환·강조, `errorBuilder`로 카메라 불가 안내
  - **딥링크(`moamal://join/XXXXXX`)와 평문 6자리를 모두 허용** — 이전에 배포된 QR 호환 유지
  - QR 생성부를 딥링크로 바꿀 때 이 판독부를 함께 수정하지 않으면 앱 내 QR 참여가 깨진다

---

### 교사 QR 공유

`lib/screens/teacher/teacher_home_screen.dart`

- AppBar QR 아이콘 → 바텀시트 (`_QrSheet`)
  - QR 이미지 160px + 세션 코드 텍스트
  - **"전체 화면으로 보기"** 버튼 → `_QrFullScreen`
- `_QrFullScreen`: 흰 배경 + QR 260px + 코드 48px (학교 태블릿 공유용)
- `qr_flutter` 패키지 사용
- **QR 페이로드는 `DeepLinkService.buildJoinUri(code)` = `moamal://join/{code}`** (2026-08-25 변경)
  - 폰 기본 카메라로 찍으면 앱이 열린다 (`AndroidManifest.xml` intent-filter `scheme=moamal, host=join`)
  - QR 생성 지점은 4곳 — `_QrSheet`, `_QrFullScreen`, `beam_projector_screen`(2). (`display_tab`·`facilitator_tab`은 죽은 코드로 확인되어 2026-08-26 삭제됨 — Mercury-Redesign-01)
  - ⚠ **앱 미설치 기기는 `moamal://`로 열 수 없다.** 웹 소개·데모는 별도 URL로 배포됐지만, 기존 QR을 HTTPS 학생 참여 경로로 연결하는 작업이 완료됐다는 뜻은 아니다.

---

### 수업 제목 입력

교사가 로그인(Google 또는 슈퍼바이저) 후 세션 시작 전 `AlertDialog`로 수업 제목 입력.

- 입력값은 `TeacherHomeScreen(initialTitle: title)`로 전달
- 건너뛰기 가능 (null 허용)

---

### 보안 원칙 (클라이언트)

- Gemini / OpenAI API 키는 클라이언트 코드에 포함하지 않음
- STT는 `functions/transcribeAudio` 프록시만 사용 (Firebase ID Token 인증)
- AI 그룹화·리포트는 `functions/openaiProxy` 프록시만 사용 (Firebase ID Token 인증)

---

## 남은 작업

- [x] Node.js 22 업그레이드 완료 (2026-08-07)
- [x] Google Sign-In SHA-1 키 Firebase Console 등록 완료 (2026-08-13)
- [x] STT gpt-transcribe 엔드투엔드 검증 완료 (2026-08-14)
- [x] openaiProxy 502 에러 해결 완료 (2026-08-18) — `gpt-5.6-luna`가 temperature를 미지원해 파라미터 전체 제거
- [x] 사재 코드 정리 완료 (2026-08-26) — `tabs/` 3개 파일(`display_tab`·`facilitator_tab`·`student_tab`) 1,129줄 삭제, 죽은 코드로 확인됨(Mercury-Redesign-01)
- [x] Firestore 규칙 배포 완료 (2026-08-27) — `Common-Rules-01`(ideas 작성자 검증)·`Common-Rules-03`(sessions 목록 조회 차단). **배포 후 실기기 확인(학생 의견 제출 → `authorUid` 기록) 아직 안 함 — 다음 세션 최우선**
- [x] Gemini QA G0~G4 완료 (2026-08-27) — 1:1 실기기 검증, 핵심 마일스톤(학생 투표→교사 실시간 반영) 통과. 상세는 `gemini_qa.html`·`BUG_LOG_v2.md`
- [x] Gemini QA G6(네트워크·생명주기, STABILITY) 완료 (2026-09-03) — 백그라운드 복귀·비행기모드·오프라인 제출·강제종료 7개 전부 실기기 검증. `Common-Network-01`(P1, Mercury v1부터 미검증) 재현 안 됨으로 종결, `Mercury-Session-02` 스냅샷 복원 실기기 확인(승인 경로). 신규 발견: 학생 세션 강제종료 시 자동 복귀 로직 부재(`Gemini-6-Session-01`). 상세는 `gemini_qa.html`·`BUG_LOG_v2.md`
- [x] Gemini S 섹션(Firestore 보안 규칙 실검증) 완료 (2026-08-28) — S-1~S-10 전부 Firestore 에뮬레이터로 통과, Apollo 진입 차단 조건(S-7·S-8·S-9) 충족
- [x] Gemini QA GR(회귀 체크) 완료 (2026-09-03) — R-1~R-8 전부 실기기 통과. `Mercury-Report-06`(P1, 리포트 생성 버튼 무반응) 실기기 검증으로 종결. 신규 발견: 슈퍼바이저 "기존 세션 재개" 시 세션 소유권 불일치로 교사 전용 쓰기 전부 실패(`Gemini-R-Supervisor-01`). **CORE·S·G7·G6·GR 전부 완료 — Apollo 진입 판단만 남음**(G5·G8 확장 항목은 대표 판단으로 스킵). 상세는 `gemini_qa.html`·`BUG_LOG_v2.md`
- [x] **웹 소개·심사용 데모** — 2026-09-14 소개 문구와 독립 학생 투표 체험 Hosting 배포. 상세는 `HACKATHON_PREP.md`.
- [ ] **QR의 웹 학생 참여 연결** — 기존 `moamal://`의 앱 미설치 기기 대응은 별도 항목 (`BUG_LOG_v2.md` Mercury-Share-01).
- [ ] **교사·학생 수동 텍스트 입력 복원 여부** — 재설계로 `student_tab`이 끊기면서 현재 `ideas` 생성 경로가 STT 단일 (`BUG_LOG_v2.md` Mercury-Redesign-01)
- [ ] `Common-Rules-02` — 투표 마감 후에도 학생 `votes` 쓰기 가능. 의도적으로 미적용, Gemini QA 종료 직후 규칙 추가 예정(현황판 §15)
- [ ] 학생 세션 강제종료 후 자동 복귀 로직 (`Gemini-6-Session-01`, 등급 확정 전략기획 판단 필요)
- [ ] 슈퍼바이저 "기존 세션 재개" 소유권 불일치 (`Gemini-R-Supervisor-01`) — 슈퍼바이저 모드 자체가 아래 항목대로 제거 예정이라 그때 함께 소멸
- [ ] firebase-functions 최신 버전 업그레이드 (`npm install --save firebase-functions@latest`)
- [ ] Firebase 개발/운영 환경 분리
- [ ] 슈퍼바이저 모드 — 출시 전 제거 또는 숨김 처리
- [ ] 플러터 앱에 카카오/네이버 SDK 연동 (플러터 대화방에서 진행)


2026-09-14: 웹 소개 페이지에 승인된 Figma 디자인 적용. 초록·노랑 색상 유지, 모바일/데스크톱 반응형 구성 및 검증 카드 높이 정렬. 상세 기록은 UI_REDESIGN_LOG.md 참조.
