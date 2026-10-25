import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siber/game/controls.dart';
import 'package:siber/game/engine.dart';
import 'package:siber/game/entities.dart';
import 'package:siber/game/painter.dart';

void main() {
  test('her nesne türüyle bir kare hatasız çizilir', () {
    final w = World(400, 800, random: Random(1));
    for (final k in EnemyKind.values) {
      w.spawnEnemy(k, 100 + k.index * 30.0, 200);
    }
    final input = GameInput()
      ..firing = true
      ..aim = -pi / 2;
    w.timers[PowerKind.missile] = 5;
    for (var i = 0; i < 90; i++) {
      w.step(1 / 60, input);
    }
    for (final k in PowerKind.values) {
      w.powerups.add(PowerUp(k, 50.0 + k.index * 40, 600));
    }
    w.texts.add(FloatText(200, 300, '+100', Colors.white));
    w.ship
      ..shieldHits = 2
      ..shieldTime = 5;
    w.detonate();
    w.step(1 / 60, input);
    final move = Stick();
    final aim = Stick()..press(1, const Offset(300, 700), const Size(400, 800));
    final painter = GamePainter(w, repaint: ChangeNotifier(), move: move, aim: aim);
    final rec = ui.PictureRecorder();
    painter.paint(Canvas(rec), const Size(400, 800));
    rec.endRecording();
  });
}
