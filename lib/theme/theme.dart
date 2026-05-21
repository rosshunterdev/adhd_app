import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Brand ─────────────────────────────────────────────────────────────────────
const Color kPrimary   = Color(0xFF3D5AFE);
const Color kSurface   = Color(0xFFF8F9FF);
const Color kTextDark  = Color(0xFF1A1A2E);
const Color kTextMuted = Color(0xFF888888);

// ── Bucket headers ────────────────────────────────────────────────────────────
const Color kTodayColor    = Color(0xFFE53935);
const Color kTomorrowColor = Color(0xFFFB8C00);
const Color kGoalsColor    = Color(0xFF43A047);

// ── MaterialApp theme ─────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: kSurface,
    colorScheme: const ColorScheme.light(
      primary: kPrimary,
      surface: kSurface,
      onSurface: kTextDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: kTextDark),
      titleTextStyle: TextStyle(
        color: kTextDark,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Color(0x14000000), // black at ~8% opacity
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
