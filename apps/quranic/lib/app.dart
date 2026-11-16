import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/islamic/islamic_tools_screen.dart';
import 'features/islamic/player/quran_mini_player.dart';

class QuranicApp extends StatelessWidget {
  const QuranicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quranic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: quranRootNavigatorKey,
      builder: (context, child) {
        final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
        return Stack(
          children: [
            Positioned.fill(child: child ?? const SizedBox.shrink()),
            Positioned(
              right: 16,
              bottom: 24 + safeBottom,
              child: const QuranMiniPlayer(),
            ),
          ],
        );
      },
      home: const SplashGate(child: IslamicToolsScreen()),
    );
  }
}

/// Keeps the gold launch artwork on screen while the first frame settles, then
/// fades into the app. `main()` already waits for preferences, so the splash is
/// purely a brand moment rather than a loading gate.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready ? widget.child : const QuranicSplash(),
    );
  }
}

class QuranicSplash extends StatelessWidget {
  const QuranicSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141008),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0xFF33280F), Color(0xFF141008)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.94 + value * 0.06,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/quranic_gold.png',
                    width: 230,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'QURANIC',
                    style: TextStyle(
                      color: Color(0xFFF0D585),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The Noble Qur’an · Recitation · Dhikr',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.68),
                      fontSize: 12.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Container(
                    width: 64,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
