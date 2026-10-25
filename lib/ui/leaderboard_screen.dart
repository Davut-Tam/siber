import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/prefs.dart';
import '../services/scores.dart';
import 'widgets.dart';

class LeaderboardScreen extends StatelessWidget {
  final Prefs prefs;
  final ScoreService scores;
  const LeaderboardScreen({super.key, required this.prefs, required this.scores});

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return Scaffold(
      backgroundColor: th.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: DemoBackground()),
          Positioned.fill(child: ColoredBox(color: th.bg.withValues(alpha: 0.75))),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: s.back,
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_rounded, color: th.text),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.leaderboard_rounded, color: th.accent),
                          const SizedBox(width: 10),
                          Text(
                            s.leaderboard,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: th.text),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _Board(prefs: prefs, scores: scores),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sıralamayı bir kez yükler; dünya sıralamasına ulaşılamazsa cihazdaki skorları ve bir not gösterir
class _Board extends StatefulWidget {
  final Prefs prefs;
  final ScoreService scores;
  const _Board({required this.prefs, required this.scores});

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  late final _future = widget.scores.top();

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return FutureBuilder<List<ScoreEntry>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return Center(child: CircularProgressIndicator(color: th.accent));
        final list = snap.data!;
        final online = widget.scores.online;
        final myId = widget.scores.myId;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Icon(online ? Icons.public_rounded : Icons.cloud_off_rounded, size: 16, color: th.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      online ? s.onlineBoard : s.localBoard,
                      style: TextStyle(color: th.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        s.noScores,
                        style: TextStyle(color: th.textMuted, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final e = list[i];
                        final self = e.id != null ? e.id == myId : e.name == widget.prefs.nickname;
                        return _Row(rank: i + 1, entry: e, self: self);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final ScoreEntry entry;
  final bool self;
  const _Row({required this.rank, required this.entry, required this.self});

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => const Color(0xFFFFC94D),
      2 => const Color(0xFFC9D6E3),
      3 => const Color(0xFFE09A5B),
      _ => null,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (rank.clamp(1, 12) * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 20), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: self ? th.accent.withValues(alpha: 0.14) : th.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: self ? th.accent : th.panelBorder, width: self ? 1.6 : 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: medal != null
                  ? Icon(
                      Icons.emoji_events_rounded,
                      color: medal,
                      size: 26,
                      shadows: [Shadow(color: medal, blurRadius: 10)],
                    )
                  : Text(
                      '$rank',
                      style: TextStyle(color: th.textMuted, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: entry.name),
                        if (self)
                          TextSpan(
                            text: '  ${S.current.you}',
                            style: TextStyle(color: th.accent, fontSize: 12),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: th.text, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    '${S.current.wave} ${entry.wave} · ${S.current.kills} ${entry.kills}',
                    style: TextStyle(color: th.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.score}',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: medal ?? th.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
