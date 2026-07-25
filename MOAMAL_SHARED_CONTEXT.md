# MOAMAL_SHARED_CONTEXT

## 문서 정보

- 마지막 갱신일: 2026-07-22
- 갱신한 역할: UI/UX Design (반응형 리팩토링)

## Flutter UI 반응형 리팩토링 (2026-07-22)

### 완료 (코드 반영, 빌드·실기기 검증 전)

- **`lib/utils/responsive.dart` 신규**: `AppBreakpoints.compact(600)` / `medium(900)` 상수, `BuildContext` 확장(`isCompact`, `isTablet`, `sw`, `sh`, `viewPad`), `sheetConstraints()` 헬퍼. 앱 전체 브레이크포인트 단일 진입점.
- **`join_screen.dart`**: body → `SafeArea + SingleChildScrollView + ConstrainedBox(maxWidth:480)`. 가로 모드·태블릿 overflow 해소. QR 스캔 프레임 `220×220` → `width×0.6`, clamp(180,280).
- **`teacher_home_screen.dart`**: `_SttBox` 고정 `height` 파라미터 제거 → `expand` 플래그 분기(Compact: `ConstrainedBox(min:100, max:화면높이×0.22)`, Medium: 부모 `Expanded`). FAB 하단 여백 `90` 고정 → `viewPadding.bottom+76`. `_QrSheet` QR `160` → LayoutBuilder `width×0.45` clamp(120,200). `_QrFullScreen` QR `260` → LayoutBuilder `width×0.55` clamp(200,380). `showModalBottomSheet`에 `constraints: sheetConstraints()` 추가(maxWidth 520).
- **`landing_screen.dart`**: PIN 다이얼로그 `insetPadding` — 태블릿 화면너비×0.3 마진. 수업 제목 다이얼로그 `insetPadding` — 태블릿 화면너비×0.25 마진. Compact/Medium Body 하단 패딩에 `MediaQuery.paddingOf().bottom` 반영.
- **`display_tab.dart`**: QR `size:180` → `Builder`로 `width×0.38` clamp(140,220).
- **`cluster_vote_screen.dart` / `report_screen.dart` / `student_session_screen.dart`**: `< 600` 리터럴 → `context.isCompact`.

### 미검증 (다음 Flutter UI/UX 방 작업)

- iPad Pro 12.9", 갤럭시탭 S 가로 모드, iPhone SE(375px) 가로 모드 실기기 빌드
- 900px 이상 expanded 레이아웃 도입 여부 (현재 medium과 동일하게 처리됨)
- 공유 화면(DisplayTab) 전용 전체화면 레이아웃 설계

### 변경하지 않은 것 (의도적)

- 브랜드 컬러·버튼 스타일·비즈니스 로직
- `main.dart` `maxScaleFactor: 1.3` (기존 텍스트 스케일 보호 유지)
- `_SpeakCard` 세로 패딩 28 (Expanded 안에서 정상 동작)

---

## 현재 상태 (STT/백엔드)

- Flutter Android Firebase 설정: `google-services.json` 로컬 배치 확인, 프로젝트 `moamal-1e601`, 패키지 `com.moamal.prototype` 일치
- Firebase STT 프록시: 코드 구현 및 npm 의존성 설치 완료; Node 문법 검사 통과. 공개 URL 상태 확인은 HTTP 404로 아직 미배포임을 확인
- OpenAI Secret Manager: 등록 전. 2026-07-18 `functions:secrets:set` 실행 결과 현재 Spark 요금제에서는 `secretmanager.googleapis.com` 활성화가 차단됨; Blaze 업그레이드 필요
- Flutter STT: OpenAI 직접 호출 제거, Firebase ID 토큰 기반 프록시 호출로 변경. 2026-07-18 디버그 APK 빌드 성공
- Android 기준 구현 STT: `BuildConfig.OPENAI_API_KEY`와 OpenAI 직접 호출 제거, 동일 Firebase ID 토큰 프록시로 변경. `assembleDebug` 성공
- Gemini: 여전히 클라이언트 키/직접 호출 구조이며 별도 서버 이전 필요

## STT 데이터 계약

```text
POST /transcribeAudio
Authorization: Bearer <Firebase ID token>
Content-Type: audio/mp4
Body: raw M4A bytes, max 10 MiB

200: { "text": String }
401: { "error": "unauthenticated" }
413: { "error": "invalid_audio_size" }
415: { "error": "unsupported_audio_type" }
429: { "error": "rate_limited" }
502: { "error": "transcription_failed" | "empty_transcription" }
```

## 배포·보안 상태

- Function 리전: `asia-northeast3`
- Secret 이름: `OPENAI_API_KEY`; 코드/저장소/클라이언트에 값 저장 금지
- 인증: Firebase ID token 서버 검증
- 비용 제어: UID당 분당 10회, 최대 인스턴스 10, 음성 10 MiB 제한
- 원음/전사문: 프록시에서 Firestore/Storage/로그에 저장하지 않음
- 검증: `npm run check`, `flutter analyze`, `flutter test`, Flutter `flutter build apk --debug`, Android `assembleDebug` 통과(2026-07-18). 양쪽 클라이언트 코드에서 OpenAI 직접 호출/키 참조 0건. 테스트는 placeholder 1건이므로 STT 계약 자동화 테스트는 없음
- 의존성 위험: 호환되는 `firebase-admin@13.10.0`, `firebase-functions@6.6.0`으로 잠금. `npm audit --omit=dev`의 Firebase Admin 하위 `uuid` 계열 중간 등급 취약점은 upstream peer 호환 수정 대기; `--force` 미적용
- 미완료: Blaze 요금제 업그레이드 및 결제 계정 연결, Secret 등록, Functions 배포, 실 호출, App Check, 예산 알림, 환경 분리. Firebase CLI 로그인과 프로젝트 접근은 완료
- 마이그레이션: 새 Flutter 앱은 배포된 프록시 URL이 필요하다. Function 배포 전에 새 클라이언트를 배포하면 STT가 실패한다. 구버전 앱의 클라이언트 OpenAI 키는 회수·폐기해야 한다.

## 위험·다음 행동

1. **전략적 보류(2026-07-18):** 학교 배포 단위 비용 모델과 서버 강제 한도를 정하기 전 Blaze 업그레이드·Function 배포를 진행하지 않음
2. 학생 수·세션 수·평균 STT 분량을 기준으로 수업/학교/월 원가 모델 작성
3. 요청당 녹음 길이, 세션당 STT 총량, 학교당 일/월 한도 및 전역 kill switch를 서버에서 강제
4. 예산 알림과 OpenAI 프로젝트 지출 한도를 설정한 뒤 제한된 교사 파일럿 실시
5. `firebase functions:secrets:set OPENAI_API_KEY`로 키 등록 후 인증된 짧은 한국어 M4A 통합 테스트
6. Firestore `sttRateLimits.expiresAt` TTL 및 App Check 적용
7. dev/staging/prod 프로젝트와 OpenAI 키 분리
8. Gemini 직접 호출도 비용 모델에 포함해 별도 서버 프록시로 이전
