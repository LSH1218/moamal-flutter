# MOAMAL_SHARED_CONTEXT

> Moamal 실행 대화방이 공유하는 단일 현황판이다. 계획과 실제 구현을 구분하며, 날짜와 코드 근거를 남긴다.

## 문서 정보

- 마지막 갱신일: 2026-07-20
- 갱신한 역할: 전략기획실·사업기획
- 기준 Flutter 커밋: `7cd5786fedb575db2e1dcdd7470e6687523c66f2` (이번 작업은 미커밋 상태)
- 기준 Android 커밋: `6e0442b2e78ee103a4bf0afdb5fb929c2919798a`

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
- 가격 근거: 공개 계약 검색에서 e알리미 학교·기관 계약 118.8만 원, 198만 원, 396만 원 사례를 확인. 제품 범위가 달라 Moamal 가격 근거가 아니라 학교 SaaS 예산 존재의 참고 증거로만 사용한다.
- 초기 BM 원칙: 파일럿 무료. 파일럿 종료 인터뷰에서 개인 교사 월/연 결제와 학교 연간 결제를 각각 질문하되 가격을 먼저 제시하지 않는다.

## 3. 핵심 교실 시나리오

1. 교사가 세션을 만든다. — Flutter 부분 구현
2. 학생이 QR/코드로 참여한다. — Flutter 코드 참여 구현, QR 생성 UI는 확인되지 않음
3. 학생이 의견을 제출한다. — Flutter STT 제출 구현, 수동 텍스트 제출은 확인되지 않음
4. AI가 유사 의견을 그룹화한다. — Flutter 클라이언트 로컬 상태로 부분 구현
5. 교사가 결과를 수정·승인한다. — **구현 완료(코드)**: ClusterVoteScreen에 "그룹 승인" 버튼, `approveGroups()` → Firestore 배치 저장
6. 참여자가 그룹 단위로 투표한다. — **구현 완료(코드)**: 학생 화면이 `approvedGroups`를 구독해 `groupId`로 투표
7. 교사가 결과와 기록을 저장한다. — 리포트 생성/표시 부분 구현, 영속 저장은 확인되지 않음

- 현재 종단 간 성공 범위: 코드 기준 세션 생성 → 코드/딥링크 참여 → STT 의견 제출 → AI 그룹화(로컬) → 교사 승인 → Firestore `approvedGroups` 저장 → 학생 구독 → 그룹 단위 투표까지 **코드 연결 완료**
- 막히는 단계: 학생 웹 참여, 실제 교실 종단 간 검증, 그룹 승인/투표의 Firebase 규칙, Gemini 종료 모델 이전
- 다음 테스트 조건: 성인 6~10명 모의 학급회의에서 교사 1대·학생 3대 이상으로 참여, STT 10회 이상, 중복 의견 3쌍 이상, 승인 그룹 투표와 결과 저장까지 완료

## 4. 구현 현황

| 영역 | 구현 완료 | 부분 구현 | 계획/미구현 | 최근 검증 |
|---|---|---|---|---|
| Flutter 앱 | Firestore 세션/의견/투표/승인그룹 repository, 코드·딥링크 참여 경로, 교사 승인 UI, 학생 그룹 투표, Android 실기기 앱 실행·랜딩·학생 참여 화면 전환 | 교사/학생 화면, 실시간 구독, 기록 화면 | 수동 텍스트 입력, 세션 참여 이후 종단 간 실기기 검증 | 2026-07-20 사용자 제공 Android 실기기 사진 2장 |
| Android 기준 앱 | 세션, 앱 딥링크 QR, 의견, AI 그룹화, 투표, 리포트 코드 | 그룹 ID 안정화와 생명주기 | 웹 참여 | 2026-07-17 코드/문서 확인; 빌드 재검증 안 함 |
| AI | Android/Flutter Gemini 그룹화와 로컬 fallback | `idea_ids` 및 겹침 기반 ID 재사용 | 서버 프록시, 병합/분리 정책, 승인 스냅샷 | 코드 확인 |
| STT | Android/Flutter 클라이언트와 Firebase Functions 서버 프록시 구현·빌드 검증(사용자 제공 최신 상태) | push-to-talk 입력 | Secret Manager·Functions 배포, 교실 환경/권한/실기기 검증 | 로컬 프록시 소스 위치는 이번 작업공간에서 확인 불가; 배포 미완료 |
| Firebase/백엔드 | 세션·ideas·votes·approvedGroups 구조와 Flutter repository | 익명 인증/실시간 구독 코드 | 서버 AI/STT, 규칙·배포 재검증 | 코드 확인; 실 Firebase 미검증 |
| Flutter UI/UX | Compact/Medium 교사·학생 화면 코드, 교사 승인 버튼, 학생 그룹 투표 카드 | 오류/빈 상태 일부 | QR 표시/스캔 검증, 수동 텍스트 입력 | 코드 확인 |
| 홈페이지 | 확인 불가 | 확인 불가 | 학생 웹 참여 | 해당 저장소 미확인 |

