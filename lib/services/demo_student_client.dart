import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// A separate Firebase app keeps student credentials out of the teacher app.
/// No admin credentials or relaxed rules are used for demo votes.
class DemoStudentClient {
  final FirebaseFirestore db;
  final String uid;
  DemoStudentClient._(this.db, this.uid);

  static Future<DemoStudentClient>? _pending;

  static Future<DemoStudentClient> connect() async {
    try {
      return await (_pending ??= _connect());
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  static Future<DemoStudentClient> _connect() async {
    const name = 'judge-demo-student';
    final existing = Firebase.apps.where((a) => a.name == name);
    final app = existing.isEmpty
        ? await Firebase.initializeApp(
            name: name,
            options: Firebase.app().options,
          )
        : existing.first;
    final auth = FirebaseAuth.instanceFor(app: app);
    final restored = await auth.authStateChanges().first;
    final user = restored ?? (await auth.signInAnonymously()).user!;
    if (!user.isAnonymous ||
        user.uid == FirebaseAuth.instance.currentUser?.uid) {
      throw StateError('체험 학생 연결을 분리하지 못했습니다.');
    }
    return DemoStudentClient._(
      FirebaseFirestore.instanceFor(app: app),
      user.uid,
    );
  }

  Future<void> join(String code, int number) async {
    final ref = db.collection('sessions').doc(code);
    await db.runTransaction((tx) async {
      final session = (await tx.get(ref)).data();
      if (session?['isJudgeDemo'] != true || session?['endedAt'] != null) {
        throw StateError('진행 중인 체험 수업에서만 참여할 수 있습니다.');
      }
      final member = ref.collection('participants').doc(uid);
      final previous = await tx.get(member);
      if (!previous.exists) {
        tx.set(member, {
          'number': number,
          'name': '체험 학생',
          'joinedAt': FieldValue.serverTimestamp(),
          'leftAt': null,
        });
      }
    });
  }

  Future<void> vote(String code, String groupId) async {
    final ref = db.collection('sessions').doc(code);
    // The transaction rechecks the server state and conflicts with a concurrent
    // close/delete. Reopening the dialog cannot create a second vote.
    await db.runTransaction((tx) async {
      final session = (await tx.get(ref)).data();
      final group = await tx.get(ref.collection('approvedGroups').doc(groupId));
      final member = await tx.get(ref.collection('participants').doc(uid));
      final voteRef = ref.collection('votes').doc(uid);
      final previous = await tx.get(voteRef);
      if (session?['isJudgeDemo'] != true ||
          session?['endedAt'] != null ||
          session?['voteOpen'] != true ||
          !group.exists ||
          !member.exists) {
        throw StateError('투표가 닫혔거나 후보가 바뀌었습니다. 다시 확인해주세요.');
      }
      if (previous.exists) return;
      tx.set(voteRef, {
        'participantId': uid,
        'groupId': groupId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
