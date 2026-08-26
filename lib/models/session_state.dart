import 'dart:math';
import 'approved_group.dart';
import 'group_snapshot.dart';
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
  final List<Participant> participants;
  final String sessionType;

  /// 세션 문서 생성 시각. 앱 재시작 후에도 수업 경과 시간의 기준이 된다 (Mercury-Session-03).
  final DateTime? createdAt;

  /// 교사가 수업을 종료한 시각. null이면 진행 중 (Gemini-1-Exit-03).
  final DateTime? endedAt;

  /// 교사가 정리한 그룹 구성. 앱 재시작 시 복원 기준 (Mercury-Session-02).
  final List<GroupSnapshotEntry> groupSnapshot;

  const SessionState({
    required this.sessionCode,
    required this.title,
    required this.voteOpen,
    this.ownerUid,
    required this.ideas,
    required this.votes,
    this.approvedGroups = const [],
    this.participants = const [],
    this.sessionType = 'class_meeting',
    this.createdAt,
    this.endedAt,
    this.groupSnapshot = const [],
  });

  bool get isEnded => endedAt != null;

  /// 현재 접속 중인 참여자. `participants`는 누적 입장자다 (Gemini-1-Exit-01).
  List<Participant> get activeParticipants =>
      participants.where((p) => p.isActive).toList();

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
    String? sessionType,
    DateTime? createdAt,
    DateTime? endedAt,
    List<GroupSnapshotEntry>? groupSnapshot,
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
      sessionType: sessionType ?? this.sessionType,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      groupSnapshot: groupSnapshot ?? this.groupSnapshot,
    );
  }

  static String _newCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
