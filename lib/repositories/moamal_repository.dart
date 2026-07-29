import '../models/approved_group.dart';
import '../models/idea.dart';
import '../models/participant.dart';
import '../models/session_state.dart';

abstract class MoamalRepository {
  Future<void> publishSession(SessionState state);
  Future<void> submitIdea(String sessionCode, Idea idea);
  Future<void> setVoteOpen(String sessionCode, bool voteOpen);
  Future<void> castVote(String sessionCode, String participantId, String groupId);
  Future<void> clearVotes(String sessionCode);
  Future<void> approveGroups(String sessionCode, List<ApprovedGroup> groups);
  Future<void> joinSession(String sessionCode, Participant participant);

  Stream<SessionState> listenToSession(String sessionCode);
  void stopListening();

  // ── Teacher mic control ────────────────────────────────────────────────
  Future<void> forceStopMic(String sessionCode, String uid);
  Future<void> clearForceStop(String sessionCode, String uid);
  Stream<bool> listenToForceStop(String sessionCode, String uid);
}
