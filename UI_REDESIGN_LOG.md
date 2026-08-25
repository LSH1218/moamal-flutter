# UI 재설계 로그

> **배경**: QA 진행 중 기존 UI가 실사용에 부적합하다고 판단, 전면 재설계 진행.  
> **디자인 레퍼런스**: `C:\Users\pc\Desktop\design_handoff_moamal_ui\모아말 재설계.dc.html` (독립 파일로 보관)  
> **작업 기간**: 2026-08 (Claude 대화방 복수 세션)

---

## 디자인 토큰

재설계 전 Material 기본 ColorScheme에서 아래 커스텀 토큰 체계로 전환.

| 토큰 | 값 | 용도 |
|------|----|------|
| `kGreen` | `#225B43` | 주요 액션, 선택 상태 |
| `kYellow` | `#F1C84B` | 강조, 배지, 마이크 활성 |
| `kGround` | `#F3EFE5` | 앱 배경, 카드 내부 그룹 영역 |
| `kInk` | `#20231F` | 본문 텍스트 |
| `kCardBg` | `#FFFDF8` | 카드 배경 |
| `kRed` | `#D32F2F` | 파괴적 액션(종료, 삭제) |
| `kDisabled` | `#B9B4A8` | 비활성 상태 |
| `kBorder` | `#E8E4DC` | 기본 테두리 |
| `kBorderMid` | `#E0DDD6` | 중간 강도 테두리 |
| `kBorderDark` | `#D8D3C6` | 강한 테두리 |

---

## 변경 내역

### 1. 마이크 제어 화면 (student_session_screen.dart)

**기존**: 기본 FloatingActionButton, SnackBar로 상태 알림  
**변경**:
- 마이크 버튼 커스텀 애니메이션 (kYellow 파동, 녹음 중 파형 표시)
- forceStop 수신 시 kRed 스타일 배너 (영구 표시, 탭으로 닫기)
- forceStart 수신 시 kGreen 배너 (3초 후 자동 닫힘) + `HapticFeedback.mediumImpact()`
- **이유**: SnackBar는 다른 UI에 가려지거나 짧아서 학생이 인지 못하는 QA 이슈 발생

### 2. 코드 입력 → 세션 화면 네비게이션 스택 (join_screen.dart)

**기존**: `Navigator.pushReplacement` 사용 → 뒤로 가기 시 부모 화면 없음(블랙스크린)  
**변경**: `Navigator.push`로 전환 (replace_all)  
**스택 구조**: 랜딩 → JoinScreen → StudentProfileScreen → StudentSessionScreen  
- **이유**: 학생이 발표 화면에서 뒤로 가면 앱이 먹통이 되는 치명적 UX 버그

### 3. 교사 홈 종료 다이얼로그 (teacher_home_screen.dart)

**기존**: `AlertDialog` 기본 스타일, "취소/확인" 버튼  
**변경**: 커스텀 `Dialog`
- kYellow "!" 배지 + "나가면 수업이 종료됩니다" 타이틀
- 실시간 의견 건수(`_session.ideas.length`) 표시
- "수업 계속하기"(kGreen, flex:1) / "종료"(kRed outline, 104px)
- `barrierDismissible: false`
- **이유**: 실수로 수업을 종료하는 사고 방지, 종료 결과(저장 여부)를 명확히 고지

### 4. 그룹 이동 시트 — 6b (organize_screen.dart + gemini_grouping_engine.dart)

**기존**: 그룹 이동 기능 없음 (AI 결과 확정 불가)  
**추가**: `_MoveGroupSheet` 바텀시트
- 원문 탭(`_IdeaCard`)과 승인 탭(`_GroupApproveCard`) 양쪽에서 진입
- 대상 그룹 선택(kGreen 하이라이트) 또는 "새 그룹" 생성
- `GeminiGroupingEngine.moveIdea()`: 소스 그룹에서 제거 → 타깃에 추가, 빈 그룹 자동 삭제
- **이유**: AI 그룹화 결과가 항상 완벽하지 않아 교사 수동 조정 필요

