import 'dart:async';
import '../models/idea.dart';

/// Gemini 호출을 줄이기 위해 의견을 배치로 묶어서 보내는 버퍼.
/// minSize개 이상이면 즉시 flush, 아니면 debounceMs 후 flush.
class IdeaChunkBuffer {
  final int minSize;
  final Duration debounce;
  final void Function(List<Idea>) onFlush;

  final _pending = <Idea>[];
  Timer? _timer;

  IdeaChunkBuffer({
    required this.minSize,
    required this.debounce,
    required this.onFlush,
  });

  void add(Idea idea) {
    _pending.add(idea);
    _timer?.cancel();
    if (_pending.length >= minSize) {
      _flush();
    } else {
      _timer = Timer(debounce, _flush);
    }
  }

  void clear() {
    _pending.clear();
    _timer?.cancel();
    _timer = null;
  }

  void _flush() {
    if (_pending.isEmpty) return;
    final batch = List<Idea>.from(_pending);
    _pending.clear();
    _timer?.cancel();
    _timer = null;
    onFlush(batch);
  }
}
