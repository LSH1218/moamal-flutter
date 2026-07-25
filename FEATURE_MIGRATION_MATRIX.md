# Moamal Android → Flutter 기능 대응표

기준 커밋: Android `6e0442b` / Flutter `7cd5786` (2026-07-11)

상태 표기: **완료**는 코드와 검증이 모두 확인된 경우, **부분 구현**은 코드가 있으나 설정·통합·검증 또는 핵심 계약이 빠진 경우, **계획**은 코드 근거가 없는 경우, **확인 불가**는 환경 또는 외부 상태를 확인하지 못한 경우다.

| 기능 | Android 상태 | Flutter 상태 | 플랫폼 의존성 | 난이도 | 우선순위 | 검증 방법 |
|---|---|---|---|---|---|---|
| 교사 Google 로그인 | 부분 구현: Firebase Auth/Google Sign-In 코드 존재, 실제 기기 검증 미확인 | 부분 구현: `AuthService` 존재, Firebase 설정 파일 없음 | Android SHA/OAuth, iOS URL scheme·reversed client ID | 중 | P0 | 양 플랫폼 실제 기기 로그인·로그아웃·재실행 |
| 학생 무계정 참여 | 부분 구현: 익명 Auth + 코드/앱 딥링크 | 부분 구현: 익명 Auth + 코드/앱 딥링크 | Firebase Anonymous Auth, 앱 설치 필요 | 중 | P0 | 두 기기에서 코드 입장, 익명 UID 유지/재발급 확인 |
| QR 참여 | 부분 구현: `moamal://join/{code}`, 웹 참여 아님 | 부분 구현: 같은 앱 딥링크; Android manifest만 설정, iOS URL scheme 누락 | Android intent filter, iOS `CFBundleURLTypes`, 향후 HTTPS/App Links | 중 | P0 | 앱 미설치/설치 상태 각각 QR 스캔; Android/iOS 콜드·웜 스타트 |
| 세션 생성·실시간 동기화 | 부분 구현: Firestore 3개 리스너 코드 | 부분 구현: 동등한 sessions/ideas/votes 리스너 코드 | Firebase 프로젝트 설정·rules·네트워크 | 중 | P0 | 교사 1 + 학생 2 실제 기기 동시 접속, 복귀/재접속 포함 |
| 원문 의견 수집 | 부분 구현: manual/STT 원문과 idea id 저장 | 부분 구현: `Idea(id,speaker,text,source)` 저장; `createdAt` 모델 보존은 불완전 | Firestore, 마이크 권한 | 중 | P0 | 한글/긴 문장/중복 의견 제출 후 원문·ID·순서 비교 |
| STT 입력 | 부분 구현: Whisper 직접 호출 | 부분 구현: `record` + Whisper 직접 호출; iOS `NSMicrophoneUsageDescription` 누락 | Android RECORD_AUDIO, iOS 마이크 권한·오디오 세션 | 중 | P1 | 권한 허용/거부, 짧은 발화, 백그라운드 전환, 한글 정확도 |
| AI 유사 그룹화 | 부분 구현: Gemini + 로컬 fallback + chunk buffer | 부분 구현: 동등 코드 존재 | 외부 API, Remote Config | 높음 | P0 | 고정 fixture로 idea 누락/중복 없음, fallback, 잘못된 JSON 검증 |
| `idea_ids`·안정적 `groupId` | 부분 구현: 기존 그룹 ID 재사용 휴리스틱, 병합/분리 정책 미확정 | 부분 구현: 같은 휴리스틱 이식 | AI 응답 비결정성, 투표 참조 무결성 | 높음 | P0 | 추가/병합/분리/재그룹화 fixture와 기존 투표 참조 회귀 테스트 |
| 교사 검토·수정·승인 | 계획/불완전: 그룹 표시만 있고 승인 상태의 저장 계약 없음 | 계획/불완전: `editable` 표시는 있으나 승인 workflow·Firestore 필드 없음 | 공통 데이터 계약 필요 | 높음 | P0 | AI 초안→교사 수정→승인 전 투표 차단→승인본 재접속 보존 E2E |
| 그룹 투표 | 부분 구현: 참가자별 1개 `groupId` 저장 | 부분 구현: 동일 계약, 투표 시작/닫기/초기화 UI 존재 | Firestore rules, 안정적 groupId | 중 | P0 | 중복 투표, 변경 투표, 닫힌 투표 거부, 그룹 재구성 후 무결성 |
| 기록·AI 리포트·공유 | 부분 구현: MeetingReport/공유 intent | 부분 구현: 리포트/`share_plus`; 영속 기록 계약은 불명확 | 외부 API, OS share sheet | 중 | P1 | 원문/그룹/투표 포함 리포트 생성, 재접속·공유 내용 검증 |
| 공용 화면 | 부분 구현: 같은 Android 앱의 display mode | 부분 구현: 교사 탭 내부 display; 독립 공개 화면 아님 | 태블릿/프로젝터 레이아웃 | 중 | P1 | Compact/Medium, 회전, 큰 글꼴, 장시간 실시간 갱신 |
| 비밀키 보호 | 위험: BuildConfig로 클라이언트 내장 | 위험: `--dart-define`로 클라이언트 내장 | 서버/Cloud Functions 필요 | 높음 | P0 | 저장소 secret scan, APK/IPA 문자열 검사, 서버 프록시 인증·제한 |
| Android 빌드 | 문서상 2026-07-07 성공, 이번 환경 미검증 | 확인 불가: Flutter SDK 없음; Gradle JVM 1GB/worker 2 설정 | JDK 17, Android SDK, Firebase 설정 | 중 | P0 | `flutter analyze`, `flutter test`, 제한 JVM 빌드 후 증액 재검증 |
| iOS 빌드 | 해당 없음 | 확인 불가/설정 미완료: Firebase plist·마이크 설명·딥링크 누락 | macOS/Xcode, signing, CocoaPods | 높음 | P0 | `flutter build ios --no-codesign`, 시뮬레이터+실기기 권한/링크 테스트 |

## 종단 간 P0 통과 조건

교사가 세션을 만들고, 학생 2명이 계정 생성 없이 코드/QR로 참여해 원문 의견을 제출하고, AI가 `idea_ids`를 보존한 초안을 만들고, 교사가 수정·승인한 뒤에만 안정적인 `groupId`로 투표가 열리며, 종료 후 원문·승인 그룹·투표·기록이 재접속 후에도 동일해야 한다.
