import 'dart:math';

// ==========================================
// TESPİT (DETECTION) MODELİ + EŞLEŞTİRME
// (Mantık değiştirilmedi — sadece ayrı dosyaya taşındı)
// ==========================================
class Detection {
  final String label;
  final double conf; // 0..100
  final double cx, cy, w, h; // normalize edilmiş (0..1) merkez ve boyut
  Detection(this.label, this.conf, this.cx, this.cy, this.w, this.h);

  double get left => cx - w / 2;
  double get right => cx + w / 2;
  double get top => cy - h / 2;
  double get bottom => cy + h / 2;

  double iou(Detection other) {
    final ix1 = max(left, other.left);
    final iy1 = max(top, other.top);
    final ix2 = min(right, other.right);
    final iy2 = min(bottom, other.bottom);
    final iw = max(0.0, ix2 - ix1);
    final ih = max(0.0, iy2 - iy1);
    final interArea = iw * ih;
    final unionArea = (w * h) + (other.w * other.h) - interArea;
    if (unionArea <= 0) return 0.0;
    return interArea / unionArea;
  }

  bool containsCenter(Detection other) {
    return other.cx >= left && other.cx <= right && other.cy >= top && other.cy <= bottom;
  }
}

class DamageMatcher {
  // Her hasar kutusu için en çok örtüştüğü (ya da merkezi içine düşen) parçayı bulur.
  static List<String> match(List<Detection> parts, List<Detection> damages) {
    final List<String> report = [];
    for (final dmg in damages) {
      Detection? bestPart;
      double bestScore = 0;
      for (final part in parts) {
        double score = part.iou(dmg);
        if (score == 0 && part.containsCenter(dmg)) score = 0.001;
        if (score > bestScore) {
          bestScore = score;
          bestPart = part;
        }
      }
      if (bestPart != null) {
        report.add('${bestPart.label}: ${dmg.label} tespit edildi (%${dmg.conf.toStringAsFixed(1)})');
      } else {
        report.add('Bilinmeyen bölge: ${dmg.label} tespit edildi (%${dmg.conf.toStringAsFixed(1)})');
      }
    }
    return report;
  }
}