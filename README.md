# Moamal — 교사 중심 실시간 의견 구조화 서비스

Flutter 기반 앱. 학생이 제출한 의견을 AI가 실시간으로 클러스터링하고, 교사가 투표·승인·리포트 생성까지 진행한다.

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
  ├── transcribeAudio  → OpenAI Whisper STT 프록시
  └── geminiProxy      → Gemini AI 프록시

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
| `functions/index.js` | Cloud Functions — STT·Gemini 프록시, rate limit |
| `firestore.rules` | Firestore 보안 규칙 |
| `firebase.json` | Firebase 배포 설정 |
| `lib/models/participant.dart` | 학생 참가자 모델 |
| `lib/models/approved_group.dart` | 교사 승인 그룹 모델 |
| `lib/models/session_state.dart` | 세션 전체 상태 |
| `lib/repositories/firebase_moamal_repository.dart` | Firestore 읽기/쓰기, 5개 스트림 구독 |
| `lib/services/gemini_api_client.dart` | Gemini 프록시 호출 (키 없음, Firebase 토큰 사용) |
| `lib/services/whisper_stt_client.dart` | STT 프록시 호출 (키 없음, Firebase 토큰 사용) |
| `lib/services/prompt_config.dart` | Firebase Remote Config 기반 AI 프롬프트 관리 |

---

## Firestore 데이터 구조

### sessions/{sessionCode}
```
sessionCode: String
title:       String
voteOpen:    bool
ownerUid:    String   ← 교사 UID
updatedAt:   Timestamp
```

### ideas/{ideaId}
```
id:        String
text:      String
speaker:   String
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
number:   int      ← 입장 순번 (1번, 2번...)
name:     String   ← 학생 입력 이름
joinedAt: Timestamp
```

---

## Cloud Functions

### transcribeAudio
- **엔드포인트**: `POST https://asia-northeast3-moamal-1e601.cloudfunctions.net/transcribeAudio`
- **인증**: `Authorization: Bearer {Firebase ID Token}`
- **Content-Type**: `audio/mp4` (최대 10MB)
- **쿼리 파라미터**: `?language=ko&prompt=수업키워드` (prompt 최대 500자, 없으면 생략)
- **Rate limit**: 분당 10회 (uid 기준)
- **응답**: `{ "text": "..." }`

### geminiProxy
- **엔드포인트**: `POST https://asia-northeast3-moamal-1e601.cloudfunctions.net/geminiProxy`
- **인증**: `Authorization: Bearer {Firebase ID Token}`
- **허용 모델**: `gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-2.0-flash-lite`
- **Rate limit**: 분당 20회 (uid 기준)
- **요청 body**: `{ "model": "gemini-2.5-flash", ...geminiBody }`
- **응답**: `{ "text": "..." }`

### openaiProxy
- **엔드포인트**: `POST https://asia-northeast3-moamal-1e601.cloudfunctions.net/openaiProxy`
- **인증**: `Authorization: Bearer {Firebase ID Token}`
- **허용 모델**: `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-5.6-sol`
- **Rate limit**: 분당 20회 (uid 기준)
- **요청 body**: `{ "model": "gpt-5.6-luna", "messages": [...], "temperature": 0.1, ... }`
- **응답**: `{ "text": "..." }` (`choices[0].message.content`)

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

| 경로 | 읽기 | 쓰기 |
|------|------|------|
| sessions | 로그인 사용자 | 교사(ownerUid) |
| ideas | 로그인 사용자 | 로그인 사용자 |
| votes | 교사 또는 본인 | 본인만 |
| approvedGroups | 로그인 사용자 | 교사만 |
| participants | 교사 또는 본인 | 본인 또는 교사 |
| teacher_notes | 로그인 사용자 | 교사만 |
| sttRateLimits | 차단 | 차단 (Functions Admin SDK만) |
| geminiRateLimits | 차단 | 차단 (Functions Admin SDK만) |
| openaiRateLimits | 차단 | 차단 (Functions Admin SDK만) |

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
  --dart-define=GEMINI_PROXY_URL=http://localhost:5001/moamal-1e601/asia-northeast3/geminiProxy
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
| 학생 참여 | `lib/screens/student/join_screen.dart` | 코드 입력 또는 QR 스캔으로 참여 |
| 교사 홈 | `lib/screens/teacher/teacher_home_screen.dart` | 세션 생성·관리, QR 공유 |
| 학생 세션 | `lib/screens/student/student_session_screen.dart` | 의견 제출, 투표 |

---

### 슈퍼바이저 모드

랜딩 화면 상단 "모아말" 로고를 **3회 연속 탭** → PIN 키패드 → `1218` 입력 → Google 로그인 없이 교사 화면 진입.

- Firebase `signInAnonymously()`로 익명 UID 발급 → Firestore 소유권 규칙 충족
- 4자리 점 표시 + 숫자 키패드 (3×4), 오입력 시 빨간 점으로 표시
- `landing_screen.dart` → `_LandingScreenState._onLogoTap()` / `_PinDialog`

---

### 학생 QR 참여

`lib/screens/student/join_screen.dart`

- 코드 직접 입력 (`TextField` 6자리) 또는 **"QR 코드로 참여"** 버튼
- QR 스캔: `mobile_scanner` 패키지, `QrScanScreen` (전체화면 카메라 + 안내 프레임)
- 스캔 성공 시 6자리 코드 추출 → 자동으로 `_join()` 호출

---

### 교사 QR 공유

`lib/screens/teacher/teacher_home_screen.dart`

- AppBar QR 아이콘 → 바텀시트 (`_QrSheet`)
  - QR 이미지 160px + 세션 코드 텍스트
  - **"전체 화면으로 보기"** 버튼 → `_QrFullScreen`
- `_QrFullScreen`: 흰 배경 + QR 260px + 코드 48px (학교 태블릿 공유용)
- `qr_flutter` 패키지 사용

---

### 수업 제목 입력

교사가 로그인(Google 또는 슈퍼바이저) 후 세션 시작 전 `AlertDialog`로 수업 제목 입력.

- 입력값은 `TeacherHomeScreen(initialTitle: title)`로 전달
- 건너뛰기 가능 (null 허용)

---

### 보안 원칙 (클라이언트)

- Gemini / OpenAI API 키는 클라이언트 코드에 포함하지 않음
- STT는 `functions/transcribeAudio` 프록시만 사용 (Firebase ID Token 인증)
- Gemini는 `functions/geminiProxy` 프록시만 사용

---

## 남은 작업

- [x] Node.js 22 업그레이드 완료 (2026-08-07)
- [ ] firebase-functions 최신 버전 업그레이드 (`npm install --save firebase-functions@latest`)
- [ ] Firebase 개발/운영 환경 분리
- [ ] Google Sign-In SHA-1 키 Firebase Console 등록 (실제 기기 로그인 테스트 전 필요)
- [ ] STT / Gemini 함수 키 설정 후 엔드-투-엔드 테스트
- [ ] 슈퍼바이저 모드 — 출시 전 제거 또는 숨김 처리
- [ ] 플러터 앱에 카카오/네이버 SDK 연동 (플러터 대화방에서 진행)
