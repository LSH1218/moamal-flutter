# 리포트 기능 재설계·구현 기록 (2026-09-04)

> 이 문서는 "리포트 기능" 대화방에서 하루 동안 진행한 논의·설계 결정·구현·검증을 시간 순으로 상세히 남긴다. 요약은 `MOAMAL_SHARED_CONTEXT.md` §8을 참고하고, 이 문서는 그 근거와 세부 과정을 담는다.

## 1. 문제 제기

대표가 "리포트 저장/공유" 기능이 핵심 기능(STT·그룹화·투표)에 밀려 **개념 설계 없이 기능만 겨우 붙어있는 상태**라고 문제 제기했다.

기존 상태(`lib/screens/teacher/report_screen.dart`):
- "AI 요약 생성"이 승인된 그룹별 대표 인용문 1개씩만 요약하는 **그룹 단위** 요약
- "저장/공유"는 그 텍스트를 안드로이드 네이티브 공유 시트로 던지는 게 전부
- 참여자 수·발언 수·수업 시간 통계 타일 외엔 구조화된 데이터 없음
- 동작 자체는 2026-09-03 GR R-8에서 정상 확인됨(`Mercury-Report-06` 종결)

## 2. 코드 조사로 밝혀진 사실

리포트 화면·모델을 읽어본 결과, 두 가지 중요한 사실을 확인했다.

### 2-1. `Idea.speaker`는 실제 이름이 아니다

`lib/screens/student/student_session_screen.dart:467`에서 학생이 의견을 낼 때 `speaker` 필드가 항상 문자열 `'학생'`으로 하드코딩되어 있었다. 즉 클라이언트 모델 어디에도 "누가 이 발언을 냈는지"가 없었다.

### 2-2. 하지만 데이터 자체는 이미 있었다

- `lib/repositories/firebase_moamal_repository.dart:61-70`의 `submitIdea()`가 이미 `authorUid`를 Firestore `ideas` 문서에 기록하고 있었다(`Common-Rules-01` 보안 규칙 검증용). 다만 `Idea.fromFirestore()`가 이 필드를 클라이언트로 읽어오지 않았을 뿐이다.
- `lib/models/participant.dart`에는 이미 `uid` + `number` + `name`(학생이 입장 시 입력)이 있었다.
- `firestore.rules:49-54`를 보면 `votes/{participantId}` 문서 ID가 곧 학생 uid이고, 교사(`isOwner`)는 이미 개별 학생이 누구에게 투표했는지 전부 읽을 수 있는 권한이 있었다. 학생끼리 서로의 투표를 못 보게 막은 것(`Common-Rules-04`, 비밀투표)이지 교사에게 막은 게 아니었다.

**결론**: "학생별 참여·발언 기록"은 신규 데이터 수집이 아니라, 이미 Firestore에 있는 `ideas.authorUid` ↔ `participants.{number,name}` ↔ `votes/{uid}`를 조인해 클라이언트로 배선하는 문제였다.

## 3. 설계 논의와 결정

### 3-1. 리포트 화면 vs 브리핑 탭 역할 분담

대표가 밝힌 목표는 두 가지였다 — ① 교사가 리포트로 평가를 할 수 있게, ② 수업 직후 한눈에 볼 수 있게. 이 둘이 서로 다른 데이터 모양을 요구한다는 게 처음 문제의식이었다.

코드를 보니 이미 `teacher_home_screen.dart`의 브리핑 탭(`_buildBriefingTab()`)이 ②(수업 중 실시간 안내: 지금 흐름·교사가 할 일·추천 질문)를 담당하고 있었다. 이걸 근거로:

- **브리핑 탭** = 수업 **중** 실시간 안내(②, 기존 유지)
- **리포트 화면** = 수업 **후** 영속 기록 + 평가(①, 신규 설계 중심)

