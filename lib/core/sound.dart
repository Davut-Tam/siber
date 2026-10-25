import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Ses efektleri ve titreşim. Sık çalan sesler havuzdan çalınır ki üst üste binebilsin.
abstract final class Sfx {
  static bool enabled = true;
  static bool haptics = true;

  static final _pools = <String, AudioPool>{};
  static final _last = <String, int>{};

  /// Havuz boyutu: aynı anda kaç kopya çalabilir
  static const _sizes = {
    'ates': 4,
    'fuze': 3,
    'isabet': 3,
    'patlama': 4,
    'buyuk_patlama': 2,
    'guc': 2,
    'vuruldu': 1,
    'bomba': 1,
    'dalga': 1,
    'alarm': 1,
    'kombo': 2,
    'kalkan': 1,
    'bitti': 1,
  };

  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(respectSilence: true, focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (_) {}
    for (final e in _sizes.entries) {
      try {
        _pools[e.key] = await AudioPool.createFromAsset(
          path: 'sounds/${e.key}.wav',
          maxPlayers: e.value,
          playerMode: PlayerMode.lowLatency,
        );
      } catch (_) {}
    }
  }

  /// [gapMs]: aynı sesin en az bu kadar arayla çalması (ateş gibi sık sesler için)
  static void play(String name, {double volume = 1, int gapMs = 0}) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (gapMs > 0 && now - (_last[name] ?? 0) < gapMs) return;
    _last[name] = now;
    _pools[name]?.start(volume: volume).catchError((_) => () async {});
  }

  static void light() {
    if (haptics) HapticFeedback.selectionClick();
  }

  static void medium() {
    if (haptics) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (haptics) HapticFeedback.heavyImpact();
  }
}
