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

  Future<void> _edit(Map<String, dynamic> supplier) async {
    final user = (supplier['user'] as Map?) ?? {};
    final nameCtrl = TextEditingController(text: user['name']?.toString() ?? '');
    final businessCtrl = TextEditingController(text: supplier['businessName']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: user['phone']?.toString() ?? '');
    final pinCtrl = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit supplier'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: businessCtrl,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Account holder name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'New PIN (leave blank to keep)'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AdminColors.danger, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final body = <String, dynamic>{};
                  if (businessCtrl.text.trim().isNotEmpty) body['businessName'] = businessCtrl.text.trim();
                  if (nameCtrl.text.trim().isNotEmpty) body['name'] = nameCtrl.text.trim();
                  if (phoneCtrl.text.trim().isNotEmpty) body['phone'] = phoneCtrl.text.trim();
                  if (pinCtrl.text.trim().isNotEmpty) body['pin'] = pinCtrl.text.trim();
                  final api = ProviderScope.containerOf(dialogContext).read(apiProvider);
                  await api.patch('/admin/suppliers/${supplier['id']}', body: body);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                } catch (e) {
                  setDialogState(() => error = e.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    businessCtrl.dispose();
    phoneCtrl.dispose();
    pinCtrl.dispose();
    if (result == true) {
      await _refresh();
      if (mounted) showAppSnack(context, 'Supplier updated.');
    }
  }

  Future<void> _delete(Map<String, dynamic> supplier) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${supplier['businessName']}?',
      message: 'This permanently removes the supplier account and their catalog.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final api = ProviderScope.containerOf(context).read(apiProvider);
      await api.delete('/admin/suppliers/${supplier['id']}');
      await _refresh();
      if (mounted) showAppSnack(context, 'Supplier deleted.');
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString(), error: true);
    }
  }
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit',
                                      onPressed: () => _edit(suppliers[i]),
                                      icon: const Icon(Icons.edit_outlined, size: 19),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      onPressed: () => _delete(suppliers[i]),
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AdminColors.danger),
                                    ),
                                  ],
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
