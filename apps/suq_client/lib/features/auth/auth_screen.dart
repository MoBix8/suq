import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _name = TextEditingController();
  final _shopName = TextEditingController();
  final _city = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _obscurePin = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsProvider);
    final remembered = prefs.getString('auth.phone');
    if (remembered != null && remembered.isNotEmpty) {
      _phone.text = remembered;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    _name.dispose();
    _shopName.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(prefsProvider).setString('auth.phone', _phone.text.trim());
      final session = ref.read(sessionProvider.notifier);
      if (_register) {
        await session.register(
          name: _name.text,
          shopName: _shopName.text,
          phone: _phone.text,
          pin: _pin.text,
          city: _city.text,
        );
      } else {
        await session.login(phone: _phone.text, pin: _pin.text);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _phoneValidator(String? value) {
    final phone = value?.trim() ?? '';
    if (!RegExp(r'^0[79]\d{8}$').hasMatch(phone)) {
      return 'Enter a valid Ethiopian number (09… or 07…)';
    }
    return null;
  }

  String? _pinValidator(String? value) {
    final pin = value?.trim() ?? '';
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return 'PIN must be 4 to 6 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.seed.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.1),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 64)),
                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            'SUQ',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'Offline shop management for Ethiopia',
                            style: TextStyle(color: AppColors.muted, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SectionCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Log in'),
                                    icon: Icon(Icons.login_rounded, size: 18),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Create shop'),
                                    icon: Icon(Icons.add_business_rounded, size: 18),
                                  ),
                                ],
                                selected: {_register},
                                onSelectionChanged: _busy
                                    ? null
                                    : (selection) {
                                        setState(() {
                                          _register = selection.first;
                                          _error = null;
                                        });
                                      },
                              ),
                              const SizedBox(height: 22),
                              if (_register) ...[
                                TextFormField(
                                  controller: _name,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Your name',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                  ),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) < 2
                                          ? 'Enter your name'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _shopName,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Shop name',
                                    prefixIcon: Icon(Icons.storefront_outlined),
                                  ),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) < 2
                                          ? 'Enter your shop name'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _city,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'City (optional)',
                                    prefixIcon: Icon(Icons.location_on_outlined),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number',
                                  hintText: '0911223344',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                validator: _phoneValidator,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _pin,
                                keyboardType: TextInputType.number,
                                obscureText: _obscurePin,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'PIN',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscurePin = !_obscurePin,
                                    ),
                                    icon: Icon(
                                      _obscurePin
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: _pinValidator,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.loss.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 18,
                                        color: AppColors.loss,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: AppColors.loss,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_register ? 'Create my shop' : 'Log in'),
                              ),
                            ],
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Demo owner: 0911111111 / 1234\n'
                              'Demo admin: 0900000000 / 1234',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 14,
                              color: AppColors.muted,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Works offline • Your data stays on this device',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
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
