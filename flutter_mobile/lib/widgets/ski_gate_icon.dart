import 'package:flutter/material.dart';

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
    final polePaint = Paint()
      ..color = poleColor
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final panelPaint = Paint()
      ..color = panelColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final panelBorderPaint = Paint()
      ..color = panelColor
      ..strokeWidth = size.width * 0.07
      ..style = PaintingStyle.stroke;

    final double leftX = size.width * 0.18;
    final double rightX = size.width * 0.82;
    final double topY = size.height * 0.0;
    final double bottomY = size.height * 1.0;
    final double panelTop = size.height * 0.12;
    final double panelBottom = size.height * 0.48;

    // Draw left pole
    canvas.drawLine(Offset(leftX, topY), Offset(leftX, bottomY), polePaint);
    // Draw right pole
    canvas.drawLine(Offset(rightX, topY), Offset(rightX, bottomY), polePaint);

    // Draw panel (rounded rectangle between poles)
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(leftX - size.width * 0.04, panelTop, rightX + size.width * 0.04, panelBottom),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(panelRect, panelPaint);
    canvas.drawRRect(panelRect, panelBorderPaint);

    // Left flag triangle on top of left pole
    final leftFlagPath = Path()
      ..moveTo(leftX, topY + size.height * 0.02)
      ..lineTo(leftX + size.width * 0.22, topY + size.height * 0.1)
      ..lineTo(leftX, topY + size.height * 0.18)
      ..close();
    canvas.drawPath(leftFlagPath, Paint()..color = panelColor..style = PaintingStyle.fill);

    // Right flag triangle on top of right pole (mirrored)
    final rightFlagPath = Path()
      ..moveTo(rightX, topY + size.height * 0.02)
      ..lineTo(rightX - size.width * 0.22, topY + size.height * 0.1)
      ..lineTo(rightX, topY + size.height * 0.18)
      ..close();
    canvas.drawPath(rightFlagPath, Paint()..color = panelColor..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
