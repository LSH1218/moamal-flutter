import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/group.dart';
import '../models/idea.dart';
import '../models/meeting_report.dart';
import 'prompt_config.dart';

const _model = 'gemini-2.0-flash-lite';

// API 키: flutter run --dart-define=GEMINI_API_KEY=xxx 로 주입
// 임시로 직접 넣는 경우 여기에 설정 (나중에 Firebase Functions로 이전 예정)
const _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

String get _endpoint =>
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';

class GeminiApiClient {
  // ── 의견 클러스터링 ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> groupIdeas(
      List<Group> existing, List<Idea> newIdeas) async {
    final body = _buildGroupBody(existing, newIdeas);
    final text = await _call(body);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  // ── 진행자 AI 브리핑 ─────────────────────────────────────────────────────

  Future<({String flow, String action, String question})> generateBriefing(
      String sessionTitle, List<Group> groups, List<Idea> ideas) async {
    final body = _buildBriefingBody(sessionTitle, groups, ideas);
    final text = await _call(body);
    final json = jsonDecode(text) as Map<String, dynamic>;
    return (
      flow: json['flow'] as String? ?? '',
      action: json['action'] as String? ?? '',
      question: json['question'] as String? ?? '',
    );
  }

  // ── 수업기록 리포트 ──────────────────────────────────────────────────────

  Future<MeetingReport> generateReport(
    String sessionTitle,
    List<Group> groups,
    Map<String, int> voteCounts,
    int totalVoters,
  ) async {
    final body =
        _buildReportBody(sessionTitle, groups, voteCounts, totalVoters);
    final text = await _call(body);
    return MeetingReport.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  // ── HTTP 공통 ────────────────────────────────────────────────────────────

  Future<String> _call(Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw Exception('Gemini HTTP ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  // ── Body builders ────────────────────────────────────────────────────────

  Map<String, dynamic> _buildGroupBody(
      List<Group> existing, List<Idea> newIdeas) {
    final sb = StringBuffer();
    if (existing.isNotEmpty) {
      final grps = existing.map((g) => {
            'id': g.id,
            'title': g.aiTitle ?? '',
            'size': g.ideas.length,
            'idea_ids': g.ideas.map((i) => i.id).toList(),
          });
      sb.writeln('기존 그룹:\n${jsonEncode(grps.toList())}\n');
    }
    final ideas = newIdeas.map((i) => {'id': i.id, 'text': i.text}).toList();
    sb.write('새 의견:\n${jsonEncode(ideas)}');

    return {
      'system_instruction': {
        'parts': [
          {'text': PromptConfig.groupingSystem()}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': sb.toString()}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
        'maxOutputTokens': 512,
      },
    };
  }

  Map<String, dynamic> _buildBriefingBody(
      String sessionTitle, List<Group> groups, List<Idea> ideas) {
    final sb = StringBuffer();
    sb.writeln('수업 주제: $sessionTitle\n');
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final title = g.aiTitle ?? '묶음 ${i + 1}';
      sb.writeln('[$title] (${g.ideas.length}명)');
      for (final idea in g.ideas) {
        sb.writeln('- ${idea.speaker}: ${idea.text}');
      }
      sb.writeln();
    }
    sb.write(PromptConfig.briefingFormat());

    return {
      'system_instruction': {
        'parts': [
          {'text': PromptConfig.briefingSystem()}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': sb.toString()}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.4,
        'maxOutputTokens': 256,
      },
    };
  }

  Map<String, dynamic> _buildReportBody(
    String sessionTitle,
    List<Group> groups,
    Map<String, int> voteCounts,
    int totalVoters,
  ) {
    final totalVotes = voteCounts.values.fold(0, (a, b) => a + b);
    final sb = StringBuffer();
    sb.writeln('[회의 정보]');
    sb.write('주제: $sessionTitle\n투표 참여: $totalVotes명');
    if (totalVoters > 0) {
      sb.write(' / 전체 $totalVoters명 (기권 ${totalVoters - totalVotes}명)');
    }
    sb.writeln('\n\n[의견 묶음]');
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final title = g.aiTitle ?? '묶음 ${i + 1}';
      final gVotes = voteCounts[g.id] ?? 0;
      sb.writeln('[$title] ${g.ideas.length}명 발언 · $gVotes표');
      for (final idea in g.ideas) {
        sb.writeln('- ${idea.speaker}: ${idea.text}');
      }
      sb.writeln();
    }
    sb.write(PromptConfig.reportFormat());

    return {
      'system_instruction': {
        'parts': [
          {'text': PromptConfig.reportSystem()}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': sb.toString()}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
        'maxOutputTokens': 512,
      },
    };
  }
}
