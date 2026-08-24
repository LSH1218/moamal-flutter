import '../models/approved_group.dart';
import '../models/idea.dart';
import '../models/merge_log.dart';
import '../models/participant.dart';
import '../models/session_state.dart';

abstract class MoamalRepository {
  Future<void> publishSession(SessionState state);
  Future<void> submitIdea(String sessionCode, Idea idea);
  Future<void> setVoteOpen(String sessionCode, bool voteOpen);
  Future<void> castVote(String sessionCode, String participantId, String groupId);
  Future<void> clearVotes(String sessionCode);
  Future<void> approveGroups(String sessionCode, List<ApprovedGroup> groups);
  Future<void> deleteApprovedGroup(String sessionCode, String groupId);
  Future<void> joinSession(String sessionCode, Participant participant);
  Future<String?> fetchSessionTitle(String sessionCode);

  Stream<SessionState> listenToSession(String sessionCode);
  void stopListening();

  // ── Teacher notes ──────────────────────────────────────────────────────
  Future<void> addTeacherNote({required String sessionCode, required String text, required String uid});
  Future<List<String>> getAllTeacherNotes(String sessionCode);

  // ── Merge log ──────────────────────────────────────────────────────────
  Future<void> saveMergeLog(String sessionCode, MergeLog log);
  Future<void> undoMergeLog(String sessionCode, MergeLog log);

  // ── Teacher mic control ────────────────────────────────────────────────
  Future<void> forceStartMic(String sessionCode, String uid);
  Future<void> clearForceStart(String sessionCode, String uid);
  Stream<bool> listenToForceStart(String sessionCode, String uid);

  Future<void> forceStopMic(String sessionCode, String uid);
  Future<void> clearForceStop(String sessionCode, String uid);
  Stream<bool> listenToForceStop(String sessionCode, String uid);
}
