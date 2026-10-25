/// Türkçe ve İngilizce metinler. Dil değişince uygulama ağacı yeniden kurulur, düz okuma yeterli.
class S {
  final String code;
  final String langName;
  final String tagline;
  final String nickname;
  final String nicknameHint;
  final String enterNick;
  final String play;
  final String leaderboard;
  final String settings;
  final String best;
  final String theme;
  final String language;
  final String sound;
  final String vibration;
  final String score;
  final String wave;
  final String Function(int) waveN;
  final String waveCleared;
  final String bossIncoming;
  final String bossDown;
  final String paused;
  final String resume;
  final String mainMenu;
  final String gameOver;
  final String newRecord;
  final String kills;
  final String waveReached;
  final String playAgain;
  final String Function(int) yourRank;
  final String move;
  final String aim;
  final String bomb;
  final String hintMove;
  final String hintAim;
  final String hintBomb;
  final String hintKeyboard;
  final String twin;
  final String spread;
  final String rapid;
  final String missile;
  final String shield;
  final String bombPickup;
  final String life;
  final String Function(int) combo;
  final String noScores;
  final String localBoard;
  final String onlineBoard;
  final String you;
  final String powerups;
  final String twinDesc;
  final String spreadDesc;
  final String rapidDesc;
  final String missileDesc;
  final String shieldDesc;
  final String bombDesc;
  final String lifeDesc;
  final String saving;
  final String Function(int) bestN;
  final String back;
  final String close;

  const S({
    required this.code,
    required this.langName,
    required this.tagline,
    required this.nickname,
    required this.nicknameHint,
    required this.enterNick,
    required this.play,
    required this.leaderboard,
    required this.settings,
    required this.best,
    required this.theme,
    required this.language,
    required this.sound,
    required this.vibration,
    required this.score,
    required this.wave,
    required this.waveN,
    required this.waveCleared,
    required this.bossIncoming,
    required this.bossDown,
    required this.paused,
    required this.resume,
    required this.mainMenu,
    required this.gameOver,
    required this.newRecord,
    required this.kills,
    required this.waveReached,
    required this.playAgain,
    required this.yourRank,
    required this.move,
    required this.aim,
    required this.bomb,
    required this.hintMove,
    required this.hintAim,
    required this.hintBomb,
    required this.hintKeyboard,
    required this.twin,
    required this.spread,
    required this.rapid,
    required this.missile,
    required this.shield,
    required this.bombPickup,
    required this.life,
    required this.combo,
    required this.noScores,
    required this.localBoard,
    required this.onlineBoard,
    required this.you,
    required this.powerups,
    required this.twinDesc,
    required this.spreadDesc,
    required this.rapidDesc,
    required this.missileDesc,
    required this.shieldDesc,
    required this.bombDesc,
    required this.lifeDesc,
    required this.saving,
    required this.bestN,
    required this.back,
    required this.close,
  });

  static S current = tr;

