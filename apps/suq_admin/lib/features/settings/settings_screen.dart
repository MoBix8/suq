import 'package:flutter/material.dart';

import '../../core/gemini_key.dart';
import '../../core/theme.dart';
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
              ],
            ),
    );
  }
}
