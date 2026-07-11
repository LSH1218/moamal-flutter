import 'package:flutter/material.dart';

const kInk = Color(0xFF20231F);
const kGreen = Color(0xFF225B43);
const kGround = Color(0xFFF3EFE5);
const kYellow = Color(0xFFF1C84B);
const kCardBg = Color(0xFFFFFDF8);

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
