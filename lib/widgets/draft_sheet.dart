import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 교사 PTT 초안 확인 시트.
/// 길게 눌러 녹음 후 전사 결과를 확인·수정 → 기록하기 or 다시 녹음.
class DraftSheet extends StatefulWidget {
  final String initialText;
  final Duration recordDuration;
  final void Function(String text) onSubmit;
  final VoidCallback onReRecord;

  const DraftSheet({
    super.key,
    required this.initialText,
    required this.recordDuration,
    required this.onSubmit,
    required this.onReRecord,
  });

  @override
  State<DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<DraftSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }

  String get _durationLabel {
    final s = widget.recordDuration.inSeconds;
    final ms = (widget.recordDuration.inMilliseconds % 1000) ~/ 100;
    return '$s.$ms초 · ${widget.initialText.length}자';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kInk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 제목 행
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✓',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '초안 확인',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _durationLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  color: kInk.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 텍스트 박스
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: null,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: kInk,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kGround,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kYellow, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kYellow, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kYellow, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '텍스트를 눌러 수정할 수 있어요. 기록하면 AI 그룹화 맥락으로 사용됩니다.',
            style: TextStyle(
              fontSize: 11.5,
              color: kInk.withValues(alpha: 0.45),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: OutlinedButton(
                  onPressed: widget.onReRecord,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kGreen,
                    side: const BorderSide(color: kGreen),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '다시 녹음',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '기록하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
