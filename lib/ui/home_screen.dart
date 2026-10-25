import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/moderation.dart';
import '../core/prefs.dart';
import '../core/themes.dart';
import '../game/engine.dart';
import '../game/entities.dart';
import '../services/scores.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final Prefs prefs;
  final ScoreService scores;
  const HomeScreen({super.key, required this.prefs, required this.scores});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _name = TextEditingController(text: widget.prefs.nickname);
  String? _error;

  S get s => S.current;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = s.enterNick);
    if (Moderation.isOffensive(name)) return setState(() => _error = s.badNick);
    widget.prefs.nickname = name;
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => GameScreen(prefs: widget.prefs, scores: widget.scores),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 1.08, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _settings() {
    widget.prefs.nickname = _name.text;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(prefs: widget.prefs, scores: widget.scores),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: th.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: DemoBackground()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [th.bg.withValues(alpha: 0.35), th.bg.withValues(alpha: 0.82)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        const NeonTitle('SİBER'),
                        const SizedBox(height: 12),
                        Text(
                          s.tagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: th.textMuted, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 28),
                        Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                s.nickname,
                                style: TextStyle(color: th.textMuted, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _name,
                                maxLength: 16,
                                textCapitalization: TextCapitalization.words,
                                autocorrect: false,
                                onChanged: (_) => setState(() => _error = null),
                                onSubmitted: (_) => _play(),
                                style: TextStyle(color: th.text, fontSize: 18, fontWeight: FontWeight.w800),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: s.nicknameHint,
                                  hintStyle: TextStyle(color: th.textMuted.withValues(alpha: 0.5)),
                                  prefixIcon: Icon(Icons.person_rounded, color: th.accent),
                                  filled: true,
                                  fillColor: th.accent.withValues(alpha: 0.06),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: th.panelBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: th.accent, width: 2),
                                  ),
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: th.danger, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              NeonButton(s.play, icon: Icons.play_arrow_rounded, big: true, onTap: _play),
                              const SizedBox(height: 12),
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
                                      s.settings,
                                      icon: Icons.tune_rounded,
                                      kind: NeonKind.outline,
                                      onTap: _settings,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.prefs.best > 0) ...[
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.emoji_events_rounded, color: th.accent2, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${s.best}: ',
                                      style: TextStyle(color: th.textMuted, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${widget.prefs.best}',
                                      style: TextStyle(
                                        fontFamily: 'Orbitron',
                                        color: th.text,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _HowTo(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final powers = [
      (PowerKind.twin, s.twin, s.twinDesc),
      (PowerKind.spread, s.spread, s.spreadDesc),
      (PowerKind.rapid, s.rapid, s.rapidDesc),
      (PowerKind.missile, s.missile, s.missileDesc),
      (PowerKind.shield, s.shield, s.shieldDesc),
      (PowerKind.bomb, s.bomb, s.bombDesc),
      (PowerKind.life, s.life.replaceAll('+1 ', ''), s.lifeDesc),
    ];
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _hint(Icons.open_with_rounded, s.hintMove)),
              const SizedBox(width: 8),
              Expanded(child: _hint(Icons.my_location_rounded, s.hintAim)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.hintKeyboard,
            style: TextStyle(color: th.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Text(
            s.powerups,
            style: TextStyle(color: th.text, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          for (final (k, name, desc) in powers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  PowerBadge(k, powerColorOf(k), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$name  ',
                            style: TextStyle(color: powerColorOf(k), fontWeight: FontWeight.w900),
                          ),
                          TextSpan(
                            text: desc,
                            style: TextStyle(color: th.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hint(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: th.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(icon, size: 16, color: th.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: th.accent, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  final Prefs prefs;
  final ScoreService scores;
  const _SettingsSheet({required this.prefs, required this.scores});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  Prefs get p => widget.prefs;
  bool _deleting = false;

  void _privacy() {
    final s = S.current;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: th.light ? Colors.white : th.bg2,
        title: Text(
          s.privacy,
          style: TextStyle(color: th.text, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: SelectableText(s.privacyText, style: TextStyle(color: th.text, height: 1.4)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s.close))],
      ),
    );
  }

  Future<void> _deleteData() async {
    final s = S.current;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: th.light ? Colors.white : th.bg2,
        title: Text(
          s.deleteData,
          style: TextStyle(color: th.text, fontWeight: FontWeight.w900),
        ),
        content: Text('${s.deleteDataInfo}\n\n${s.deleteConfirm}', style: TextStyle(color: th.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              s.delete,
              style: TextStyle(color: th.danger, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final done = await widget.scores.deleteMine();
    p.best = 0;
    if (mounted) setState(() => _deleting = false);
    messenger.showSnackBar(SnackBar(content: Text(done ? s.deleted : s.deleteFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Panel(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: th.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.settings,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: th.text),
                      ),
                    ),
                    IconButton(
                      tooltip: s.close,
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: th.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label(s.theme),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.08,
                  children: [
                    for (final t in GameTheme.all)
                      ThemeSwatch(
                        theme: t,
                        selected: t.id == p.theme.id,
                        onTap: () {
                          Navigator.pop(context);
                          p.theme = t;
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _label(s.language),
                Row(
                  children: [
                    for (final code in S.all) ...[
                      Expanded(
                        child: NeonButton(
                          S.byCode(code).langName,
                          kind: p.lang.code == code ? NeonKind.primary : NeonKind.outline,
                          onTap: p.lang.code == code
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  p.lang = S.byCode(code);
                                },
                        ),
                      ),
                      if (code != S.all.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _toggle(Icons.volume_up_rounded, s.sound, p.sound, (v) => setState(() => p.sound = v)),
                _toggle(Icons.vibration_rounded, s.vibration, p.vibration, (v) => setState(() => p.vibration = v)),
                const SizedBox(height: 14),
                NeonButton(s.privacy, icon: Icons.privacy_tip_rounded, kind: NeonKind.ghost, onTap: _privacy),
                const SizedBox(height: 8),
                NeonButton(
                  _deleting ? '…' : s.deleteData,
                  icon: Icons.delete_outline_rounded,
                  kind: NeonKind.ghost,
                  onTap: _deleting ? null : _deleteData,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(color: th.textMuted, fontWeight: FontWeight.w800, letterSpacing: 1),
    ),
  );

  Widget _toggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, color: th.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: th.text, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        Switch(value: value, activeThumbColor: th.accent, onChanged: onChanged),
      ],
    ),
  );
}
