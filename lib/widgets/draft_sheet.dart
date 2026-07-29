import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STT 전사 결과를 학생이 확인·수정하고 제출하는 바텀시트.
/// onSubmit: 최종 텍스트를 상위로 전달.
/// onReRecord: 시트를 닫고 다시 녹음 상태로 복귀.
class DraftSheet extends StatefulWidget {
  final String initialText;
  final void Function(String text) onSubmit;
  final VoidCallback onReRecord;

  const DraftSheet({
    super.key,
    required this.initialText,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '이렇게 들렸어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '잘못 들린 부분이 있으면 수정해 주세요.',
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: null,
            minLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              filled: true,
              fillColor: kGround,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onReRecord,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('다시 녹음'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '제출',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
