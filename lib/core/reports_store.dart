import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Oluşturulup cihaza kaydedilen bir PDF ekspertiz raporunun kaydı.
/// Ana sayfada "Oluşturulan Raporlar" listesini beslemek için kullanılır.
class ReportRecord {
  final String id;
  final String pdfPath;
  final String plateText;
  final String carType;
  final DateTime createdAt;

  ReportRecord({
    required this.id,
    required this.pdfPath,
    required this.plateText,
    required this.carType,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'pdfPath': pdfPath,
    'plateText': plateText,
    'carType': carType,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReportRecord.fromJson(Map<String, dynamic> j) => ReportRecord(
    id: j['id'] as String,
    pdfPath: j['pdfPath'] as String,
    plateText: j['plateText'] as String,
    carType: j['carType'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

/// Oluşturulan PDF raporlarının listesini cihazda kalıcı olarak saklar
/// (SharedPreferences + JSON) — HistoryStore ile aynı desen.
class ReportsStore {
  ReportsStore._();
  static const _key = 'pdf_reports_v1';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('ReportsStore.init() çağrılmadan kullanılmaya çalışıldı.');
    }
    return p;
  }

  /// En yeni rapor en üstte olacak şekilde tüm raporları döndürür.
  static List<ReportRecord> getAll() {
    final raw = _p.getStringList(_key) ?? [];
    final records = raw
        .map((s) {
      try {
        return ReportRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    })
        .whereType<ReportRecord>()
        .toList();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  static Future<void> add(ReportRecord record) async {
    final raw = _p.getStringList(_key) ?? [];
    raw.add(jsonEncode(record.toJson()));
    await _p.setStringList(_key, raw);
  }

  static Future<void> remove(String id) async {
    final all = getAll()..removeWhere((r) => r.id == id);
    await _p.setStringList(_key, all.map((r) => jsonEncode(r.toJson())).toList());
  }

  static Future<void> clear() async {
    await _p.remove(_key);
  }
}