import 'package:flutter/material.dart';
import '../theme.dart';

/// 骰子面 1-6 的点位（3x3 归一化坐标 0..1）
const _pips = {
  1: [Offset(0.5, 0.5)],
  2: [Offset(0.28, 0.28), Offset(0.72, 0.72)],
  3: [Offset(0.28, 0.28), Offset(0.5, 0.5), Offset(0.72, 0.72)],
  4: [Offset(0.28, 0.28), Offset(0.72, 0.28), Offset(0.28, 0.72), Offset(0.72, 0.72)],
  5: [Offset(0.28, 0.28), Offset(0.72, 0.28), Offset(0.5, 0.5), Offset(0.28, 0.72), Offset(0.72, 0.72)],
  6: [Offset(0.28, 0.24), Offset(0.72, 0.24), Offset(0.28, 0.5), Offset(0.72, 0.5), Offset(0.28, 0.76), Offset(0.72, 0.76)],
};

class DiceFace extends StatelessWidget {
  final int value;
  final double size;
  const DiceFace({super.key, required this.value, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DicePainter(value)),
    );
  }
}

class _DicePainter extends CustomPainter {
  final int value;
  _DicePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = T.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), border);

    final dot = Paint()..color = T.teal;
    for (final o in _pips[value] ?? _pips[3]!) {
      canvas.drawCircle(
        Offset(o.dx * size.width, o.dy * size.height),
        size.width * 0.062,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter old) => old.value != value;
}
