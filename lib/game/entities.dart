import 'dart:ui';

enum EnemyKind { drone, dart, tank, sniper, splitter, mini, kamikaze, boss }

enum PowerKind { twin, spread, rapid, missile, shield, bomb, life }

/// Süreli silah güçleri; kalkan, bomba ve can anında etki eder
const timedPowers = [PowerKind.twin, PowerKind.spread, PowerKind.rapid, PowerKind.missile];

class Ship {
  double x, y, vx = 0, vy = 0;

  /// Burnun baktığı yön ve dönüş hızından gelen kanat yatışı (-1..1)
  double angle = -1.5708, bank = 0;
  int lives = 3;

  /// Vurulduktan sonraki dokunulmazlık (sn)
  double invuln = 0;
  int shieldHits = 0;
  double shieldTime = 0;

  /// Namlu alevi (sn)
  double muzzle = 0;

  Ship(this.x, this.y);

  bool get shielded => shieldHits > 0 && shieldTime > 0;
}

class Bullet {
  double x, y, vx, vy, r;
  int damage;
  final bool enemy;
  final bool missile;
  double life;
  Enemy? target;

  Bullet(
    this.x,
    this.y,
    this.vx,
    this.vy, {
    this.r = 4,
    this.damage = 1,
    this.enemy = false,
    this.missile = false,
    this.life = 2.5,
  });
}

class Enemy {
  final EnemyKind kind;
  double x, y, vx = 0, vy = 0, r;
  int hp;
  final int maxHp;
  final int value;
  final int color;

  /// Yaşı (sn), ateş/hamle sayacı ve davranış evresi
  double t = 0, cd, phase;
  int state = 0;

  /// Vurulunca beyaz parlama (sn)
  double flash = 0;

  /// Son çarpan şok dalgasının numarası (aynı dalga iki kez vurmasın)
  int shockId = -1;

  /// Davranışa özel ara değerler (hamle yönü, nişan açısı, ikinci sayaç)
  double a = 0, b = 0, c = 0;
  bool dead = false;

  Enemy(this.kind, this.x, this.y, this.r, this.hp, this.value, this.color, {this.cd = 2, this.phase = 0}) : maxHp = hp;

  bool get isBoss => kind == EnemyKind.boss;
}

class PowerUp {
  final PowerKind kind;
  double x, y, vx, vy, t = 0;
  PowerUp(this.kind, this.x, this.y, {this.vx = 0, this.vy = 0});
}

enum ParticleType { spark, smoke, ring, debris, flame, glow }

class Particle {
  final ParticleType type;
  double x, y, vx, vy, life, size, rot, spin;
  final double maxLife, drag, grow;
  final Color color;

  Particle(
    this.type,
    this.x,
    this.y, {
    this.vx = 0,
    this.vy = 0,
    required this.life,
    required this.size,
    required this.color,
    this.drag = 0,
    this.grow = 0,
    this.rot = 0,
    this.spin = 0,
  }) : maxLife = life;

  double get fade => (life / maxLife).clamp(0.0, 1.0);
}

class FloatText {
  double x, y, life;
  final double maxLife;
  final String text;
  final Color color;
  final double size;

  FloatText(this.x, this.y, this.text, this.color, {this.size = 14, this.life = 1}) : maxLife = life;
}

class Star {
  double x, y;
  final double r, layer, twinkle;
  Star(this.x, this.y, this.r, this.layer, this.twinkle);
}

/// Bombanın genişleyen şok dalgası
class Shockwave {
  final int id;
  final double x, y, maxR;
  double r = 0;
  Shockwave(this.id, this.x, this.y, this.maxR);
}

/// Oyun dünyasından arayüze (ses, titreşim, yazı) giden olaylar
enum GameEvent {
  shoot,
  missile,
  hit,
  explode,
  bigExplode,
  power,
  shield,
  playerHit,
  bomb,
  wave,
  waveCleared,
  boss,
  bossDown,
  combo,
  gameOver,
}