## 5. 배포·운영 현황

- Android 빌드: Android 문서는 2026-07-07 성공이라고 기록하나 현재 환경에서 재검증하지 않음
- Flutter Android 빌드·실행: **1차 성공(2026-07-20, 사용자 제공 실기기 사진)**. Android 실기기에서 랜딩 화면이 정상 렌더링되고 학생 역할 선택 후 6자리 세션 코드 입력 화면으로 전환됨. APK 생성 명령·빌드 로그는 이번 대화에서 확인하지 않았으며, 세션 참여 완료·Firebase 연결·다기기 동기화는 아직 미검증
- Flutter iOS 빌드: Windows 환경이라 확인 불가
- 2026-07-17 개발 PC 진단: Android Studio 2026.1.2, Flutter 3.44.6, Dart 3.12.2, Android API/Build Tools 36.0.0, JDK 21 설치 완료. Android toolchain과 라이선스 정상. 연결 기기 `R59MA03BRCN`은 USB 디버깅 미승인
- Firebase 환경: 사용자가 2026-07-17 현재 Android 저장소의 `firestore.rules`와 동일한 규칙을 Firebase에 입력했다고 보고함. 규칙의 `게시` 완료 여부는 확인 불가. 실제 개발 저장소 `C:\Users\pc\Desktop\moamal-flutter\android\app\google-services.json` 배치를 확인했으며 프로젝트 ID는 `moamal-1e601`, 패키지 `com.moamal.prototype` 일치. 설정 파일은 점검용 복제 저장소에는 복사하지 않음
- 백엔드 배포: OpenAI STT Firebase Functions 프록시는 양쪽 구현·빌드 검증됐다는 최신 상태를 사용자로부터 확인. Secret Manager와 Functions 실배포는 Blaze 연결 전이라 보류. 현재 작업공간에서는 프록시 소스 위치를 확인하지 못했으므로 배포 완료로 간주하지 않는다.
- 분석/오류 추적: 확인 불가

## 6. 주요 위험

