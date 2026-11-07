import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/activation/activation_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/home_shell.dart';
import 'providers.dart';

class SuqApp extends ConsumerWidget {
  const SuqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final entitlement = ref.watch(entitlementProvider);

    final Widget home;
    if (!session.isLoggedIn) {
      home = const AuthScreen();
    } else {
      home = entitlement.when(
        data: (state) =>
            state.active ? const HomeShell() : ActivationScreen(state: state),
        loading: () => const SplashScreen(),
        error: (error, stack) => ActivationScreen(error: error.toString()),
      );
    }

    return MaterialApp(
      title: 'SUQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.seed,
      body: SizedBox.expand(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/branding/qaf_logo.png',
                  width: 190,
                  height: 106,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                const Text(
                  'SUQ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking your subscription…',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
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
