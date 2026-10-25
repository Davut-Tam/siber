import 'dart:math';
import 'dart:ui';

import '../core/i18n.dart';
import '../core/themes.dart';
import 'entities.dart';

/// Oyuncunun o anki kumandası
class GameInput {
  /// Hareket yönü ve şiddeti (uzunluk 0..1)
  Offset move = Offset.zero;

  /// Nişan açısı (radyan); ateş ederken dolu
  double? aim;
  bool firing = false;

  /// Bir kerelik bomba isteği; dünya okuyunca sıfırlar
  bool bomb = false;
}

enum BannerKind { wave, cleared, boss, bossDown }

/// Güçlerin renkleri (oyunda ve arayüzde ortak)
Color powerColorOf(PowerKind k) {
  final t = GameTheme.current;
  return switch (k) {
    PowerKind.twin => t.accent,
    PowerKind.spread => t.accent2,
    PowerKind.rapid => const Color(0xFFFFC21A),
    PowerKind.missile => const Color(0xFFFF8A3D),
    PowerKind.shield => const Color(0xFF3FB6FF),
    PowerKind.bomb => const Color(0xFFFF4D6D),
    PowerKind.life => const Color(0xFFFF5C8A),
  };
}

/// Oyunun bütün simülasyonu. Sabit adımla (saniyede 60) ilerler; çizim ve arayüz yalnızca okur.
class World {
  World(this.w, this.h, {Random? random}) : rnd = random ?? Random() {
    ship = Ship(w / 2, h * 0.62);
    _initStars();
  }

  double w, h;
  final Random rnd;
  late Ship ship;

  final bullets = <Bullet>[];
  final enemies = <Enemy>[];
  final powerups = <PowerUp>[];
  final particles = <Particle>[];
  final texts = <FloatText>[];
  final stars = <Star>[];
  final shockwaves = <Shockwave>[];
  final events = <GameEvent>[];

  /// Liste taranırken doğan düşmanlar (bölünenin parçaları, ana geminin dronları) adım sonunda eklenir
  final _pending = <Enemy>[];

  int score = 0, kills = 0, wave = 0, bombs = 1, combo = 0, multiplier = 1;
  double comboTimer = 0;

  /// Toplam oyun süresi (sn, ağır çekim dahil)
  double time = 0;

  /// Ekran sarsıntısı (piksel), beyaz parlama, kırmızı hasar parlaması, ağır çekim (sn)
  double shake = 0, flash = 0, hurt = 0, slowmo = 0;

  /// Süreli güçlerin kalan süreleri (sn)
  final timers = <PowerKind, double>{};
  double _fireCd = 0, _missileCd = 0;

  int _toSpawn = 0;
  double _spawnCd = 0, _spawnInterval = 1, _waveDelay = 1.2;
  int _shockId = 0, _sinceDrop = 0;
  Enemy? boss;

  BannerKind? banner;
  double bannerTime = 0;

  bool over = false;

  /// Izgaranın kayma miktarı
  double gridScroll = 0;

  GameTheme get theme => GameTheme.current;

  static const shipRadius = 11.0;
  static const _maxSpeed = 400.0;
  static const _margin = 26.0;

  // ─── Yardımcılar ──────────────────────────────────────────────────────────

  double _r(double a, double b) => a + rnd.nextDouble() * (b - a);

  static double angleDiff(double a, double b) {
    var d = (b - a) % (2 * pi);
    if (d > pi) d -= 2 * pi;
    if (d < -pi) d += 2 * pi;
    return d;
  }

  /// Saniyeye göre ayarlanmış yumuşatma katsayısı (60 Hz'de [perFrame])
  static double _ease(double perFrame, double dt) => 1 - pow(1 - perFrame, dt * 60).toDouble();

  Color _enemyColor(int i) => theme.enemies[i % theme.enemies.length];

  void _initStars() {
    stars.clear();
    for (var i = 0; i < 120; i++) {
      final layer = i < 55 ? 0.0 : (i < 95 ? 0.5 : 1.0);
      stars.add(Star(_r(0, w), _r(0, h), _r(0.4, 1.0) + layer * 1.1, layer, _r(0, 6.28)));
    }
  }

  void resize(double nw, double nh) {
    if (nw == w && nh == h) return;
    final sx = nw / w, sy = nh / h;
    w = nw;
    h = nh;
    ship
      ..x = (ship.x * sx).clamp(_margin, w - _margin)
      ..y = (ship.y * sy).clamp(_margin, h - _margin);
    _initStars();
  }