### 5. 그룹 병합 시트 — 8d (organize_screen.dart + gemini_grouping_engine.dart)

**기존**: 병합 기능 없음  
**추가**: `_MergeGroupSheet` 바텀시트
- 승인 탭 "병합" 칩에서 진입, 기준 그룹 고정 + 나머지 다중 선택
- 실시간 "의견 N건이 한 그룹으로 합쳐집니다" 카운트
- 그룹명 TextField(소스 그룹명 pre-fill), 승인 전까지 되돌리기 안내
- `GeminiGroupingEngine.mergeGroups()`: 타깃 그룹들 ideas를 소스로 흡수 후 그룹 제거
- **이유**: 유사한 의미의 그룹이 AI에 의해 분리되는 경우 교사가 직접 합칠 수 있어야 함

---

### 6. 교사 홈 하단 독 레이아웃 (teacher_dock.dart)

**기존**: 마이크 버튼이 Stack + Transform.translate로 독 위에 떠오르는 FAB 형태  
**변경**: `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)` 인라인 5버튼 플랫 레이아웃
- [공유][정리][마이크][학생][종료] 5개 버튼 동일 높이 배치
- 마이크 버튼은 72×72 원형, kYellow/kRed/kBlue 상태 색상, `_PulsingRing` 애니메이션
- `_micOverflow` / `_micSize` 상수 제거, `_DockSlotBadge`(정리 건수 배지) 유지
- **이유**: 교사 요청 — "5개가 플랫하게 밑에 들어가 있는 걸 생각했어"

### 7. 교사 VAD (teacher_home_screen.dart)

**기존**: VAD 없음 — 교사 Toggle 모드에서 침묵이 지속돼도 녹음이 끝나지 않음  
**변경**: `_startVAD()` / `_stopVAD()` 추가
- `amplitudeStream` 구독, 200ms 간격 진폭 모니터링
- silence threshold `-34dBFS` (기기 ambient noise floor 고려한 값), 3초 침묵 시 자동 `_stopAndTranscribe()`
- Toggle 탭 → 녹음 시작 시 VAD 시작, 재탭·취소·dispose 시 VAD 중지
- **이유**: StudentSessionScreen에만 VAD가 있었고 TeacherHomeScreen에는 미구현 상태였음

### 8. 세션 복귀 (main.dart + teacher_home_screen.dart)

**기존**: 앱 재시작 시 항상 랜딩 화면으로 이동, 진행 중 수업 복귀 불가  
**변경**: SharedPreferences `active_teacher_session` 키로 세션 코드 저장
- `_startSession()`: 세션 시작/복귀 시 `prefs.setString('active_teacher_session', code)`
- `onPopInvokedWithResult`: 종료 확인 시 `prefs.remove('active_teacher_session')`
- `main.dart _init()`: 딥링크 확인 후 저장된 세션 코드 있으면 `TeacherHomeScreen(existingCode:)` push
- `Navigator.push` 사용(pushReplacement 아님) — 랜딩 스택 유지, 종료 다이얼로그 정상 동작
- **이유**: 교사가 실수로 앱을 닫거나 백그라운드 전환 후 복귀 시 수업이 이어져야 함

### 9. 학생 forceStop 배너 상태 분리 (student_session_screen.dart) — 2026-08-24

**기존**: `_forceStopped` 하나가 배너 표시와 마이크 잠금을 겸함. 배너는 kInk(검정) + SnackBar 중복 + 닫기 불가
**변경**:
- 배너 kRed + 닫기(×) 아이콘, 배너 전체 탭으로 닫기
- SnackBar 제거 (배너와 중복 안내)
- 상태 2개로 분리 — `_forceStopBannerVisible`(학생이 닫을 수 있는 안내) / `_forceStopped`(교사만 해제하는 잠금)
- **이유**: 명세대로 "탭으로 닫기"를 붙이면 학생이 배너를 닫는 순간 마이크 잠금까지 풀려 교사 제어가 무력화된다.
  배너를 닫아도 마이크 영역이 kDisabled + "마이크 꺼짐"으로 잠금을 계속 표시하므로 학생 혼란은 없다