로 역할을 나누되, 완전 분리(A안)가 아니라 **리포트 상단에 "오늘 흐름 요약"을 남기는 절충안(B안)**으로 확정했다. 리포트만 열어도 그날 흐름을 놓치지 않게 하기 위해서다. 이건 기존에 있던 `MeetingReport.overview`/`_TopicsPanel`을 그대로 살리는 것이라 추가 비용이 거의 없었다.

### 3-2. 일반 회의록 구조와의 비교

"보통 회의를 하면 뭘 기록하는가"를 짚어보니, 표준 회의록(한국 초등 학급회의록 포함) 구조는 대략: 일시·장소, 참석자 명단, 안건, 토의 내용, 결정사항, 실천사항.

기존 `MeetingReport` 모델을 이 틀에 대응시켜보니 이미 상당히 맞아떨어졌다:

| 회의록 항목 | MeetingReport 필드 | 상태 |
|---|---|---|
| 토의 내용 | `overview` + `groups[].keyQuote` | 이미 있음 |
| 결정사항 | `conclusion`, `voteSummary` | 이미 있음 |
| 실천사항 | `nextAction` | 이미 있음 |
| 미결 쟁점 | `unresolved` | 이미 있음 |
| 참석자 명단 | 없음 | **빠짐** |
| 개인별 발언 | 없음 | **빠짐** |

즉 "개념 설계가 없다"는 문제의식과 달리, 그룹/세션 단위 회의록 골격은 이미 갖춰져 있었고, 진짜 빠진 건 참석자 명단과 개인별 발언 두 가지였다.

### 3-3. 토론·심포지엄 확장을 고려한 설계 원칙

대표가 "학급회의는 기술실증이고, 진짜 목표는 토론·심포지엄 평가"라고 명확히 했다. 다만 `MOAMAL_SHARED_CONTEXT.md` §2에 "최초 범위는 학급회의 한 종류로 고정한다. 토론 평가·심포지엄·입장 전환 토론·퀴즈는 후속 검증 전 개발 동결한다"는 원칙이 있어, 토론용 필드(진영·역할·발언순서·루브릭)를 지금 추측해서 만들지 않기로 했다.

대신 원칙만 세웠다: 개인별 발언 기록을 "학급회의 전용"이 아니라 "**학생 uid 기준 발언 로그**"로 일반적인 모양으로 설계한다. `uid → [{발언 내용, 시각, 속한 그룹/주제}]`라는 최소 구조는 학급회의에도 필요한 것이라 지금 당장 추가 비용이 없고, 나중에 토론이 풀리면 여기에 `진영`이나 `역할` 같은 필드를 **얹는** 확장이 되지 구조를 갈아엎는 게 아니게 된다.

### 3-4. "공유" → "내보내기" 재정의, 실명 노출 결정

기존 "저장/공유" 버튼은 `share_plus`로 텍스트를 안드로이드 공유 시트에 던지는 것 — "누군가에게 보내기"를 전제로 한 기능이었다. 그런데 대표가 원한 건 "보내기"가 아니라 **본인이 학교 인트라넷·나이스 생활기록부에 옮겨 넣을 수 있는 형태로 저장**하는 것이었다.

흥미롭게도 코드에 이 방향의 흔적이 이미 있었다 — `_MediumBody`(태블릿 레이아웃)의 버튼 라벨이 이미 "PDF 내보내기 / 학교 시스템 연동"이라고 적혀 있었는데, 실제 동작은 여전히 옛날 텍스트 공유였다.

논의 끝에 결정한 방향:
- **"내보내기"(파일 생성) 중심으로 재정의**하되, 같은 표준 OS 공유 시트로 카톡/문자 등 외부 공유도 겸용한다 — 파일이 곧 카톡으로도, 인트라넷 업로드로도 갈 수 있으니 하나의 메커니즘으로 충분하다.
- **학생 실명을 그대로 노출한다** — 목적지가 교사 본인의 공인 시스템(생활기록부 등)이라는 전제이고, 공유 시트 자체가 매번 목적지를 교사가 직접 고르는 구조라 텍스트 공유 때보다 위험이 커지지 않는다는 판단.
- 형식은 **PDF(사람이 읽는 회의록)와 CSV(표 데이터, 나이스 등 시스템 붙여넣기용)** 둘 다 만들되, PDF부터 먼저 구현한다.

