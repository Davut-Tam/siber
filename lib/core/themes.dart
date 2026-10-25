import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n.dart';

/// Oyunun renk teması: zemin, ızgara, uçak, mermi, düşman ve arayüz renkleri birlikte seçilir.
class GameTheme {
  final String id;
  final String nameTr, nameEn;

  /// Açık zeminli tema: ışıltılar toplamalı (plus) karıştırılmaz, normal boyanır
  final bool light;

  final Color bg, bg2, nebula1, nebula2, grid, star;
  final Color accent, accent2;
  final Color shipBody, shipDark, canopy, flame;
  final Color bullet, bulletGlow, enemyBullet;

  /// Düşman renkleri: dron, zikzak, tank, nişancı, bölünen, kamikaze, ana gemi
  final List<Color> enemies;
  final Color text, textMuted, panel, panelBorder, danger, good;

  const GameTheme({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    this.light = false,
    required this.bg,
    required this.bg2,
    required this.nebula1,
    required this.nebula2,
    required this.grid,
    required this.star,
    required this.accent,
    required this.accent2,
    required this.shipBody,
    required this.shipDark,
    required this.canopy,
    required this.flame,
    required this.bullet,
    required this.bulletGlow,
    required this.enemyBullet,
    required this.enemies,
    required this.text,
    required this.textMuted,
    required this.panel,
    required this.panelBorder,
    required this.danger,
    required this.good,
  });

  String get name => S.current.code == 'en' ? nameEn : nameTr;

  /// Işıltılar için karıştırma kipi
  BlendMode get glowBlend => light ? BlendMode.srcOver : BlendMode.plus;

  SystemUiOverlayStyle get overlay => light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

  static GameTheme current = neon;

  static GameTheme byId(String? id) => all.firstWhere((t) => t.id == id, orElse: () => neon);

  static const all = [neon, synth, matrix, lava, gold, ice];

  static const neon = GameTheme(
    id: 'neon',
    nameTr: 'Neon',
    nameEn: 'Neon',
    bg: Color(0xFF03060D),
    bg2: Color(0xFF07152A),
    nebula1: Color(0x5000B4FF),
    nebula2: Color(0x3CA100FF),
    grid: Color(0x2600D2FF),
    star: Color(0xFFE6F7FF),
    accent: Color(0xFF00E5FF),
    accent2: Color(0xFFFF3D9A),
    shipBody: Color(0xFFDCEBFA),
    shipDark: Color(0xFF5F7C9C),
    canopy: Color(0xFF00E5FF),
    flame: Color(0xFF4FC3FF),
    bullet: Color(0xFFE8FDFF),
    bulletGlow: Color(0xFF00E5FF),
    enemyBullet: Color(0xFFFF4D6D),
    enemies: [
      Color(0xFFFF3D9A),
      Color(0xFFFFD23F),
      Color(0xFFFF7B2E),
      Color(0xFFB66DFF),
      Color(0xFF3DFF9A),
      Color(0xFFFF4040),
      Color(0xFFFF2E88),
    ],
    text: Color(0xFFE6F7FF),
    textMuted: Color(0x99E6F7FF),
    panel: Color(0xD90A1424),
    panelBorder: Color(0x4D00E5FF),
    danger: Color(0xFFFF4D6D),
    good: Color(0xFF3DFF9A),
  );

  static const synth = GameTheme(
    id: 'synth',
    nameTr: 'Synthwave',
    nameEn: 'Synthwave',
    bg: Color(0xFF0E0221),
    bg2: Color(0xFF2A0845),
    nebula1: Color(0x60FF2BD6),
    nebula2: Color(0x4CFF8A00),
    grid: Color(0x40FF2BD6),
    star: Color(0xFFFFE6FF),
    accent: Color(0xFFFF2BD6),
    accent2: Color(0xFFFFE45E),
    shipBody: Color(0xFFF5E6FF),
    shipDark: Color(0xFF7A4FA8),
    canopy: Color(0xFFFFE45E),
    flame: Color(0xFFFF8A00),
    bullet: Color(0xFFFFF6C2),
    bulletGlow: Color(0xFFFFE45E),
    enemyBullet: Color(0xFF00F0FF),
    enemies: [
      Color(0xFF00F0FF),
      Color(0xFFFFE45E),
      Color(0xFFFF8A00),
      Color(0xFF7CFF6B),
      Color(0xFFB98CFF),
      Color(0xFFFF3B3B),
      Color(0xFF00F0FF),
    ],
    text: Color(0xFFFFE6FF),
    textMuted: Color(0x99FFE6FF),
    panel: Color(0xD91A0633),
    panelBorder: Color(0x4DFF2BD6),
    danger: Color(0xFFFF3B6B),
    good: Color(0xFF7CFF6B),
  );

  static const matrix = GameTheme(
    id: 'matrix',
    nameTr: 'Matris',
    nameEn: 'Matrix',
    bg: Color(0xFF000804),
    bg2: Color(0xFF001A0C),
    nebula1: Color(0x4400FF66),
    nebula2: Color(0x2600AA44),
    grid: Color(0x3300FF66),
    star: Color(0xFFA8FFC8),
    accent: Color(0xFF00FF66),
    accent2: Color(0xFFC8FF00),
    shipBody: Color(0xFFD8FFE6),
    shipDark: Color(0xFF2E7A4E),
    canopy: Color(0xFF00FF66),
    flame: Color(0xFF9DFF4D),
    bullet: Color(0xFFEAFFEF),
    bulletGlow: Color(0xFF00FF66),
    enemyBullet: Color(0xFFFF3355),
    enemies: [
      Color(0xFFC8FF00),
      Color(0xFF00FFC8),
      Color(0xFFFFB000),
      Color(0xFFFF5CF0),
      Color(0xFF66FFE0),
      Color(0xFFFF3355),
      Color(0xFFFF5CF0),
    ],
    text: Color(0xFFD8FFE6),
    textMuted: Color(0x99D8FFE6),
    panel: Color(0xD9031A0D),
    panelBorder: Color(0x4D00FF66),
    danger: Color(0xFFFF3355),
    good: Color(0xFFC8FF00),
  );

