import 'package:flutter/foundation.dart';
import '../models/approved_group.dart';
import '../models/group.dart';
import '../models/group_snapshot.dart';
import '../models/idea.dart';
import '../models/merge_log.dart';
import 'ai_api_client.dart';
import 'grouping_engine.dart';
import 'idea_chunk_buffer.dart';

const _bufferMinSize = 3;
const _bufferDebounce = Duration(milliseconds: 2500);

/// Gemini 기반 클러스터링 — 응답 전까지 Jaccard 폴백 사용.
/// Java GeminiGroupingEngine의 동일한 incremental 전략.
class GeminiGroupingEngine {
  final _fallback = GroupingEngine();
  final _api = AiApiClient();
  final void Function() onUpdate;

  late final IdeaChunkBuffer _buffer;
  List<Group>? _cachedGroups;
  List<Group>? _mergeSnapshot;
  final _processedIds = <String>{};
  String sessionTitle = '';
  List<String> recentTeacherNotes = [];
  bool _frozen = false;
  VoidCallback? onGroupUpdate;

  /// 그룹 구성이 바뀔 때마다 호출된다 — 호출자가 Firestore에 스냅샷으로 저장한다.
  /// (Mercury-Session-02: 앱 재시작 시 교사의 병합·이동 결과가 사라지던 문제)
  void Function(List<Group> groups)? onGroupsChanged;

  // GPT 호출 순차 처리용
  bool _calling = false;
  final _pendingBatches = <List<Idea>>[];

  GeminiGroupingEngine({required this.onUpdate}) {
    _buffer = IdeaChunkBuffer(
      minSize: _bufferMinSize,
      debounce: _bufferDebounce,
      onFlush: _callGemini,
    );
  }

  // ── Public API ───────────────────────────────────────────────────────────

  List<Group>? get cachedGroups => _cachedGroups;

  bool get hasCachedGroups => _cachedGroups != null;

  /// Firestore 스냅샷으로 그룹 구성을 복원한다.
  ///
  /// 복원된 의견은 `_processedIds`에 등록해 **다시 GPT로 보내지 않는다.**
  /// 이 표시가 없으면 `makeGroups()`가 기존 의견 전부를 버퍼에 넣어
  /// 재그룹화를 유발하고, 교사가 정리한 구성이 그대로 덮인다.
  ///
  /// 스냅샷에 없는 의견(복귀 중 새로 들어온 것)은 미처리로 남아
  /// 다음 배치에서 기존 그룹에 편입된다.
  bool restoreSnapshot(List<GroupSnapshotEntry> snapshot, List<Idea> ideas) {
    if (_cachedGroups != null) return false;
    if (snapshot.isEmpty) return false;

    final byId = {for (final i in ideas) i.id: i};
    final restored = <Group>[];
    for (final entry in snapshot) {
      final groupIdeas =
          entry.ideaIds.map((id) => byId[id]).whereType<Idea>().toList();
      // 원문이 삭제된 그룹은 복원하지 않는다 — ideas 컬렉션이 단일 진실이다.
      if (groupIdeas.isEmpty) continue;
      restored.add(Group(
        id: entry.groupId,
        ideas: groupIdeas,
        aiTitle: entry.aiTitle,
      ));
    }
    if (restored.isEmpty) return false;

    _cachedGroups = restored;
    for (final g in restored) {
      for (final i in g.ideas) {
        _processedIds.add(i.id);
      }
    }
    onGroupUpdate?.call();
    return true;
  }

  List<Group> makeGroups(List<Idea> ideas) {
    if (!_frozen) {
      for (final idea in ideas) {
        if (!_processedIds.contains(idea.id)) _buffer.add(idea);
      }
    }
    if (_cachedGroups != null) return _cachedGroups!;
    // 빈 텍스트 의견은 Jaccard 폴백에도 포함하지 않음
    final valid = ideas.where((i) => i.text.trim().isNotEmpty).toList();
    return _fallback.makeGroups(valid);
  }

