import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'analysis_record.dart';

/// Analiz geçmişini cihazda kalıcı olarak saklar (SharedPreferences + JSON).
/// Uygulama kapatılıp açılsa bile kayıtlar korunur.
class HistoryStore {
  HistoryStore._();
  static const _key = 'analysis_history_v1';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('HistoryStore.init() çağrılmadan kullanılmaya çalışıldı.');
    }
    return p;
  }

  /// En yeni analiz en üstte olacak şekilde tüm geçmişi döndürür.
  static List<AnalysisRecord> getAll() {
    final raw = _p.getStringList(_key) ?? [];
    final records = raw
        .map((s) {
      try {
        return AnalysisRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    })
        .whereType<AnalysisRecord>()
        .toList();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  static Future<void> add(AnalysisRecord record) async {
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