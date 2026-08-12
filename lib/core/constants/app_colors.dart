import 'package:flutter/material.dart';

class AppColors {
  // Brand Primaries & Electric Accents
  static const Color primary = Color(0xFF3B5BFD); // High-Precision Royal Indigo
  static const Color primaryDark = Color(0xFF2A42CE);
  static const Color primaryLight = Color(0xFF637CFF);
  static const Color secondary = Color(0xFF0EA5E9); // Electric Cyan

  // Surface & Canvas (Light Theme)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightElevated = Color(0xFFF1F5F9);
  static const Color cardBorderLight = Color(0xFFE2E8F0);

  // Surface & Canvas (Executive Obsidian Dark Theme)
  static const Color backgroundDark = Color(0xFF090D16); // Deep Obsidian
  static const Color surfaceDark = Color(0xFF111726); // Midnight Slate
  static const Color surfaceDarkElevated = Color(0xFF1A2236); // Elevated Slate
  static const Color surfaceDarkHighlight = Color(0xFF232D47);
  static const Color cardBorderDark = Color(0x1FFFFFFF); // 12% Hairline Glass Border

  // Typography Tokens
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // Semantic Feedback
  static const Color success = Color(0xFF10B981); // Emerald Active
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B); // Amber Alert
  static const Color error = Color(0xFFF43F5E); // Crimson Rose
  static const Color info = Color(0xFF3B82F6); // Cobalt Info

  // Executive Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B5BFD), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF151C2E), Color(0xFF0F1524)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ambientMeshDark = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF0B0F19)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