## 4. 구현 순서와 세부 내용

작업은 "개인별 발언 기록(2번)" → "투표 참여 여부(3번)" → "참석자 명단(1번)" → "PDF 내보내기(5번-PDF)" → "실기기 검증" → "CSV 내보내기(5번-CSV)" 순서로 진행했다.

### 4-1. `Idea.authorUid` 추가

`lib/models/idea.dart`에 `authorUid` 필드를 추가하고 `fromFirestore()`가 파싱하도록 수정했다. 기존에 Firestore 규칙 검증용으로만 쓰이던 필드를 리포트의 학생별 발언 귀속에 재사용한다.

### 4-2. `_StudentRecordsPanel` / `_StudentRecordCard` 신설

`lib/screens/teacher/report_screen.dart`에 새 위젯을 추가했다.

- `session.participants`를 번호순으로 정렬
- `ideas.authorUid`로 학생별 발언 목록을 조인 (`Map<String, List<Idea>>`)
- `session.votes`(이미 `SessionState`에 로드돼 있어 신규 Firestore 구독 불필요)로 "투표: 그룹명" / "투표 안 함" 표시
- `authorUid`가 없는 구버전 발언은 특정 학생에게 귀속시키지 않고 "작성자 미상 N건"으로 따로 표시
- 참석 요약 라인("참석 N명" 또는 "참석 N명 · 종료 시점 접속 M명")과 개별 "이탈함" 배지(`participant.isActive` 기준) 추가
- 섹션 제목: "학생별 발언 기록" → "**참석자 · 학생별 발언 기록**"

컴팩트(모바일)·미디엄(태블릿) 레이아웃 둘 다에 삽입했다.

### 4-3. `_StatRow`의 "참여" 통계 버그 수정

기존 코드:
```dart
value: '${session.votes.isNotEmpty ? session.votes.length : session.ideas.length}명'
```
발언도 투표도 안 한 학생을 아예 못 세는 부정확한 근사치였다. `session.participants.length`(실제 누적 출석)로 교체했다(participants가 비어있는 아주 오래된 세션 데이터를 위해 기존 근사치를 폴백으로 남겨둠).

### 4-4. `MeetingReport.toPlainText()` 확장

화면에 보이는 정보와 공유되는 텍스트가 일치해야 한다는 원칙에 따라, `lib/models/meeting_report.dart`의 `toPlainText()`에 `participants`/`ideas`/`votes`/`groupTitleById` 선택 인자를 추가하고 `[ 참석자 · 학생별 발언 기록 ]` 섹션을 덧붙이도록 확장했다. 화면의 조인 로직과 동일한 규칙을 그대로 재사용한다.

### 4-5. PDF 내보내기 (`lib/services/report_pdf_exporter.dart`)

- `pdf`, `printing` 패키지 추가
- 한글 렌더링은 `PdfGoogleFonts.notoSansKRRegular/Bold`(printing 패키지)로 해결 — 런타임에 구글 폰트를 다운로드해 캐싱하는 방식이라 리포에 폰트 파일을 직접 넣지 않는다. **최초 생성 시 기기 인터넷 연결이 필요**하다는 제약이 있다.
- `buildReportPdf()`가 화면·`toPlainText()`와 동일한 조인 규칙으로 전체 흐름/의견 묶음/투표 결과/결론/미결 쟁점/교사 후속 조치/참석자·학생별 발언 기록을 A4 PDF로 구성한다.
- `report_screen.dart`의 "저장/공유" 버튼(appbar 퀵액션 + 본문 CTA)을 `_exportPdf()`로 교체 — `Printing.sharePdf()`가 표준 OS 공유 시트를 그대로 띄운다.
- 테스트(`test/report_pdf_exporter_test.dart`)는 네트워크 의존을 피하려고 폰트 로더를 주입 가능하게 설계(`regularFontLoader`/`boldFontLoader` 파라미터) — 기본 pdf 내장 폰트(Helvetica)로 구조·조인 로직만 검증한다(한글 글리프 자체는 검증 대상이 아님, PDF magic bytes로 유효성만 확인).

