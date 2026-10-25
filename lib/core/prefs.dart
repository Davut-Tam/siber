import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'sound.dart';
import 'themes.dart';

/// Takma ad, tema, dil, ses, titreşim ve rekor; cihazda saklanır
class Prefs extends ChangeNotifier {
  final SharedPreferences _p;

  Prefs(this._p) {
    GameTheme.current = GameTheme.byId(_p.getString('tema'));
    S.current = S.byCode(_p.getString('dil') ?? _systemLang());
    Sfx.enabled = sound;
    Sfx.haptics = vibration;
  }

  static String _systemLang() => PlatformDispatcher.instance.locale.languageCode == 'tr' ? 'tr' : 'en';

  String get nickname => _p.getString('ad') ?? '';
  set nickname(String v) => _p.setString('ad', v.trim());

  GameTheme get theme => GameTheme.current;
  set theme(GameTheme t) {
    _p.setString('tema', t.id);
    GameTheme.current = t;
    notifyListeners();
  }

  S get lang => S.current;
  set lang(S s) {
    _p.setString('dil', s.code);
    S.current = s;
    notifyListeners();
  }

  bool get sound => _p.getBool('ses') ?? true;
  set sound(bool v) {
    _p.setBool('ses', v);
    Sfx.enabled = v;
    notifyListeners();
  }

  bool get vibration => _p.getBool('titresim') ?? true;
  set vibration(bool v) {
    _p.setBool('titresim', v);
    Sfx.haptics = v;
    notifyListeners();
  }

  int get best => _p.getInt('rekor') ?? 0;
  set best(int v) => _p.setInt('rekor', v);

  SharedPreferences get raw => _p;
}
