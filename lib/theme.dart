import 'package:flutter/material.dart';

class T {
  static const ink = Color(0xFF16241F);
  static const ink2 = Color(0xFF5B6B64);
  static const ink3 = Color(0xFF93A09A);
  static const line = Color(0xFFE5EAE7);
  static const line2 = Color(0xFFEEF2EF);
  static const bg = Color(0xFFF5F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF8FAF9);
  static const teal = Color(0xFF0F6E56);
  static const tealB = Color(0xFF1D9E75);
  static const tealSoft = Color(0xFFE3F2EC);
  static const amber = Color(0xFFBA7517);
  static const danger = Color(0xFFC0392B);

  /// v2 视觉 token：三级投影（对应预览 sh-1 / sh-2 / sh-3）
  static const shadow1 = [
    BoxShadow(color: Color(0x0A103026), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const shadow2 = [
    BoxShadow(color: Color(0x12103026), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const shadow3 = [
    BoxShadow(color: Color(0x21103026), blurRadius: 34, offset: Offset(0, 14)),
  ];
  static const tealGradient = LinearGradient(
    colors: [Color(0xFF14926F), Color(0xFF0A5142)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 8 组头像渐变，对应 UI 稿
  static const palettes = [
    [Color(0xFF5B8DEF), Color(0xFF7F6EE8)],
    [Color(0xFFE8836B), Color(0xFFE0A24A)],
    [Color(0xFF1D9E75), Color(0xFF0F6E56)],
    [Color(0xFFD4537E), Color(0xFF993556)],
    [Color(0xFF888780), Color(0xFF5F5E5A)],
    [Color(0xFF378ADD), Color(0xFF185FA5)],
    [Color(0xFF0F6E56), Color(0xFF14795F)],
    [Color(0xFF7F6EE8), Color(0xFF5B8DEF)],
  ];

  static List<Color> palette(int i) => palettes[i % palettes.length];
}

/// 全局动效曲线
class Motion {
  static const curve = Cubic(0.2, 0.8, 0.2, 1.0);
  static const spring = Cubic(0.2, 0.9, 0.25, 1.0);
  static const dur = Duration(milliseconds: 320);
  static const durFast = Duration(milliseconds: 220);
}