  void _persist() {
    onGroupsChanged?.call(_cachedGroups ?? const []);
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

  // sourceGroupId 그룹에 targetGroupIds 그룹들의 의견을 모두 합침, 빈 그룹 제거.
  // 병합 전 상태를 MergeLog로 반환 — 호출자가 Firestore에 저장.
  MergeLog? mergeGroups(
    String sourceGroupId,
    List<String> targetGroupIds,
    String newTitle, {
    List<ApprovedGroup> approvedGroups = const [],
  }) {
    if (_cachedGroups == null) return null;
    _mergeSnapshot = List<Group>.from(_cachedGroups!);

    final allSourceIds = {sourceGroupId, ...targetGroupIds};
    final sourceGroupObjects =
        _cachedGroups!.where((g) => allSourceIds.contains(g.id)).toList();

    final absorbed = <Idea>[];
    final kept = <Group>[];
    for (final g in _cachedGroups!) {
      if (targetGroupIds.contains(g.id)) {
        absorbed.addAll(g.ideas);
      } else {
        kept.add(g);
      }
    }
    _cachedGroups = kept.map((g) {
      if (g.id != sourceGroupId) return g;
      return Group(
          id: g.id,
          ideas: List<Idea>.from([...g.ideas, ...absorbed]),
          aiTitle: newTitle);
    }).toList();
    onGroupUpdate?.call();
    _persist();

    final logSources = sourceGroupObjects.map((g) {
      final approved = approvedGroups.cast<ApprovedGroup?>().firstWhere(
            (ag) => ag?.groupId == g.id,
            orElse: () => null,
          );
      return MergeLogSourceGroup(
        groupId: g.id,
        title: makeGroupTitle(g),
        ideaIds: g.ideas.map((i) => i.id).toList(),
        wasApproved: approved != null,
        approvedAt: approved?.approvedAt,
        approvedBy: approved?.approvedBy,
        revision: approved?.revision,
      );
    }).toList();

    return MergeLog(
      logId: 'merge_${DateTime.now().millisecondsSinceEpoch}',
      mergedAt: DateTime.now(),
      sourceGroups: logSources,
      resultGroupId: sourceGroupId,
      undone: false,
    );
  }

  bool get canUndoMerge => _mergeSnapshot != null;

  void undoMerge() {
    if (_mergeSnapshot == null) return;
    _cachedGroups = _mergeSnapshot;
    _mergeSnapshot = null;
    onGroupUpdate?.call();
    _persist();
  }

  // ideaFallback: 미분류 의견(어떤 그룹에도 없는)을 이동할 때 넘김
  void moveIdea(String ideaId, String? targetGroupId, {Idea? ideaFallback}) {
    Idea? moved;
    final updated = <Group>[];
    for (final g in (_cachedGroups ?? [])) {
      final idx = g.ideas.indexWhere((i) => i.id == ideaId);
      if (idx >= 0 && moved == null) {
        moved = g.ideas[idx];
        final remaining = List<Idea>.from(g.ideas)..removeAt(idx);
        if (remaining.isNotEmpty) updated.add(g.copyWith(ideas: remaining));
      } else {
        updated.add(g);
      }
    }
    moved ??= ideaFallback;
    if (moved == null) return;

    if (targetGroupId == null) {
      final newId = 'manual_${DateTime.now().millisecondsSinceEpoch}';
      updated.add(Group(id: newId, ideas: [moved], aiTitle: null));
    } else {
      for (var i = 0; i < updated.length; i++) {
        if (updated[i].id == targetGroupId) {
          updated[i] = updated[i].copyWith(ideas: List<Idea>.from([...updated[i].ideas, moved]));
          break;
        }
      }
    }
    _cachedGroups = updated;
    onGroupUpdate?.call();
    _persist();
  }

  void reset() {
    _buffer.clear();
    _cachedGroups = null;
    _mergeSnapshot = null;
    _processedIds.clear();
    _pendingBatches.clear();
    _calling = false;
    _frozen = false;
    recentTeacherNotes = [];
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _callGemini(List<Idea> rawBatch) async {
    // 빈 텍스트 의견 즉시 처리 완료 표시 (GPT에 보내지 않음)
    final emptyIdeas = rawBatch.where((i) => i.text.trim().isEmpty).toList();
    if (emptyIdeas.isNotEmpty) _markProcessed(emptyIdeas);

    final batch = rawBatch.where((i) => i.text.trim().isNotEmpty).toList();
    if (batch.isEmpty) return;

    // 이미 GPT 호출 중이면 큐에 쌓아두고 완료 후 순차 처리
    if (_calling) {
      _pendingBatches.add(batch);
      return;
    }
    await _processQueue(batch);
  }

  Future<void> _processQueue(List<Idea> first) async {
    _calling = true;
    var current = first;
    try {
      while (true) {
        // snapshot은 루프 시작 직전 _cachedGroups 기준 — 이전 배치 결과 반영됨
        final snapshot = List<Group>.from(_cachedGroups ?? []);
        try {
          final result = await _api.groupIdeas(snapshot, current,
              sessionTitle: sessionTitle, teacherNotes: recentTeacherNotes);
          _applyResult(result, current, snapshot);
        } catch (e) {
          _markProcessed(current);
        }
        if (_pendingBatches.isEmpty) break;
        current = _pendingBatches.removeAt(0);
      }
    } finally {
      _calling = false;
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
      _mergeSnapshot = null; // AI 재구성 시 이전 병합 undo 무효화
      _markProcessed(batch);
      onUpdate();
      onGroupUpdate?.call();
      _persist();
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
    final minOverlap = (ideas.length / 2).ceil().clamp(1, ideas.length);
    if (best != null && bestOverlap >= minOverlap) return best.id;
    if (proposed.trim().isNotEmpty) return proposed;
    return ideas.first.id;
  }
}