### 4-6. CSV 내보내기 (`lib/services/report_csv_exporter.dart`)

- `csv` 패키지 추가(8.0.0 — `ListToCsvConverter`가 아니라 `Csv` 클래스 기반의 새 API를 씀에 유의)
- PDF가 "사람이 읽는 회의록"이라면 CSV는 "학교 인트라넷·나이스처럼 표 데이터를 기대하는 곳에 붙여넣기용"이라는 성격 차이를 명확히 하고, 서술형 섹션(전체 흐름·결론 등)은 CSV에 담지 않고 **학생별 행만** 담았다.
- 컬럼: 번호, 이름, 참석 상태, 발언 건수, 발언 내용(`|`로 구분), 투표 여부, 투표 대상
- `Csv(addBom: true).encode(rows)`로 UTF-8 BOM을 붙여 엑셀에서 한글이 깨지지 않게 했다.
- `Printing` 패키지는 PDF 전용이라, CSV는 `path_provider`로 임시 디렉터리에 파일을 직접 쓴 뒤 `share_plus`의 `Share.shareXFiles()`로 공유 시트를 띄우는 방식을 썼다.
- `report_screen.dart`의 "내보내기" 버튼을 **형식 선택 바텀시트**(`_showExportSheet()`)로 바꿔 PDF/CSV 중 고르게 했다. appbar 퀵액션과 본문 CTA가 이 시트를 공유한다.
- 테스트(`test/report_csv_exporter_test.dart`) 4건: UTF-8 BOM 확인, 헤더·번호순 정렬, 이탈 학생 표시, 쉼표·줄바꿈이 든 발언의 CSV 왕복(quote/escape) 무결성.

## 5. 실기기 검증 (Claude가 adb로 수행 — QA 분담 원칙: 화면전환·로그는 Claude, STT·터치감은 사용자)

에뮬레이터(`emulator-5554`, Android 14)=교사, 실기기 SM A305N(`R59MA03BRCN`, Android 11)=학생으로 새 세션(코드 `7Y01NM`)을 만들어 전 과정을 검증했다.

1. **참석만(발언 없이)**: 참여 통계 "1명" 정확히 표시 — `_StatRow` 버그 수정이 실제로 해결됐음을 확인 (이전 로직이었다면 0으로 잘못 셌을 상황).
2. **사용자가 학생 기기 마이크로 실발화** 3회("경복궁 말고 롯데월드 같은...", "앞에 산인 남산에 가서...", "이번 소풍은 경복궁으로") → 참여 1·발언 3·AI그룹 1로 정상 반영. "참석자 · 학생별 발언 기록"에 "1번 김철수 · 발언 3건"과 실제 발언 3건 전부 정상 렌더링(레이아웃 깨짐 없음).
3. **"AI 요약 생성"** → 리포트 생성 성공 → "내보내기" 버튼 활성화.
4. **PDF 경로**: 버튼 탭 → 로딩 스피너 → 표준 공유 시트에 실제 파일 `모아말_수업기록_7Y01NM.pdf` 등장(Nearby Share·인쇄·Drive·메시지·블루투스). "인쇄" 옵션으로 PDF 렌더링을 직접 열어 확인 — **노토산스 한글 폰트가 정상 다운로드·임베드**되어 전체 흐름/의견 묶음/투표 결과/결론/미결 쟁점/교사 후속 조치/참석자·학생별 발언 기록 전 섹션이 한글 깨짐 없이 출력됨.
5. **CSV 경로**: "내보내기" → 바텀시트에서 CSV 선택 → 공유 시트에 실제 파일 `모아말_학생기록_7Y01NM.csv` 등장(Nearby Share·Drive·Gmail). `adb shell run-as com.moamal.prototype cat cache/...csv`로 파일을 직접 당겨 내용을 확인 — 헤더와 학생 행(`1,김철수,접속 중,3,경복궁 말고 롯데월드 같은... | 앞에 산인 남산에... | 이번 소풍은 경복궁으로 가요.,투표 안 함,`)이 정확했다.

