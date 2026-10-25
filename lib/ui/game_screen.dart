import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/i18n.dart';
import '../core/prefs.dart';
import '../core/sound.dart';
import '../game/controls.dart';
import '../game/engine.dart';
import '../game/entities.dart';
import '../game/painter.dart';
import '../services/scores.dart';
import 'leaderboard_screen.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final Prefs prefs;
  final ScoreService scores;
  const GameScreen({super.key, required this.prefs, required this.scores});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _step = 1 / 60;

  World? _world;
  final _input = GameInput();
  final _move = Stick(), _aim = Stick();
  final _repaint = _Repaint();
  late final Ticker _ticker;
  Duration? _last;
  double _acc = 0, _overTimer = 0, _lastAim = -pi / 2;
  bool _paused = false, _finished = false, _newRecord = false;
  int? _rank;
  late final DateTime _started = DateTime.now();

  // Klavye ve fare (web ve masaüstü)
  final _focus = FocusNode();
  final _keys = <LogicalKeyboardKey>{};
  bool _mouseFiring = false;
  Offset? _mouse;

  S get s => S.current;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_frame)..start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_finished && _world != null && !_world!.over) {
      _pause();
    }
  }

  // ─── Döngü ────────────────────────────────────────────────────────────────

  void _frame(Duration now) {
    final dt = _last == null ? 0.0 : min(0.25, (now - _last!).inMicroseconds / 1e6);
    _last = now;
    final w = _world;
    if (w == null || _paused) return;
    _acc += dt;
    var steps = 0;
    while (_acc >= _step && steps < 5) {
      _applyInput(w);
      w.step(_step, _input);
      _handleEvents(w);
      _acc -= _step;
      steps++;
    }
    if (steps == 5) _acc = 0;
    if (w.over && !_finished) {
      _overTimer += dt;
      if (_overTimer > 1.5) _finish(w);
    }
    _repaint.tick();
  }

  void _applyInput(World w) {
    if (_move.active) {
      _input.move = shapeMove(_move.vector);
    } else {
      var kx = 0.0, ky = 0.0;
      if (_keys.contains(LogicalKeyboardKey.keyA) || _keys.contains(LogicalKeyboardKey.arrowLeft)) {
        kx -= 1;
      }
      if (_keys.contains(LogicalKeyboardKey.keyD) || _keys.contains(LogicalKeyboardKey.arrowRight)) {
        kx += 1;
      }
      if (_keys.contains(LogicalKeyboardKey.keyW) || _keys.contains(LogicalKeyboardKey.arrowUp)) {
        ky -= 1;
      }
      if (_keys.contains(LogicalKeyboardKey.keyS) || _keys.contains(LogicalKeyboardKey.arrowDown)) {
        ky += 1;
      }
      _input.move = Offset(kx, ky);
    }
    if (_aim.active) {
      final v = _aim.vector;
      // Parmak yeni değdiyse son nişan korunur, dokunmak hemen ateş ettirir
      if (v.distance > 0.2) _lastAim = v.direction;
      _input
        ..firing = true
        ..aim = _lastAim;
    } else if (_mouseFiring && _mouse != null) {
      _lastAim = atan2(_mouse!.dy - w.ship.y, _mouse!.dx - w.ship.x);
      _input
        ..firing = true
        ..aim = _lastAim;
    } else {
      _input
        ..firing = false
        ..aim = null;
    }
  }

  void _handleEvents(World w) {
    for (final e in w.events) {
      switch (e) {
        case GameEvent.shoot:
          Sfx.play('ates', volume: 0.32, gapMs: 70);
        case GameEvent.missile:
          Sfx.play('fuze', volume: 0.45, gapMs: 200);
        case GameEvent.hit:
          Sfx.play('isabet', volume: 0.4, gapMs: 60);
        case GameEvent.explode:
          Sfx.play('patlama', volume: 0.6, gapMs: 45);
          Sfx.light();
        case GameEvent.bigExplode:
          Sfx.play('buyuk_patlama', volume: 0.75, gapMs: 80);
          Sfx.medium();
        case GameEvent.power:
          Sfx.play('guc', volume: 0.8);
          Sfx.light();
        case GameEvent.shield:
          Sfx.play('kalkan', volume: 0.7);
          Sfx.medium();
        case GameEvent.playerHit:
          Sfx.play('vuruldu');
          Sfx.heavy();
        case GameEvent.bomb:
          Sfx.play('bomba');
          Sfx.heavy();
        case GameEvent.wave || GameEvent.waveCleared:
          Sfx.play('dalga', volume: 0.6);
        case GameEvent.boss:
          Sfx.play('alarm', volume: 0.7);
          Sfx.heavy();
        case GameEvent.bossDown:
          Sfx.play('buyuk_patlama');
          Sfx.heavy();
        case GameEvent.combo:
          Sfx.play('kombo', volume: 0.6);
        case GameEvent.gameOver:
          Sfx.play('buyuk_patlama');
          Sfx.heavy();
      }
    }
    w.events.clear();
  }

  Future<void> _finish(World w) async {
    _finished = true;
    Sfx.play('bitti', volume: 0.8);
    final best = widget.prefs.best;
    _newRecord = w.score > best;
    if (_newRecord) widget.prefs.best = w.score;
    setState(() {});
    if (w.score <= 0) return;
    final rank = await widget.scores.submit(
      ScoreEntry(name: widget.prefs.nickname, score: w.score, wave: w.wave, kills: w.kills, date: _started),
    );
    if (mounted) setState(() => _rank = rank);
  }

  void _pause() {
    if (_paused) return;
    _move.release();
    _aim.release();
    _mouseFiring = false;
    setState(() => _paused = true);
  }

  void _resume() {
    _last = null;
    _acc = 0;
    setState(() => _paused = false);
    _focus.requestFocus();
  }

  void _restart() {
    final w = _world!;
    setState(() {
      _world = World(w.w, w.h);
      _finished = false;
      _paused = false;
      _newRecord = false;
      _rank = null;
      _overTimer = 0;
      _move.release();
      _aim.release();
    });
    _focus.requestFocus();
  }

  // ─── Dokunma, fare, klavye ────────────────────────────────────────────────

  void _down(PointerDownEvent e, Size area) {
    if (_paused || _world?.over != false) return;
    if (e.kind == PointerDeviceKind.mouse) {
      _mouse = e.localPosition;
      _mouseFiring = true;
      return;
    }
    final stick = e.localPosition.dx < area.width / 2 ? _move : _aim;
    if (!stick.active) stick.press(e.pointer, e.localPosition, area);
  }

  void _drag(PointerMoveEvent e) {
    if (e.kind == PointerDeviceKind.mouse) {
      _mouse = e.localPosition;
      return;
    }
    for (final s in [_move, _aim]) {
      if (s.pointer == e.pointer) s.drag(e.localPosition);
    }
  }

  void _up(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse) _mouseFiring = false;
    for (final s in [_move, _aim]) {
      if (s.pointer == e.pointer) s.release();
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    if (e is KeyDownEvent) {
      if (k == LogicalKeyboardKey.space) {
        _input.bomb = true;
      } else if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyP) {
        _paused ? _resume() : _pause();
      }
      _keys.add(k);
    } else if (e is KeyUpEvent) {
      _keys.remove(k);
    }
    return KeyEventResult.handled;
  }

  // ─── Görünüm ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: th.bg,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final w = _world ??= World(size.width, size.height);
            w.resize(size.width, size.height);
            return Stack(
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _down(e, size),
                  onPointerMove: _drag,
                  onPointerHover: (e) => _mouse = e.localPosition,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: GamePainter(w, repaint: _repaint, move: _move, aim: _aim),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                SafeArea(
                  child: AnimatedBuilder(
                    animation: _repaint,
                    builder: (context, _) => _Hud(world: w, onPause: _pause, onBomb: () => _input.bomb = true),
                  ),
                ),
                if (_paused) _pauseOverlay(),
                if (_finished) _overOverlay(w),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dim(Widget child) => Positioned.fill(
    child: ColoredBox(
      color: (th.light ? Colors.white : Colors.black).withValues(alpha: 0.6),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    ),
  );

  Widget _pauseOverlay() => _dim(
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.paused,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4, color: th.accent),
            ),
            const SizedBox(height: 24),
            NeonButton(s.resume, icon: Icons.play_arrow_rounded, big: true, onTap: _resume),
            const SizedBox(height: 12),
            NeonButton(
              s.mainMenu,
              icon: Icons.home_rounded,
              kind: NeonKind.outline,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _overOverlay(World w) => _dim(
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(
          scale: 0.85 + 0.15 * v,
          child: Opacity(opacity: v.clamp(0, 1), child: child),
        ),
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _newRecord ? s.newRecord : s.gameOver,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: _newRecord ? th.accent2 : th.accent,
                  shadows: [
                    Shadow(color: (_newRecord ? th.accent2 : th.accent).withValues(alpha: 0.6), blurRadius: 20),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: w.score.toDouble()),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  '${v.round()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Orbitron', fontSize: 46, fontWeight: FontWeight.w900, color: th.text),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [_stat(s.waveReached, '${w.wave}'), const SizedBox(width: 10), _stat(s.kills, '${w.kills}')],
              ),
              const SizedBox(height: 12),
              Text(
                _rank != null ? s.yourRank(_rank!) : (w.score > 0 ? s.saving : s.bestN(widget.prefs.best)),
                textAlign: TextAlign.center,
                style: TextStyle(color: th.textMuted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              NeonButton(s.playAgain, icon: Icons.replay_rounded, big: true, onTap: _restart),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      s.leaderboard,
                      icon: Icons.leaderboard_rounded,
                      kind: NeonKind.outline,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LeaderboardScreen(prefs: widget.prefs, scores: widget.scores),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeonButton(
                      s.mainMenu,
                      icon: Icons.home_rounded,
                      kind: NeonKind.ghost,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _stat(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: th.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 22, fontWeight: FontWeight.w900, color: th.text),
          ),
          Text(
            label,
            style: TextStyle(color: th.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _Repaint extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Oyun üstü göstergeler: skor, kombo, dalga, canlar, güç süreleri, ana gemi çubuğu, duyurular, bomba
class _Hud extends StatelessWidget {
  final World world;
  final VoidCallback onPause, onBomb;
  const _Hud({required this.world, required this.onPause, required this.onBomb});

  @override
  Widget build(BuildContext context) {
    final w = world;
    final s = S.current;
    final boss = w.boss;
    return Stack(
      children: [
        Positioned(
          left: 14,
          top: 8,
          right: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.score,
                        style: TextStyle(
                          color: th.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${w.score}',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: th.text,
                              shadows: [Shadow(color: th.accent.withValues(alpha: 0.6), blurRadius: 10)],
                            ),
                          ),
                          if (w.multiplier > 1) ...[
                            const SizedBox(width: 8),
                            _ComboChip(multiplier: w.multiplier, timer: w.comboTimer / 2),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final k in timedPowers)
                            if (w.has(k)) _PowerTimer(kind: k, left: w.timers[k]!),
                          if (w.ship.shielded)
                            _PowerTimer(kind: PowerKind.shield, left: w.ship.shieldTime, count: w.ship.shieldHits),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    s.waveN(max(1, w.wave)),
                    style: TextStyle(color: th.accent, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IgnorePointer(
                          child: Row(
                            children: [
                              for (var i = 0; i < max(3, w.ship.lives); i++)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    size: 22,
                                    color: i < w.ship.lives ? th.danger : th.textMuted.withValues(alpha: 0.25),
                                    shadows: i < w.ship.lives ? [Shadow(color: th.danger, blurRadius: 8)] : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onPause,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: th.panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: th.panelBorder),
                            ),
                            child: Icon(Icons.pause_rounded, color: th.text),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (boss != null && boss.state > 0)
          Positioned(
            top: 62,
            left: 60,
            right: 60,
            child: IgnorePointer(child: _BossBar(boss: boss)),
          ),
        if (w.bannerTime > 0 && w.banner != null)
          Positioned.fill(
            child: IgnorePointer(child: _Banner(world: w)),
          ),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: _BombButton(count: w.bombs, onTap: w.over ? null : onBomb),
          ),
        ),
      ],
    );
  }
}

class _ComboChip extends StatelessWidget {
  final int multiplier;
  final double timer;
  const _ComboChip({required this.multiplier, required this.timer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 3),
      decoration: BoxDecoration(
        color: th.accent2.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: th.accent2, width: 1.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'x$multiplier',
            style: TextStyle(color: th.accent2, fontWeight: FontWeight.w900, fontSize: 15, height: 1.1),
          ),
          SizedBox(
            width: 26,
            height: 3,
            child: LinearProgressIndicator(
              value: timer.clamp(0, 1),
              backgroundColor: th.accent2.withValues(alpha: 0.2),
              color: th.accent2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerTimer extends StatelessWidget {
  final PowerKind kind;
  final double left;
  final int? count;
  const _PowerTimer({required this.kind, required this.left, this.count});

  @override
  Widget build(BuildContext context) {
    final c = powerColorOf(kind);
    final max = kind == PowerKind.shield ? 20.0 : 25.0;
    final blink = left < 3 && (left * 6).floor().isOdd;
    return Opacity(
      opacity: blink ? 0.4 : 1,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: (left / max).clamp(0, 1),
              strokeWidth: 2.6,
              color: c,
              backgroundColor: c.withValues(alpha: 0.18),
            ),
            Icon(powerIcon(kind), size: 17, color: c),
            if (count != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  '$count',
                  style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BossBar extends StatelessWidget {
  final Enemy boss;
  const _BossBar({required this.boss});

  @override
  Widget build(BuildContext context) {
    final p = (boss.hp / boss.maxHp).clamp(0.0, 1.0);
    final c = th.enemies[6];
    return Column(
      children: [
        Text(
          S.current.code == 'en' ? 'MOTHERSHIP' : 'ANA GEMİ',
          style: TextStyle(color: c, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withValues(alpha: 0.6)),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: p,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c, th.danger]),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final World world;
  const _Banner({required this.world});

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final w = world;
    final (text, color) = switch (w.banner!) {
      BannerKind.wave => (s.waveN(w.wave), th.accent),
      BannerKind.cleared => (s.waveCleared, th.good),
      BannerKind.boss => (s.bossIncoming, th.danger),
      BannerKind.bossDown => (s.bossDown, th.accent2),
    };
    // 2.2 sn: hızlı büyüyerek gelir, bekler, solarak gider
    final age = 2.2 - w.bannerTime;
    final inK = (age / 0.25).clamp(0.0, 1.0);
    final outK = (w.bannerTime / 0.4).clamp(0.0, 1.0);
    final scale = 1.6 - 0.6 * Curves.easeOutBack.transform(inK);
    final warn = w.banner == BannerKind.boss && (age * 6).floor().isOdd;
    return Align(
      alignment: const Alignment(0, -0.25),
      child: Opacity(
        opacity: min(inK, outK) * (warn ? 0.55 : 1),
        child: Transform.scale(
          scale: scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 4,
                color: th.light ? color : Colors.white,
                shadows: [
                  Shadow(color: color, blurRadius: 24),
                  Shadow(color: color.withValues(alpha: 0.7), blurRadius: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BombButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const _BombButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = powerColorOf(PowerKind.bomb);
    final enabled = count > 0 && onTap != null;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.16),
            border: Border.all(color: c, width: 2),
            boxShadow: enabled ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 18)] : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(powerIcon(PowerKind.bomb), color: c, size: 30),
              Positioned(
                right: 8,
                bottom: 6,
                child: Text(
                  '$count',
                  style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