| 위험 | 영향 | 상태/근거 | 대응 |
|---|---|---|---|
| ~~Flutter 학생 투표가 그룹이 아닌 `idea.id`에 저장됨~~ | ~~높음~~ | **해결됨 2026-07-17** — `_VoteList`가 `approvedGroups`를 사용 | 완료 |
| ~~Flutter 그룹이 로컬 메모리에만 존재~~ | ~~높음~~ | **해결됨 2026-07-17** — `approveGroups()` Firestore 배치 저장 | 완료 |
| ~~교사 승인 단계 없음~~ | ~~높음~~ | **해결됨 2026-07-17** — ClusterVoteScreen에 승인 버튼 추가 | 완료 |
| Gemini/OpenAI 키가 클라이언트 빌드 인자로 들어감 | 높음 | 확인됨 | 서버/Cloud Functions 프록시로 이전; 비밀값 커밋 금지 |
| 한 repository 인스턴스의 `listenToSession()`이 기존 구독을 중단 | 중간 | 확인됨 — ClusterVoteScreen이 동일 repo로 다시 호출 | 화면 간 구독 소유권 분리 또는 단일 상태 계층 도입 |
| 웹 참여를 구현으로 오인 | 높음 | 현재 딥링크만 확인 | 앱 딥링크임을 명시 |
| Android 빌드 차단 | 중간 | 기존에는 `google-services.json` 누락으로 중단됐으나 2026-07-17 실제 개발 저장소에 파일 배치와 패키지 일치를 확인. 재빌드는 아직 미실행 | 실제 개발 저장소에서 재빌드 |
| Firestore `approvedGroups` 보안 규칙 미설정 | 중간 | 신규 컬렉션이므로 기존 rules에 없음 | Firebase 콘솔에서 ownerUid만 write 가능하도록 규칙 추가 필요 |
| 학생 투표 리스너와 현재 규칙 충돌 | 높음 | 규칙은 학생에게 `votes/{본인UID}`만 읽도록 허용하지만 앱은 `votes` 컬렉션 전체를 구독 | 공개 집계 문서/교사용 원본 투표를 분리하거나 권한별 리스너 계약 수정 |
| 인증 사용자 간 세션 격리 없음 | 높음 | 현재 규칙의 세션·ideas 읽기가 `signedIn()`만 요구 | 참여 권한 문서 또는 별도 참여 토큰 검증 도입 |
| 학생이 다른 의견을 수정 가능 | 높음 | `ideas`의 `create, update`가 모든 인증 사용자에게 허용 | 작성자 UID와 허용 필드 검증; 학생 update 금지 또는 본인 문서만 허용 |
| `gemini-2.0-flash-lite` 종료 | 높음 | 코드에 남아 있으며 공식 종료일 2026-06-01 경과 | `gemini-3.1-flash-lite` 후보로 런타임·JSON 품질·비용 재검증 |
| STT를 경쟁력과 동일시 | 높음 | 최초 교사는 음성+묶기+투표 전체 흐름을 제안 | STT 사용률·교정률과 전체 과업시간을 분리 측정 |
| 단일 교사 요구를 시장으로 일반화 | 높음 | 정성 증거 1명, 반복 사용·지불 의향 없음 | 디자인 파트너 1명 + 독립 교사 2~4명으로 확장 검증 |

## 7. 현재 우선순위

1. 아이디어 제공 교사 재인터뷰: 최초 문제, 현재 우회 방법, 반드시 필요한 기능, 실제 수업 날짜와 디자인 파트너 동의 확인
2. 성인 6~10명 최소 모의 수업: STT → 그룹 승인 → 투표 → 기록까지 실패 지점과 시간을 측정
3. 파일럿 필수 차단 요소만 수정: 보안 규칙, Gemini 모델 이전, STT 프록시 배포, 오류 복구, 수동 입력 fallback
4. 2~4주 파일럿: 3명 교사, 총 6~12개 수업을 목표로 하되 디자인 파트너 1명부터 순차 시작
5. 2026-08-21 계속/피벗/폐기 판정

## 8. 대화방별 다음 행동

- **App 개발**: `flutter analyze` 후 오류 수정; 실기기 통합 테스트
- **백엔드**: `approvedGroups` Firestore 보안 규칙 추가 (ownerUid 소유자만 write)
- **AI**: 병합/분리 시 stable `groupId` 정책과 스키마 검증 정의 (기존 과제)
- **Flutter UI/UX**: 교사 클러스터 카드에 `editable: true` 편집 흐름 설계 (다음 단계)
- **STT**: 핵심 그룹 투표 연결 완료 — 이제 키 노출 서버 프록시 이전 논의 가능

## 9. 최근 변경 기록

