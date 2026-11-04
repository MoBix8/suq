import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/activation/activation_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/home_shell.dart';
import 'providers.dart';
import 'widgets/common.dart';

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
        data: (state) => state.active
            ? const HomeShell()
            : ActivationScreen(state: state),
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 78),
            const SizedBox(height: 22),
            const Text(
              'SUQ',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Checking your subscription…',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
