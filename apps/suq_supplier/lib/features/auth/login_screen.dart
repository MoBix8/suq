import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _rememberedPhoneKey = 'supplier.phone';

  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final remembered = ref.read(prefsProvider).getString(_rememberedPhoneKey);
    if (remembered != null && remembered.isNotEmpty) {
      _phone.text = remembered;
    }
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

    if (phone.length < 9) {
      setState(() => _error = 'Enter your supplier phone number.');
      return;
    }
    if (pin.length < 4) {
      setState(() => _error = 'Enter your PIN.');
      return;
    }

    await ref.read(prefsProvider).setString(_rememberedPhoneKey, phone);
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
              constraints: const BoxConstraints(maxWidth: 1020),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 780;
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
      padding: EdgeInsets.all(wide ? 40 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SupplierColors.deep, SupplierColors.seed, SupplierColors.bright],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const SupplierLogo(size: 54),
                  const SizedBox(width: 13),
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
                        'Supplier workspace',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: wide ? 36 : 22),
              Text(
                'Stock the shops\nthat stock the city.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: wide ? 30 : 23,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Publish bulk listings, quote deliveries, and fulfil shop orders from one calm workspace.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: wide ? 13.5 : 12.5,
                  height: 1.55,
                ),
              ),
              SizedBox(height: wide ? 30 : 20),
              const _Feature(
                icon: Icons.inventory_2_outlined,
                text: 'Retail catalog library for shops',
              ),
              const _Feature(
                icon: Icons.sell_outlined,
                text: 'Wholesale listings priced by sale unit',
              ),
              const _Feature(
                icon: Icons.receipt_long_outlined,
                text: 'Shop orders and delivery quotes',
              ),
              const _Feature(
                icon: Icons.route_outlined,
                text: 'Distance, weight and volume pricing',
              ),
            ],
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
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFE3D4FF), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
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
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Supplier sign in',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SupplierColors.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Use the supplier account created for you by SUQ.',
            style: TextStyle(color: SupplierColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 13),
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
                tooltip: obscure ? 'Show PIN' : 'Hide PIN',
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
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: SupplierColors.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 17,
                    color: SupplierColors.danger,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: SupplierColors.danger,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
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
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.support_agent_rounded,
                size: 15,
                color: SupplierColors.muted.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'Need an account? Contact the SUQ administrator.',
                  style: TextStyle(color: SupplierColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
