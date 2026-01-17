import 'package:flutter/material.dart';

enum ThemePreset {
  glassIce,
  obsidian,
  blueprint,
  sunset,
  verdant,
  mono,
}

class UiTheme {
  final String id;
  final String label;
  final List<Color> backgroundGradient;
  final Color panelTint;
  final Color panelBorder;
  final Color panelShadow;
  final Color accent;
  final Color accentAlt;

  const UiTheme({
    required this.id,
    required this.label,
    required this.backgroundGradient,
    required this.panelTint,
    required this.panelBorder,
    required this.panelShadow,
    required this.accent,
    required this.accentAlt,
  });
}

class UiThemes {
  static const UiTheme glassIce = UiTheme(
    id: 'glassIce',
    label: 'Glass Ice',
    backgroundGradient: [
      Color(0xFFCBD7F0),
      Color(0xFFEDEFF8),
      Color(0xFFDCE6F7),
    ],
    panelTint: Color(0x33FFFFFF),
    panelBorder: Color(0x66FFFFFF),
    panelShadow: Color(0x33000000),
    accent: Color(0xFF2A5CFF),
    accentAlt: Color(0xFF19B6A8),
  );

  static const UiTheme obsidian = UiTheme(
    id: 'obsidian',
    label: 'Obsidian',
    backgroundGradient: [
      Color(0xFF0F1116),
      Color(0xFF1B202B),
      Color(0xFF11151C),
    ],
    panelTint: Color(0x331B202B),
    panelBorder: Color(0x552A3242),
    panelShadow: Color(0x99000000),
    accent: Color(0xFF5AA9FF),
    accentAlt: Color(0xFFFFC857),
  );

  static const UiTheme blueprint = UiTheme(
    id: 'blueprint',
    label: 'Blueprint',
    backgroundGradient: [
      Color(0xFF0B2D5C),
      Color(0xFF0F3C73),
      Color(0xFF0B2D5C),
    ],
    panelTint: Color(0x3320406E),
    panelBorder: Color(0x665DD3FF),
    panelShadow: Color(0x66000000),
    accent: Color(0xFF5DD3FF),
    accentAlt: Color(0xFFFFC857),
  );

  static const UiTheme sunset = UiTheme(
    id: 'sunset',
    label: 'Sunset Forge',
    backgroundGradient: [
      Color(0xFFFFE2B6),
      Color(0xFFF8C4A4),
      Color(0xFFF5B6B8),
    ],
    panelTint: Color(0x33FFFFFF),
    panelBorder: Color(0x66FFFFFF),
    panelShadow: Color(0x33000000),
    accent: Color(0xFFEF6A4C),
    accentAlt: Color(0xFF3B82F6),
  );

  static const UiTheme verdant = UiTheme(
    id: 'verdant',
    label: 'Verdant',
    backgroundGradient: [
      Color(0xFFE2F6E9),
      Color(0xFFCFF0E6),
      Color(0xFFBFE7DD),
    ],
    panelTint: Color(0x33FFFFFF),
    panelBorder: Color(0x66FFFFFF),
    panelShadow: Color(0x33000000),
    accent: Color(0xFF1BA784),
    accentAlt: Color(0xFF2A5CFF),
  );

  static const UiTheme mono = UiTheme(
    id: 'mono',
    label: 'Mono Studio',
    backgroundGradient: [
      Color(0xFFF2F2F2),
      Color(0xFFE8E8E8),
      Color(0xFFF2F2F2),
    ],
    panelTint: Color(0x33FFFFFF),
    panelBorder: Color(0x66000000),
    panelShadow: Color(0x22000000),
    accent: Color(0xFF111111),
    accentAlt: Color(0xFF4B5563),
  );

  static const Map<ThemePreset, UiTheme> presets = {
    ThemePreset.glassIce: glassIce,
    ThemePreset.obsidian: obsidian,
    ThemePreset.blueprint: blueprint,
    ThemePreset.sunset: sunset,
    ThemePreset.verdant: verdant,
    ThemePreset.mono: mono,
  };
}