디버깅 메모: 에뮬레이터 UI 좌표는 `adb shell uiautomator dump`로 정확한 `bounds`를 구해서 탭했다(스크린샷 픽셀을 눈대중으로 계산하면 배율(예: 900x2000 표시 → 1080x2400 실제) 때문에 자꾸 빗나갔다). Windows Git Bash에서 `adb ... /sdcard/...` 같은 절대경로는 MSYS 경로 변환 때문에 깨지므로 `export MSYS_NO_PATHCONV=1`이 필요했다.

## 6. 테스트·정적 분석 최종 상태

- `flutter analyze`: 신규 이슈 0건 (기존 경고 10건 그대로 — 이번 작업과 무관)
- `flutter test`: **39/39 통과**
  - `test/report_student_records_test.dart` (13건 — Idea.authorUid 파싱, 학생별 발언 조인, 참석/이탈 표시)
  - `test/report_pdf_exporter_test.dart` (2건)
  - `test/report_csv_exporter_test.dart` (4건)
  - 기존 20건(참여자 라이프사이클, 세션 재개, 그룹 스냅샷 등) 회귀 없음

## 7. 변경 파일 목록

- `lib/models/idea.dart` — `authorUid` 필드 추가
- `lib/models/meeting_report.dart` — `toPlainText()`에 학생별 발언·참석·투표 섹션 추가
- `lib/screens/teacher/report_screen.dart` — `_StudentRecordsPanel`/`_StudentRecordCard` 신설, `_StatRow` 참여 통계 수정, PDF/CSV 내보내기 바텀시트
- `lib/services/report_pdf_exporter.dart` — 신규
- `lib/services/report_csv_exporter.dart` — 신규
- `test/report_student_records_test.dart` — 신규
- `test/report_pdf_exporter_test.dart` — 신규
- `test/report_csv_exporter_test.dart` — 신규
- `pubspec.yaml` — `pdf`, `printing`, `csv` 패키지 추가
- `MOAMAL_SHARED_CONTEXT.md` §8 — 논의·결정·구현·검증 진행 기록

## 8. 남은 것

§8에 정리된 대로, 오늘 논의에서 나온 1~5번 항목은 전부 구현·검증이 끝났다. 남은 건 대표가 실제 파일럿에서 리포트 기능을 써보며 나오는 피드백을 반영하는 것, 그리고 토론·심포지엄 기능이 실제로 풀릴 때 §3-3의 원칙(학생 uid 기준 로그에 진영/역할 필드를 얹는 확장)에 따라 별도로 설계하는 것이다.

## 9. 사후 발견 버그: 리포트 화면 세션 스냅샷 고정 (`Gemini-9-Report-02`)

1~5번 구현이 끝난 뒤, 대표가 실사용 중 발견했다: **리포트를 생성한 뒤 학생이 투표해도, 리포트 화면을 나가지 않고 그대로 보고 있으면 투표 결과가 반영되지 않는다.**

### 9-1. 원인

`TeacherHomeScreen._goToReport()`가 `Navigator.push()`할 때 `ReportScreen`에 그 순간의 `SessionState`를 **값으로 한 번만** 넘기고 있었다:

```dart
builder: (_) => ReportScreen(session: _session, ...)
```