### 10. 좁은 화면(320dp) 다이얼로그 대응 (responsive.dart + landing_screen.dart) — 2026-08-24

**기존**: 브레이크포인트가 600/900 두 개뿐 — "넓어질 때"만 다루고 좁은 쪽 하한이 없었음
**변경**:
- `AppBreakpoints.narrow = 360`, `context.isNarrow`, `dialogInsetH(context, {tabletFactor})` 신설
- PIN 패드 키를 고정 60dp → `LayoutBuilder` 폭 역산(44~60dp clamp, 터치 최소 44dp 보장)
- 코드 입력·수업 제목 다이얼로그 `scrollable: true` (키보드 대응)
- 세션 선택 다이얼로그를 전체 폭 세로 버튼 2개로 전환 — 폭과 무관하게 라벨 잘림 없음
- 다이얼로그 좌우 여백 360dp 미만에서 40 → 16dp
- **이유**: Mercury-Layout-01 3건이 전부 "좁은 폭에서 고정 크기가 가로를 소진"하는 같은 원인

---

## 변경되지 않은 것

- Firestore 데이터 구조 (세션, 의견, 투표, 승인 그룹)
- Cloud Functions 엔드포인트
- AI 그룹화 로직 (`GeminiGroupingEngine._callGemini` 등 내부 알고리즘)
- 슈퍼바이저 모드 PIN 진입 방식
- QR 스캔·공유 기능

---

## QA 체크리스트 (재설계 이후)

Mercury QA v2 진행 현황 (2026-08-22 기준):

**Section 1~4** ✅ 완료 (2026-08-21)
- [x] forceStart 배너 → 3초 후 사라지는지, 햅틱 울리는지 _(Section 2 스킵 예정)_
- [x] 교사 홈 종료 다이얼로그 → 의견 건수 실제 값 반영 ✅
- [x] 세션 복귀 (백그라운드 → 복귀, 앱 재시작 → 복귀) ✅
- [x] 교사 STT PTT / Toggle 모드 정상 동작 ✅
- [x] VAD 3초 침묵 자동 종료 (교사 Toggle) ✅ (버그 수정 후)
- [x] 무음 녹음 → Whisper 환각 텍스트 전송 안 됨 ✅
- [x] OrganizeScreen 의견 건수 표시 ✅
- [x] 그룹 필터 칩 동작 ✅

**Section 5** ✅ 완료 (2026-08-22)
- [x] 그룹 이동: 이동 후 원문·승인 탭 즉시 반영 ✅ (List<dynamic> 타입 버그 수정 후)
- [x] 새 그룹 생성 ✅
- [x] 그룹 병합 시트 열기 ✅
- [x] 병합 실행 → 그룹 수 감소, 의견 수 합산 ✅
- [x] 병합 overflow ✅ (ConstrainedBox 수정 후)

**Section 6** ✅ 완료 (2026-08-24)
- [x] 승인 탭: AI 제안 배지(kYellow), 승인하기/승인 취소 전환 ✅
- [x] 승인 후 Firestore approvedGroups 문서 추가 ✅
- [x] 이름 수정 다이얼로그 + TextField pre-fill ✅ (크래시 수정 후)
- [x] 이름 수정 저장 → Firestore title 업데이트 + 앱 즉시 반영 ✅
- [x] 승인 취소 → "AI 제안" 복원 ✅ (deleteApprovedGroup 수정 후)
- [x] 병합 시트: 선택 시 "의견 N건" 카운트 실시간 갱신 ✅
- [x] 병합 그룹명 비워두고 병합 → 소스 이름 유지 ✅

