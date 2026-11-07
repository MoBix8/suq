import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../providers.dart';
import './common.dart';

/// Two small buttons used by the catalog tabs to back up or restore a
/// resource as JSON. Export shows the payload in a dialog (and copies it to
/// the clipboard); import accepts a pasted payload and posts it to the server.
class ExportImportButtons extends StatelessWidget {
  const ExportImportButtons({
    super.key,
    required this.exportPath,
    required this.importPath,
    required this.onImported,
    this.exportLabel = 'Export',
    this.importLabel = 'Import',
  });

  final String exportPath;
  final String importPath;
  final VoidCallback onImported;
  final String exportLabel;
  final String importLabel;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (compact) ...[
          IconButton(
            tooltip: exportLabel,
            onPressed: () => _export(context),
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: importLabel,
            onPressed: () => _import(context),
            icon: const Icon(Icons.upload_rounded),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: () => _export(context),
            icon: const Icon(Icons.download_rounded, size: 17),
            label: Text(exportLabel),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _import(context),
            icon: const Icon(Icons.upload_rounded, size: 17),
            label: Text(importLabel),
          ),
        ],
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final api = ProviderScope.containerOf(context).read(apiProvider);
      final response = await api.get(exportPath);
      final text = const JsonEncoder.withIndent('  ').convert(response);
      if (!context.mounted) return;
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exported JSON'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (context.mounted) {
        showAppSnack(context, 'Copied to clipboard.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }

  Future<void> _import(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import JSON'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: 'Paste the exported JSON here…',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;

    try {
      Map<String, dynamic> payload;
      try {
        payload = Map<String, dynamic>.from(jsonDecode(result) as Map);
      } catch (_) {
        throw ApiException('The pasted text is not valid JSON.');
      }
      final api = ProviderScope.containerOf(context).read(apiProvider);
      final response = await api.post(importPath, body: payload);
      if (!context.mounted) return;
      onImported();
      showAppSnack(context, 'Imported: ${response.toString()}');
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) showAppSnack(context, error.toString(), error: true);
    }
  }
}
