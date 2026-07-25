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

  /// 학생 입장: 번호·이름을 participants 컬렉션에 저장
  Future<void> joinSession(String sessionCode, Participant participant);

  Stream<SessionState> listenToSession(String sessionCode);
  void stopListening();
}
