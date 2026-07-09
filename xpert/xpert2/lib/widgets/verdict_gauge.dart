import 'dart:math';
import 'package:flutter/cupertino.dart';

/// İmza görsel öğesi: araç gösterge panelindeki devir/yakıt ibresini
/// andıran yarım-daire "hasar şiddeti" göstergesi. Pill/rozet yerine
/// kullanılır — 0.0 (temiz) ile 1.0 (ağır hasar) arasında bir ibre çizer.
class VerdictGauge extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final Color trackColor;
  final String label;
  final IconData icon;
  final double size;

  const VerdictGauge({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    required this.label,
    required this.icon,
    this.size = 108,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.72,
      child: CustomPaint(
        painter: _GaugePainter(
          value: value.clamp(0, 1),
          color: color,
          trackColor: trackColor,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: size * 0.19),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size * 0.10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;

  _GaugePainter({required this.value, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 8;
    const startAngle = pi; // 180°
    const sweepTotal = pi; // yarım daire

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepTotal, false, trackPaint);

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * value,
      false,
      valuePaint,
    );

    // Küçük skala çentikleri (0 / orta / maks)
    final tickPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2;
    for (int i = 0; i <= 4; i++) {
      final a = startAngle + sweepTotal * (i / 4);
      final p1 = center + Offset(cos(a), sin(a)) * (radius + 7);
      final p2 = center + Offset(cos(a), sin(a)) * (radius + 12);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // İbre
    final needleAngle = startAngle + sweepTotal * value;
    final needleEnd = center + Offset(cos(needleAngle), sin(needleAngle)) * (radius - 14);
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color || oldDelegate.trackColor != trackColor;
}