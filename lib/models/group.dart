import 'idea.dart';

class Group {
  final String id;
  final List<Idea> ideas;
  final String? aiTitle;

  const Group({
    required this.id,
    required this.ideas,
    this.aiTitle,
  });

  Group copyWith({List<Idea>? ideas, String? aiTitle}) {
    return Group(
      id: id,
      ideas: ideas ?? this.ideas,
      aiTitle: aiTitle ?? this.aiTitle,
    );
  }

  String get summary {
    if (ideas.isEmpty) return '';
    final text = ideas.first.text;
    return text.length <= 34 ? text : '${text.substring(0, 34)}...';
  }

  String get displayTitle => aiTitle ?? summary;
}
