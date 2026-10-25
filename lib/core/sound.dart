import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Ses efektleri ve titreşim. SoLoud sesleri belleğe alır ve aynı sesi üst üste çalabilir;
/// iOS'ta AVPlayer kullanmadığından açılışta medya sunucusunu beklemez.
abstract final class Sfx {
  static bool enabled = true;
  static bool haptics = true;

  static final _sources = <String, AudioSource>{};
  static final _voices = <String, List<SoundHandle>>{};
  static final _last = <String, int>{};

  /// Aynı anda en fazla kaç kopya çalabilir
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

  static AppLifecycleListener? _lifecycle;

  /// Her açılış/kapanışta artar; arka plana geçilirken süren bir yükleme yarıda bırakılır
  static int _generation = 0;

  /// Açılışı bekletmemek için runApp'ten sonra beklenmeden çağrılır; yüklenmeyen ses sessizce atlanır.
  /// Uygulama gizlenince ses motoru kapatılır (arka planda sessizlik çalıp pil harcamasın), görününce açılır.
  static Future<void> init() async {
    _lifecycle ??= AppLifecycleListener(onHide: _stop, onShow: init);
    final gen = ++_generation;
    try {
      await SoLoud.instance.init();
    } catch (_) {
      return;
    }
    for (final name in _sizes.keys) {
      if (gen != _generation) return;
      try {
        _sources[name] = await SoLoud.instance.loadAsset('assets/sounds/$name.wav');
      } catch (_) {}
    }
  }

  static void _stop() {
    _generation++;
    _sources.clear();
    _voices.clear();
    try {
      SoLoud.instance.deinit();
    } catch (_) {}
  }

  /// [gapMs]: aynı sesin en az bu kadar arayla çalması (ateş gibi sık sesler için)
  static void play(String name, {double volume = 1, int gapMs = 0}) {
    if (!enabled) return;
    final source = _sources[name];
    if (source == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (gapMs > 0 && now - (_last[name] ?? 0) < gapMs) return;
    _last[name] = now;
    try {
      final soloud = SoLoud.instance;
      final voices = _voices.putIfAbsent(name, () => [])..removeWhere((h) => !soloud.getIsValidVoiceHandle(h));
      // Sınır dolduysa en eski kopya susturulur
      if (voices.length >= _sizes[name]!) soloud.stop(voices.removeAt(0));
      voices.add(soloud.play(source, volume: volume));
    } catch (_) {}
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
