import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart';
import 'scores.dart';

/// Firebase Realtime Database'teki dünya sıralaması. Her oyuncunun tek satırı vardır: en iyi skoru.
/// Bağlantı yoksa skor cihazda saklanır ve cihazdaki skorlar gösterilir.
class FirebaseScoreService implements ScoreService {
  FirebaseScoreService(this._local);

  final LocalScoreService _local;
  static const _timeout = Duration(seconds: 8);

  bool _online = true;
  String? _uid;

  @override
  bool get online => _online;

  @override
  String? get myId => _uid;

  Future<DatabaseReference> _scores() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: firebaseOptions);
    final auth = FirebaseAuth.instance;
    _uid = (auth.currentUser ?? (await auth.signInAnonymously()).user!).uid;
    return FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: firebaseOptions.databaseURL).ref('skorlar');
  }

  @override
  Future<int?> submit(ScoreEntry entry) async {
    final localRank = await _local.submit(entry);
    try {
      final scores = await _scores().timeout(_timeout);
      final mine = scores.child(_uid!);
      final snap = await mine.get().timeout(_timeout);
      final old = snap.value is Map ? ScoreEntry.fromJson(snap.value as Map) : null;
      if (old == null || entry.score > old.score) {
        await mine.set({...entry.toJson(), 'tarih': ServerValue.timestamp}).timeout(_timeout);
      } else if (old.name != entry.name) {
        // Rekor kırılmadı ama takma ad değiştiyse sıralamada yeni ad görünsün
        await mine.child('ad').set(entry.name).timeout(_timeout);
      }
      // Bu skordan yüksek kaç oyuncu var
      final above = await scores.orderByChild('puan').startAfter(entry.score).get().timeout(_timeout);
      _online = true;
      return above.children.length + 1;
    } catch (_) {
      _online = false;
      return localRank;
    }
  }

  @override
  Future<List<ScoreEntry>> top({int limit = 100}) async {
    try {
      final scores = await _scores().timeout(_timeout);
      final snap = await scores.orderByChild('puan').limitToLast(limit).get().timeout(_timeout);
      final list = [
        for (final c in snap.children)
          if (c.value is Map) ScoreEntry.fromJson(c.value as Map, id: c.key),
      ]..sort((a, b) => b.score.compareTo(a.score));
      _online = true;
      return list;
    } catch (_) {
      _online = false;
      return _local.top(limit: limit);
    }
  }
}
