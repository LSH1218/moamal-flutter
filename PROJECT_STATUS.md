# Moamal Flutter 프로젝트 상태

> 기준일: 2026-07-17  
> 기준 커밋: `7cd5786fedb575db2e1dcdd7470e6687523c66f2` (이번 작업은 미커밋 상태)

## 기능 대응표

| 핵심 단계 | Android 기준 구현 | Flutter 주력 구현 | 판정 |
|---|---|---|---|
| 세션 생성 | Firestore publish 및 교사 화면 | `TeacherHomeScreen._startSession()` → `publishSession()` | 양쪽 구현, Flutter 실행 미검증 |
| 학생 참여 | 코드 + `moamal://join/{code}` QR 딥링크 | 코드 입력 + 딥링크 수신 + 익명 로그인 | 부분 대응; Flutter QR 생성/웹 참여 없음 |
| 의견 제출 | 수동/STT 의견 저장 | 학생 STT 의견 저장 | Flutter 부분 구현; 수동 텍스트 입력 없음 |
| AI 유사 그룹화 | Gemini + fallback + ID 안정화 | Gemini + fallback + 겹침 기반 ID 재사용 | 양쪽 코드 구현; Flutter 결과는 로컬 메모리만 |
| 교사 검토·승인 | 그룹 표시와 일부 편집 동작 | ClusterVoteScreen에 **"그룹 승인" 버튼 추가 (2026-07-17)** — `approveGroups()` → Firestore 배치 저장 | **코드 구현 완료**; 실기기 미검증 |
| 그룹 투표 | 계산된 그룹의 `group.id`로 투표 | 학생 화면이 **`approvedGroups` 구독** + **`groupId`로 투표 (2026-07-17)** | **코드 불일치 해결**; 실기기 미검증 |
| 기록 | 로컬 초안/AI 리포트/공유 | AI 리포트 생성·표시 | Flutter 영속 저장 확인 불가 |
| 실시간 동기화 | sessions + ideas + votes 구독 | 동일 3개 경로 + **approvedGroups (2026-07-17)** 구독 | **4개 경로 구현**; 화면 간 구독 소유권 위험 잔존 |
| STT | Whisper 클라이언트 직접 호출 | Whisper 클라이언트 직접 호출 | 코드 구현; 키/실기기 위험 |
| AI 보안 | 클라이언트 직접 호출 | `--dart-define` 키로 클라이언트 직접 호출 | 운영용 미완료 |

## 가장 작은 다음 통합 단위 — 완료 조건 점검

> "교사가 현재 AI 그룹 초안을 승인하면 Firestore에 승인 그룹 스냅샷이 저장되고, 학생 화면이 그 목록을 구독해 안정적인 `groupId`로 한 표를 제출하며, 교사 화면이 같은 ID로 집계한다."

| 완료 조건 | 상태 |
|---|---|
| 1. repository 단위 테스트에서 승인 그룹 직렬화/역직렬화가 원문 참조와 ID를 보존 | **코드 작성 완료** (`test/approved_group_test.dart`) — `flutter test` 미실행 |
| 2. 교사 승인 후 학생 스트림에 동일한 그룹 목록이 나타난다 | **코드 연결 완료** — 실기기 미검증 |
| 3. 학생 투표 문서의 `groupId`가 승인 그룹 문서 ID와 일치한다 | **코드 연결 완료** — 실기기 미검증 |
| 4. 교사 집계가 해당 그룹에 1표를 표시한다 | **코드 연결 완료** (`ClusterVoteScreen` 투표 바 차트 → `session.votes` 집계) — 실기기 미검증 |
| 5. 앱 재진입 뒤에도 승인 그룹과 투표가 유지된다 | **코드 연결 완료** (Firestore 영속) — 실기기 미검증 |

## 빌드·테스트 상태

- 2026-07-20: 사용자 제공 Android 실기기 사진으로 Flutter 앱 실행, 랜딩 화면 렌더링, 학생 역할 선택 후 세션 코드 입력 화면 전환을 확인했다.
- 판정: Android 실기기 UI 스모크 테스트 1차 성공. 세션 코드 참여 완료, Firebase 연결, 교사-학생 다기기 동기화, 그룹 승인·투표는 아직 실기기 미검증이다.
- 2026-07-17: `flutter --version`, `flutter pub get`, `flutter analyze`, `flutter test` 시도
- 결과: 현재 실행 환경 PATH에서 `flutter` 명령을 찾지 못해 전부 실행 불가
- 이번 작업 코드 변경: 정적 코드 검토로 일관성 확인; SDK 있는 환경에서 재실행 필요
- 판정: 빌드/테스트 성공으로 간주하지 않음

## 알려진 문제

- Firestore `approvedGroups` 보안 규칙이 없다 — Firebase 콘솔에서 추가 필요.
- `FirebaseMoamalRepository.listenToSession()`이 호출될 때 기존 구독을 중단하므로 동일 인스턴스를 여러 화면이 공유하면 구독 충돌 가능성이 있다 (`ClusterVoteScreen`이 같은 repo 인스턴스로 다시 구독).
- AI/STT API 키가 클라이언트 빌드에 포함되는 구조다.
- Flutter 저장소의 README는 기본 생성 템플릿 상태다.
- 실제 Firebase 환경, 보안 규칙 배포, Android/iOS 실기기 동작은 확인하지 못했다.
- `ClusterVoteScreen`의 `groups`는 화면 진입 시점의 스냅샷이다. 진입 후 새 의견이 들어와도 그룹이 자동 갱신되지 않는다 (기존 제한, 이번 작업 범위 밖).
