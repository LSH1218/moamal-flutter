import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/session_state.dart';
import '../theme/app_theme.dart';

class StatRow extends StatelessWidget {
  final SessionState session;
  final List<Group> groups;

  const StatRow({super.key, required this.session, required this.groups});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: '의견', value: session.ideas.length),
        const SizedBox(width: 8),
        _Stat(label: '묶음', value: groups.length),
        const SizedBox(width: 8),
        _Stat(label: '투표', value: session.votes.length),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
