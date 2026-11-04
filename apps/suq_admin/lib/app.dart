import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/home_shell.dart';
import 'providers.dart';

class SuqAdminApp extends ConsumerWidget {
  const SuqAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return MaterialApp(
      title: AdminConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light(),
      home: session.isLoggedIn ? const HomeShell() : const LoginScreen(),
    );
  }
}
