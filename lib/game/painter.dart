import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/themes.dart';
import 'controls.dart';
import 'engine.dart';
import 'entities.dart';

/// Güçlerin simgeleri (çizimde ve arayüzde ortak)
IconData powerIcon(PowerKind k) => switch (k) {
  PowerKind.twin => Icons.view_column_rounded,
  PowerKind.spread => Icons.call_split_rounded,
  PowerKind.rapid => Icons.bolt_rounded,
  PowerKind.missile => Icons.rocket_launch_rounded,
  PowerKind.shield => Icons.shield_rounded,
  PowerKind.bomb => Icons.flare_rounded,
  PowerKind.life => Icons.favorite_rounded,
};

/// Oyun alanının tamamını çizer: zemin, düşmanlar, mermiler, uçak, efektler ve sanal çubuklar
class GamePainter extends CustomPainter {
  GamePainter(this.world, {required Listenable repaint, this.move, this.aim, this.showSticks = true})
    : super(repaint: repaint);

  final World world;
  final Stick? move, aim;
  final bool showSticks;

  GameTheme get t => GameTheme.current;

  static final _iconCache = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    final w = world;
    _background(canvas, size);

    canvas.save();
    if (w.shake > 0) {
      final r = w.rnd;
      canvas.translate((r.nextDouble() - 0.5) * w.shake, (r.nextDouble() - 0.5) * w.shake);
    }
    for (final sw in w.shockwaves) {
      _shockwave(canvas, sw);
    }
    for (final p in w.powerups) {
      _powerup(canvas, p);
    }
    _particles(canvas, behind: true);
    for (final e in w.enemies) {
      _enemy(canvas, e);
    }
    _bullets(canvas);
    if (!w.over) _ship(canvas);
    _particles(canvas, behind: false);
    _texts(canvas);
    canvas.restore();

