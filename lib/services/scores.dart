import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ScoreEntry {
  /// Çevrim içi kayıtlarda oyuncunun kimliği; kendi satırını vurgulamak için
  final String? id;
  final String name;
  final int score, wave, kills;
  final DateTime date;

  const ScoreEntry({
    this.id,
    required this.name,
    required this.score,
    required this.wave,
    required this.kills,
    required this.date,
  });

  Map<String, Object> toJson() => {
    'ad': name,
    'puan': score,
    'dalga': wave,
    'dusurulen': kills,
    'tarih': date.millisecondsSinceEpoch,
  };

  factory ScoreEntry.fromJson(Map json, {String? id}) => ScoreEntry(
    id: id,
    name: json['ad'] as String? ?? '?',
    score: (json['puan'] as num?)?.toInt() ?? 0,
    wave: (json['dalga'] as num?)?.toInt() ?? 0,
    kills: (json['dusurulen'] as num?)?.toInt() ?? 0,
    date: DateTime.fromMillisecondsSinceEpoch((json['tarih'] as num?)?.toInt() ?? 0),
  );
}

/// Sıralama kaynağı: Firebase'deki dünya sıralaması ya da (bağlantı yoksa) bu cihazın skorları
abstract class ScoreService {
  /// Son okumada dünya sıralamasına ulaşılabildi mi
  bool get online;

  /// Bu oyuncunun çevrim içi kimliği
  String? get myId;

  /// Skoru kaydeder, sıralamadaki yerini (1'den başlar) döner
  Future<int?> submit(ScoreEntry entry);

  Future<List<ScoreEntry>> top({int limit = 100});
}

class LocalScoreService implements ScoreService {
  final SharedPreferences _prefs;
  LocalScoreService(this._prefs);

  static const _key = 'skorlar';
  static const _keep = 100;

  @override
  bool get online => false;

  @override
  String? get myId => null;

  List<ScoreEntry> _load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => ScoreEntry.fromJson(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int?> submit(ScoreEntry entry) async {
    final list = _load()
      ..add(entry)
      ..sort((a, b) => b.score.compareTo(a.score));
    final rank = list.indexOf(entry) + 1;
    await _prefs.setString(_key, jsonEncode([for (final e in list.take(_keep)) e.toJson()]));
    return rank;
  }

  @override
  Future<List<ScoreEntry>> top({int limit = 100}) async => _load().take(limit).toList();
}
