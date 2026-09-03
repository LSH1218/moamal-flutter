import '../models/approved_group.dart';
import '../models/group.dart';
import '../models/idea.dart';
import '../models/merge_log.dart';
import '../models/participant.dart';
import '../models/session_meta.dart';
import '../models/session_state.dart';

abstract class MoamalRepository {
  Future<void> publishSession(SessionState state);
  Future<void> submitIdea(String sessionCode, Idea idea);
  Future<void> setVoteOpen(String sessionCode, bool voteOpen);
  Future<void> castVote(String sessionCode, String participantId, String groupId);
  /// 학생 자신의 투표만 실시간 구독 — voteOpen 재개방 시 로컬 상태가
  /// 서버와 어긋나지 않도록 한다(Gemini-4-Vote-01).
  Stream<String?> listenToMyVote(String sessionCode, String participantId);
  Future<void> clearVotes(String sessionCode);
  Future<void> approveGroups(String sessionCode, List<ApprovedGroup> groups);
  Future<void> deleteApprovedGroup(String sessionCode, String groupId);
  Future<void> joinSession(String sessionCode, Participant participant);
  Future<String?> fetchSessionTitle(String sessionCode);

  /// 세션 문서만 1회 조회 — 복귀 가능 여부 판단용.
  /// 하위 컬렉션은 읽지 않는다(앱 시작 시 문서 read 1회).
  /// 세션이 없으면 null.
  Future<SessionMeta?> fetchSessionMeta(String sessionCode);

  // ── 세션 라이프사이클 ────────────────────────────────────────────────────
  /// 교사 종료 — 세션 문서에 endedAt 기록. 학생 화면이 이 값을 구독한다.
  Future<void> endSession(String sessionCode);

  /// 학생 퇴장 — participants/{uid}.leftAt 기록. 문서는 삭제하지 않는다(누적 보존).
  Future<void> markParticipantLeft(String sessionCode, String uid);

  /// 교사가 정리한 그룹 구성 저장 — 앱 재시작 시 복원용.
  Future<void> saveGroupSnapshot(String sessionCode, List<Group> groups);

  Stream<SessionState> listenToSession(String sessionCode);
  void stopListening();

  // ── Teacher notes ──────────────────────────────────────────────────────
  Future<void> addTeacherNote({required String sessionCode, required String text, required String uid});
  Future<List<String>> getAllTeacherNotes(String sessionCode);

  /// 가장 최근 교사 발문 1건을 실시간 구독 — 학생 화면 질문 카드용
  /// (Gemini-7-TeacherNote-01: 기존엔 `ideas`에서 `speaker=='교사'`를
  /// 찾는 죽은 코드였다. 교사 발문은 `teacher_notes`에만 저장된다).
  Stream<String?> listenToLatestTeacherNote(String sessionCode);

  // ── Merge log ──────────────────────────────────────────────────────────
  Future<void> saveMergeLog(String sessionCode, MergeLog log);
  Future<void> undoMergeLog(String sessionCode, MergeLog log);

  // ── Teacher mic control ────────────────────────────────────────────────
  // forceStart: 잠금 해제만(학생이 직접 눌러야 녹음 시작).
  // forceSpeak: 잠금 해제 + 즉시 녹음 시작(교사가 "지금 말하세요" 지목할 때).
  Future<void> forceStartMic(String sessionCode, String uid);
  Future<void> clearForceStart(String sessionCode, String uid);
  Stream<bool> listenToForceStart(String sessionCode, String uid);

  Future<void> forceSpeakMic(String sessionCode, String uid);
  Future<void> clearForceSpeak(String sessionCode, String uid);
  Stream<bool> listenToForceSpeak(String sessionCode, String uid);

  Future<void> forceStopMic(String sessionCode, String uid);
  Future<void> clearForceStop(String sessionCode, String uid);
  Stream<bool> listenToForceStop(String sessionCode, String uid);
}
