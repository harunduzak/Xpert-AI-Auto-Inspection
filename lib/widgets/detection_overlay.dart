import 'package:flutter/cupertino.dart';
import '../core/detection.dart';

/// Fotoğrafın üzerine, [Detection] listelerinden gelen normalize edilmiş
/// (0..1) kutuları gerçek piksel boyutuna ölçekleyip çizer.
/// Sadece görselleştirme amaçlıdır; algılama mantığına dokunmaz.
class DetectionOverlay extends StatelessWidget {
  final List<Detection> parts;
  final List<Detection> damages;
  final bool showParts;
  final bool showDamages;
  final Color partColor;
  final Color damageColor;

  const DetectionOverlay({
    super.key,
    required this.parts,
    required this.damages,
    required this.partColor,
    required this.damageColor,
    this.showParts = true,
    this.showDamages = true,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BoxPainter(
          parts: showParts ? parts : const [],
          damages: showDamages ? damages : const [],
          partColor: partColor,
          damageColor: damageColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  final List<Detection> parts;
  final List<Detection> damages;
  final Color partColor;
  final Color damageColor;

  _BoxPainter({
    required this.parts,
    required this.damages,
    required this.partColor,
    required this.damageColor,
  });

  void _drawSet(Canvas canvas, Size size, List<Detection> items, Color color) {
    final boxPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final fillPaint = Paint()..color = color.withOpacity(0.12);

    for (final d in items) {
      final rect = Rect.fromLTWH(
        d.left * size.width,
        d.top * size.height,
        d.w * size.width,
        d.h * size.height,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, boxPaint);

      // Küçük etiket şeridi
      final tp = TextPainter(
        text: TextSpan(
          text: d.label,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelBg = Rect.fromLTWH(
        rect.left,
        (rect.top - 16).clamp(0, size.height - 16),
        tp.width + 8,
        16,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelBg, const Radius.circular(4)),
        Paint()..color = color,
      );
      tp.paint(canvas, Offset(labelBg.left + 4, labelBg.top + 2));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawSet(canvas, size, parts, partColor);
    _drawSet(canvas, size, damages, damageColor);
  }

  @override
  bool shouldRepaint(covariant _BoxPainter oldDelegate) {
    return oldDelegate.parts != parts ||
        oldDelegate.damages != damages ||
        oldDelegate.partColor != partColor ||
        oldDelegate.damageColor != damageColor;
  }
}