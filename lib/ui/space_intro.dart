import 'dart:math';

import 'package:flutter/material.dart';

import '../core/themes.dart';

/// Açılış animasyonu: karanlıkta atan küçük bir nokta patlar, yıldızlar ve bulutsular
/// merkezden dışarı yayılarak uzayı oluşturur, sonra sahne ana ekrana karışır. Dokununca atlanır.
class SpaceIntro extends StatefulWidget {
  final GameTheme theme;
  final VoidCallback onDone;
  const SpaceIntro({super.key, required this.theme, required this.onDone});

  /// Yerel açılış ekranıyla aynı renk; geçiş fark edilmesin
  static const void0 = Color(0xFF03060D);

  @override
  State<SpaceIntro> createState() => _SpaceIntroState();
}

class _SpaceIntroState extends State<SpaceIntro> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
    ..forward().whenComplete(widget.onDone);
  late final _stars = _IntroStar.generate(Random(7), 260);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _skip() {
    // Sona yakın değilse kararma bölümüne atla
    if (_c.value < _IntroPainter.fadeStart) _c.forward(from: _IntroPainter.fadeStart);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final p = _c.value;
          final fade = 1 - Curves.easeInOut.transform(_seg(p, _IntroPainter.fadeStart, 1));
          return Opacity(
            opacity: fade,
            child: CustomPaint(
              size: Size.infinite,
              painter: _IntroPainter(p, widget.theme, _stars),
            ),
          );
        },
      ),
    );
  }
}

/// [p]'nin [a]–[b] aralığındaki ilerlemesi (0–1)
double _seg(double p, double a, double b) => ((p - a) / (b - a)).clamp(0.0, 1.0);

class _IntroStar {
  final double angle, dist, size, delay, twinkle;
  final bool tinted;
  const _IntroStar(this.angle, this.dist, this.size, this.delay, this.twinkle, this.tinted);

  static List<_IntroStar> generate(Random r, int n) => [
    for (var i = 0; i < n; i++)
      _IntroStar(
        r.nextDouble() * pi * 2,
        // Kenarlara doğru seyrelmesin diye karekök dağılımı; bir kısmı ekran dışına uçar
        0.04 + sqrt(r.nextDouble()) * 1.05,
        0.6 + pow(r.nextDouble(), 3) * 2.2,
        r.nextDouble() * 0.12,
        r.nextDouble() * pi * 2,
        r.nextDouble() < 0.18,
      ),
  ];
}

class _IntroPainter extends CustomPainter {
  final double p;
  final GameTheme t;
  final List<_IntroStar> stars;
  _IntroPainter(this.p, this.t, this.stars);

  // Zaman çizelgesi (toplam sürenin oranı)
  static const bang = 0.24; // nokta patlar
  static const fadeStart = 0.8; // sahne ana ekrana karışmaya başlar

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final reach = size.longestSide * 0.62;
    final grow = _seg(p, bang, 0.72);
    final blend = t.light ? BlendMode.srcOver : BlendMode.plus;

    // Zemin: boşluğun siyahından temanın uzay rengine
    final bgT = Curves.easeOut.transform(_seg(p, bang, 0.7));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(SpaceIntro.void0, t.bg2, bgT)!, Color.lerp(SpaceIntro.void0, t.bg, bgT)!],
        ).createShader(Rect.fromCircle(center: c, radius: reach)),
    );

    // Bulutsular merkezden açılır
    final neb = Curves.easeOutCubic.transform(_seg(p, bang + 0.02, 0.78));
    if (neb > 0) {
      void cloud(Offset dir, double r, Color col) {
        final at = c + dir * reach * neb;
        final rad = reach * r * (0.2 + 0.8 * neb);
        canvas.drawCircle(
          at,
          rad,
          Paint()
            ..blendMode = blend
            ..shader = RadialGradient(
              colors: [col.withValues(alpha: col.a * neb), col.withValues(alpha: 0)],
            ).createShader(Rect.fromCircle(center: at, radius: rad)),
        );
      }

      cloud(const Offset(-0.32, -0.38), 0.85, t.nebula1);
      cloud(const Offset(0.36, 0.3), 0.75, t.nebula2);
      cloud(const Offset(0.1, -0.05), 0.5, t.nebula1);
    }

    // Yıldızlar: çıkışta hız izi bırakır, yavaşladıkça noktaya döner
    if (p >= bang) {
      final starPaint = Paint()
        ..blendMode = blend
        ..strokeCap = StrokeCap.round;
      for (final s in stars) {
        final local = _seg(grow, s.delay, 1);
        if (local <= 0) continue;
        final e = Curves.easeOutExpo.transform(local);
        final ePrev = Curves.easeOutExpo.transform((local - 0.05).clamp(0.0, 1.0));
        final dir = Offset(cos(s.angle), sin(s.angle));
        final head = c + dir * reach * s.dist * e;
        final tail = c + dir * reach * s.dist * ePrev;
        final glow = 0.55 + 0.45 * sin(s.twinkle + p * 18);
        final col = s.tinted ? t.accent : t.star;
        starPaint
          ..color = col.withValues(alpha: (0.35 + 0.65 * glow) * min(1, local * 6))
          ..strokeWidth = s.size;
        canvas.drawLine(tail, head, starPaint);
      }
    }

    // Patlama ışığı ve şok halkası
    final flash = _seg(p, bang, bang + 0.22);
    if (flash > 0 && flash < 1) {
      final ease = Curves.easeOutCubic.transform(flash);
      final r = reach * 1.2 * ease;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = blend
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9 * (1 - flash)),
              t.accent.withValues(alpha: 0.35 * (1 - flash)),
              t.accent.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(Rect.fromCircle(center: c, radius: max(1, r))),
      );
      canvas.drawCircle(
        c,
        reach * 0.9 * ease,
        Paint()
          ..blendMode = blend
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 6 * (1 - flash)
          ..color = t.accent.withValues(alpha: 0.8 * (1 - flash))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Başlangıçtaki nokta (yerel açılış ekranındakinin devamı): iki kez atar, patlamadan hemen önce sıkışır
    if (p < bang + 0.04) {
      const appear = 1.0;
      final pulse = 1 + 0.35 * sin(_seg(p, 0.04, bang - 0.04) * pi * 4).abs();
      final squeeze = 1 - 0.5 * Curves.easeIn.transform(_seg(p, bang - 0.04, bang));
      final burst = 1 + 3 * _seg(p, bang, bang + 0.04);
      final fadeOut = 1 - _seg(p, bang, bang + 0.04);
      final r = 3.0 * appear * pulse * squeeze * burst;
      canvas.drawCircle(
        c,
        r * 7,
        Paint()
          ..blendMode = blend
          ..color = t.accent.withValues(alpha: 0.45 * appear * fadeOut)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 3 + 1),
      );
      canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: appear * fadeOut));
    }
  }

  @override
  bool shouldRepaint(_IntroPainter old) => old.p != p || old.t != t;
}
