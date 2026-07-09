import '../core/detection.dart';

/// [Detection] sınıfının kendisi (backend) değiştirilmeden,
/// geçmiş kaydı için JSON'a çevirme/geri okuma yardımcıları.
Map<String, dynamic> detectionToJson(Detection d) => {
  'label': d.label,
  'conf': d.conf,
  'cx': d.cx,
  'cy': d.cy,
  'w': d.w,
  'h': d.h,
};

Detection detectionFromJson(Map<String, dynamic> j) => Detection(
  j['label'] as String,
  (j['conf'] as num).toDouble(),
  (j['cx'] as num).toDouble(),
  (j['cy'] as num).toDouble(),
  (j['w'] as num).toDouble(),
  (j['h'] as num).toDouble(),
);