import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/prefs.dart';
import 'core/sound.dart';
import 'core/themes.dart';
import 'services/firebase_scores.dart';
import 'services/scores.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final raw = await SharedPreferences.getInstance();
  final prefs = Prefs(raw);
  final scores = FirebaseScoreService(LocalScoreService(raw));
  await Sfx.init();
  runApp(SiberApp(prefs: prefs, scores: scores));
}

class SiberApp extends StatefulWidget {
  final Prefs prefs;
  final ScoreService scores;
  const SiberApp({super.key, required this.prefs, required this.scores});

  @override
  State<SiberApp> createState() => _SiberAppState();
}

class _SiberAppState extends State<SiberApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.prefs,
      builder: (context, _) {
        final t = widget.prefs.theme;
        SystemChrome.setSystemUIOverlayStyle(t.overlay);
        // Tema ya da dil değişince ağaç yeni anahtarla baştan kurulur; sabit (const) parçalar da yenilenir
        return MaterialApp(
          key: ValueKey('${t.id}-${widget.prefs.lang.code}'),
          title: 'Siber',
          debugShowCheckedModeBanner: false,
          theme: buildMaterialTheme(t),
          home: HomeScreen(prefs: widget.prefs, scores: widget.scores),
        );
      },
    );
  }
}
