import 'package:flutter/material.dart';

/// 앱 공통 화면 너비 브레이크포인트
class AppBreakpoints {
  AppBreakpoints._();

  /// 600 미만 → 폰 세로(compact) 레이아웃
  static const double compact = 600;

  /// 900 이상 → 태블릿(expanded) 레이아웃
  static const double medium = 900;
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
}

/// 바텀시트·다이얼로그가 태블릿에서 과도하게 넓어지지 않도록 제한
BoxConstraints sheetConstraints({double maxWidth = 520}) =>
    BoxConstraints(maxWidth: maxWidth);