**Section 7** ✅ 완료 (2026-08-24)
- [x] 승인 0개 → 투표 탭 빈 상태 + "승인 탭으로" 버튼 ✅
- [x] "승인 탭으로" 탭 → 승인 탭으로 전환 ✅
- [x] 승인 그룹 있을 때 투표 탭 → 카드 목록 + "투표 시작" (kGreen) ✅
- [x] "투표 시작" → voteOpen=true + "투표 닫고 결과 확정" (kRed) 전환 ✅
- [x] Firebase votes 추가 → 득표 바 실시간 갱신 ✅
- [x] 1위 그룹 kYellow 테두리 + kYellow 바 강조 ✅
- [x] 투표 중 승인/취소 비활성 ✅ (시각 피드백 없음은 Mercury-4-Organize-01 P2 기존 버그)
- [x] "투표 닫고 결과 확정" → voteOpen=false + 안내 문구 사라짐 ✅

**Section 8** ✅ 완료 (2026-08-24)
- [x] OrganizeScreen 헤더 ← 탭 → TeacherHomeScreen 복귀 ✅
- [x] 복귀 후 Firebase 콘솔 의견 추가 → LIVE 화면 실시간 반영(발언 7→8) ✅ broadcast stream 공유 정상, 복귀 후에도 스트림 유지
- [x] 그룹 이동/병합 후 복귀 → 변경 반영 ✅ 병합 그룹 "김치와 김치요리" 유지, 새 의견이 "매운 음식" 그룹에 정상 편입
- [x] 진입→나가기→재진입 3회 반복 → 크래시·상태 오염 없음 ✅

> ⚠️ 테스트 중 "접근성 높은 불고기" 승인이 사라진 것을 발견. AI 재그룹화 부작용이 아니라
> 승인 취소 버튼이 실제로 눌린 것으로 확인 — `deleteApprovedGroup` 호출부는 `_unapprove` 단일 경로이고,
> 그룹 id 불일치였다면 고아 문서가 남아야 하나 Firestore엔 `group1` 하나뿐.
> 투표 중 무반응 → 재탭 습관 → 투표 종료 후 실삭제로 이어지는 경로이므로
> **Mercury-4-Organize-01을 P2 → P1로 상향** (BUG_LOG_v2.md 참조).

**Section 9 (학생 흐름)** → **Gemini QA 이관** (2026-08-24)
- 학생 화면이 교사 세션에 종속되어 단일 기기로는 부분 확인만 가능
- Gemini는 에뮬레이터(교사) + 공기계(학생) 2기기 구성으로 진행
- 인수인계 문서: `MERCURY_TO_GEMINI_HANDOFF.md`

**Section 10 (보고서 생성 및 공유)** ⚠️ 조건부 완료 (2026-08-24)
- [x] 10-1 ReportScreen 진입 → 통계·주제 목록·생성 버튼 표시 ✅ (독의 kRed "종료" 버튼 → `_goToReport()`, 세션은 종료되지 않음)
- [~] 10-2 AI 요약 생성 → **GPT 호출·생성은 성공하나 화면이 갱신되지 않음** (Mercury-Report-06, P1). 재진입해야 결과가 보임
- [~] 10-3 리포트 없을 때 공유 버튼 비활성 → **상단 AppBar만 적용, 하단 CTA는 여전히 무방비** (Mercury-Report-02 부분 해결)
- [x] 10-4 생성 후 공유 버튼 → 공유 시트에 리포트 본문 정상 노출 ✅

> 리포트 화면은 설계가 확정되지 않아 QA로 수정 방향을 정할 수 없는 항목이 4건 있음
> (공유 버튼 이중화 / 자동 생성 여부 / 최종 산출물 형태 / 참여자 정의). BUG_LOG_v2.md "설계 미확정 항목" 참조.
>
> Section 10 진행 중 세션 지속성 관련 P1 2건 추가 발견:
> - **Mercury-Session-02 (P1)**: 앱 재시작 시 교사의 병합·이동·승인 결과가 전부 소실되고 AI가 재그룹화
> - **Mercury-Session-03 (P2)**: 앱 재시작 시 수업 경과 시간 리셋 (39:29 → 02:05)

