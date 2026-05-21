import 'package:flutter/material.dart';

/// A premium ski slalom gate icon that depicts two poles with a connecting
/// panel and dynamic direction-change arrows — rendered entirely via CustomPaint
/// so it scales cleanly at any size.
class SkiGateIcon extends StatelessWidget {
  final Color poleColor;
  final Color panelColor;
  final double size;

  const SkiGateIcon({
    super.key,
    this.poleColor = Colors.white,
    this.panelColor = const Color(0xFF00E5CC),
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SkiGatePainter(poleColor: poleColor, panelColor: panelColor),
      ),
    );
  }
}

class _SkiGatePainter extends CustomPainter {
  final Color poleColor;
  final Color panelColor;

  _SkiGatePainter({required this.poleColor, required this.panelColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Glow layer ──────────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..color = panelColor.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // ── Poles ────────────────────────────────────────────────────────────────
    final polePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [poleColor, poleColor.withValues(alpha: 0.55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double lx = w * 0.20;
    final double rx = w * 0.80;
    final double poleTop = h * 0.06;
    final double poleBot = h * 1.0;

    // glow behind poles
    final glowPolePaint = Paint()
      ..color = panelColor.withValues(alpha: 0.15)
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(lx, poleTop), Offset(lx, poleBot), glowPolePaint);
    canvas.drawLine(Offset(rx, poleTop), Offset(rx, poleBot), glowPolePaint);

    canvas.drawLine(Offset(lx, poleTop), Offset(lx, poleBot), polePaint);
    canvas.drawLine(Offset(rx, poleTop), Offset(rx, poleBot), polePaint);

    // ── Panel (filled + border with gradient) ────────────────────────────────
    final double panelTop = h * 0.10;
    final double panelBot = h * 0.50;
    final double panelL = lx - w * 0.05;
    final double panelR = rx + w * 0.05;
    final double radius = w * 0.10;

    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(panelL, panelTop, panelR, panelBot),
      Radius.circular(radius),
    );

    // Fill with gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          panelColor.withValues(alpha: 0.90),
          panelColor.withValues(alpha: 0.55),
        ],
      ).createShader(Rect.fromLTRB(panelL, panelTop, panelR, panelBot))
      ..style = PaintingStyle.fill;

    // Glow behind panel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(panelL - 2, panelTop - 2, panelR + 2, panelBot + 2),
        Radius.circular(radius + 2),
      ),
      glowPaint,
    );

    canvas.drawRRect(panelRect, fillPaint);

    // Border
    canvas.drawRRect(
      panelRect,
      Paint()
        ..color = panelColor
        ..strokeWidth = w * 0.065
        ..style = PaintingStyle.stroke,
    );

    // ── Direction-change chevron arrows ──────────────────────────────────────
    // Two small chevrons pointing in opposite directions, centered in the panel.
    // Left chevron points ←, right chevron points →.
    final double arrowCy = (panelTop + panelBot) / 2;
    final double arrowCx = (lx + rx) / 2;
    final double arrowR = w * 0.09;  // half-width of each arm
    final double arrowH = h * 0.09;  // vertical reach
    final double gap = w * 0.14;     // horizontal gap between the two chevrons

    _drawChevron(canvas, arrowCx - gap, arrowCy, arrowR, arrowH,
        pointsLeft: true, color: Colors.white);
    _drawChevron(canvas, arrowCx + gap, arrowCy, arrowR, arrowH,
        pointsLeft: false, color: Colors.white);

    // ── Flag triangles on top of each pole ──────────────────────────────────
    _drawFlag(canvas, lx, poleTop, w, h, panelColor, pointsRight: true);
    _drawFlag(canvas, rx, poleTop, w, h, panelColor, pointsRight: false);
  }

  /// Draws a "<" or ">" chevron at [cx, cy].
  void _drawChevron(
    Canvas canvas,
    double cx,
    double cy,
    double halfWidth,
    double halfHeight, {
    required bool pointsLeft,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.92)
      ..strokeWidth = halfHeight * 0.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final tipX = pointsLeft ? cx - halfWidth : cx + halfWidth;
    final backX = pointsLeft ? cx + halfWidth * 0.3 : cx - halfWidth * 0.3;

    final path = Path()
      ..moveTo(backX, cy - halfHeight)
      ..lineTo(tipX, cy)
      ..lineTo(backX, cy + halfHeight);

    canvas.drawPath(path, paint);
  }

  /// Draws a small triangular flag on top of a pole.
  void _drawFlag(
    Canvas canvas,
    double poleX,
    double topY,
    double w,
    double h,
    Color color, {
    required bool pointsRight,
  }) {
    final flagPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double tipX = pointsRight ? poleX + w * 0.20 : poleX - w * 0.20;

    final path = Path()
      ..moveTo(poleX, topY + h * 0.01)
      ..lineTo(tipX, topY + h * 0.09)
      ..lineTo(poleX, topY + h * 0.17)
      ..close();

    canvas.drawPath(path, flagPaint);
  }

  @override
  bool shouldRepaint(covariant _SkiGatePainter old) =>
      old.poleColor != poleColor || old.panelColor != panelColor;
}
