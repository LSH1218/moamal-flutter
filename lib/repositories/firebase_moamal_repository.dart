import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/approved_group.dart';
import '../models/group.dart';
import '../models/group_snapshot.dart';
import '../models/idea.dart';
import '../models/merge_log.dart';
import '../models/participant.dart';
import '../models/session_meta.dart';
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
      'sessionType': state.sessionType,
      'updatedAt': FieldValue.serverTimestamp(),
      // 세션 생성 시점에만 호출되는 경로이므로 여기서 기준 시각을 확정한다.
      // 복귀(existingCode)는 publishSession을 타지 않아 값이 덮이지 않는다.
      'createdAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      if (state.ownerUid != null) 'ownerUid': state.ownerUid,
    };
    await _sessionRef(state.sessionCode).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> submitIdea(String sessionCode, Idea idea) async {
    // authorUid는 Firestore 규칙이 작성자 검증에 사용한다.
    // 의견 쓰기 경로가 이 메서드 하나뿐이라 여기서 채워야 누락이 생기지 않는다.
    final authorUid = FirebaseAuth.instance.currentUser?.uid;
    if (authorUid == null) {
      throw StateError('로그인 후에만 의견을 제출할 수 있습니다.');
    }
    await _sessionRef(sessionCode)
        .collection('ideas')
        .doc(idea.id)
        .set({
      ...idea.toFirestore(),
      'authorUid': authorUid,
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
  Future<void> deleteApprovedGroup(String sessionCode, String groupId) async {
    await _sessionRef(sessionCode)
        .collection('approvedGroups')
        .doc(groupId)
        .delete();
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
  Future<void> endSession(String sessionCode) async {
    await _sessionRef(sessionCode).set({
      'endedAt': FieldValue.serverTimestamp(),
      'voteOpen': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 그룹 구성을 세션 문서 필드로 저장한다.
  // 하위 컬렉션이 아니라 필드인 이유: sessions update는 이미 교사 전용이라
  // 보안 규칙 추가·재배포 없이 동작한다.
  @override
  Future<void> saveGroupSnapshot(String sessionCode, List<Group> groups) async {
    await _sessionRef(sessionCode).set({
      'groupSnapshot':
          groups.map((g) => GroupSnapshotEntry.fromGroup(g).toMap()).toList(),
      'groupSnapshotAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> joinSession(String sessionCode, Participant participant) async {
    await _sessionRef(sessionCode)
        .collection('participants')
        .doc(participant.uid)
        .set(participant.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> markParticipantLeft(String sessionCode, String uid) async {
    await _sessionRef(sessionCode)
        .collection('participants')
        .doc(uid)
        .set({'leftAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  @override
  Future<SessionMeta?> fetchSessionMeta(String sessionCode) async {
    final snap = await _sessionRef(sessionCode).get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    return SessionMeta(
      sessionCode: sessionCode,
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate(),
      endedAt: (data?['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<String?> fetchSessionTitle(String sessionCode) async {
    final snap = await _sessionRef(sessionCode).get();
    if (!snap.exists) return null;
    return (snap.data() as Map<String, dynamic>?)?['title'] as String?;
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

  // ── Teacher notes ─────────────────────────────────────────────────────────

  @override
  Future<void> addTeacherNote({required String sessionCode, required String text, required String uid}) async {
    await _sessionRef(sessionCode).collection('teacher_notes').add({
      'text': text,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'instruction',
    });
  }

  @override
  Future<List<String>> getAllTeacherNotes(String sessionCode) async {
    final snap = await _sessionRef(sessionCode)
        .collection('teacher_notes')
        .orderBy('createdAt')
        .get();
    return snap.docs
        .map((d) => (d.data()['text'] as String?) ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // ── Merge log ─────────────────────────────────────────────────────────────

  @override
  Future<void> saveMergeLog(String sessionCode, MergeLog log) async {
    await _sessionRef(sessionCode)
        .collection('mergeLogs')
        .doc(log.logId)
        .set(log.toFirestore());
  }

  @override
  Future<void> undoMergeLog(String sessionCode, MergeLog log) async {
    // resultGroupId를 참조하는 votes 먼저 조회
    final votesSnap = await _sessionRef(sessionCode)
        .collection('votes')
        .where('groupId', isEqualTo: log.resultGroupId)
        .get();

    final batch = _db.batch();

    // 해당 votes 삭제
    for (final doc in votesSnap.docs) {
      batch.delete(doc.reference);
    }

    // approvedGroups에서 resultGroup 삭제
    batch.delete(_sessionRef(sessionCode)
        .collection('approvedGroups')
        .doc(log.resultGroupId));

    // wasApproved된 sourceGroup 복원
    for (final sg in log.sourceGroups) {
      if (!sg.wasApproved) continue;
      batch.set(
        _sessionRef(sessionCode).collection('approvedGroups').doc(sg.groupId),
        {
          'groupId': sg.groupId,
          'title': sg.title,
          'idea_ids': sg.ideaIds,
          'approvedAt': sg.approvedAt != null
              ? Timestamp.fromDate(sg.approvedAt!)
              : FieldValue.serverTimestamp(),
          'approvedBy': sg.approvedBy ?? '',
          'revision': sg.revision ?? 1,
        },
      );
    }

    // 로그 undone 처리
    batch.update(
      _sessionRef(sessionCode).collection('mergeLogs').doc(log.logId),
      {'undone': true},
    );

    await batch.commit();
  }

  // ── Teacher mic control ────────────────────────────────────────────────────

  @override
  Future<void> forceStartMic(String sessionCode, String uid) async {
    await _sessionRef(sessionCode)
        .collection('participants')
        .doc(uid)
        .set({'forceStart': true}, SetOptions(merge: true));
  }

  @override
  Future<void> clearForceStart(String sessionCode, String uid) async {
    await _sessionRef(sessionCode)
        .collection('participants')
        .doc(uid)
        .set({'forceStart': false}, SetOptions(merge: true));
  }

  @override
  Stream<bool> listenToForceStart(String sessionCode, String uid) {
    return _sessionRef(sessionCode)
        .collection('participants')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data()?['forceStart'] as bool? ?? false);
  }

  @override
  Future<void> forceStopMic(String sessionCode, String uid) async {
    await _sessionRef(sessionCode)
        .collection('participants')
        .doc(uid)
        .set({'forceStop': true}, SetOptions(merge: true));
  }

  @override
  Future<void> clearForceStop(String sessionCode, String uid) async {
    await _sessionRef(sessionCode)
        .collection('participants')
        .doc(uid)
        .set({'forceStop': false}, SetOptions(merge: true));
  }

  @override
  Stream<bool> listenToForceStop(String sessionCode, String uid) {
    return _sessionRef(sessionCode)
        .collection('participants')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data()?['forceStop'] as bool? ?? false);
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
        .where((idea) => idea.text.trim().isNotEmpty)
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

    final snapshotRaw = data?['groupSnapshot'] as List<dynamic>? ?? const [];
    final groupSnapshot = snapshotRaw
        .map((e) => GroupSnapshotEntry.fromMap(e as Map<String, dynamic>))
        .where((e) => e.groupId.isNotEmpty)
        .toList();

    return SessionState(
      sessionCode: data?['sessionCode'] as String? ?? '',
      title: data?['title'] as String? ?? '',
      voteOpen: data?['voteOpen'] as bool? ?? false,
      ownerUid: data?['ownerUid'] as String?,
      sessionType: data?['sessionType'] as String? ?? 'class_meeting',
      ideas: ideas,
      votes: votes,
      approvedGroups: approvedGroups,
      participants: participants,
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate(),
      endedAt: (data?['endedAt'] as Timestamp?)?.toDate(),
      groupSnapshot: groupSnapshot,
    );
  }
}
