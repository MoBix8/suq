import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  bool _creating = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await ref.read(apiProvider).get('/admin/suppliers');
    return (response['suppliers'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _refresh() async => setState(() => _future = _load());

  Future<void> _create() async {
    final draft = await showDialog<_SupplierDraft>(
      context: context,
      builder: (_) => const _CreateSupplierDialog(),
    );
    if (draft == null) return;
    setState(() => _creating = true);
    try {
      await ref
          .read(apiProvider)
          .post(
            '/admin/suppliers',
            body: {
              'name': draft.name,
              'businessName': draft.businessName,
              'phone': draft.phone,
              'pin': draft.pin,
            },
          );
      await _refresh();
      if (mounted) showAppSnack(context, 'Supplier account created.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted)
        showAppSnack(context, 'Could not create supplier: $error', error: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            children: [
              const SizedBox(height: 100),
              Center(
                child: Text('Could not load suppliers: ${snapshot.error}'),
              ),
              Center(
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ),
            ],
          );
        }
        final suppliers = snapshot.data;
        if (suppliers == null)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Supplier accounts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _creating ? null : _create,
                          icon: _creating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(_creating ? 'Creating…' : 'Create supplier'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Suppliers manage their own catalog and orders. They cannot view shop accounts.',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                    const SizedBox(height: 16),
                    if (suppliers.isEmpty)
                      const SectionCard(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No supplier accounts yet.'),
                        ),
                      )
                    else
                      SectionCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < suppliers.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AdminColors.seed.withValues(
                                    alpha: .1,
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping_outlined,
                                    color: AdminColors.seed,
                                  ),
                                ),
                                title: Text(
                                  '${suppliers[i]['businessName'] ?? 'Supplier'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${suppliers[i]['user']?['name'] ?? ''} · ${suppliers[i]['user']?['phone'] ?? ''}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _SupplierDraft {
  const _SupplierDraft(this.name, this.businessName, this.phone, this.pin);
  final String name;
  final String businessName;
  final String phone;
  final String pin;
}

class _CreateSupplierDialog extends StatefulWidget {
  const _CreateSupplierDialog();

  @override
  State<_CreateSupplierDialog> createState() => _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends State<_CreateSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create supplier account'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _business,
              decoration: const InputDecoration(
                labelText: 'Supplier business name',
              ),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 2 ? 'Enter a business name' : null,
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Account holder name',
              ),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 2 ? 'Enter a name' : null,
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (v) => (v?.trim().length ?? 0) < 9
                  ? 'Enter a valid phone number'
                  : null,
            ),
            TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Temporary PIN'),
              validator: (v) => (v?.length ?? 0) < 4
                  ? 'PIN must have at least 4 digits'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _SupplierDraft(
              _name.text.trim(),
              _business.text.trim(),
              _phone.text.trim(),
              _pin.text,
            ),
          );
        },
        child: const Text('Create account'),
      ),
    ],
  );
}
