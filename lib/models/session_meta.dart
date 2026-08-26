/// 세션 문서의 라이프사이클 필드만 담는 경량 모델.
///
/// 앱 시작 시 "저장된 세션으로 복귀해도 되는가"를 판단하는 용도다.
/// 하위 컬렉션(ideas·votes·participants…)을 읽지 않으므로 문서 read 1회로 끝난다.
class SessionMeta {
  final String sessionCode;
  final DateTime? createdAt;
  final DateTime? endedAt;

  const SessionMeta({
    required this.sessionCode,
    required this.createdAt,
    required this.endedAt,
  });

  bool get isEnded => endedAt != null;

  /// 복귀 허용 조건: **당일에 만들어졌고 아직 끝나지 않은 세션** (2026-08-26 대표 결정).
  ///
  /// `createdAt`이 없으면 이 변경 이전에 만들어진 세션이라 판단할 근거가 없다.
  /// 이때는 복귀하지 않는다 — 잘못 복귀해 어제 수업에 발언이 섞이는 쪽이,
  /// 코드를 다시 입력하는 것보다 나쁘다.
  bool canResumeAt(DateTime now) {
    if (isEnded) return false;
    final created = createdAt;
    if (created == null) return false;
    final local = created.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }
}