  static final tr = S(
    code: 'tr',
    langName: 'Türkçe',
    tagline: 'Gökyüzü senin. Dalgaları temizle, sıralamada yüksel.',
    nickname: 'Takma adın',
    nicknameHint: 'ör. Kartal',
    enterNick: 'Önce bir takma ad yaz',
    play: 'OYNA',
    leaderboard: 'Sıralama',
    settings: 'Ayarlar',
    best: 'En iyi',
    theme: 'Tema',
    language: 'Dil',
    sound: 'Ses',
    vibration: 'Titreşim',
    score: 'SKOR',
    wave: 'DALGA',
    waveN: (n) => 'DALGA $n',
    waveCleared: 'DALGA TEMİZLENDİ',
    bossIncoming: 'ANA GEMİ YAKLAŞIYOR',
    bossDown: 'ANA GEMİ DÜŞTÜ',
    paused: 'DURAKLATILDI',
    resume: 'DEVAM ET',
    mainMenu: 'Ana menü',
    gameOver: 'OYUN BİTTİ',
    newRecord: 'YENİ REKOR!',
    kills: 'Düşürülen',
    waveReached: 'Ulaşılan dalga',
    playAgain: 'TEKRAR OYNA',
    yourRank: (n) => 'Sıralaman: #$n',
    move: 'HAREKET',
    aim: 'NİŞAN',
    bomb: 'BOMBA',
    hintMove: 'Sol yarı: hareket',
    hintAim: 'Sağ yarı: nişan ve ateş',
    hintBomb: 'Bomba ekrandaki her şeyi temizler',
    hintKeyboard: 'Klavye: WASD hareket, fare nişan ve ateş, boşluk bomba',
    twin: 'ÇİFT ATEŞ',
    spread: 'YELPAZE',
    rapid: 'HIZLI ATEŞ',
    missile: 'GÜDÜMLÜ FÜZE',
    shield: 'KALKAN',
    bombPickup: '+1 BOMBA',
    life: '+1 CAN',
    combo: (n) => 'x$n KOMBO',
    noScores: 'Henüz skor yok. İlk sen ol!',
    localBoard: 'Dünya sıralamasına bağlanılamadı; bu cihazdaki skorlar gösteriliyor.',
    onlineBoard: 'Dünya sıralaması: her oyuncunun en iyi skoru',
    you: 'sen',
    powerups: 'Güçler',
    twinDesc: 'Yan yana iki namlu',
    spreadDesc: 'Üç yöne birden ateş',
    rapidDesc: 'İki kat hızlı ateş',
    missileDesc: 'Hedefi kendi bulan füzeler',
    shieldDesc: 'Üç darbeyi emer',
    bombDesc: 'Ekrandaki her şeyi siler',
    lifeDesc: 'Bir can daha',
    saving: 'Kaydediliyor…',
    bestN: (n) => 'En iyi: $n',
    back: 'Geri',
    close: 'Kapat',
  );

  static final en = S(
    code: 'en',
    langName: 'English',
    tagline: 'The sky is yours. Clear the waves, climb the leaderboard.',
    nickname: 'Your nickname',
    nicknameHint: 'e.g. Falcon',
    enterNick: 'Enter a nickname first',
    play: 'PLAY',
    leaderboard: 'Leaderboard',
    settings: 'Settings',
    best: 'Best',
    theme: 'Theme',
    language: 'Language',
    sound: 'Sound',
    vibration: 'Vibration',
    score: 'SCORE',
    wave: 'WAVE',
    waveN: (n) => 'WAVE $n',
    waveCleared: 'WAVE CLEARED',
    bossIncoming: 'MOTHERSHIP INCOMING',
    bossDown: 'MOTHERSHIP DOWN',
    paused: 'PAUSED',
    resume: 'RESUME',
    mainMenu: 'Main menu',
    gameOver: 'GAME OVER',
    newRecord: 'NEW RECORD!',
    kills: 'Kills',
    waveReached: 'Wave reached',
    playAgain: 'PLAY AGAIN',
    yourRank: (n) => 'Your rank: #$n',
    move: 'MOVE',
    aim: 'AIM',
    bomb: 'BOMB',
    hintMove: 'Left half: move',
    hintAim: 'Right half: aim and fire',
    hintBomb: 'A bomb clears the whole screen',
    hintKeyboard: 'Keyboard: WASD to move, mouse to aim and fire, space for bomb',
    twin: 'TWIN FIRE',
    spread: 'SPREAD',
    rapid: 'RAPID FIRE',
    missile: 'HOMING MISSILES',
    shield: 'SHIELD',
    bombPickup: '+1 BOMB',
    life: '+1 LIFE',
    combo: (n) => 'x$n COMBO',
    noScores: 'No scores yet. Be the first!',
    localBoard: "Couldn't reach the world leaderboard; showing scores on this device.",
    onlineBoard: "World leaderboard: each player's best score",
    you: 'you',
    powerups: 'Power-ups',
    twinDesc: 'Two barrels side by side',
    spreadDesc: 'Fire in three directions',
    rapidDesc: 'Double fire rate',
    missileDesc: 'Missiles that find their target',
    shieldDesc: 'Absorbs three hits',
    bombDesc: 'Wipes everything on screen',
    lifeDesc: 'One more life',
    saving: 'Saving…',
    bestN: (n) => 'Best: $n',
    back: 'Back',
    close: 'Close',
  );

  static const all = ['tr', 'en'];

  static S byCode(String? code) => code == 'en' ? en : tr;
}