  // ─── Adım ─────────────────────────────────────────────────────────────────

  void step(double dtReal, GameInput input) {
    if (slowmo > 0) slowmo -= dtReal;
    final dt = dtReal * (slowmo > 0 ? 0.35 : 1.0);
    time += dt;

    _updateBackground(dt);
    _updateParticles(dt);
    _updateTexts(dt);
    shake = max(0, shake - 40 * dtReal);
    flash = max(0, flash - dtReal);
    hurt = max(0, hurt - dtReal);
    if (bannerTime > 0) bannerTime -= dtReal;

    if (over) {
      _updateBullets(dt);
      return;
    }

    _updateWaves(dt);
    _updateShip(dt, input);
    _updateWeapons(dt, input);
    _updateBullets(dt);
    _updateEnemies(dt);
    _updateShockwaves(dt);
    _updatePowerups(dt);
    _collide();

    enemies
      ..removeWhere((e) => e.dead)
      ..addAll(_pending);
    _pending.clear();
    bullets.removeWhere((b) => b.life <= 0);

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        combo = 0;
        multiplier = 1;
      }
    }
  }

  void _updateBackground(double dt) {
    gridScroll = (gridScroll + 26 * dt) % 64;
    for (final s in stars) {
      s.y += (18 + 80 * s.layer) * dt;
      s.x -= ship.vx * 0.035 * (0.3 + s.layer) * dt;
      if (s.y > h + 4) {
        s.y = -4;
        s.x = _r(0, w);
      }
      if (s.x < -4) s.x += w + 8;
      if (s.x > w + 4) s.x -= w + 8;
    }
  }

  // ─── Dalgalar ─────────────────────────────────────────────────────────────

  void _updateWaves(double dt) {
    if (_waveDelay > 0) {
      _waveDelay -= dt;
      if (_waveDelay <= 0) _startWave();
      return;
    }
    if (_toSpawn > 0) {
      _spawnCd -= dt;
      if (_spawnCd <= 0) {
        _spawnFromWave();
        _spawnCd = _spawnInterval * _r(0.6, 1.3);
      }
    } else if (enemies.isEmpty && _pending.isEmpty && wave > 0) {
      final bonus = wave * 250;
      score += bonus;
      _text(w / 2, h * 0.42, '+$bonus', theme.accent2, size: 22, life: 1.6);
      _banner(BannerKind.cleared);
      events.add(GameEvent.waveCleared);
      _waveDelay = 2.6;
    }
  }

  void _startWave() {
    wave++;
    if (wave % 5 == 0) {
      _toSpawn = 0;
      final hp = 160 + wave * 32;
      boss = Enemy(EnemyKind.boss, w / 2, -90, 62, hp, 5000 * (wave ~/ 5), 6, cd: 2.4, phase: 3);
      _pending.add(boss!);
      _banner(BannerKind.boss);
      events.add(GameEvent.boss);
    } else {
      _toSpawn = min(70, 6 + wave * 3);
      _spawnInterval = max(0.26, 1.15 - wave * 0.065);
      _spawnCd = 0.4;
      _banner(BannerKind.wave);
      events.add(GameEvent.wave);
    }
  }

  void _banner(BannerKind kind) {
    banner = kind;
    bannerTime = 2.2;
  }

  void _spawnFromWave() {
    final pool = <(EnemyKind, int)>[
      (EnemyKind.drone, 10),
      if (wave >= 2) (EnemyKind.dart, 6),
      if (wave >= 3) (EnemyKind.splitter, 4),
      if (wave >= 4) (EnemyKind.sniper, 3),
      if (wave >= 6) (EnemyKind.tank, 2 + wave ~/ 10),
      if (wave >= 7) (EnemyKind.kamikaze, 3),
    ];
    final total = pool.fold(0, (s, e) => s + e.$2);
    var pick = rnd.nextInt(total);
    var kind = EnemyKind.drone;
    for (final (k, wgt) in pool) {
      if (pick < wgt) {
        kind = k;
        break;
      }
      pick -= wgt;
    }
    final (x, y) = _edgePoint();
    // Dronlar ve zikzaklar zaman zaman küme halinde gelir
    final group = switch (kind) {
      EnemyKind.drone when wave >= 3 && rnd.nextDouble() < 0.35 => 3,
      EnemyKind.dart when rnd.nextDouble() < 0.4 => 2,
      _ => 1,
    };
    for (var i = 0; i < group && _toSpawn > 0; i++) {
      spawnEnemy(kind, x + _r(-30, 30), y + _r(-30, 30));
      _toSpawn--;
    }
  }

  (double, double) _edgePoint() {
    const m = 40.0;
    return switch (rnd.nextInt(4)) {
      0 => (_r(0, w), -m),
      1 => (w + m, _r(0, h)),
      2 => (_r(0, w), h + m),
      _ => (-m, _r(0, h)),
    };
  }

  Enemy spawnEnemy(EnemyKind kind, double x, double y) {
    final e = switch (kind) {
      EnemyKind.drone => Enemy(kind, x, y, 14, 1 + wave ~/ 8, 100, 0),
      EnemyKind.dart => Enemy(kind, x, y, 11, 1 + wave ~/ 12, 150, 1, phase: _r(0, 6)),
      EnemyKind.tank => Enemy(kind, x, y, 26, 8 + wave ~/ 2, 500, 2, cd: _r(1.5, 2.5)),
      EnemyKind.sniper => Enemy(kind, x, y, 15, 3 + wave ~/ 6, 300, 3, cd: _r(2, 3), phase: rnd.nextBool() ? 1 : -1),
      EnemyKind.splitter => Enemy(kind, x, y, 22, 4 + wave ~/ 6, 250, 4, phase: _r(0, 6)),
      EnemyKind.mini => Enemy(kind, x, y, 9, 1, 50, 4),
      EnemyKind.kamikaze => Enemy(kind, x, y, 16, 2 + wave ~/ 8, 200, 5),
      EnemyKind.boss => Enemy(kind, x, y, 62, 200, 5000, 6),
    };
    _pending.add(e);
    return e;
  }

  // ─── Uçak ─────────────────────────────────────────────────────────────────

  void _updateShip(double dt, GameInput input) {
    final s = ship;
    var m = input.move;
    if (m.distance > 1) m = m / m.distance;
    final k = _ease(0.2, dt);
    s.vx += (m.dx * _maxSpeed - s.vx) * k;
    s.vy += (m.dy * _maxSpeed - s.vy) * k;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    // Kenarda durur, ekrandan çıkmaz
    if (s.x < _margin || s.x > w - _margin) {
      s.x = s.x.clamp(_margin, w - _margin);
      s.vx = 0;
    }
    if (s.y < _margin || s.y > h - _margin) {
      s.y = s.y.clamp(_margin, h - _margin);
      s.vy = 0;
    }

    double? target;
    if (input.firing && input.aim != null) {
      target = _aimAssist(input.aim!);
      input.aim = target;
    } else if (Offset(s.vx, s.vy).distance > 40) {
      target = atan2(s.vy, s.vx);
    }
    if (target != null) {
      final d = angleDiff(s.angle, target);
      s.angle += d * _ease(input.firing ? 0.4 : 0.16, dt);
      s.bank += ((d * 2.2).clamp(-1.0, 1.0) - s.bank) * _ease(0.15, dt);
    } else {
      s.bank -= s.bank * _ease(0.1, dt);
    }

    if (s.invuln > 0) s.invuln -= dt;
    if (s.muzzle > 0) s.muzzle -= dt;
    if (s.shieldTime > 0) {
      s.shieldTime -= dt;
      if (s.shieldTime <= 0) s.shieldHits = 0;
    }

    // Motor alevi izi
    final speed = Offset(s.vx, s.vy).distance;
    final back = s.angle + pi;
    for (final side in const [-1.0, 1.0]) {
      final px = s.x + cos(back) * 22 + cos(s.angle + pi / 2) * side * 3;
      final py = s.y + sin(back) * 22 + sin(s.angle + pi / 2) * side * 3;
      final v = 140 + speed * 0.4;
      particles.add(
        Particle(
          ParticleType.flame,
          px,
          py,
          vx: cos(back) * v + _r(-25, 25),
          vy: sin(back) * v + _r(-25, 25),
          life: _r(0.12, 0.2) * (0.6 + speed / _maxSpeed),
          size: _r(2.5, 4),
          color: theme.flame,
          drag: 3,
        ),
      );
    }
  }

  /// Nişan yönünün ~15° yakınında düşman varsa ona kilitlenir (en dar açılı, yakın olan önce)
  double _aimAssist(double angle) {
    Enemy? best;
    var bestScore = double.infinity;
    for (final e in enemies) {
      final a = atan2(e.y - ship.y, e.x - ship.x);
      final diff = angleDiff(angle, a).abs();
      if (diff > 0.27) continue;
      final score = diff + _dist(e.x, e.y, ship.x, ship.y) / 2000;
      if (score < bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best == null ? angle : atan2(best.y - ship.y, best.x - ship.x);
  }

  // ─── Silahlar ─────────────────────────────────────────────────────────────

  bool has(PowerKind k) => (timers[k] ?? 0) > 0;

  void _updateWeapons(double dt, GameInput input) {
    for (final k in timedPowers) {
      final t = timers[k];
      if (t != null && t > 0) timers[k] = t - dt;
    }

    if (_fireCd > 0) _fireCd -= dt;
    if (input.firing && input.aim != null && _fireCd <= 0) {
      _fire(input.aim!);
      _fireCd = has(PowerKind.rapid) ? 0.05 : 0.095;
    }

    if (has(PowerKind.missile)) {
      _missileCd -= dt;
      if (_missileCd <= 0 && enemies.isNotEmpty) {
        _launchMissiles();
        _missileCd = 0.7;
      }
    }

    if (input.bomb) {
      input.bomb = false;
      if (bombs > 0) detonate();
    }
  }

  void _fire(double a) {
    final s = ship;
    const speed = 950.0;
    final nx = s.x + cos(a) * 24, ny = s.y + sin(a) * 24;
    final px = cos(a + pi / 2), py = sin(a + pi / 2);
    final twin = has(PowerKind.twin);
    final angles = has(PowerKind.spread) ? const [-0.22, 0.0, 0.22] : const [0.0];
    for (final da in angles) {
      final offsets = da == 0 && twin ? const [-7.0, 7.0] : const [0.0];
      for (final o in offsets) {
        final ang = a + da;
        bullets.add(Bullet(nx + px * o, ny + py * o, cos(ang) * speed, sin(ang) * speed, r: 3.5, life: 1.2));
      }
    }
    s.muzzle = 0.05;
    events.add(GameEvent.shoot);
  }

  void _launchMissiles() {
    final s = ship;
    for (final side in const [-1.0, 1.0]) {
      final out = s.angle + side * pi / 2;
      final b = Bullet(
        s.x + cos(out) * 16,
        s.y + sin(out) * 16,
        cos(out) * 160 + cos(s.angle) * 220,
        sin(out) * 160 + sin(s.angle) * 220,
        r: 5,
        damage: 3,
        missile: true,
        life: 3,
      )..target = _nearestEnemy(s.x, s.y);
      bullets.add(b);
    }
    events.add(GameEvent.missile);
  }

  Enemy? _nearestEnemy(double x, double y) {
    Enemy? best;
    var bd = double.infinity;
    for (final e in enemies) {
      if (e.dead) continue;
      final d = _dist(e.x, e.y, x, y);
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    return best;
  }

  /// Bomba: ekranı tarayan şok dalgası, düşman mermilerini siler
  void detonate() {
    bombs--;
    shockwaves.add(Shockwave(++_shockId, ship.x, ship.y, sqrt(w * w + h * h)));
    flash = 0.55;
    shake = 20;
    slowmo = 0.45;
    for (final b in bullets) {
      if (!b.enemy) continue;
      b.life = 0;
      _sparks(b.x, b.y, theme.enemyBullet, 3, 120);
    }
    particles.add(Particle(ParticleType.glow, ship.x, ship.y, life: 0.5, size: 140, color: theme.accent, grow: 300));
    events.add(GameEvent.bomb);
  }

  // ─── Mermiler ─────────────────────────────────────────────────────────────

  void _updateBullets(double dt) {
    for (final b in bullets) {
      if (b.missile) {
        if (b.target == null || b.target!.dead) {
          b.target = _nearestEnemy(b.x, b.y);
        }
        final cur = atan2(b.vy, b.vx);
        var sp = Offset(b.vx, b.vy).distance;
        sp = min(680, sp + 900 * dt);
        var ang = cur;
        final t = b.target;
        if (t != null) {
          final d = angleDiff(cur, atan2(t.y - b.y, t.x - b.x));
          ang = cur + d.clamp(-7.5 * dt, 7.5 * dt);
        }
        b.vx = cos(ang) * sp;
        b.vy = sin(ang) * sp;
        if (rnd.nextBool()) {
          particles.add(
            Particle(
              ParticleType.smoke,
              b.x,
              b.y,
              life: 0.35,
              size: 3,
              grow: 14,
              color: theme.textMuted,
              vx: _r(-10, 10),
              vy: _r(-10, 10),
            ),
          );
        }
      }
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.x < -60 || b.x > w + 60 || b.y < -60 || b.y > h + 60) b.life = 0;
    }
  }

  void _enemyShot(double x, double y, double angle, double speed, {double r = 5}) {
    bullets.add(Bullet(x, y, cos(angle) * speed, sin(angle) * speed, r: r, enemy: true, life: 6));
  }

  // ─── Düşmanlar ────────────────────────────────────────────────────────────

  void _updateEnemies(double dt) {
    final s = ship;
    for (final e in enemies) {
      e.t += dt;
      if (e.flash > 0) e.flash -= dt;
      final dx = s.x - e.x, dy = s.y - e.y;
      final dist = max(1.0, sqrt(dx * dx + dy * dy));
      final ux = dx / dist, uy = dy / dist;
      final ang = atan2(dy, dx);

      void steer(double tx, double ty, double rate) {
        final k = _ease(rate, dt);
        e.vx += (tx - e.vx) * k;
        e.vy += (ty - e.vy) * k;
      }

      switch (e.kind) {
        case EnemyKind.drone:
        case EnemyKind.mini:
          final sp = e.kind == EnemyKind.mini ? 175.0 : min(260.0, 95 + wave * 8.0);
          steer(ux * sp, uy * sp, 0.05);
        case EnemyKind.dart:
          final sp = min(330.0, 190 + wave * 6.0);
          final wob = sin(e.t * 5 + e.phase) * 0.9;
          var tx = ux - uy * wob, ty = uy + ux * wob;
          final l = sqrt(tx * tx + ty * ty);
          tx /= l;
          ty /= l;
          steer(tx * sp, ty * sp, 0.18);
        case EnemyKind.tank:
          final sp = dist > 170 ? 48.0 : 0.0;
          steer(ux * sp, uy * sp, 0.04);
          e.a = ang; // taret açısı
          e.cd -= dt;
          if (e.cd <= 0) {
            for (final da in const [-0.2, 0.0, 0.2]) {
              _enemyShot(e.x + cos(ang) * 30, e.y + sin(ang) * 30, ang + da, 230, r: 6);
            }
            e.cd = max(1.4, 2.6 - wave * 0.04);
            e.flash = 0.04;
          }
        case EnemyKind.sniper:
          final radial = dist > 300 ? 1.0 : (dist < 210 ? -1.0 : 0.0);
          steer(ux * radial * 130 - uy * e.phase * 70, uy * radial * 130 + ux * e.phase * 70, 0.05);
          e.cd -= dt;
          // Son 0.25 saniyede nişan kilitlenir; oyuncu lazer çizgisinden kaçabilir
          if (e.cd > 0.25) e.a = ang;
          e.state = e.cd < 0.8 ? 1 : 0;
          if (e.cd <= 0) {
            _enemyShot(e.x + cos(e.a) * 20, e.y + sin(e.a) * 20, e.a, 540, r: 5);
            e.cd = max(1.6, 2.8 - wave * 0.03);
          }
        case EnemyKind.splitter:
          final sp = 62.0;
          final wob = sin(e.t * 2 + e.phase) * 0.5;
          steer((ux - uy * wob) * sp, (uy + ux * wob) * sp, 0.04);
        case EnemyKind.kamikaze:
          switch (e.state) {
            case 0: // yaklaş
              steer(ux * 75, uy * 75, 0.05);
              if (dist < 290 && e.t > 1.2) {
                e.state = 1;
                e.cd = 0.8;
              }
            case 1: // gerilip nişan al
              steer(0, 0, 0.12);
              e.a = ux;
              e.b = uy;
              e.cd -= dt;
              if (e.cd <= 0) {
                e.state = 2;
                e.cd = 1.1;
                e.vx = e.a * 720;
                e.vy = e.b * 720;
              }
            default: // atıl
              e.cd -= dt;
              if (rnd.nextBool()) {
                particles.add(
                  Particle(
                    ParticleType.flame,
                    e.x,
                    e.y,
                    life: 0.25,
                    size: 6,
                    color: _enemyColor(e.color),
                    vx: -e.vx * 0.1,
                    vy: -e.vy * 0.1,
                  ),
                );
              }
              if (e.cd <= 0) {
                e.state = 0;
                e.t = 0;
                e.vx *= 0.3;
                e.vy *= 0.3;
              }
          }
        case EnemyKind.boss:
          _updateBoss(e, dt, ang);
      }

      if (e.kind != EnemyKind.boss) {
        e.x += e.vx * dt;
        e.y += e.vy * dt;
      }
    }
  }

  void _updateBoss(Enemy e, double dt, double ang) {
    final p = e.hp / e.maxHp;
    if (e.state == 0) {
      // Giriş: yukarıdan süzülerek yerine gelir
      e.y += (h * 0.2 - e.y) * _ease(0.03, dt);
      if ((e.y - h * 0.2).abs() < 4) {
        e.state = 1;
        e.t = 0;
      }
      return;
    }
    final tx = w / 2 + sin(e.t * 0.5) * w * 0.3;
    final ty = h * 0.2 + sin(e.t * 1.1) * h * 0.06;
    e.x += (tx - e.x) * _ease(0.05, dt);
    e.y += (ty - e.y) * _ease(0.05, dt);
    e.a = ang;

    // Çember atış
    e.cd -= dt;
    if (e.cd <= 0) {
      final n = p < 0.5 ? 20 : 14;
      for (var i = 0; i < n; i++) {
        _enemyShot(e.x, e.y, e.t * 0.7 + i * 2 * pi / n, 170, r: 6);
      }
      e.cd = p < 0.33 ? 1.7 : 2.5;
    }
    // Hedefli üçlü
    if (p < 0.66) {
      e.phase -= dt;
      if (e.phase <= 0) {
        for (final da in const [-0.15, 0.0, 0.15]) {
          _enemyShot(e.x + cos(ang) * 50, e.y + sin(ang) * 50, ang + da, 270, r: 6);
        }
        e.phase = 1.15;
      }
    }
    // Sarmal
    if (p < 0.33) {
      e.b -= dt;
      if (e.b <= 0) {
        e.c += 0.45;
        _enemyShot(e.x, e.y, e.c, 210, r: 5);
        _enemyShot(e.x, e.y, e.c + pi, 210, r: 5);
        e.b = 0.11;
      }
    }
    // Yardımcı dronlar
    if ((e.t % 6) < dt) {
      for (final side in const [-1.0, 1.0]) {
        spawnEnemy(EnemyKind.mini, e.x + side * 60, e.y + 20);
      }
    }
  }

  // ─── Şok dalgası ve güçler ────────────────────────────────────────────────

  void _updateShockwaves(double dt) {
    for (final sw in shockwaves) {
      sw.r += 1500 * dt;
      for (final e in enemies) {
        if (e.dead || e.shockId == sw.id) continue;
        if (_dist(e.x, e.y, sw.x, sw.y) < sw.r + e.r) {
          e.shockId = sw.id;
          _damage(e, e.isBoss ? (e.maxHp * 0.12).round() : 40, e.x, e.y);
        }
      }
      for (final b in bullets) {
        if (b.enemy && b.life > 0 && _dist(b.x, b.y, sw.x, sw.y) < sw.r) {
          b.life = 0;
        }
      }
    }
    shockwaves.removeWhere((sw) => sw.r > sw.maxR);
  }

  void _updatePowerups(double dt) {
    final s = ship;
    for (final p in powerups) {
      p.t += dt;
      final d = _dist(p.x, p.y, s.x, s.y);
      if (d < 150) {
        final k = 420 / max(d, 1);
        p.vx = (s.x - p.x) * k;
        p.vy = (s.y - p.y) * k;
      } else {
        p.vx *= 1 - min(1, 2 * dt);
        p.vy *= 1 - min(1, 2 * dt);
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (d < 30) {
        _apply(p.kind, p.x, p.y);
        p.t = 999;
      }
    }
    powerups.removeWhere((p) => p.t > 12);
  }

  void _apply(PowerKind k, double x, double y) {
    final s = S.current;
    final label = switch (k) {
      PowerKind.twin => s.twin,
      PowerKind.spread => s.spread,
      PowerKind.rapid => s.rapid,
      PowerKind.missile => s.missile,
      PowerKind.shield => s.shield,
      PowerKind.bomb => s.bombPickup,
      PowerKind.life => s.life,
    };
    switch (k) {
      case PowerKind.twin || PowerKind.spread || PowerKind.rapid || PowerKind.missile:
        const dur = {PowerKind.twin: 14.0, PowerKind.spread: 12.0, PowerKind.rapid: 10.0, PowerKind.missile: 12.0};
        timers[k] = min(25, max(0, timers[k] ?? 0) + dur[k]!);
        events.add(GameEvent.power);
      case PowerKind.shield:
        ship
          ..shieldHits = 3
          ..shieldTime = 20;
        events.add(GameEvent.shield);
      case PowerKind.bomb:
        bombs = min(3, bombs + 1);
        events.add(GameEvent.power);
      case PowerKind.life:
        ship.lives = min(5, ship.lives + 1);
        events.add(GameEvent.power);
    }
    _text(x, y - 20, label, powerColor(k), size: 15, life: 1.3);
    particles.add(Particle(ParticleType.ring, x, y, life: 0.4, size: 10, grow: 160, color: powerColor(k)));
  }

  Color powerColor(PowerKind k) => powerColorOf(k);

  void _maybeDrop(Enemy e) {
    final chance = switch (e.kind) {
      EnemyKind.tank => 0.45,
      EnemyKind.sniper => 0.25,
      EnemyKind.splitter => 0.2,
      EnemyKind.kamikaze => 0.15,
      EnemyKind.mini => 0.02,
      EnemyKind.boss => 1.0,
      _ => 0.06,
    };
    _sinceDrop++;
    final count = e.isBoss ? 3 : (rnd.nextDouble() < chance || _sinceDrop > 22 ? 1 : 0);
    for (var i = 0; i < count; i++) {
      _sinceDrop = 0;
      final pool = <(PowerKind, int)>[
        (PowerKind.twin, 20),
        (PowerKind.spread, 16),
        (PowerKind.rapid, 15),
        (PowerKind.missile, 14),
        (PowerKind.shield, 13),
        if (bombs < 3) (PowerKind.bomb, 11),
        if (ship.lives < 5) (PowerKind.life, 5),
      ];
      var pick = rnd.nextInt(pool.fold(0, (s, p) => s + p.$2));
      var kind = PowerKind.twin;
      for (final (k, wgt) in pool) {
        if (pick < wgt) {
          kind = k;
          break;
        }
        pick -= wgt;
      }
      final a = _r(0, 2 * pi);
      powerups.add(PowerUp(kind, e.x, e.y, vx: cos(a) * 90, vy: sin(a) * 90));
    }
  }

  // ─── Çarpışmalar ──────────────────────────────────────────────────────────

  void _collide() {
    final s = ship;
    for (final e in enemies) {
      if (e.dead) continue;
      for (final b in bullets) {
        if (b.enemy || b.life <= 0) continue;
        if (_dist(e.x, e.y, b.x, b.y) < e.r + b.r) {
          b.life = 0;
          if (b.missile) _sparks(b.x, b.y, const Color(0xFFFF8A3D), 8, 220);
          _damage(e, b.damage, b.x, b.y);
          if (e.dead) break;
        }
      }
      if (e.dead) continue;
      if (_dist(e.x, e.y, s.x, s.y) < e.r * 0.85 + shipRadius) {
        if (e.isBoss) {
          final a = atan2(s.y - e.y, s.x - e.x);
          s.vx = cos(a) * 500;
          s.vy = sin(a) * 500;
        } else {
          _kill(e, rewarded: false);
        }
        _playerHit();
        if (over) return;
      }
    }
    for (final b in bullets) {
      if (!b.enemy || b.life <= 0) continue;
      if (_dist(b.x, b.y, s.x, s.y) < b.r + shipRadius - 2) {
        b.life = 0;
        _playerHit();
        if (over) return;
      }
    }
  }

  void _damage(Enemy e, int dmg, double x, double y) {
    e.hp -= dmg;
    e.flash = 0.07;
    if (e.hp <= 0) {
      _kill(e);
    } else {
      _sparks(x, y, _enemyColor(e.color), 4, 160);
      events.add(GameEvent.hit);
    }
  }

  void _kill(Enemy e, {bool rewarded = true}) {
    e.dead = true;
    final color = _enemyColor(e.color);
    if (rewarded) {
      kills++;
      combo = comboTimer > 0 ? combo + 1 : 1;
      comboTimer = 2.0;
      final m = min(8, 1 + combo ~/ 5);
      if (m > multiplier) {
        _text(ship.x, ship.y - 46, S.current.combo(m), theme.accent2, size: 18, life: 1.2);
        events.add(GameEvent.combo);
      }
      multiplier = m;
      final pts = e.value * multiplier;
      score += pts;
      _text(e.x, e.y, '+$pts', color, size: e.isBoss ? 26 : 13, life: e.isBoss ? 1.8 : 0.9);
      _maybeDrop(e);
    }
    if (e.kind == EnemyKind.splitter) {
      for (var i = 0; i < 3; i++) {
        final a = i * 2 * pi / 3 + _r(0, 1);
        spawnEnemy(EnemyKind.mini, e.x + cos(a) * 14, e.y + sin(a) * 14)
          ..vx = cos(a) * 200
          ..vy = sin(a) * 200;
      }
    }
    if (e.isBoss) {
      boss = null;
      for (var i = 0; i < 7; i++) {
        explode(e.x + _r(-60, 60), e.y + _r(-50, 50), i.isEven ? color : theme.accent, 2.2);
      }
      particles.add(Particle(ParticleType.ring, e.x, e.y, life: 0.9, size: 20, grow: 900, color: theme.accent2));
      flash = 0.6;
      shake = 24;
      slowmo = 1.1;
      _banner(BannerKind.bossDown);
      events.add(GameEvent.bossDown);
    } else {
      explode(e.x, e.y, color, e.r / 14);
      shake = max(shake, e.r > 20 ? 7 : 3);
      events.add(e.r > 20 ? GameEvent.bigExplode : GameEvent.explode);
    }
  }

  void _playerHit() {
    final s = ship;
    if (s.invuln > 0) return;
    if (s.shielded) {
      s.shieldHits--;
      if (s.shieldHits <= 0) s.shieldTime = 0;
      s.invuln = 0.5;
      shake = max(shake, 7);
      particles.add(
        Particle(ParticleType.ring, s.x, s.y, life: 0.35, size: 30, grow: 140, color: const Color(0xFF4FC3FF)),
      );
      events.add(GameEvent.shield);
      return;
    }
    s.lives--;
    s.invuln = 2.0;
    shake = 16;
    hurt = 0.4;
    combo = 0;
    multiplier = 1;
    comboTimer = 0;
    explode(s.x, s.y, theme.accent, 1.2);
    events.add(GameEvent.playerHit);
    if (s.lives <= 0) {
      over = true;
      explode(s.x, s.y, theme.flame, 3);
      particles.add(Particle(ParticleType.ring, s.x, s.y, life: 0.8, size: 10, grow: 600, color: theme.accent));
      slowmo = 1.4;
      shake = 26;
      flash = 0.4;
      events.add(GameEvent.gameOver);
    }
  }

  // ─── Efektler ─────────────────────────────────────────────────────────────

  void explode(double x, double y, Color color, double scale) {
    final n = (12 * scale).round().clamp(8, 40);
    _sparks(x, y, color, n, 380 * sqrt(scale));
    for (var i = 0; i < (3 * scale).round().clamp(2, 8); i++) {
      final a = _r(0, 2 * pi), sp = _r(60, 200);
      particles.add(
        Particle(
          ParticleType.debris,
          x,
          y,
          vx: cos(a) * sp,
          vy: sin(a) * sp,
          life: _r(0.5, 0.9),
          size: _r(3, 6) * sqrt(scale),
          color: color,
          drag: 1.5,
          rot: a,
          spin: _r(-12, 12),
        ),
      );
    }
    for (var i = 0; i < (3 * scale).round().clamp(2, 6); i++) {
      particles.add(
        Particle(
          ParticleType.smoke,
          x + _r(-8, 8),
          y + _r(-8, 8),
          vx: _r(-30, 30),
          vy: _r(-30, 30),
          life: _r(0.6, 1.0),
          size: 6 * scale,
          grow: 40 * scale,
          color: theme.textMuted,
          drag: 1,
        ),
      );
    }
    particles
      ..add(Particle(ParticleType.glow, x, y, life: 0.22, size: 28 * scale, color: color, grow: 60 * scale))
      ..add(Particle(ParticleType.ring, x, y, life: 0.35, size: 6 * scale, grow: 220 * scale, color: color));
    if (particles.length > 1100) {
      particles.removeRange(0, particles.length - 1100);
    }
  }

  void _sparks(double x, double y, Color color, int n, double speed) {
    for (var i = 0; i < n; i++) {
      final a = _r(0, 2 * pi), sp = _r(0.3, 1) * speed;
      particles.add(
        Particle(
          ParticleType.spark,
          x,
          y,
          vx: cos(a) * sp,
          vy: sin(a) * sp,
          life: _r(0.3, 0.7),
          size: _r(1.5, 3),
          color: color,
          drag: 3,
        ),
      );
    }
  }

  void _text(double x, double y, String text, Color color, {double size = 14, double life = 1}) {
    texts.add(FloatText(x, y, text, color, size: size, life: life));
    if (texts.length > 24) texts.removeAt(0);
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.drag > 0) {
        final k = max(0.0, 1 - p.drag * dt);
        p.vx *= k;
        p.vy *= k;
      }
      p.size += p.grow * dt;
      p.rot += p.spin * dt;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  void _updateTexts(double dt) {
    for (final t in texts) {
      t.y -= 38 * dt;
      t.life -= dt;
    }
    texts.removeWhere((t) => t.life <= 0);
  }

  static double _dist(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return sqrt(dx * dx + dy * dy);
  }
}
