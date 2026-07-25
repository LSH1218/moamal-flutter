import 'dart:math';
import 'approved_group.dart';
import 'idea.dart';
import 'participant.dart';

class SessionState {
  final String sessionCode;
  final String title;
  final bool voteOpen;
  final String? ownerUid;
  final List<Idea> ideas;
  final Map<String, String> votes; // participantId → groupId
  final List<ApprovedGroup> approvedGroups;
  final List<Participant> participants; // 번호 순 정렬

  const SessionState({
    required this.sessionCode,
    required this.title,
    required this.voteOpen,
    this.ownerUid,
    required this.ideas,
    required this.votes,
    this.approvedGroups = const [],
    this.participants = const [],
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
    List<ApprovedGroup>? approvedGroups,
    List<Participant>? participants,
  }) {
    return SessionState(
      sessionCode: sessionCode ?? this.sessionCode,
      title: title ?? this.title,
      voteOpen: voteOpen ?? this.voteOpen,
      ownerUid: ownerUid ?? this.ownerUid,
      ideas: ideas ?? this.ideas,
      votes: votes ?? this.votes,
      approvedGroups: approvedGroups ?? this.approvedGroups,
      participants: participants ?? this.participants,
    );
  }

  static String _newCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
