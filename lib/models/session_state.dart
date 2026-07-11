import 'dart:math';
import 'idea.dart';

class SessionState {
  final String sessionCode;
  final String title;
  final bool voteOpen;
  final String? ownerUid;
  final List<Idea> ideas;
  final Map<String, String> votes; // participantId → groupId

  const SessionState({
    required this.sessionCode,
    required this.title,
    required this.voteOpen,
    this.ownerUid,
    required this.ideas,
    required this.votes,
  });

  factory SessionState.initial() => SessionState(
        sessionCode: _newCode(),
        title: '우리나라를 대표하는 음식은 무엇일까요?',
        voteOpen: false,
        ideas: const [],
        votes: const {},
      );

  SessionState copyWith({
    String? sessionCode,
    String? title,
    bool? voteOpen,
    String? ownerUid,
    List<Idea>? ideas,
    Map<String, String>? votes,
  }) {
    return SessionState(
      sessionCode: sessionCode ?? this.sessionCode,
      title: title ?? this.title,
      voteOpen: voteOpen ?? this.voteOpen,
      ownerUid: ownerUid ?? this.ownerUid,
      ideas: ideas ?? this.ideas,
      votes: votes ?? this.votes,
    );
  }

  static String _newCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
