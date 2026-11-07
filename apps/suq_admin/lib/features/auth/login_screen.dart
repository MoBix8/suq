import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/remembered_phone.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load any remembered phone number without blocking the first frame.
    RememberedPhoneStore.read().then((value) {
      if (value != null && value.isNotEmpty && mounted) {
        _phone.text = value;
      }
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final pin = _pin.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter the administrator phone number.');
      return;
    }

    // Keep the phone number even when the PIN is missing or rejected.
    await RememberedPhoneStore.write(phone);

    if (pin.length < 4) {
      setState(() => _error = 'Enter the administrator PIN.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(sessionProvider.notifier).login(phone: phone, pin: pin);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 760;
                  final brand = _BrandPanel(wide: wide);
                  final form = _LoginForm(
                    phone: _phone,
                    pin: _pin,
                    obscure: _obscure,
                    submitting: _submitting,
                    error: _error,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onSubmit: _submit,
                  );
                  if (!wide) {
                    return Column(
                      children: [brand, const SizedBox(height: 18), form],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: brand),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: form),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(wide ? 38 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14305C), Color(0xFF1E4B8F), Color(0xFF2A6ABF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const AdminLogo(size: 52),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SUQ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    'Admin console',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: wide ? 32 : 18),
          Text(
            'Run the SUQ subscription service.',
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? 27 : 21,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Approve bank transfers, manage shop subscriptions, and curate the product library that every SUQ shop downloads.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: wide ? 13.5 : 12.5,
              height: 1.5,
            ),
          ),
          SizedBox(height: wide ? 28 : 18),
          const _Feature(
            icon: Icons.verified_user_outlined,
            text: 'Manual payment verification',
          ),
          const _Feature(
            icon: Icons.storefront_outlined,
            text: 'Shop subscriptions & renewals',
          ),
          const _Feature(
            icon: Icons.inventory_2_outlined,
            text: 'Shared product library',
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8FC0FF), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.phone,
    required this.pin,
    required this.obscure,
    required this.submitting,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final TextEditingController phone;
  final TextEditingController pin;
  final bool obscure;
  final bool submitting;
  final String? error;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Administrator sign in',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AdminColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use the ADMIN account created by the SUQ server.',
            style: TextStyle(color: AdminColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pin,
            obscureText: obscure,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'PIN',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AdminColors.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 17,
                    color: AdminColors.danger,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AdminColors.danger,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: submitting ? null : () => onSubmit(),
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded, size: 19),
            label: Text(submitting ? 'Signing in…' : 'Sign in'),
          ),
          const SizedBox(height: 16),
          Text(
            'Server: ${AdminConfig.apiBaseUrl}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AdminColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
