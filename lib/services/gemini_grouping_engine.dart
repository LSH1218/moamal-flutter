import '../models/group.dart';
import '../models/idea.dart';
import 'gemini_api_client.dart';
import 'grouping_engine.dart';
import 'idea_chunk_buffer.dart';

const _bufferMinSize = 3;
const _bufferDebounce = Duration(milliseconds: 2500);

/// Gemini 기반 클러스터링 — 응답 전까지 Jaccard 폴백 사용.
/// Java GeminiGroupingEngine의 동일한 incremental 전략.
class GeminiGroupingEngine {
  final _fallback = GroupingEngine();
  final _api = GeminiApiClient();
  final void Function() onUpdate;

  late final IdeaChunkBuffer _buffer;
  List<Group>? _cachedGroups;
  final _processedIds = <String>{};
  String sessionTitle = '';
  List<String> recentTeacherNotes = [];
  bool _frozen = false;

  GeminiGroupingEngine({required this.onUpdate}) {
    _buffer = IdeaChunkBuffer(
      minSize: _bufferMinSize,
      debounce: _bufferDebounce,
      onFlush: _callGemini,
    );
  }

  // ── Public API ───────────────────────────────────────────────────────────

  List<Group> makeGroups(List<Idea> ideas) {
    if (!_frozen) {
      for (final idea in ideas) {
        if (!_processedIds.contains(idea.id)) _buffer.add(idea);
      }
    }
    return _cachedGroups ?? _fallback.makeGroups(ideas);
  }

  void freeze() {
    _frozen = true;
    _buffer.clear();
  }

  String makeGroupTitle(Group group) =>
      group.aiTitle != null ? group.aiTitle! : _fallback.makeGroupTitle(group);

  Map<String, int> voteCounts(List<Group> groups, Map<String, String> votes) =>
      _fallback.voteCounts(groups, votes);

  List<String> topKeywords(List<Idea> ideas, int limit) =>
      _fallback.topKeywords(ideas, limit);

  void reset() {
    _buffer.clear();
    _cachedGroups = null;
    _processedIds.clear();
    _frozen = false;
    recentTeacherNotes = [];
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _callGemini(List<Idea> batch) async {
    final snapshot = List<Group>.from(_cachedGroups ?? []);
    try {
      final result = await _api.groupIdeas(snapshot, batch,
          sessionTitle: sessionTitle, teacherNotes: recentTeacherNotes);
      _applyResult(result, batch, snapshot);
    } catch (_) {
      // 폴백 유지 — 처리된 것으로 표시해 재큐 방지
      _markProcessed(batch);
    }
  }

  void _applyResult(
      Map<String, dynamic> result, List<Idea> batch, List<Group> prev) {
    try {
      final byId = <String, Idea>{};
      for (final g in prev) {
        for (final i in g.ideas) { byId[i.id] = i; }
      }
      for (final i in batch) { byId[i.id] = i; }

      final grpsJson = result['groups'] as List<dynamic>;
      final updated = <Group>[];
      for (final gj in grpsJson) {
        final gm = gj as Map<String, dynamic>;
        final gid = gm['id'] as String;
        final title = gm['title'] as String?;
        final ideaIds = (gm['idea_ids'] as List<dynamic>).cast<String>();

        final groupIdeas =
            ideaIds.map((id) => byId[id]).whereType<Idea>().toList();
        if (groupIdeas.isEmpty) continue;

        updated.add(Group(
          id: _stableGroupId(gid, groupIdeas, prev),
          ideas: groupIdeas,
          aiTitle: title,
        ));
      }
      updated.sort((a, b) => b.ideas.length.compareTo(a.ideas.length));

      _cachedGroups = updated;
      _markProcessed(batch);
      onUpdate();
    } catch (_) {
      _markProcessed(batch);
    }
  }

  void _markProcessed(List<Idea> batch) {
    for (final i in batch) { _processedIds.add(i.id); }
  }

  String _stableGroupId(String proposed, List<Idea> ideas, List<Group> prev) {
    if (ideas.isEmpty) return proposed;
    final ideaIds = {for (final i in ideas) i.id};

    Group? best;
    int bestOverlap = 0;
    for (final p in prev) {
      final overlap = p.ideas.where((i) => ideaIds.contains(i.id)).length;
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        best = p;
      }
    }
    final minOverlap = (ideas.length / 2).ceil().clamp(2, ideas.length);
    if (best != null && bestOverlap >= minOverlap) return best.id;
    if (proposed.trim().isNotEmpty) return proposed;
    return ideas.first.id;
  }
}
