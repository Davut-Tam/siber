import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/themes.dart';
import '../game/engine.dart';
import '../game/entities.dart';
import '../game/painter.dart';

GameTheme get th => GameTheme.current;

/// Yarı saydam cam panel
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: th.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: th.panelBorder, width: 1.2),
        boxShadow: [BoxShadow(color: th.accent.withValues(alpha: th.light ? 0.08 : 0.15), blurRadius: 30)],
      ),
      child: child,
    );
  }
}

enum NeonKind { primary, outline, ghost }

/// Basınca hafifçe çöken, neon kenarlı düğme
class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final NeonKind kind;
  final bool big;
  const NeonButton(this.label, {super.key, this.icon, this.onTap, this.kind = NeonKind.primary, this.big = false});

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.kind == NeonKind.primary;
    final fg = primary ? (th.light ? Colors.white : th.bg) : th.text;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: widget.onTap == null ? 0.45 : 1,
          child: Container(
            height: widget.big ? 62 : 50,
            padding: EdgeInsets.symmetric(horizontal: widget.big ? 22 : 12),
            decoration: BoxDecoration(
              gradient: primary ? LinearGradient(colors: [th.accent, Color.lerp(th.accent, th.accent2, 0.55)!]) : null,
              color: primary
                  ? null
                  : (widget.kind == NeonKind.outline ? th.accent.withValues(alpha: 0.08) : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
              border: primary ? null : Border.all(color: th.accent.withValues(alpha: 0.55), width: 1.4),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: th.accent.withValues(alpha: _down ? 0.25 : 0.5),
                        blurRadius: _down ? 10 : 24,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: primary ? fg : th.accent, size: widget.big ? 26 : 19),
                  SizedBox(width: widget.big ? 10 : 7),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: widget.big ? 22 : 15,
                        letterSpacing: widget.big ? 4 : 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Parlayan, ara sıra kayan (glitch) oyun başlığı
class NeonTitle extends StatefulWidget {
  final String text;
  final double size;
  const NeonTitle(this.text, {super.key, this.size = 64});

  @override
  State<NeonTitle> createState() => _NeonTitleState();
}

class _NeonTitleState extends State<NeonTitle> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        // Döngünün kısa bir anında renk katmanları kayar
        final glitch = v > 0.92 && v < 0.96 ? sin(v * 400) * 4 : 0.0;
        TextStyle style(Color c, [List<Shadow>? shadows]) => TextStyle(
          fontSize: widget.size,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: widget.size * 0.14,
          color: c,
          height: 1.25,
          shadows: shadows,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(-glitch, 0),
              child: Text(widget.text, style: style(th.accent2.withValues(alpha: glitch == 0 ? 0 : 0.8))),
            ),
            Transform.translate(
              offset: Offset(glitch, 0),
              child: Text(widget.text, style: style(th.accent.withValues(alpha: glitch == 0 ? 0 : 0.8))),
            ),
            Text(
              widget.text,
              style: style(th.light ? th.text : Colors.white, [
                Shadow(color: th.accent, blurRadius: 18 + 8 * sin(v * 2 * pi)),
                Shadow(color: th.accent.withValues(alpha: 0.6), blurRadius: 40),
              ]),
            ),
          ],
        );
      },
    );
  }
}

/// Ana sayfanın arkasında kendi kendine oynayan oyun
class DemoBackground extends StatefulWidget {
  const DemoBackground({super.key});

  @override
  State<DemoBackground> createState() => _DemoBackgroundState();
}

class _DemoBackgroundState extends State<DemoBackground> with SingleTickerProviderStateMixin {
  World? _world;
  final _input = GameInput();
  final _tick = _Repaint();
  late final Ticker _ticker;
  Duration? _last;
  double _acc = 0, _wanderCd = 0;
  Offset _wander = Offset.zero;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_frame)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  void _frame(Duration now) {
    final dt = _last == null ? 0.0 : min(0.1, (now - _last!).inMicroseconds / 1e6);
    _last = now;
    final w = _world;
    if (w == null) return;
    _acc += dt;
    while (_acc >= 1 / 60) {
      _autoPilot(w);
      w.ship
        ..invuln = 0
        ..lives = 3;
      w.step(1 / 60, _input);
      w.events.clear();
      _acc -= 1 / 60;
    }
    _tick.tick();
  }

  /// En yakın düşmana ateş eder, ekranın ortasında rastgele noktalar arasında süzülür
  void _autoPilot(World w) {
    Enemy? target;
    var best = double.infinity;
    for (final e in w.enemies) {
      final d = (e.x - w.ship.x).abs() + (e.y - w.ship.y).abs();
      if (d < best) {
        best = d;
        target = e;
      }
    }
    _input
      ..firing = target != null
      ..aim = target == null ? null : atan2(target.y - w.ship.y, target.x - w.ship.x);
    _wanderCd -= 1 / 60;
    if (_wanderCd <= 0) {
      _wander = Offset(w.w * (0.25 + _rnd.nextDouble() * 0.5), w.h * (0.35 + _rnd.nextDouble() * 0.4));
      _wanderCd = 2.5;
    }
    var move = _wander - Offset(w.ship.x, w.ship.y);
    move = move.distance < 20 ? Offset.zero : move / move.distance * 0.55;
    // Yaklaşan düşmandan kaç
    if (target != null && best < 140) {
      final away = Offset(w.ship.x - target.x, w.ship.y - target.y);
      move += away / away.distance;
    }
    _input.move = move;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = _world ??= World(c.maxWidth, c.maxHeight)..bombs = 0;
        w.resize(c.maxWidth, c.maxHeight);
        return RepaintBoundary(
          child: CustomPaint(
            painter: GamePainter(w, repaint: _tick, showSticks: false),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _Repaint extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Bir temanın küçük önizlemesi: zemin, vurgu ve mermi renkleri
class ThemeSwatch extends StatelessWidget {
  final GameTheme theme;
  final bool selected;
  final VoidCallback onTap;
  const ThemeSwatch({super.key, required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.bg, t.bg2]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? th.accent : th.panelBorder, width: selected ? 2.5 : 1),
          boxShadow: selected ? [BoxShadow(color: t.accent.withValues(alpha: 0.4), blurRadius: 14)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.navigation_rounded,
                    color: t.shipBody,
                    size: 26,
                    shadows: [Shadow(color: t.accent, blurRadius: 10)],
                  ),
                  const SizedBox(width: 6),
                  for (final c in [t.bulletGlow, t.enemies[0], t.enemies[1]])
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: c, blurRadius: 6)],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.name,
              style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arayüzde güç simgesi rozeti
class PowerBadge extends StatelessWidget {
  final PowerKind kind;
  final Color color;
  final double size;
  const PowerBadge(this.kind, this.color, {super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      child: Icon(powerIcon(kind), color: color, size: size * 0.55),
    );
  }
}
