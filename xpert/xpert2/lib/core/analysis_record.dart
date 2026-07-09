import 'detection.dart';
import 'detection_json.dart';

/// Tamamlanmış bir analizin geçmişte saklanacak anlık görüntüsü.
/// Backend sonuçlarını (id sonuçları, parçalar, hasarlar, hasar raporu)
/// olduğu gibi taşır — analiz mantığına dokunulmaz, sadece saklanır.
class AnalysisRecord {
  final String id;
  final String imagePath;
  final DateTime createdAt;
  final Map<String, Map<String, dynamic>> idResults; // car, car-type, plate, plate_text
  final List<Detection> parts;
  final List<Detection> damages;
  final List<String> damageReport;

  AnalysisRecord({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    required this.idResults,
    required this.parts,
    required this.damages,
    required this.damageReport,
  });

  String get plateText =>
      (idResults['plate_text']?['label'] as String?) ?? 'Plaka bulunamadı';

  String get carType => (idResults['car-type']?['label'] as String?) ?? 'Bilinmiyor';

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'idResults': idResults,
    'parts': parts.map(detectionToJson).toList(),
    'damages': damages.map(detectionToJson).toList(),
    'damageReport': damageReport,
  };

  factory AnalysisRecord.fromJson(Map<String, dynamic> j) {
    final rawIdResults = (j['idResults'] as Map).map(
          (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
    );
    return AnalysisRecord(
      id: j['id'] as String,
      imagePath: j['imagePath'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      idResults: rawIdResults,
      parts: (j['parts'] as List).map((e) => detectionFromJson(Map<String, dynamic>.from(e))).toList(),
      damages: (j['damages'] as List).map((e) => detectionFromJson(Map<String, dynamic>.from(e))).toList(),
      damageReport: (j['damageReport'] as List).map((e) => e.toString()).toList(),
    );
  }
}