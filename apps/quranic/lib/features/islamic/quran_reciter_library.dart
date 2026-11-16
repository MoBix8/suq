import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'quran_audio.dart';
import 'quran_audio_store.dart';
import 'quran_meta.dart';

/// Library of available reciters. Tap a reciter to see their chapters and
/// download/play options.
class QuranReciterLibraryScreen extends ConsumerStatefulWidget {
  const QuranReciterLibraryScreen({super.key});

  @override
  ConsumerState<QuranReciterLibraryScreen> createState() =>
      _QuranReciterLibraryScreenState();
}

class _QuranReciterLibraryScreenState
    extends ConsumerState<QuranReciterLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QuranReciter> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return quranReciters;
    return quranReciters
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            r.label.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final reciters = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Reciters')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search reciters…',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          Expanded(
            child: reciters.isEmpty
                ? const Center(child: Text('No reciters match your search.'))
                : ListView.builder(
                    itemCount: reciters.length,
                    itemBuilder: (context, i) {
                      final r = reciters[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.accent.withValues(alpha: 0.15),
                          child: Text(
                            r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(r.name),
                        subtitle: Text(r.style),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                QuranReciterDetailScreen(reciter: r),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Detail screen for a single reciter.
class QuranReciterDetailScreen extends ConsumerStatefulWidget {
  const QuranReciterDetailScreen({super.key, required this.reciter});

  final QuranReciter reciter;

  @override
  ConsumerState<QuranReciterDetailScreen> createState() =>
      _QuranReciterDetailScreenState();
}

class _QuranReciterDetailScreenState
    extends ConsumerState<QuranReciterDetailScreen> {
  Future<void> _downloadAll() async {
    final store = ref.read(quranAudioStoreProvider);
    store.startDownload(reciter: widget.reciter.id);
    // Wait for completion.
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      return store.isDownloading;
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reciter = widget.reciter;
    final store = ref.watch(quranAudioStoreProvider);
    return FutureBuilder<Set<int>>(
      future: store.downloadedChapters(reciter.id),
      builder: (context, snapshot) {
        final downloaded = snapshot.data ?? <int>{};
        return Scaffold(
          appBar: AppBar(title: Text(reciter.label)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        AppColors.accent.withValues(alpha: 0.15),
                    child: Text(
                      reciter.name.isNotEmpty
                          ? reciter.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reciter.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reciter.style,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Downloaded: ${downloaded.length} / 114 chapters',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Biography',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${reciter.name} is a renowned Quran reciter. '
                'Full biography can be added here.',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: store.isDownloading
                          ? null
                          : () => unawaited(_downloadAll()),
                      icon: store.isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(store.isDownloading
                          ? 'Downloading… ${(store.job?.progress ?? 0) * 100 ~/ 1}%'
                          : 'Download all chapters'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Chapters',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...List.generate(114, (i) {
                final chapter = i + 1;
                final isDownloaded = downloaded.contains(chapter);
                return ListTile(
                  dense: true,
                  title: Text('Surah $chapter'),
                  trailing: isDownloaded
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.green)
                      : const Icon(Icons.download_outlined),
                  onTap: () async {
                    if (isDownloaded) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Playing Surah $chapter')),
                      );
                    } else {
                      store.startDownload(
                          reciter: reciter.id, chapter: chapter);
                      await Future.doWhile(() async {
                        await Future.delayed(
                            const Duration(milliseconds: 300));
                        return store.isDownloading;
                      });
                      if (mounted) setState(() {});
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