    _overlays(canvas, size);
    if (showSticks && !w.over) {
      final h = size.height;
      _stick(canvas, move, Offset(Stick.radius + 26, h - Stick.radius - 30), S.current.move);
      _stick(canvas, aim, Offset(size.width - Stick.radius - 26, h - Stick.radius - 30), S.current.aim);
    }
  }

  Paint _glow(Color c, [double alpha = 1]) => Paint()
    ..color = c.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..blendMode = t.glowBlend;

  // ─── Zemin ────────────────────────────────────────────────────────────────

  void _background(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [t.bg, t.bg2]));
    final time = world.time;
    for (final (c, color, r) in [
      (Offset(size.width * (0.2 + 0.05 * sin(time * 0.05)), size.height * 0.22), t.nebula1, size.width * 0.9),
      (Offset(size.width * (0.85 + 0.05 * cos(time * 0.04)), size.height * 0.72), t.nebula2, size.width * 0.8),
    ]) {
      canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, [color, color.withValues(alpha: 0)]));
    }

    // Neon ızgara: yatay çizgiler aşağı akar, dikeyler uçağın tersine hafif kayar
    final grid = Paint()
      ..color = t.grid
      ..strokeWidth = 1;
    const step = 64.0;
    final ox = -(world.ship.x * 0.06) % step;
    for (var x = ox; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = world.gridScroll - step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Yıldızlar: üç katman, katmana göre boy ve parlaklık
    final starPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..blendMode = t.glowBlend;
    for (final layer in const [0.0, 0.5, 1.0]) {
      final pts = <Offset>[];
      for (final s in world.stars) {
        if (s.layer == layer) pts.add(Offset(s.x, s.y));
      }
      starPaint
        ..strokeWidth = 1.2 + layer * 1.8
        ..color = t.star.withValues(alpha: (0.3 + layer * 0.45) * (0.75 + 0.25 * sin(world.time * 2 + layer * 3)));
      canvas.drawPoints(ui.PointMode.points, pts, starPaint);
    }
  }

  // ─── Uçak ─────────────────────────────────────────────────────────────────

  static final _fuselage = Path()
    ..moveTo(27, 0)
    ..cubicTo(22, -2.2, 12, -4.6, 0, -4.8)
    ..lineTo(-16, -4.4)
    ..lineTo(-21, -3.2)
    ..lineTo(-21, 3.2)
    ..lineTo(-16, 4.4)
    ..lineTo(0, 4.8)
    ..cubicTo(12, 4.6, 22, 2.2, 27, 0)
    ..close();

  static Path _mirrored(List<Offset> half) {
    final p = Path()..addPolygon(half, true);
    return p..addPolygon([for (final o in half) Offset(o.dx, -o.dy)], true);
  }

  static final _wings = _mirrored(const [Offset(6, -4.5), Offset(-9, -23), Offset(-15, -23.5), Offset(-12, -4.5)]);
  static final _canards = _mirrored(const [Offset(17, -3), Offset(11, -9.5), Offset(8.5, -9.5), Offset(9.5, -3.5)]);
  static final _fins = _mirrored(const [
    Offset(-11, -4.4),
    Offset(-19, -12.5),
    Offset(-22.5, -12.5),
    Offset(-19.5, -4),
  ]);

  void _ship(Canvas canvas) {
    final s = world.ship;
    if (s.invuln > 0 && (s.invuln * 14).floor().isEven) return;
    final speed = Offset(s.vx, s.vy).distance / 400;

    canvas.save();
    canvas.translate(s.x, s.y);

    // Yerdeki gölge yükseklik hissi verir
    canvas.save();
    canvas.translate(7, 11);
    canvas.rotate(s.angle);
    canvas.scale(0.92, 0.92 * (1 - s.bank.abs() * 0.28));
    final shadow = Paint()..color = Colors.black.withValues(alpha: t.light ? 0.16 : 0.32);
    canvas
      ..drawPath(_wings, shadow)
      ..drawPath(_fins, shadow)
      ..drawPath(_fuselage, shadow);
    canvas.restore();

    if (!t.light) {
      canvas.drawCircle(
        Offset.zero,
        40,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, 40, [
            t.accent.withValues(alpha: 0.22),
            t.accent.withValues(alpha: 0),
          ])
          ..blendMode = BlendMode.plus,
      );
    }

    canvas.rotate(s.angle);
    canvas.scale(1, 1 - s.bank.abs() * 0.28);

    // Art yakıcı alevi
    final flicker = sin(world.time * 70) * 1.6;
    for (final y in const [-2.2, 2.2]) {
      final len = 7 + speed * 15 + flicker;
      final outer = Path()
        ..moveTo(-21.5, y - 1.9)
        ..quadraticBezierTo(-21.5 - len * 0.6, y - 1.4, -21.5 - len, y)
        ..quadraticBezierTo(-21.5 - len * 0.6, y + 1.4, -21.5, y + 1.9)
        ..close();
      canvas.drawPath(outer, _glow(t.flame, 0.85));
      final inner = Path()
        ..moveTo(-21.5, y - 0.9)
        ..lineTo(-21.5 - len * 0.5, y)
        ..lineTo(-21.5, y + 0.9)
        ..close();
      canvas.drawPath(inner, _glow(Colors.white, 0.9));
    }

    final body = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, -24 + s.bank * 10),
        Offset(0, 24 + s.bank * 10),
        [Color.lerp(t.shipBody, Colors.white, 0.25)!, t.shipBody, t.shipDark],
        const [0, 0.45, 1],
      );
    canvas
      ..drawPath(_wings, body)
      ..drawPath(_fins, body)
      ..drawPath(_canards, body);

    // Kanat hücum kenarı ve uç şeritleri
    final stripe = Paint()
      ..color = t.accent
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final sy in const [-1.0, 1.0]) {
      canvas
        ..drawLine(Offset(5, -5 * sy), Offset(-9.5, -22.5 * sy), stripe)
        ..drawLine(Offset(-11, -23.2 * sy), Offset(-15, -23.5 * sy), stripe..strokeWidth = 2.6);
      stripe.strokeWidth = 1.6;
    }

    canvas.drawPath(
      _fuselage,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -5),
          const Offset(0, 5),
          [Color.lerp(t.shipBody, Colors.white, 0.35)!, t.shipBody, t.shipDark],
          const [0, 0.5, 1],
        ),
    );
    // Gövde ortası çizgisi
    canvas.drawLine(
      const Offset(-18, 0),
      const Offset(4, 0),
      Paint()
        ..color = t.shipDark.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );

    // Kokpit camı
    final canopy = Rect.fromCenter(center: const Offset(12.5, 0), width: 13, height: 5.4);
    canvas
      ..drawOval(
        canopy,
        Paint()
          ..shader = ui.Gradient.linear(
            canopy.topLeft,
            canopy.bottomRight,
            [Color.lerp(t.canopy, Colors.white, 0.6)!, t.canopy, Color.lerp(t.canopy, Colors.black, 0.5)!],
            const [0, 0.45, 1],
          ),
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(14, -1), width: 5, height: 1.4),
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );

    // Motor ağızları
    final nozzle = Paint()..color = Color.lerp(t.shipDark, Colors.black, 0.4)!;
    for (final y in const [-2.2, 2.2]) {
      canvas.drawCircle(Offset(-21.2, y), 1.9, nozzle);
    }

    // Namlu alevi
    if (s.muzzle > 0) {
      final twin = world.has(PowerKind.twin);
      for (final y in twin ? const [-7.0, 7.0] : const [0.0]) {
        canvas
          ..drawCircle(Offset(27, y), 7, _glow(t.bulletGlow, 0.55))
          ..drawCircle(Offset(27, y), 3, _glow(Colors.white, 0.9));
      }
    }
    canvas.restore();

    if (s.shielded) {
      final pulse = 0.5 + 0.3 * sin(world.time * 6);
      const shieldColor = Color(0xFF4FC3FF);
      canvas
        ..drawCircle(Offset(s.x, s.y), 34, _glow(shieldColor, 0.08))
        ..drawCircle(
          Offset(s.x, s.y),
          34,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = shieldColor.withValues(alpha: pulse),
        );
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = shieldColor.withValues(alpha: 0.8);
      for (var i = 0; i < s.shieldHits; i++) {
        final a0 = world.time * 2 + i * 2 * pi / 3;
        canvas.drawArc(Rect.fromCircle(center: Offset(s.x, s.y), radius: 39), a0, 0.7, false, arc);
      }
    }
  }

  // ─── Düşmanlar ────────────────────────────────────────────────────────────

  static Path _poly(int n, double r, [double rot = 0]) {
    return Path()..addPolygon([
      for (var i = 0; i < n; i++) Offset(cos(rot + i * 2 * pi / n) * r, sin(rot + i * 2 * pi / n) * r),
    ], true);
  }

  void _enemy(Canvas canvas, Enemy e) {
    final c = t.enemies[e.color % t.enemies.length];
    final dark = Color.lerp(c, t.light ? Colors.white : Colors.black, t.light ? 0.55 : 0.6)!;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = c;
    final fill = Paint()..color = dark;
    final r = e.r;

    canvas.save();
    canvas.translate(e.x, e.y);
    canvas.drawCircle(
      Offset.zero,
      r * 2,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, r * 2, [c.withValues(alpha: 0.28), c.withValues(alpha: 0)])
        ..blendMode = t.glowBlend,
    );

    switch (e.kind) {
      case EnemyKind.drone || EnemyKind.mini:
        final hex = _poly(6, r, e.t * 0.8);
        canvas
          ..drawPath(hex, fill)
          ..drawPath(hex, stroke);
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = c;
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 0.62), -e.t * 3 + i * 2.09, 1.2, false, arc);
        }
        canvas.drawCircle(Offset.zero, r * (0.26 + 0.06 * sin(e.t * 8)), _glow(Color.lerp(c, Colors.white, 0.4)!));
      case EnemyKind.dart:
        canvas.rotate(atan2(e.vy, e.vx));
        final p = Path()
          ..moveTo(r * 1.6, 0)
          ..lineTo(-r, -r)
          ..lineTo(-r * 0.4, 0)
          ..lineTo(-r, r)
          ..close();
        canvas
          ..drawCircle(Offset(-r * 0.7, 0), r * 0.6, _glow(c, 0.6))
          ..drawPath(p, Paint()..color = c)
          ..drawPath(p, stroke..color = Color.lerp(c, Colors.white, 0.5)!);
      case EnemyKind.tank:
        final oct = _poly(8, r, pi / 8);
        canvas
          ..drawPath(oct, fill)
          ..drawPath(oct, stroke..strokeWidth = 2.6)
          ..drawPath(_poly(8, r * 0.7, pi / 8), stroke..strokeWidth = 1.2);
        canvas.save();
        canvas.rotate(e.a);
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(0, -3.5, r * 1.2, 7), const Radius.circular(2)),
            Paint()..color = c,
          )
          ..drawCircle(Offset.zero, r * 0.45, Paint()..color = c)
          ..drawCircle(Offset.zero, r * 0.2, Paint()..color = dark);
        canvas.restore();
        _hpBar(canvas, e, r);
      case EnemyKind.sniper:
        if (e.state == 1) {
          final k = (1 - e.cd / 0.8).clamp(0.0, 1.0);
          canvas.drawLine(
            Offset.zero,
            Offset(cos(e.a) * 1600, sin(e.a) * 1600),
            Paint()
              ..color = t.danger.withValues(alpha: 0.15 + 0.55 * k * (0.6 + 0.4 * sin(world.time * 40)))
              ..strokeWidth = 1 + k * 1.5,
          );
        }
        canvas.rotate(e.a);
        final d = Path()
          ..moveTo(r * 1.3, 0)
          ..lineTo(0, -r * 0.85)
          ..lineTo(-r, 0)
          ..lineTo(0, r * 0.85)
          ..close();
        canvas
          ..drawRect(Rect.fromLTWH(0, -1.6, r * 2, 3.2), Paint()..color = c)
          ..drawPath(d, fill)
          ..drawPath(d, stroke)
          ..drawCircle(Offset.zero, r * 0.28, _glow(Color.lerp(c, Colors.white, 0.4)!));
      case EnemyKind.splitter:
        final pulse = 1 + 0.08 * sin(e.t * 4 + e.phase);
        canvas.drawCircle(Offset.zero, r * pulse, Paint()..color = c.withValues(alpha: 0.18));
        canvas.drawCircle(Offset.zero, r * pulse, stroke..color = c.withValues(alpha: 0.8));
        for (var i = 0; i < 3; i++) {
          final a = e.t * 0.9 + i * 2 * pi / 3;
          final o = Offset(cos(a), sin(a)) * r * 0.42;
          canvas
            ..drawCircle(o, r * 0.36, Paint()..color = dark)
            ..drawCircle(
              o,
              r * 0.36,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = c,
            )
            ..drawCircle(o, r * 0.13, _glow(c));
        }
      case EnemyKind.kamikaze:
        final charging = e.state == 1;
        final scale = charging ? 1.12 + 0.06 * sin(world.time * 40) : 1.0;
        if (charging || e.state == 2) {
          canvas.drawCircle(Offset.zero, r * 1.7, _glow(t.danger, charging ? 0.35 : 0.25));
        }
        canvas.rotate(e.t * (e.state == 2 ? 14 : 4));
        final star = Path();
        for (var i = 0; i < 16; i++) {
          final rr = (i.isEven ? r * 1.15 : r * 0.55) * scale;
          final a = i * pi / 8;
          final p = Offset(cos(a) * rr, sin(a) * rr);
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        star.close();
        canvas
          ..drawPath(star, fill..color = charging ? Color.lerp(dark, t.danger, 0.5)! : dark)
          ..drawPath(star, stroke..color = charging ? t.danger : c)
          ..drawCircle(Offset.zero, r * 0.3, _glow(charging ? Colors.white : c));
      case EnemyKind.boss:
        _boss(canvas, e, c, dark);
    }

    if (e.flash > 0) {
      canvas.drawCircle(Offset.zero, r, _glow(Colors.white, (e.flash / 0.07) * 0.55));
    }
    canvas.restore();
  }

  void _hpBar(Canvas canvas, Enemy e, double r) {
    if (e.hp >= e.maxHp) return;
    final rect = Rect.fromLTWH(-r, -r - 10, r * 2, 3.5);
    canvas
      ..drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = Colors.black45)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top, rect.width * e.hp / e.maxHp, rect.height),
          const Radius.circular(2),
        ),
        Paint()..color = t.good,
      );
  }

  void _boss(Canvas canvas, Enemy e, Color c, Color dark) {
    final r = e.r;
    final hurt = 1 - e.hp / e.maxHp;
    canvas.drawCircle(
      Offset.zero,
      r * 1.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = c.withValues(alpha: 0.85),
    );
    // Dönen taretler
    for (var i = 0; i < 8; i++) {
      final a = e.t * 0.5 + i * pi / 4;
      final p = Offset(cos(a), sin(a)) * r * 1.25;
      canvas
        ..drawCircle(p, r * 0.13, Paint()..color = dark)
        ..drawCircle(
          p,
          r * 0.13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c,
        )
        ..drawCircle(p, r * 0.05, _glow(c));
    }
    final hull = _poly(6, r * 0.95, pi / 6 + sin(e.t * 0.3) * 0.1);
    canvas
      ..drawPath(hull, Paint()..shader = ui.Gradient.radial(Offset.zero, r, [Color.lerp(dark, c, 0.35)!, dark]))
      ..drawPath(
        hull,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = c,
      )
      ..drawPath(
        _poly(6, r * 0.62, -e.t * 0.4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.withValues(alpha: 0.7),
      );
    // Hasar aldıkça çatlaklar ve kıvılcımlar
    if (hurt > 0.3) {
      final crack = Paint()
        ..color = t.danger.withValues(alpha: 0.6 + 0.3 * sin(e.t * 20))
        ..strokeWidth = 2;
      canvas
        ..drawLine(Offset(-r * 0.6, -r * 0.2), Offset(-r * 0.2, r * 0.1), crack)
        ..drawLine(Offset(r * 0.3, -r * 0.5), Offset(r * 0.5, -r * 0.1), crack);
    }
    // Göz: oyuncuyu izler
    final eye = r * 0.3;
    canvas
      ..drawCircle(Offset.zero, eye * 1.5, _glow(c, 0.35 + 0.2 * sin(e.t * 3)))
      ..drawCircle(Offset.zero, eye, Paint()..color = Color.lerp(c, Colors.white, 0.3)!)
      ..drawCircle(Offset(cos(e.a), sin(e.a)) * eye * 0.45, eye * 0.42, Paint()..color = Colors.black);
  }

  // ─── Mermiler, güçler, şok dalgası ────────────────────────────────────────

  void _bullets(Canvas canvas) {
    final outer = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = t.bulletGlow.withValues(alpha: 0.45)
      ..blendMode = t.glowBlend;
    final inner = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = t.bullet;
    final eGlow = _glow(t.enemyBullet, 0.32);
    final eCore = Paint()..color = Color.lerp(t.enemyBullet, Colors.white, t.light ? 0.0 : 0.55)!;
    for (final b in world.bullets) {
      if (b.enemy) {
        canvas
          ..drawCircle(Offset(b.x, b.y), b.r * 2.2, eGlow)
          ..drawCircle(Offset(b.x, b.y), b.r, eCore);
      } else if (b.missile) {
        final a = atan2(b.vy, b.vx);
        canvas.save();
        canvas.translate(b.x, b.y);
        canvas.rotate(a);
        canvas
          ..drawCircle(const Offset(-7, 0), 5, _glow(const Color(0xFFFF8A3D), 0.7))
          ..drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -2, 12, 4), const Radius.circular(2)),
            Paint()..color = Color.lerp(t.shipBody, Colors.white, 0.3)!,
          )
          ..drawCircle(const Offset(6, 0), 2, Paint()..color = t.danger);
        canvas.restore();
      } else {
        final tail = Offset(b.x - b.vx * 0.02, b.y - b.vy * 0.02);
        canvas
          ..drawLine(tail, Offset(b.x, b.y), outer)
          ..drawLine(tail, Offset(b.x, b.y), inner);
      }
    }
  }

  void _powerup(Canvas canvas, PowerUp p) {
    if (p.t > 9 && (p.t * 8).floor().isOdd) return;
    final color = world.powerColor(p.kind);
    final pos = Offset(p.x, p.y + sin(p.t * 3) * 3);
    canvas.drawCircle(pos, 30, _glow(color, 0.18 + 0.08 * sin(p.t * 5)));
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    final hex = _poly(6, 16, p.t * 0.8);
    canvas
      ..drawPath(hex, Paint()..color = t.panel)
      ..drawPath(
        hex,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = color,
      );
    canvas.restore();
    final icon = powerIcon(p.kind);
    final key = '${icon.codePoint}-${color.toARGB32()}';
    final tp = _iconCache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 17, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _shockwave(Canvas canvas, Shockwave sw) {
    final k = (sw.r / sw.maxR).clamp(0.0, 1.0);
    canvas
      ..drawCircle(
        Offset(sw.x, sw.y),
        sw.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26 * (1 - k) + 4
          ..color = t.accent.withValues(alpha: 0.5 * (1 - k))
          ..blendMode = t.glowBlend,
      )
      ..drawCircle(
        Offset(sw.x, sw.y),
        sw.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - k)),
      );
  }

  // ─── Parçacıklar ve yazılar ───────────────────────────────────────────────

  void _particles(Canvas canvas, {required bool behind}) {
    for (final p in world.particles) {
      final isBehind = p.type == ParticleType.flame || p.type == ParticleType.smoke;
      if (isBehind != behind) continue;
      final f = p.fade;
      switch (p.type) {
        case ParticleType.spark:
          canvas.drawLine(
            Offset(p.x - p.vx * 0.03, p.y - p.vy * 0.03),
            Offset(p.x, p.y),
            _glow(p.color, f)
              ..strokeWidth = p.size
              ..strokeCap = StrokeCap.round,
          );
        case ParticleType.flame:
          canvas.drawCircle(Offset(p.x, p.y), p.size * (0.4 + 0.6 * f), _glow(p.color, f * 0.75));
        case ParticleType.smoke:
          canvas.drawCircle(Offset(p.x, p.y), p.size, Paint()..color = p.color.withValues(alpha: 0.22 * f));
        case ParticleType.ring:
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size,
            _glow(p.color, f)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1 + 4 * f,
          );
        case ParticleType.debris:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rot);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45),
            Paint()..color = p.color.withValues(alpha: f),
          );
          canvas.restore();
        case ParticleType.glow:
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size,
            Paint()
              ..shader = ui.Gradient.radial(Offset(p.x, p.y), max(1, p.size), [
                p.color.withValues(alpha: 0.7 * f),
                p.color.withValues(alpha: 0),
              ])
              ..blendMode = t.glowBlend,
          );
      }
    }
  }

  void _texts(Canvas canvas) {
    for (final txt in world.texts) {
      final k = txt.life / txt.maxLife;
      final pop = 1 + 0.35 * pow(max(0, k - 0.7) / 0.3, 2);
      final tp = TextPainter(
        text: TextSpan(
          text: txt.text,
          style: TextStyle(
            fontFamily: 'Exo2',
            fontWeight: FontWeight.w900,
            fontSize: txt.size * pop,
            color: txt.color.withValues(alpha: min(1, k * 2.5)),
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5 * k), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(txt.x - tp.width / 2, txt.y - tp.height / 2));
    }
  }

  // ─── Ekran üstü efektler ve çubuklar ──────────────────────────────────────

  void _overlays(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (world.hurt > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            size.longestSide * 0.7,
            [t.danger.withValues(alpha: 0), t.danger.withValues(alpha: 0.55 * world.hurt / 0.4)],
            const [0.55, 1],
          ),
      );
    }
    if (world.flash > 0) {
      canvas.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: (world.flash * 0.9).clamp(0.0, 0.7)));
    }
  }

  void _stick(Canvas canvas, Stick? s, Offset idle, String label) {
    if (s == null) return;
    final r = Stick.radius;
    final active = s.active;
    final center = active ? s.center : idle;
    final k = active ? 1.0 : 0.4;
    canvas
      ..drawCircle(center, r, Paint()..color = t.text.withValues(alpha: 0.05 * k))
      ..drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = t.accent.withValues(alpha: 0.4 * k),
      );
    if (!active) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Exo2',
            color: t.accent.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      return;
    }
    final head = center + s.vector * r;
    canvas
      ..drawLine(
        center,
        head,
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = t.accent.withValues(alpha: 0.3),
      )
      ..drawCircle(head, 25, Paint()..color = t.accent.withValues(alpha: 0.85))
      ..drawCircle(head.translate(-7, -7), 8, Paint()..color = Colors.white.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(GamePainter old) => old.world != world || old.showSticks != showSticks;
}
