import 'package:flutter/material.dart';

/// 앱 공통 화면 너비 브레이크포인트
class AppBreakpoints {
  AppBreakpoints._();

  /// 600 미만 → 폰 세로(compact) 레이아웃
  static const double compact = 600;

  /// 900 이상 → 태블릿(expanded) 레이아웃
  static const double medium = 900;

  /// 360 미만 → 소형 기기. 고정 크기 요소를 유연하게 바꿔야 하는 하한
  static const double narrow = 360;
}

extension AppSizeExt on BuildContext {
  double get sw => MediaQuery.sizeOf(this).width;
  double get sh => MediaQuery.sizeOf(this).height;

  /// 홈 인디케이터·노치 등 시스템 여백
  EdgeInsets get viewPad => MediaQuery.paddingOf(this);

  /// 600 미만: 폰 세로 레이아웃
  bool get isCompact => sw < AppBreakpoints.compact;

  /// 900 이상: 태블릿 레이아웃
  bool get isTablet => sw >= AppBreakpoints.medium;

  /// 360 미만: 소형·저가형 기기(예: 320dp). 고정 크기 요소의 하한 대응이 필요한 구간
  bool get isNarrow => sw < AppBreakpoints.narrow;
}

/// 다이얼로그 좌우 여백.
/// 좁은 기기에서 40dp 고정이면 내부 폭을 80dp나 깎아 고정 크기 요소가 넘친다.
double dialogInsetH(BuildContext context, {double tabletFactor = 0.25}) =>
    context.isTablet
        ? context.sw * tabletFactor
        : context.isNarrow
            ? 16.0
            : 40.0;

/// 바텀시트·다이얼로그가 태블릿에서 과도하게 넓어지지 않도록 제한
BoxConstraints sheetConstraints({double maxWidth = 520}) =>
    BoxConstraints(maxWidth: maxWidth);
