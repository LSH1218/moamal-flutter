import 'package:flutter/material.dart';

// 브랜드 5색
const kInk    = Color(0xFF20231F);
const kGreen  = Color(0xFF225B43);
const kGround = Color(0xFFF3EFE5);
const kYellow = Color(0xFFF1C84B);
const kCardBg = Color(0xFFFFFDF8);

// 파생 색 — 상태 표현 전용
const kRed        = Color(0xFFD32F2F); // 녹음 중·LIVE·종료·에러
const kBlue       = Color(0xFF2C6BA8); // 전사 중 스피너
const kDisabled   = Color(0xFFB9B4A8); // 강제 종료된 마이크·비활성
const kBorder     = Color(0xFFE8E4DC); // 카드 테두리 (연)
const kBorderMid  = Color(0xFFE0DDD6); // 카드 테두리 (중)
const kBorderDark = Color(0xFFD8D3C6); // 카드 테두리 (진)
const kErrorBg    = Color(0xFFFCF0EF); // 코드 입력 에러 배경

ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: kGround,
      colorScheme: const ColorScheme.light(
        primary: kGreen,
        secondary: kYellow,
        surface: kGround,
        onPrimary: Colors.white,
        onSecondary: kInk,
        onSurface: kInk,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kGreen,
          side: const BorderSide(color: kGreen),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: const CardThemeData(
        color: kCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kGreen, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        bodySmall: TextStyle(color: kInk),
        bodyMedium: TextStyle(color: kInk),
        bodyLarge: TextStyle(color: kInk),
        titleMedium: TextStyle(color: kInk, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: kInk, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: kInk, fontWeight: FontWeight.bold),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kInk,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0DDD6),
        space: 1,
        thickness: 1,
      ),
    );
