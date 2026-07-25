import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/approved_group.dart';
import '../models/idea.dart';
import '../models/participant.dart';
import '../models/session_state.dart';
import 'moamal_repository.dart';

class FirebaseMoamalRepository implements MoamalRepository {
  final FirebaseFirestore _db;
  StreamSubscription<DocumentSnapshot>? _sessionSub;
  StreamSubscription<QuerySnapshot>? _ideasSub;
  StreamSubscription<QuerySnapshot>? _votesSub;
  StreamSubscription<QuerySnapshot>? _approvedGroupsSub;
  StreamSubscription<QuerySnapshot>? _participantsSub;

  // 다섯 컬렉션 최신값 캐싱 — Java 버전의 maybeEmit 패턴
  DocumentSnapshot? _latestSession;
  QuerySnapshot? _latestIdeas;
  QuerySnapshot? _latestVotes;
  QuerySnapshot? _latestApprovedGroups;
  QuerySnapshot? _latestParticipants;
  bool _votesReady = false;
  bool _participantsReady = false;
  StreamController<SessionState>? _controller;

  FirebaseMoamalRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference _sessionRef(String code) =>
      _db.collection('sessions').doc(code);

  // ── Write ──────────────────────────────────────────────────────────────────

  @override
  Future<void> publishSession(SessionState state) async {
    final data = {
      'sessionCode': state.sessionCode,
      'title': state.title,
      'voteOpen': state.voteOpen,
      'updatedAt': FieldValue.serverTimestamp(),
      if (state.ownerUid != null) 'ownerUid': state.ownerUid,
    };
    await _sessionRef(state.sessionCode).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> submitIdea(String sessionCode, Idea idea) async {
    await _sessionRef(sessionCode)
        .collection('ideas')
        .doc(idea.id)
        .set({
      ...idea.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setVoteOpen(String sessionCode, bool voteOpen) async {
    await _sessionRef(sessionCode).set({
      'voteOpen': voteOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> castVote(
      String sessionCode, String participantId, String groupId) async {
    await _sessionRef(sessionCode)
        .collection('votes')
        .doc(participantId)
        .set({
      'participantId': participantId,
      'groupId': groupId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> clearVotes(String sessionCode) async {
    final snapshot =
        await _sessionRef(sessionCode).collection('votes').get();
    if (snapshot.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> approveGroups(
      String sessionCode, List<ApprovedGroup> groups) async {
    final ref = _sessionRef(sessionCode).collection('approvedGroups');
    final batch = _db.batch();
    for (final g in groups) {
      batch.set(ref.doc(g.groupId), g.toFirestore());
    }
    await batch.commit();
  }

  @override
  Future<void> joinSession(String sessionCode, Participant participant) async {
    await _sessionRef(sessionCode)
        .collection('participants')
        .doc(participant.uid)
        .set(participant.toFirestore(), SetOptions(merge: true));
  }

  // ── Real-time subscription ─────────────────────────────────────────────────

  @override
  Stream<SessionState> listenToSession(String sessionCode) {
    stopListening();
    _controller = StreamController<SessionState>.broadcast();
    _latestSession = null;
    _latestIdeas = null;
    _latestVotes = null;
    _latestApprovedGroups = null;
    _latestParticipants = null;
    _votesReady = false;
    _participantsReady = false;

    final ref = _sessionRef(sessionCode);

    _sessionSub = ref.snapshots().listen((snap) {
      _latestSession = snap;
      _maybeEmit();
    }, onError: _controller!.addError);

    _ideasSub = ref.collection('ideas').snapshots().listen((snap) {
      _latestIdeas = snap;
      _maybeEmit();
    }, onError: _controller!.addError);

    _votesSub = ref.collection('votes').snapshots().listen((snap) {
      _latestVotes = snap;
      _votesReady = true;
      _maybeEmit();
    }, onError: (_) {
      // 학생은 votes 컬렉션 전체 구독 권한이 없음 — 빈 상태로 처리
      _votesReady = true;
      _maybeEmit();
    });

    _approvedGroupsSub =
        ref.collection('approvedGroups').snapshots().listen((snap) {
      _latestApprovedGroups = snap;
      _maybeEmit();
    }, onError: _controller!.addError);

    _participantsSub =
        ref.collection('participants').snapshots().listen((snap) {
      _latestParticipants = snap;
      _participantsReady = true;
      _maybeEmit();
    }, onError: (_) {
      _participantsReady = true;
      _maybeEmit();
    });

    return _controller!.stream;
  }

  @override
  void stopListening() {
    _sessionSub?.cancel();
    _ideasSub?.cancel();
    _votesSub?.cancel();
    _approvedGroupsSub?.cancel();
    _participantsSub?.cancel();
    _sessionSub = null;
    _ideasSub = null;
    _votesSub = null;
    _approvedGroupsSub = null;
    _participantsSub = null;
    _controller?.close();
    _controller = null;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _maybeEmit() {
    if (_controller == null || _controller!.isClosed) return;
    if (_latestSession == null ||
        _latestIdeas == null ||
        _latestApprovedGroups == null ||
        !_votesReady ||
        !_participantsReady) {
      return;
    }
    _controller!.add(_buildState());
  }

  SessionState _buildState() {
    final sessionDoc = _latestSession!;
    final data = sessionDoc.data() as Map<String, dynamic>?;

    final ideas = _latestIdeas!.docs
        .map((d) => Idea.fromFirestore(d.id, d.data() as Map<String, dynamic>))
        .toList();

    final votes = <String, String>{};
    if (_latestVotes != null) {
      for (final doc in _latestVotes!.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final pid = d['participantId'] as String?;
        final gid = d['groupId'] as String?;
        if (pid != null && gid != null) votes[pid] = gid;
      }
    }

    final approvedGroups = _latestApprovedGroups!.docs
        .map((d) => ApprovedGroup.fromFirestore(
            d.id, d.data() as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.approvedAt.compareTo(b.approvedAt));

    final participants = _latestParticipants == null
        ? <Participant>[]
        : (_latestParticipants!.docs
            .map((d) => Participant.fromFirestore(
                d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number)));

    return SessionState(
      sessionCode: data?['sessionCode'] as String? ?? '',
      title: data?['title'] as String? ?? '',
      voteOpen: data?['voteOpen'] as bool? ?? false,
      ownerUid: data?['ownerUid'] as String?,
      ideas: ideas,
      votes: votes,
      approvedGroups: approvedGroups,
      participants: participants,
    );
  }
}