| 날짜 | 역할 | 변경 내용 | 검증/근거 | 다른 방에 미치는 영향 |
|---|---|---|---|---|
| 2026-07-17 | 백엔드/Firebase | 사용자가 기존 `firestore.rules`와 동일한 규칙을 Firebase에 입력했다고 보고. 실제 개발 저장소에 `google-services.json` 배치 완료 | 파일 존재, 프로젝트 `moamal-1e601`, 패키지 `com.moamal.prototype` 일치 확인; 실제 콘솔 규칙 게시 상태와 빌드는 미확인 | Firebase 설정 파일 누락 차단은 해소됐으며 Android 재빌드 가능 |
| 2026-07-17 | App 개발 (승인 그룹 통합) | `ApprovedGroup` 모델 신설; `SessionState`에 `approvedGroups` 추가; `MoamalRepository.approveGroups()` 추가; `FirebaseMoamalRepository`에 4번째 구독(`approvedGroups`)과 배치 저장 구현; `ClusterVoteScreen`에 "그룹 승인" 버튼 추가; `StudentSessionScreen._VoteList`를 `approvedGroups` 기반으로 수정; `test/approved_group_test.dart` 추가 | 코드 정적 확인; `flutter analyze` / `flutter test`는 SDK 부재로 미실행 | AI·백엔드·UI가 동일한 `approvedGroups` 스키마를 사용해야 함 |
| 2026-07-17 | App 개발 | 양쪽 저장소 기능 대응표 작성, 최소 다음 통합 단위를 승인 그룹 스냅샷으로 결정 | 기준 커밋의 README/PROJECT_STATUS/실제 코드 | AI·백엔드·UI가 동일한 그룹 계약을 사용해야 함 |
| 2026-07-17 | Flutter UI/UX | 테마·라우팅·화면·상태관리·공통 컴포넌트와 상태 UI 정적 점검 | Flutter `lib/`, `test/`, `pubspec.yaml` | 공용 화면 연결과 오류·오프라인·권한 상태를 통합 범위에 포함 |
| 2026-07-18 | 전략기획실 | 최초 교사 대화 근거 반영, STT 유지·디자인 파트너 파일럿·개발 동결·판정일 결정 | 첨부 대화 5장, 사용자 제공 최신 기술 상태, 공개 학교 계약 사례, 공식 Gemini 지원 중단 문서 | 전 실행 방은 학급회의 파일럿 필수 범위 외 신규 기능을 동결 |
| 2026-07-20 | Flutter UI/UX | Flutter Android 실기기 1차 실행 성공 기록: 랜딩 렌더링과 학생 참여 화면 전환 확인 | 사용자 제공 실기기 사진 2장 | App 개발은 다음 검증을 세션 참여·Firebase 동기화·승인 그룹 투표로 확장 |

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

## 11. Flutter UI/UX 코드 감사 (이전 기록 유지)

- 구현 완료(코드 확인): Material 3 색상 테마, 랜딩·학생 코드 참여·교사 라이브 홈·학생 세션·그룹/투표·리포트 화면, 600px 기준 compact/medium 분기, 일부 로딩·빈 상태·SnackBar 오류 피드백.
- 부분 구현: 라우팅은 `MaterialPageRoute` 직접 호출, Provider는 서비스 주입용, 화면 상태는 `setState`와 stream 구독 중심이다. `FacilitatorTab`·`StudentTab`·`DisplayTab` 파일은 현재 라우팅에서 사용되지 않는다.
- 계획/미구현: Firestore `hasError` 전용 UI와 재시도, 연결 끊김·재연결, 영구 권한 거부 후 설정 이동, 교사 그룹 수정 UI, 공유 화면 진입, 공통 상태 컴포넌트, 골든 테스트.
- 지원 기기: 레이아웃 코드상 compact/medium만 확인. Android 휴대폰·태블릿, iPhone, iPad, 공유 화면의 실제 검증은 확인 불가.
- 공통 컴포넌트 후보: responsive shell/breakpoint, Moamal app bar/logo, action/button, panel/card, session code/QR panel, loading/empty/error/offline/permission status view, live badge, vote row/bar, STT recorder/status. 현재 별도 위젯은 `GroupCard`, `MicButton`, `StatRow`다.
- 접근성 위험: 전역 텍스트 배율을 최대 1.3으로 제한한다.
