import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Firebase Remote Config에서 AI 프롬프트를 서빙.
/// 첫 fetch 전까지는 하드코딩 기본값 사용.
class PromptConfig {
  static const _groupingSystem = '''당신은 한국 교사의 수업 중 학생 의견을 실시간으로 묶어주는 AI입니다.
규칙:
1. 의미가 비슷한 의견을 같은 그룹으로 묶기
2. 각 그룹에 한국어 짧은 제목(2~4단어) 생성
3. 하나의 의견은 하나의 그룹에만 속함
4. 기존 그룹이 있으면 새 의견을 기존 그룹에 배정하거나 새 그룹 생성
5. 반드시 유효한 JSON만 반환

출력 형식:
{"groups":[{"id":"그룹ID","title":"제목","idea_ids":["의견ID"]}]}''';

  static const _briefingSystem =
      '한국 초중고 수업 현장에서 교사를 실시간으로 돕는 AI입니다. 간결하고 실용적으로 답합니다.';

  static const _briefingFormat =
      '교사에게 실시간으로 알려줘. JSON만 반환:\n'
      '{"flow":"현재 의견 흐름(2문장)","action":"지금 바로 할 행동(1문장)","question":"학생에게 던질 다음 질문(1문장)"}';

  static const _reportSystem =
      '당신은 초중고 학급회의 내용을 교사용 공문 수준으로 정리하는 AI입니다.\n'
      '발언에 없는 내용은 추가하지 않습니다. 반드시 유효한 JSON만 반환합니다.';

  static const _reportFormat =
      '위 학급회의를 교사용 요약 리포트로 작성해 주세요. JSON만 반환:\n'
      '{"overview":"전체 흐름 2문장",'
      '"groups":[{"title":"묶음명","size":발언수,"votes":득표수,"key_quote":"대표발언"}],'
      '"vote_summary":"투표 결과 1문장",'
      '"conclusion":"결론 또는 미결",'
      '"next_action":"교사 후속 조치 1-2문장",'
      '"unresolved":"남은 쟁점 또는 null"}';

  static const _defaults = <String, String>{
    'prompt_grouping_system': _groupingSystem,
    'prompt_briefing_system': _briefingSystem,
    'prompt_briefing_format': _briefingFormat,
    'prompt_report_system': _reportSystem,
    'prompt_report_format': _reportFormat,
  };

  static FirebaseRemoteConfig? _rc;

  static Future<void> init() async {
    _rc = FirebaseRemoteConfig.instance;
    await _rc!.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await _rc!.setDefaults(_defaults);
    _rc!.fetchAndActivate(); // 백그라운드 — 다음 실행부터 반영
  }

  static String groupingSystem() => _get('prompt_grouping_system');
  static String briefingSystem() => _get('prompt_briefing_system');
  static String briefingFormat() => _get('prompt_briefing_format');
  static String reportSystem() => _get('prompt_report_system');
  static String reportFormat() => _get('prompt_report_format');

  static String _get(String key) {
    if (_rc == null) return _defaults[key] ?? '';
    final val = _rc!.getString(key);
    return val.isEmpty ? (_defaults[key] ?? '') : val;
  }
}
