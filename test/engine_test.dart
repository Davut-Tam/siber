import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:siber/game/engine.dart';
import 'package:siber/game/entities.dart';

/// En yakın düşmana nişan alıp ateş eden, rastgele dolaşan basit bir oyuncu
void autoPlay(World w, GameInput input, Random rnd) {
  Enemy? target;
  var best = double.infinity;
  for (final e in w.enemies) {
    final d = (e.x - w.ship.x).abs() + (e.y - w.ship.y).abs();
    if (d < best) {
      best = d;
      target = e;
    }
  }
  input
    ..firing = target != null
    ..aim = target == null ? null : atan2(target.y - w.ship.y, target.x - w.ship.x);
  if (rnd.nextDouble() < 0.02) {
    input.move = Offset(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1);
  }
}

void main() {
  const dt = 1 / 60;

  test('uzun otomatik oyun hatasız ilerler, puan ve dalga artar', () {
    final rnd = Random(1);
    final w = World(400, 800, random: Random(2));
    final input = GameInput();
    w.ship.lives = 999;
    final events = <GameEvent>{};
    for (var i = 0; i < 60 * 240 && !w.over; i++) {
      autoPlay(w, input, rnd);
      if (i % 900 == 0) input.bomb = true;
      w.step(dt, input);
      events.addAll(w.events);
      w.events.clear();
    }
    expect(w.score, greaterThan(0));
    expect(w.kills, greaterThan(10));
    expect(w.wave, greaterThanOrEqualTo(3));
    expect(events, containsAll([GameEvent.shoot, GameEvent.explode, GameEvent.wave]));
    // Parçacıklar sınırsız büyümez
    expect(w.particles.length, lessThan(1500));
  });

  test('beşinci dalga ana gemidir ve yenilebilir', () {
    final w = World(400, 800, random: Random(3));
    final input = GameInput();
    w.ship.lives = 999;
    w.wave = 4;
    for (var i = 0; i < 120 && w.boss == null; i++) {
      w.step(dt, input);
    }
    expect(w.wave, 5);
    expect(w.boss, isNotNull);
    final events = <GameEvent>{};
    for (var i = 0; i < 60 * 180 && w.boss != null; i++) {
      final b = w.boss!;
      input
        ..firing = true
        ..aim = atan2(b.y - w.ship.y, b.x - w.ship.x);
      w.ship.invuln = 1; // testte uçak ölmesin
      w.step(dt, input);
      events.addAll(w.events);
      w.events.clear();
    }
    expect(events, contains(GameEvent.bossDown));
    expect(w.powerups.length, greaterThanOrEqualTo(1));
  });

  test('bomba ekrandaki düşmanları ve düşman mermilerini temizler', () {
    final w = World(400, 800, random: Random(4));
    final input = GameInput();
    for (var i = 0; i < 6; i++) {
      w.spawnEnemy(EnemyKind.drone, 50.0 + i * 50, 100);
    }
    w.step(dt, input); // bekleyen düşmanlar listeye girer
    expect(w.enemies.length, 6);
    w.bullets.add(Bullet(200, 300, 0, 0, enemy: true, life: 5));
    final bombs = w.bombs;
    input.bomb = true;
    for (var i = 0; i < 60; i++) {
      w.step(dt, input);
    }
    expect(w.bombs, bombs - 1);
    expect(w.enemies.where((e) => e.kind == EnemyKind.drone), isEmpty);
    expect(w.bullets.where((b) => b.enemy), isEmpty);
  });

  test('bölünen düşman ölünce üç küçük dron bırakır', () {
    final w = World(400, 800, random: Random(5));
    final input = GameInput();
    final e = w.spawnEnemy(EnemyKind.splitter, 200, 150)..hp = 1;
    w.step(dt, input);
    w.bullets.add(Bullet(e.x, e.y, 0, 0, life: 1));
    w.step(dt, input);
    expect(e.dead, isTrue);
    expect(w.enemies.where((x) => x.kind == EnemyKind.mini).length, 3);
  });

  test('güç toplamak silahı değiştirir, kalkan bir darbeyi emer', () {
    final w = World(400, 800, random: Random(6));
    final input = GameInput();
    w.powerups.add(PowerUp(PowerKind.twin, w.ship.x, w.ship.y));
    w.powerups.add(PowerUp(PowerKind.shield, w.ship.x, w.ship.y));
    w.step(dt, input);
    expect(w.has(PowerKind.twin), isTrue);
    expect(w.ship.shielded, isTrue);
    final lives = w.ship.lives;
    w.bullets.add(Bullet(w.ship.x, w.ship.y, 0, 0, enemy: true, life: 1));
    w.step(dt, input);
    expect(w.ship.lives, lives);
    expect(w.ship.shieldHits, 2);
  });
}
