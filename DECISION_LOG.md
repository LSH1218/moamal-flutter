# DECISION_LOG

## 2026-07-22 — 전체 UI 반응형 리팩토링 (폰·태블릿·가로 모드)

- 상태: 결정 및 Flutter 코드 반영 완료, 빌드·실기기 검증 전
- 결정: 모든 화면의 고정 크기 레이아웃을 제거하고 MediaQuery·Expanded·ConstrainedBox·LayoutBuilder 기반 비율형 레이아웃으로 전환한다. 공통 브레이크포인트(`AppBreakpoints.compact = 600`, `medium = 900`)와 확장 유틸(`lib/utils/responsive.dart`)을 단일 진입점으로 관리한다.
- 근거: 초등 교실 환경에서 교사가 아이패드, 갤럭시탭, 스마트폰 가로 모드 등 다양한 기기를 사용한다. 고정 픽셀(`width: 350`, `height: 130`, `padding: all(32)` 등)이 레이아웃 overflow와 불균형한 여백을 유발했다.
- 주요 패턴 결정:
  - 브레이크포인트 < 600: compact(폰), ≥ 600: medium(폰 가로·태블릿 세로), ≥ 900: expanded(태블릿 가로) — 단 900 분기는 현재 미사용, compact/medium 2단계로 운영
  - SafeArea는 최상단 Scaffold 바디 또는 스크롤 가능 영역 최외곽에 배치, 헤더 내 `SafeArea(bottom: false)`와 혼용 허용
  - 다이얼로그·바텀시트는 `insetPadding` 또는 `constraints: sheetConstraints()`로 태블릿 maxWidth 520 제한
  - `_SttBox`의 높이 의존성을 `expand` 플래그로 분리 — Compact에서는 `ConstrainedBox(min:100, max:화면높이×0.22)`, Medium에서는 부모 `Expanded`가 결정
  - QR 뷰는 LayoutBuilder 또는 Builder로 `width * 비율`, clamp(min, max) 패턴 통일
  - FAB 하단 여백은 `MediaQuery.viewPaddingOf().bottom + 76` 동적 계산 — 홈 인디케이터(아이폰 34px) 대응
  - 학생 참여 화면(`join_screen`) body에 `SafeArea + SingleChildScrollView + ConstrainedBox(maxWidth: 480)` — 가로 모드 overflow 완전 차단
- 브랜드 컬러·버튼 스타일·비즈니스 로직: 변경 없음
- 텍스트 스케일: `main.dart`의 `maxScaleFactor: 1.3` 제한 유지
- 미검증 사항: 실제 iPad Pro 12.9", 갤럭시탭 S 가로 모드, iPhone SE(375px) 가로 모드에서 실기기 빌드 검증 필요
- 후속 결정: 900 이상 expanded 레이아웃 도입 여부(현재 medium과 동일), 공유 화면(DisplayTab) 전용 전체화면 레이아웃

## 2026-07-18 — STT 공급자 키를 Firebase Functions 뒤로 이동

- 상태: 결정 및 Flutter/Android 코드 반영·빌드 검증 완료, 배포 전
- 결정: Flutter와 Android 클라이언트의 OpenAI 직접 호출 및 빌드 키 주입을 제거하고, Firebase ID 토큰 인증 HTTPS Function이 Secret Manager의 키로 OpenAI Transcription API를 호출한다.
- 근거: 모바일 바이너리의 비밀키는 추출 가능하며 학생 음성과 비용 발생 API를 서버 측 인증·제한·로그 정책 아래 두어야 한다.
- 데이터 처리: 음성은 요청 처리 중 메모리에서만 외부 STT 공급자에 전달하며 Moamal 서버 저장소에는 저장하지 않는다.
- 운영 제약: Function이 먼저 배포되어야 새 Flutter STT가 동작한다. Secret은 환경별로 분리하고 구버전 클라이언트 키는 마이그레이션 후 폐기한다.
- 후속 결정: App Check 강제 시점, 보존·동의 문구, 환경별 호출 한도, Gemini 프록시 구조.