**Section R (회귀 체크)** ⚠️ 조건부 완료 (2026-08-24)
- [x] R-1 빔 프로젝터 화면 진입 → 투표 결과 정상 표시 ✅ (독 "공유" → QR 시트 → "빔프로젝터 화면 열기")
- [x] R-2 투표 바 실시간 갱신 ✅ Firebase 콘솔 투표 추가 시 즉시 반영(참여 1→2명, 0→1표, 50%/50%). `StreamSubscription` 구조라 ReportScreen 같은 갱신 문제 없음
  - ⚠️ 동점인데 한 그룹만 1위 강조 (Mercury-Vote-01, P3)
- [x] R-3 슈퍼바이저 PIN → 세션 선택 → 코드 입력 ✅ 기능 정상
  - ⚠️ 320dp 폭에서 다이얼로그 3종 레이아웃 초과 (Mercury-Layout-01, P2)
- [~] R-4 QR 공유 → **기능 미구현**. QR에 딥링크가 아닌 평문 코드만 인코딩(Mercury-Share-01, **P1**),
  시스템 공유 시트를 여는 경로 자체가 없음(Mercury-Share-02, P2)
- [x] R-5 디자인 토큰 — Material 기본 파란색 잔존 **없음** ✅ 선택 핸들·커서·포커스 테두리 모두 kGreen, 스크롤 끝 효과에도 파란 글로우 없음
  - ⚠️ 승인 버튼 스피너가 kGreen 고정이라 kGreen 배경 위에서 비가시 (Mercury-4-Organize-04, P3)
- [x] R-6 다크 모드 → 전후 화면 동일 ✅
  - `main.dart:48`에 `darkTheme:` 미정의 → 시스템 다크 모드를 **무시하고 항상 라이트 테마로 렌더링**.
    체크리스트 요구사항(kGround/kCardBg 불투명 유지)은 충족되나, 다크 모드 지원 여부는 별도 결정 사항

---

## Mercury QA v2 종료 (2026-08-24)

Section 0~8, 10, R 완료. **Section 9(학생 흐름)는 2기기 환경이 필요해 Gemini QA로 이관**
(`MERCURY_TO_GEMINI_HANDOFF.md`).

### Mercury에서 발견된 P1 (우선 수정 대상)

| ID | 내용 |
|---|---|
| Mercury-Share-01 | QR에 딥링크 미인코딩 → 학생이 QR을 찍어도 앱이 열리지 않음 |
| Mercury-Session-02 | 앱 재시작 시 교사의 병합·이동·승인 결과 전부 소실 |
| Mercury-Report-06 | 리포트 생성 버튼 무반응(화면 미갱신) → 반복 탭·GPT 비용 중복 |
| Mercury-4-Organize-01 | 승인 취소 피드백 부재 → 재탭 습관 → 투표 종료 후 실삭제로 데이터 유실 (P2에서 상향) |
| Mercury-3-Student-01 | StudentSessionScreen StreamBuilder 재구독 (Gemini에서 재현 확인 예정) |
| Common-Network-01 | 백그라운드 복귀 Firestore 리스너 재연결 미검증 |

### 별도 결정이 필요한 사항 (QA 범위 밖)

- 리포트 화면 설계 미확정 4건 (공유 버튼 이중화 / 자동 생성 여부 / 최종 산출물 형태 / 참여자 정의)
- 반응형 — 화면 14개 중 8개만 적용, 320dp 하한 미대응
- iOS 지원 범위 — Windows 개발 환경이라 빌드 불가, 실행 이력 전무
- 다크 모드 지원 여부