  static const lava = GameTheme(
    id: 'lava',
    nameTr: 'Lav',
    nameEn: 'Lava',
    bg: Color(0xFF0D0302),
    bg2: Color(0xFF2A0905),
    nebula1: Color(0x60FF3D00),
    nebula2: Color(0x40FFB000),
    grid: Color(0x33FF5A1F),
    star: Color(0xFFFFD9C2),
    accent: Color(0xFFFF6A1F),
    accent2: Color(0xFFFFD23F),
    shipBody: Color(0xFFF2E2D9),
    shipDark: Color(0xFF7A4A3A),
    canopy: Color(0xFFFFD23F),
    flame: Color(0xFFFFB000),
    bullet: Color(0xFFFFF2D1),
    bulletGlow: Color(0xFFFF8A1F),
    enemyBullet: Color(0xFFFF2E5A),
    enemies: [
      Color(0xFFFFD23F),
      Color(0xFFFF2E5A),
      Color(0xFFC04CFF),
      Color(0xFF2EC4FF),
      Color(0xFF9AFF3D),
      Color(0xFFFF2E2E),
      Color(0xFFC04CFF),
    ],
    text: Color(0xFFFFE9DD),
    textMuted: Color(0x99FFE9DD),
    panel: Color(0xD91F0806),
    panelBorder: Color(0x4DFF6A1F),
    danger: Color(0xFFFF2E5A),
    good: Color(0xFF9AFF3D),
  );

  static const gold = GameTheme(
    id: 'gold',
    nameTr: 'Altın',
    nameEn: 'Gold',
    bg: Color(0xFF070604),
    bg2: Color(0xFF1A1407),
    nebula1: Color(0x40FFC94D),
    nebula2: Color(0x30FF8A3D),
    grid: Color(0x26FFC94D),
    star: Color(0xFFFFF3D1),
    accent: Color(0xFFFFC94D),
    accent2: Color(0xFFFF7A59),
    shipBody: Color(0xFF3A3220),
    shipDark: Color(0xFF14110A),
    canopy: Color(0xFFFFC94D),
    flame: Color(0xFFFFB347),
    bullet: Color(0xFFFFF6D9),
    bulletGlow: Color(0xFFFFC94D),
    enemyBullet: Color(0xFFFF4D6D),
    enemies: [
      Color(0xFFFF7A59),
      Color(0xFF4DD6FF),
      Color(0xFFC46BFF),
      Color(0xFF6BFF9E),
      Color(0xFFFF4DA6),
      Color(0xFFFF3B3B),
      Color(0xFF4DD6FF),
    ],
    text: Color(0xFFFFF3D1),
    textMuted: Color(0x99FFF3D1),
    panel: Color(0xD914100A),
    panelBorder: Color(0x4DFFC94D),
    danger: Color(0xFFFF4D6D),
    good: Color(0xFF6BFF9E),
  );

  static const ice = GameTheme(
    id: 'ice',
    nameTr: 'Buz',
    nameEn: 'Ice',
    light: true,
    bg: Color(0xFFEAF2FA),
    bg2: Color(0xFFD3E4F4),
    nebula1: Color(0x3300A3FF),
    nebula2: Color(0x26FF4D8F),
    grid: Color(0x1F0B2545),
    star: Color(0xFF8FA9C4),
    accent: Color(0xFF0B6CFF),
    accent2: Color(0xFFFF3D7F),
    shipBody: Color(0xFF1B3358),
    shipDark: Color(0xFF0A1A33),
    canopy: Color(0xFF4FD1FF),
    flame: Color(0xFFFF8A1F),
    bullet: Color(0xFF0B6CFF),
    bulletGlow: Color(0xFF4FA3FF),
    enemyBullet: Color(0xFFE8283C),
    enemies: [
      Color(0xFFE8283C),
      Color(0xFFFF8A1F),
      Color(0xFF6A3DFF),
      Color(0xFF00A884),
      Color(0xFFD63DFF),
      Color(0xFFC21F1F),
      Color(0xFF6A3DFF),
    ],
    text: Color(0xFF0B1B33),
    textMuted: Color(0x990B1B33),
    panel: Color(0xEBFFFFFF),
    panelBorder: Color(0x400B6CFF),
    danger: Color(0xFFE8283C),
    good: Color(0xFF00A884),
  );
}

ThemeData buildMaterialTheme(GameTheme t) {
  final base = ThemeData(
    brightness: t.light ? Brightness.light : Brightness.dark,
    fontFamily: 'Exo2',
    scaffoldBackgroundColor: t.bg,
    colorScheme: (t.light ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
      primary: t.accent,
      secondary: t.accent2,
      surface: t.bg2,
      error: t.danger,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: t.accent, selectionHandleColor: t.accent),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: t.text, displayColor: t.text),
  );
}
