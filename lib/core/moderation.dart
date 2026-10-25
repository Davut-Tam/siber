/// Takma ad denetimi: dünya sıralamasında herkes görür, küfür ve hakaret içeren adlar kabul edilmez
/// ve eski sürümlerden gelmiş olsalar bile gizlenir.
abstract final class Moderation {
  /// Aradaki boşluk ya da işaretlerle bölünse bile yakalanan, başka kelimenin içinde geçmeyen kökler
  static const _anywhere = [
    'orospu',
    'orosbu',
    'siktir',
    'sikerim',
    'sikeyim',
    'sikis',
    'pezevenk',
    'kahpe',
    'gavat',
    'ibne',
    'amcik',
    'aminakoy',
    'aminako',
    'anani',
    'gotveren',
    'kaltak',
    'surtuk',
    'fuck',
    'shit',
    'bitch',
    'cunt',
    'faggot',
    'whore',
    'slut',
    'pussy',
    'asshole',
    'motherf',
    'hitler',
    'nazi',
    'porno',
  ];

  /// Yalnızca kelime başında geçerse sayılan kökler (ör. "klasik", "kayarak" yakalanmasın)
  static const _prefix = [
    'sikim',
    'siker',
    'sikey',
    'sikik',
    'siks',
    'yarak',
    'gote',
    'gotun',
    'dick',
    'cock',
    'rape',
    'porn',
    'piclik',
    'nigger',
    'nigga',
  ];

  /// Tek başına kelime olarak geçerse sayılan kısaltmalar
  static const _exact = ['sik', 'amk', 'aq', 'amq', 'mk', 'oc', 'pic', 'sg', 'sex', 'wtf', 'kys'];

  // Listeler de ada uygulanan sadeleştirmeden geçer (ör. "yarrak" → "yarak")
  static final _anywhereN = _anywhere.map(_normalize).toList();
  static final _prefixN = _prefix.map(_normalize).toList();
  static final _exactN = _exact.map(_normalize).toSet();

  static const _fold = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    '@': 'a',
    r'$': 's',
    '!': 'i',
  };

  /// Küçük harfe çevirir, Türkçe harfleri ve rakamla yazılmış harfleri sadeleştirir, tekrarlayan harfleri teke indirir
  static String _normalize(String s) {
    final lower = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    final out = StringBuffer();
    String? prev;
    for (final ch in lower.split('')) {
      final c = _fold[ch] ?? ch;
      if (c == prev && RegExp('[a-z]').hasMatch(c)) continue;
      out.write(c);
      prev = c;
    }
    return out.toString();
  }

  static bool isOffensive(String name) {
    final norm = _normalize(name);
    final words = norm.split(RegExp('[^a-z]+')).where((w) => w.isNotEmpty).toList();
    final joined = words.join();
    if (_anywhereN.any(joined.contains)) return true;
    for (final w in words) {
      if (_exactN.contains(w) || _prefixN.any(w.startsWith)) return true;
    }
    return false;
  }

  /// Sıralamada gösterilecek ad
  static String display(String name) => isOffensive(name) ? '***' : name;
}
