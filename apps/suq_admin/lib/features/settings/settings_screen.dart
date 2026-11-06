import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/gemini_key.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _key = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  bool _saving = false;
  bool _hasSavedKey = false;

  List<Map<String, dynamic>> _admins = [];
  bool _adminsLoading = false;
  bool _creatingAdmin = false;

  @override
  void initState() {
    super.initState();
    GeminiKeyStore.read().then((value) {
      if (!mounted) return;
      setState(() {
        _hasSavedKey = value != null && value.isNotEmpty;
        _loading = false;
      });
    });
    _loadAdmins();
  }

  Future<void> _editAdmin(Map<String, dynamic> admin) async {
    final nameCtrl = TextEditingController(text: admin['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: admin['phone'] as String? ?? '');
    final pinCtrl = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit admin account'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  final pin = pinCtrl.text.trim();
                  if (name.isNotEmpty) body['name'] = name;
                  if (phone.isNotEmpty) body['phone'] = phone;
                  if (pin.isNotEmpty) body['pin'] = pin;
                  final api = ProviderScope.containerOf(dialogContext).read(apiProvider);
                  await api.patch('/admin/admins/${admin['id']}', body: body);
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
    phoneCtrl.dispose();
    pinCtrl.dispose();
    if (result == true && mounted) {
      showAppSnack(context, 'Admin updated.');
      _loadAdmins();
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> admin) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${admin['name']}?',
      message: 'This permanently removes the admin account.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final api = ProviderScope.containerOf(context).read(apiProvider);
      await api.delete('/admin/admins/${admin['id']}');
      if (mounted) {
        showAppSnack(context, 'Admin deleted.');
        _loadAdmins();
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _loadAdmins() async {
    setState(() => _adminsLoading = true);
    try {
      final api = ProviderScope.containerOf(context).read(apiProvider);
      final response = await api.get('/admin/admins');
      final list = response['admins'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _admins = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          _adminsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _adminsLoading = false);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _key.text.trim();
    if (value.isEmpty) {
      showAppSnack(context, 'Paste a Gemini API key first.', error: true);
      return;
    }
    setState(() => _saving = true);
    await GeminiKeyStore.write(value);
    if (!mounted) return;
    _key.clear();
    setState(() {
      _saving = false;
      _hasSavedKey = true;
    });
    showAppSnack(context, 'Gemini API key saved.');
  }

  Future<void> _clear() async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove Gemini API key?',
      message: 'Product translation suggestions will stop until you add a key again.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await GeminiKeyStore.clear();
    if (!mounted) return;
    _key.clear();
    setState(() => _hasSavedKey = false);
    showAppSnack(context, 'Gemini API key removed.');
  }

  Future<void> _createAdmin() async {
    setState(() => _creatingAdmin = true);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create admin account'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'PIN (min 4)'),
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
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (name.length < 2) {
                  setDialogState(() => error = 'Enter a name.');
                  return;
                }
                if (phone.isEmpty) {
                  setDialogState(() => error = 'Enter a phone number.');
                  return;
                }
                if (pin.length < 4) {
                  setDialogState(() => error = 'PIN must be at least 4 digits.');
                  return;
                }
                try {
                  final api = ProviderScope.containerOf(dialogContext).read(apiProvider);
                  await api.post('/admin/admins', body: {
                    'name': name,
                    'phone': phone,
                    'pin': pin,
                  });
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                } catch (e) {
                  setDialogState(() => error = e.toString());
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    pinCtrl.dispose();
    if (mounted) setState(() => _creatingAdmin = false);
    if (result == true && mounted) {
      showAppSnack(context, 'Admin account created.');
      _loadAdmins();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Gemini translations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Saved on this device and used when suggesting Amharic and Afan Oromo names.',
                  style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasSavedKey ? 'A Gemini API key is saved on this device.' : 'No Gemini API key saved yet.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _key,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: _hasSavedKey ? 'Replace Gemini API key' : 'Gemini API key',
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show' : 'Hide',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Saving…' : 'Save key'),
                          ),
                          if (_hasSavedKey)
                            OutlinedButton(
                              onPressed: _clear,
                              child: const Text('Remove key'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Admin accounts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Create additional administrator accounts.',
                style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
              ),
              const SizedBox(height: 18),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_adminsLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_admins.isEmpty)
                      const Text('No admin accounts.', style: TextStyle(color: AdminColors.muted))
                    else
                      ..._admins.map((admin) => _AdminRow(
                            admin: admin,
                            onEdit: () => _editAdmin(admin),
                            onDelete: () => _deleteAdmin(admin),
                          )),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _creatingAdmin ? null : _createAdmin,
                      icon: _creatingAdmin
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.person_add_alt_1_rounded, size: 19),
                      label: Text(_creatingAdmin ? 'Creating…' : 'Create admin account'),
                    ),
                  ],
                ),
              ),
            ],
            ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.admin,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> admin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.seed.withValues(alpha: 0.1),
            child: Text(
              (admin['name'] as String? ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AdminColors.seed, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  admin['phone'] as String? ?? '',
                  style: const TextStyle(fontSize: 11.5, color: AdminColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AdminColors.danger),
          ),
        ],
      ),
    );
  }
}
