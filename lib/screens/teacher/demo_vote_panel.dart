import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/session_state.dart';
import '../../services/demo_student_client.dart';
import '../../theme/app_theme.dart';

/// Only marked demo sessions owned by the current teacher show this entry.
class DemoVotePanel extends StatefulWidget {
  final SessionState session;
  const DemoVotePanel({super.key, required this.session});
  @override
  State<DemoVotePanel> createState() => _DemoVotePanelState();
}

class _DemoVotePanelState extends State<DemoVotePanel> {
  late final _demo = kIsWeb
      ? FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.session.sessionCode)
            .get()
      : null;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _demo,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data?['isJudgeDemo'] != true ||
            data?['ownerUid'] != FirebaseAuth.instance.currentUser?.uid) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '혼자서도 투표해볼 수 있어요',
                style: TextStyle(fontWeight: FontWeight.bold, color: kGreen),
              ),
              const SizedBox(height: 6),
              const Text(
                '예시 학생 5명은 자동으로 투표하지 않습니다. '
                '체험 학생 1명으로 직접 한 표를 보내보세요. 교사 화면은 그대로 유지됩니다.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.how_to_vote_outlined),
                label: const Text('학생으로 한 표 넣어보기'),
                onPressed:
                    !widget.session.voteOpen || widget.session.endedAt != null
                    ? null
                    : () {
                        final next =
                            widget.session.participants.fold<int>(
                              0,
                              (n, p) => p.number > n ? p.number : n,
                            ) +
                            1;
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => _DemoVoteDialog(
                            code: widget.session.sessionCode,
                            number: next,
                          ),
                        );
                      },
              ),
              Text(
                widget.session.voteOpen
                    ? '체험 후 교사 화면에서 득표를 확인하고, 수업기록을 열어보세요.'
                    : '후보를 승인한 뒤 아래의 ‘투표 시작’을 눌러주세요.',
                style: const TextStyle(fontSize: 12, color: kInk),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DemoVoteDialog extends StatefulWidget {
  final String code;
  final int number;
  const _DemoVoteDialog({required this.code, required this.number});
  @override
  State<_DemoVoteDialog> createState() => _DemoVoteDialogState();
}

class _DemoVoteDialogState extends State<_DemoVoteDialog> {
  DemoStudentClient? _client;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _session;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _groups;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _vote;
  String? _selected;
  String? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = await DemoStudentClient.connect();
      await client.join(widget.code, widget.number);
      final ref = client.db.collection('sessions').doc(widget.code);
      if (!mounted) return;
      setState(() {
        _client = client;
        _session = ref.snapshots();
        _groups = ref.collection('approvedGroups').snapshots();
        _vote = ref
            .collection('votes')
            .doc(client.uid)
            .snapshots(includeMetadataChanges: true);
      });
    } catch (error) {
      debugPrint('Demo student connection failed: $error');
      if (mounted) {
        setState(() => _error = '학생 연결에 실패했습니다. 인터넷 연결을 확인하고 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_sending || _selected == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _client!.vote(widget.code, _selected!);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '표를 보내지 못했습니다. 연결 상태와 투표가 열려 있는지 확인해주세요.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('체험 학생의 투표'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('같은 수업에 체험 학생으로 참여합니다.\n선택한 한 표는 실제 수업 기록에 남습니다.'),
                const SizedBox(height: 16),
                if (_loading)
                  const CircularProgressIndicator()
                else if (_client == null)
                  TextButton(onPressed: _connect, child: const Text('다시 연결하기'))
                else
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _session,
                    builder: (context, session) =>
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _groups,
                          builder: (context, groups) =>
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: _vote,
                                builder: (context, vote) {
                                  if (session.hasError ||
                                      groups.hasError ||
                                      vote.hasError) {
                                    return const Text(
                                      '수업 정보를 불러오지 못했습니다. 창을 닫고 다시 열어주세요.',
                                    );
                                  }
                                  if (!session.hasData ||
                                      !groups.hasData ||
                                      !vote.hasData) {
                                    return const CircularProgressIndicator();
                                  }
                                  final docs = groups.data!.docs;
                                  final chosen = vote.data!.data()?['groupId'];
                                  // Do not show success for an unacknowledged local write.
                                  if (chosen != null &&
                                      !vote.data!.metadata.hasPendingWrites) {
                                    final names = docs.where(
                                      (d) => d.id == chosen,
                                    );
                                    final title = names.isEmpty
                                        ? '선택한 후보'
                                        : names.first.data()['title'];
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: kGreen,
                                          size: 36,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '$title에 한 표를 보냈어요.',
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '교사 화면으로 돌아가 득표를 확인하세요.\n수업기록에는 ‘체험 학생’의 선택이 남습니다.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    );
                                  }
                                  final open =
                                      session.data!.data()?['voteOpen'] ==
                                          true &&
                                      session.data!.data()?['endedAt'] == null;
                                  final valid = docs.any(
                                    (d) => d.id == _selected,
                                  );
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!open) const Text('지금은 투표가 닫혀 있습니다.'),
                                      if (docs.isEmpty)
                                        const Text('승인된 후보가 없습니다.'),
                                      for (final doc in docs)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton(
                                              onPressed: open && !_sending
                                                  ? () => setState(
                                                      () => _selected = doc.id,
                                                    )
                                                  : null,
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor:
                                                    _selected == doc.id
                                                    ? kYellow
                                                    : null,
                                                foregroundColor: kInk,
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                              ),
                                              child: Text(
                                                '${_selected == doc.id ? '✓ ' : ''}${doc.data()['title']}',
                                              ),
                                            ),
                                          ),
                                        ),
                                      FilledButton(
                                        onPressed: open && valid && !_sending
                                            ? _submit
                                            : null,
                                        child: Text(
                                          _sending
                                              ? '한 표를 보내는 중…'
                                              : '이 의견에 투표하기',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                        ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: const Text('교사 화면으로 돌아가기'),
          ),
        ],
      ),
    );
  }
}
