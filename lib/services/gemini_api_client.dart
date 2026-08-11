import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/group.dart';
import '../models/idea.dart';
import '../models/meeting_report.dart';
import 'prompt_config.dart';

const _model = 'gemini-2.5-flash';
const _defaultEndpoint =
    'https://asia-northeast3-moamal-1e601.cloudfunctions.net/geminiProxy';
const _endpoint = String.fromEnvironment(
  'GEMINI_PROXY_URL',
  defaultValue: _defaultEndpoint,
);

class GeminiApiClient {
  // ── 의견 클러스터링 ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> groupIdeas(
      List<Group> existing, List<Idea> newIdeas,
      {String sessionTitle = '', List<String> teacherNotes = const []}) async {
    final body = _buildGroupBody(existing, newIdeas,
        sessionTitle: sessionTitle, teacherNotes: teacherNotes);
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
    int totalVoters, {
    List<String> teacherNotes = const [],
  }) async {
    final body = _buildReportBody(sessionTitle, groups, voteCounts, totalVoters,
        teacherNotes: teacherNotes);
    final text = await _call(body);
    return MeetingReport.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  // ── HTTP 공통 ────────────────────────────────────────────────────────────

  Future<String> _call(Map<String, dynamic> geminiBody) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    final idToken = await user.getIdToken();

    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'model': _model, ...geminiBody}),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 429) throw Exception('요청이 너무 많습니다. 잠시 후 다시 시도하세요.');
    if (resp.statusCode != 200) {
      throw Exception('AI 요청 실패 (${resp.statusCode})');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return _stripMarkdown(json['text'] as String);
  }

  String _stripMarkdown(String text) {
    final s = text.trim();
    if (s.startsWith('```')) {
      final start = s.indexOf('\n') + 1;
      final end = s.lastIndexOf('```');
      if (start > 0 && end > start) return s.substring(start, end).trim();
    }
    return s;
  }

  // ── Body builders ────────────────────────────────────────────────────────

  Map<String, dynamic> _buildGroupBody(
      List<Group> existing, List<Idea> newIdeas,
      {String sessionTitle = '', List<String> teacherNotes = const []}) {
    final sb = StringBuffer();
    if (sessionTitle.isNotEmpty) {
      sb.write('수업 주제: $sessionTitle');
      if (teacherNotes.isNotEmpty) {
        sb.write(' | 교사 최근 지시: \'${teacherNotes.last}\'');
      }
      sb.writeln('\n');
    }
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
        'maxOutputTokens': 1024,
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
        'maxOutputTokens': 1024,
      },
    };
  }
}
