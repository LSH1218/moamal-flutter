import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/group.dart';
import '../../../models/idea.dart';
import '../../../models/participant.dart';
import '../../../models/session_state.dart';
import '../../../repositories/firebase_moamal_repository.dart';
import '../../../services/gemini_grouping_engine.dart';
import '../../../services/whisper_stt_client.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/group_card.dart';
import '../../../widgets/mic_button.dart';
import '../../../widgets/stat_row.dart';

class StudentTab extends StatefulWidget {
  final SessionState session;
  final List<Group> groups;
  final GeminiGroupingEngine groupingEngine;
  final FirebaseMoamalRepository repo;

  const StudentTab({
    super.key,
    required this.session,
    required this.groups,
    required this.groupingEngine,
    required this.repo,
  });

  @override
  State<StudentTab> createState() => _StudentTabState();
}

class _StudentTabState extends State<StudentTab> {
  final _speakerCtrl = TextEditingController();
  final _ideaCtrl = TextEditingController();
  final _sttClient = WhisperSttClient();

  @override
  void dispose() {
    _speakerCtrl.dispose();
    _ideaCtrl.dispose();
    _sttClient.dispose();
    super.dispose();
  }

  Future<void> _submitIdea() async {
    final speaker = _speakerCtrl.text.trim();
    final text = _ideaCtrl.text.trim();
    if (speaker.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 내용을 모두 입력해 주세요.')),
      );
      return;
    }
    final idea = Idea(
      id: const Uuid().v4(),
      speaker: speaker,
      text: text,
      source: 'teacher',
    );
    await widget.repo.submitIdea(widget.session.sessionCode, idea);
    _ideaCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('의견 카드를 전송했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final gid in widget.session.votes.values) {
      counts[gid] = (counts[gid] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        StatRow(session: widget.session, groups: widget.groups),
        const SizedBox(height: 12),
        _Panel(
          title: '발표 기록',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '발표자 이름',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: kGreen,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _speakerCtrl,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 10),
              const Text(
                '발표 내용',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: kGreen,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _ideaCtrl,
                maxLines: 3,
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MicButton(
                      sttClient: _sttClient,
                      prompt: buildWhisperPrompt(widget.session.title),
                      onResult: (text) {
                        final current = _ideaCtrl.text.trim();
                        _ideaCtrl.text =
                            current.isEmpty ? text : '$current\n$text';
                      },
                      onError: (msg) => ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitIdea,
                      child: const Text('의견 추가'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '학생 마이크 제어',
          child: widget.session.participants.isEmpty
              ? const Text(
                  '아직 참여한 학생이 없습니다.',
                  style: TextStyle(color: Colors.black38),
                )
              : Column(
                  children: widget.session.participants
                      .map((p) => _ParticipantRow(
                            participant: p,
                            onForceStop: () => widget.repo.forceStopMic(
                                widget.session.sessionCode, p.uid),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '의견 묶음 ${widget.groups.length}개',
          child: widget.groups.isEmpty
              ? const Text(
                  '아직 등록된 의견이 없습니다.',
                  style: TextStyle(color: Colors.black38),
                )
              : Column(
                  children: widget.groups
                      .asMap()
                      .entries
                      .map(
                        (e) => GroupCard(
                          index: e.key,
                          group: e.value,
                          voteCount: counts[e.value.id] ?? 0,
                          editable: false,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final Participant participant;
  final VoidCallback onForceStop;

  const _ParticipantRow({
    required this.participant,
    required this.onForceStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              participant.displayName,
              style: const TextStyle(fontSize: 14, color: kInk),
            ),
          ),
          OutlinedButton(
            onPressed: onForceStop,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
              side: const BorderSide(color: Color(0xFFD32F2F)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('중지', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
