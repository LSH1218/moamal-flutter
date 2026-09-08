import 'package:uuid/uuid.dart';

import '../models/idea.dart';
import '../models/participant.dart';
import '../models/session_state.dart';
import '../repositories/firebase_moamal_repository.dart';
import 'auth_service.dart';

/// 해커톤 심사용 데모 시드 — "우리 반에서 바꾸고 싶은 것은?" 학급회의 시나리오.
/// IntroScreen·LandingScreen 양쪽에서 재사용한다.
const demoTitle = '우리 반에서 바꾸고 싶은 것은 무엇인가요?';

/// (번호, 이름) — 참여자 목록과 발언자 표시(speaker)를 동시에 채운다.
/// authorUid는 보안 규칙상 실제 로그인 사용자(교사)로 고정되지만, speaker는
/// 그냥 표시용 문자열이라 자유롭게 학생별로 다르게 줄 수 있다.
const demoStudents = [
  (1, '김민서'),
  (2, '이도윤'),
  (3, '박서연'),
  (4, '최지훈'),
  (5, '정하은'),
];

/// 시드 의견 — 위 학생 순서를 순환하며 speaker로 배정된다.
const demoIdeas = [
  '쉬는 시간을 늘렸으면 좋겠어요.',
  '쉬는 시간이 너무 짧아요.',
  '급식 메뉴가 다양했으면 좋겠어요.',
  '교실에 책을 더 많이 놔주세요.',
  '체육시간을 늘려주세요.',
  '쉬는 시간을 5분 더 주세요.',
  '급식에 디저트가 있었으면 해요.',
  '독서 시간을 따로 만들어주세요.',
];

/// 익명 로그인 + 새 세션 생성 + 참가자 5명 + 시드 의견 8개 제출까지 마치고
/// 생성된 세션 코드를 반환한다. 호출자가 그 코드로 TeacherHomeScreen에
/// 진입시키면 된다.
Future<String> seedJudgeDemoSession({
  required AuthService auth,
  required FirebaseMoamalRepository repo,
}) async {
  await auth.signInAnonymously();

  final session = SessionState.initial().copyWith(
    title: demoTitle,
    ownerUid: auth.currentUid,
  );
  await repo.publishSession(session);

  // 참가자 목록 — 세션 소유자(교사)는 다른 uid로도 participants 문서를
  // 만들 수 있다(firestore.rules: isOwner(sessionCode)). "참여 0명"으로
  // 보이지 않도록 데모용 학생 5명을 실제 참가자로 등록한다.
  for (var i = 0; i < demoStudents.length; i++) {
    final (number, name) = demoStudents[i];
    await repo.joinSession(
      session.sessionCode,
      Participant(
        uid: 'demo-student-$i',
        number: number,
        name: name,
        joinedAt: DateTime.now(),
      ),
    );
  }

  // 의견 — authorUid는 보안 규칙상 실제 로그인한 교사 uid로 고정되지만,
  // speaker는 표시용 문자열이라 학생 이름을 순환 배정해 발언자가
  // 다양하게 보이도록 한다(원문 목록·리포트 인용에 그대로 쓰인다).
  for (var i = 0; i < demoIdeas.length; i++) {
    final (number, name) = demoStudents[i % demoStudents.length];
    await repo.submitIdea(
      session.sessionCode,
      Idea(
        id: const Uuid().v4(),
        speaker: '$number번 $name',
        text: demoIdeas[i],
        source: 'text',
      ),
    );
  }

  return session.sessionCode;
}