`MaterialPageRoute`의 `builder`는 push 시점에 한 번 호출될 뿐, 부모(`TeacherHomeScreen`)가 이후 `setState`로 아무리 갱신돼도 이미 만들어진 `ReportScreen` 인스턴스를 다시 빌드하지 않는다. 즉 `session` 필드는 그 순간의 **고정 스냅샷**이었다.

같은 코드베이스의 `OrganizeScreen`·`BeamProjectorScreen`·`ClusterVoteScreen`은 이미 이 문제를 알고 있었다 — `organize_screen.dart`의 문서 주석에 "화면이 직접 `listenToSession()`을 부르면 리포지터리가 기존 구독을 끊고 새로 만들기 때문에 build마다 재구독이 발생한다(`Mercury-3-Student-01`)"고 적혀 있고, 대신 교사 홈이 만든 broadcast 스트림(`_sessionStream`)을 그대로 받아 `StreamBuilder`로 실시간 갱신하는 패턴을 쓰고 있었다. 리포트 화면만 이 패턴이 빠져 있었던 이유는, 애초에 리포트 화면엔 "실시간으로 바뀌는 걸 보여줘야 할 것"이 거의 없었기 때문이다(그룹 요약은 한 번 생성하면 끝, 통계는 참고용). 오늘 학생별 투표 표시를 추가하면서 처음으로 "화면이 열려 있는 동안 계속 바뀌는 데이터"가 리포트에 생겼고, 그래서 이 공백이 드러났다.

### 9-2. 수정

- `report_screen.dart`: `ReportScreen`에 `required this.sessionStream`(`Stream<SessionState>`) 파라미터 추가. `_ReportScreenState`에 `_session` 필드와 `StreamSubscription<SessionState>? _sessionSub`를 두고, `initState()`에서 `widget.sessionStream.listen()`으로 구독해 `_session`을 계속 갱신(`dispose()`에서 해제). `_exportPdf()`·`_exportCsv()`·`build()`가 전부 `widget.session`(고정값) 대신 `_session`(최신값)을 참조하도록 교체
- `teacher_home_screen.dart`: `_goToReport()`가 기존 `_sessionStream`(이미 있던 broadcast 스트림 — `_goToSummary()`·`_goToProjector()`와 동일하게 재사용, 새로 구독하지 않음)을 전달하도록 수정. 스트림이 준비되기 전엔 진입하지 않는 가드도 다른 `_goTo*` 메서드와 동일하게 추가

### 9-3. 검증

`flutter analyze` 신규 이슈 0(기존 10건 그대로), `flutter test` 39/39 통과. 실기기로 정확히 문제가 됐던 시나리오를 재현해 확인했다:

1. 에뮬레이터(교사)에서 리포트 화면을 열고 "AI 요약 생성" — 이 시점엔 참여 학생이 발언만 했고 투표는 안 한 상태
2. 화면을 전혀 벗어나지 않은 채로, 실기기(학생, SM A305N)에서 새 참가자로 참여 코드 입력 → 투표 화면에서 "어린이대공원 소풍" 선택 → 투표 확정
3. 교사 쪽 화면을 다시 스크린샷 — **"9번 이상호 · 투표: 어린이대공원 소풍"이 초록색으로 실시간 반영됨**(수정 전이었다면 "투표 안 함"으로 고정돼 있었을 상황)

검증 과정에서 세션 코드에 대문자 O(letter)와 숫자 0(zero)이 섞여 있어 실기기 코드 입력 키패드에서 헷갈렸다 — `MOAMAL_SHARED_CONTEXT.md` §8 UI/UX 항목에 이미 적혀 있던 "세션 코드 생성 시 혼동 문자(O, 0, I, 1, l) 제외" 미해결 항목과 정확히 같은 문제를 실제로 겪은 사례.

상세 기록은 `BUG_LOG_v2.md`의 `[Gemini-9-Report-02]` 항목 참조.
