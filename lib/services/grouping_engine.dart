import '../models/group.dart';
import '../models/idea.dart';

/// Jaccard 유사도 기반 로컬 클러스터링 — Gemini 폴백으로 사용
class GroupingEngine {
  static const double _threshold = 0.34;

  static const _stopWords = {
    '저는', '우리', '그리고', '하는', '하고', '같아요', '좋아요', '정말',
  };

  List<Group> makeGroups(List<Idea> ideas) {
    final groups = <Group>[];
    for (final idea in ideas) {
      Group? match;
      outer:
      for (final group in groups) {
        for (final item in group.ideas) {
          if (_similarity(item.text, idea.text) >= _threshold) {
            match = group;
            break outer;
          }
        }
      }
      if (match == null) {
        match = Group(id: idea.id, ideas: <Idea>[]);
        groups.add(match);
      }
      groups[groups.indexOf(match)] =
          match.copyWith(ideas: List<Idea>.from([...match.ideas, idea]));
    }
    groups.sort((a, b) => b.ideas.length.compareTo(a.ideas.length));
    return groups;
  }

  Map<String, int> voteCounts(List<Group> groups, Map<String, String> votes) {
    final validIds = {for (final g in groups) g.id};
    final counts = <String, int>{};
    for (final groupId in votes.values) {
      if (validIds.contains(groupId)) {
        counts[groupId] = (counts[groupId] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<String> topKeywords(List<Idea> ideas, int limit) {
    final counts = <String, int>{};
    for (final idea in ideas) {
      for (final token in _tokens(idea.text)) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }
    final words = counts.keys.toList()
      ..sort((a, b) {
        final diff = counts[b]! - counts[a]!;
        return diff != 0 ? diff : a.compareTo(b);
      });
    return words.take(limit).toList();
  }

  String makeGroupTitle(Group group) {
    final keywords = topKeywords(group.ideas, 2);
    if (keywords.isNotEmpty) return keywords.join(' · ');
    return group.summary;
  }

  Set<String> _tokens(String text) {
    final cleaned =
        text.toLowerCase().replaceAll(RegExp(r'[^가-힣a-z0-9\s]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !_stopWords.contains(w))
        .toSet();
  }

  double _similarity(String a, String b) {
    final left = _tokens(a);
    final right = _tokens(b);
    final common = left.intersection(right).length;
    final denom = left.length < right.length ? left.length : right.length;
    return common / (denom == 0 ? 1 : denom);
  }
}
