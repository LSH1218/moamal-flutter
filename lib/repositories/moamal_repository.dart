import '../models/idea.dart';
import '../models/session_state.dart';

abstract class MoamalRepository {
  Future<void> publishSession(SessionState state);
  Future<void> submitIdea(String sessionCode, Idea idea);
  Future<void> setVoteOpen(String sessionCode, bool voteOpen);
  Future<void> castVote(String sessionCode, String participantId, String groupId);
  Future<void> clearVotes(String sessionCode);

  Stream<SessionState> listenToSession(String sessionCode);
  void stopListening();
}
