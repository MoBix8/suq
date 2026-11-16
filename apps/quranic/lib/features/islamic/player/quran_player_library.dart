import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../quran_meta.dart';
import 'quran_player_audio.dart';
import 'quran_player_downloads.dart';
import 'quran_player_models.dart';
import 'quran_player_screen.dart';

/// Every reciter that mp3quran.net publishes, searchable and filterable by
/// what is already saved on the device.
class QuranPlayerLibraryScreen extends ConsumerStatefulWidget {
  const QuranPlayerLibraryScreen({super.key});

  @override
  ConsumerState<QuranPlayerLibraryScreen> createState() =>
      _QuranPlayerLibraryScreenState();
}

class _QuranPlayerLibraryScreenState
    extends ConsumerState<QuranPlayerLibraryScreen> {
  final _search = TextEditingController();
  late Future<List<QuranPlayerReciter>> _future;
  String _query = '';
  bool _downloadedOnly = false;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(quranPlayerCatalogProvider).load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(quranPlayerDownloadsProvider).warmUp();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = ref.read(quranPlayerCatalogProvider).load(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(quranPlayerProvider);
    final downloads = ref.read(quranPlayerDownloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qur’an player'),
        actions: [
          IconButton(
            tooltip: 'Refresh reciters',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<QuranPlayerReciter>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? const <QuranPlayerReciter>[];
          if (all.isEmpty) {
            return _CatalogError(onRetry: _reload);
          }
          if (!_restored) {
            _restored = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(quranPlayerProvider).restore(all);
            });
          }

          return AnimatedBuilder(
            animation: downloads,
            builder: (context, _) {
              final query = _query.trim().toLowerCase();
              final filtered = <QuranPlayerReciter>[];
              for (final reciter in all) {
                if (_downloadedOnly &&
                    downloads.downloaded(reciter.key).isEmpty) {
                  continue;
                }
                if (query.isNotEmpty && !_matches(reciter, query)) continue;
                filtered.add(reciter);
              }

              return Column(
                children: [
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      if (!controller.hasSession) {
                        return const SizedBox.shrink();
                      }
                      return _ContinueCard(
                        controller: controller,
                        onOpen: () => _openPlayer(context),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search reciters or rewayas',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All reciters'),
                          selected: !_downloadedOnly,
                          onSelected: (_) =>
                              setState(() => _downloadedOnly = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Downloaded'),
                          selected: _downloadedOnly,
                          onSelected: (_) =>
                              setState(() => _downloadedOnly = true),
                        ),
                        const Spacer(),
                        Text(
                          '${filtered.length}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const _EmptyLibrary()
                        : _ReciterGrid(
                            reciters: filtered,
                            downloads: downloads,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _matches(QuranPlayerReciter reciter, String query) {
    return reciter.name.toLowerCase().contains(query) ||
        reciter.style.toLowerCase().contains(query) ||
        reciter.arabicName.contains(query);
  }

  void _openPlayer(BuildContext context) {
    showQuranPlayerSheet(context);
  }
}

class _ReciterGrid extends StatelessWidget {
  const _ReciterGrid({
    required this.reciters,
    required this.downloads,
  });

  final List<QuranPlayerReciter> reciters;
  final QuranPlayerDownloads downloads;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<QuranPlayerReciter>>{};
    for (final reciter in reciters) {
      groups.putIfAbsent(reciter.firstLetter, () => []).add(reciter);
    }

    final slivers = <Widget>[];
    groups.forEach((letter, items) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              letter,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final reciter = items[index];
                return _ReciterCard(
                  reciter: reciter,
                  saved: downloads.downloaded(reciter.key).length,
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      );
    });

    return CustomScrollView(
      slivers: [
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _ReciterCard extends StatelessWidget {
  const _ReciterCard({required this.reciter, required this.saved});

  final QuranPlayerReciter reciter;
  final int saved;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => QuranReciterDetailScreen(reciter: reciter),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            QuranReciterAvatar(reciter: reciter, size: 56),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                reciter.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                reciter.style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                reciter.arabicName.isEmpty
                    ? '${reciter.chapters.length} surah'
                    : '${reciter.chapters.length} surah',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9.5,
                ),
              ),
            ),
            if (saved > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.profit.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$saved saved',
                  style: const TextStyle(
                    color: AppColors.profit,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.controller, required this.onOpen});

  final QuranPlayerController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final reciter = controller.reciter!;
    final chapter = controller.chapterMeta!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: AppColors.seed,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                QuranReciterAvatar(reciter: reciter, size: 44, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONTINUE LISTENING',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${chapter.nameSimple} · ${reciter.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: controller.toggle,
                  icon: Icon(
                    controller.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppColors.accent,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 46,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            const Text(
              'The reciter list could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connect to the internet once so the library can be saved for '
              'offline use.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Nothing saved yet. Download a surah to listen offline.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
    );
  }
}

/// A reciter's biography, their whole collection and per-surah downloads.
class QuranReciterDetailScreen extends ConsumerStatefulWidget {
  const QuranReciterDetailScreen({super.key, required this.reciter});

  final QuranPlayerReciter reciter;

  @override
  ConsumerState<QuranReciterDetailScreen> createState() =>
      _QuranReciterDetailScreenState();
}

class _QuranReciterDetailScreenState
    extends ConsumerState<QuranReciterDetailScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  QuranPlayerReciter get _reciter => widget.reciter;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(quranPlayerProvider);
    final downloads = ref.watch(quranPlayerDownloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _reciter.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, downloads]),
        builder: (context, _) {
          final saved = downloads.downloaded(_reciter.key);
          final job = downloads.job;
          final jobHere = job != null && job.reciterKey == _reciter.key;
          final query = _query.trim().toLowerCase();
          final chapters = <int>[];
          for (final number in _reciter.chapters) {
            if (query.isEmpty) {
              chapters.add(number);
              continue;
            }
            final meta = quranChapterByNumber(number);
            if (meta.nameSimple.toLowerCase().contains(query) ||
                meta.meaning.toLowerCase().contains(query) ||
                meta.nameArabic.contains(query) ||
                '$number' == query) {
              chapters.add(number);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              _Header(
                reciter: _reciter,
                saved: saved.length,
                playing: controller.reciter?.key == _reciter.key,
                isPlaying: controller.isPlaying,
                onPlay: () {
                  final first = saved.isNotEmpty
                      ? saved.reduce((a, b) => a < b ? a : b)
                      : _reciter.chapters.first;
                  controller.open(_reciter, first);
                  showQuranPlayerSheet(context);
                },
              ),
              const SizedBox(height: 14),
              _Biography(reciter: _reciter),
              if (downloads.error != null) ...[
                const SizedBox(height: 14),
                _DownloadError(
                  message: downloads.error!,
                  onDismiss: downloads.clearError,
                ),
              ],
              const SizedBox(height: 14),
              _DownloadCard(
                reciter: _reciter,
                downloads: downloads,
                saved: saved,
                jobHere: jobHere,
                job: job,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Surahs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${chapters.length} of ${_reciter.chapters.length}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Find a surah',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (chapters.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'No surah matches that search.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (final number in chapters)
                _ChapterTile(
                  reciter: _reciter,
                  number: number,
                  downloads: downloads,
                  controller: controller,
                  job: job,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.reciter,
    required this.saved,
    required this.playing,
    required this.isPlaying,
    required this.onPlay,
  });

  final QuranPlayerReciter reciter;
  final int saved;
  final bool playing;
  final bool isPlaying;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          QuranReciterAvatar(reciter: reciter, size: 92, radius: 26),
          const SizedBox(height: 14),
          Text(
            reciter.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (reciter.arabicName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reciter.arabicName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 22,
                color: AppColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(label: reciter.style),
              _Tag(label: '${reciter.chapters.length} surah'),
              if (saved > 0) _Tag(label: '$saved saved', good: true),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPlay,
              icon: Icon(
                playing && isPlaying
                    ? Icons.graphic_eq_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(playing ? 'Continue listening' : 'Start listening'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.good = false});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (good ? AppColors.profit : AppColors.seed).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: good ? AppColors.profit : AppColors.seed,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Biography extends StatelessWidget {
  const _Biography({required this.reciter});

  final QuranPlayerReciter reciter;

  @override
  Widget build(BuildContext context) {
    final surahs = reciter.chapters.length;
    final provided = reciter.bio?.trim() ?? '';
    final text = StringBuffer();
    if (provided.isNotEmpty) {
      text.write(provided);
      text.write('\n\n');
    } else {
      text
        ..write('${reciter.name} is a Qur’an reciter whose ')
        ..write(reciter.style)
        ..write(' recitation is published on mp3quran.net. ');
      if (surahs == 114) {
        text.write('This collection holds the complete Qur’an, all 114 '
            'surahs, and can be streamed or saved for offline listening.');
      } else {
        text.write('This collection holds $surahs of the 114 surahs. The '
            'remaining surahs are not part of this recording.');
      }
      text.write('\n\n');
    }
    text.write('Downloaded surahs stay on this device and play without a '
        'connection.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 17),
              SizedBox(width: 6),
              Text(
                'About the reciter',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text.toString(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadError extends StatelessWidget {
  const _DownloadError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.reciter,
    required this.downloads,
    required this.saved,
    required this.jobHere,
    required this.job,
  });

  final QuranPlayerReciter reciter;
  final QuranPlayerDownloads downloads;
  final Set<int> saved;
  final bool jobHere;
  final QuranPlayerDownloadJob? job;

  @override
  Widget build(BuildContext context) {
    final total = reciter.chapters.length;
    final done = saved.length;
    final allSaved = done >= total;
    final busy = downloads.isDownloading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_for_offline_outlined, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Offline downloads',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '$done / $total',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.profit),
            ),
          ),
          if (jobHere && job != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Downloading surah ${job!.chapter} · '
                    '${(job!.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: downloads.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: allSaved || busy
                        ? null
                        : () {
                            final started = downloads.start(
                              reciterKey: reciter.key,
                              chapters: reciter.chapters,
                              urlFor: reciter.urlFor,
                            );
                            if (!started) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Another download is running. Wait for it '
                                    'to finish or cancel it first.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(allSaved ? 'All surahs saved' : 'Download all'),
                  ),
                ),
                if (done > 0) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _confirmRemove(context),
                    child: const Text('Delete'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete downloads?'),
        content: Text(
          'Surahs saved for ${reciter.name} will be removed from this device. '
          'You can download them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await downloads.removeReciter(reciter.key);
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.reciter,
    required this.number,
    required this.downloads,
    required this.controller,
    required this.job,
  });

  final QuranPlayerReciter reciter;
  final int number;
  final QuranPlayerDownloads downloads;
  final QuranPlayerController controller;
  final QuranPlayerDownloadJob? job;

  @override
  Widget build(BuildContext context) {
    final meta = quranChapterByNumber(number);
    final downloaded = downloads.isDownloaded(reciter.key, number);
    final partial = downloads.hasPartial(reciter.key, number);
    final jobHere = job != null &&
        job!.reciterKey == reciter.key &&
        job!.chapter == number;
    final active = controller.reciter?.key == reciter.key &&
        controller.chapter == number;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            controller.open(reciter, number);
            showQuranPlayerSheet(context);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.seed
                        : AppColors.seed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: active
                      ? const Icon(
                          Icons.graphic_eq_rounded,
                          size: 17,
                          color: Colors.white,
                        )
                      : Text(
                          '$number',
                          style: const TextStyle(
                            color: AppColors.seed,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.nameSimple,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${meta.nameArabic} · ${meta.verseCount} ayah',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (jobHere)
                  IconButton(
                    tooltip: 'Cancel download',
                    onPressed: downloads.cancel,
                    icon: SizedBox(
                      width: 20,
                      height: 20,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: job!.progress,
                            strokeWidth: 2,
                            color: AppColors.seed,
                            backgroundColor: AppColors.border,
                          ),
                          const Icon(Icons.close_rounded, size: 10),
                        ],
                      ),
                    ),
                  )
                else if (downloaded)
                  IconButton(
                    tooltip: 'Delete download',
                    onPressed: _remove,
                    icon: const Icon(
                      Icons.download_done_rounded,
                      color: AppColors.profit,
                      size: 20,
                    ),
                  )
                else
                  IconButton(
                    tooltip: partial ? 'Resume download' : 'Download',
                    onPressed: () {
                      final started = downloads.start(
                        reciterKey: reciter.key,
                        chapters: [number],
                        urlFor: reciter.urlFor,
                      );
                      if (!started) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Another download is running. Cancel it first.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      partial
                          ? Icons.restart_alt_rounded
                          : Icons.download_rounded,
                      color: partial ? AppColors.warning : AppColors.muted,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _remove() async {
    await downloads.removeChapter(reciter.key, number);
  }
}
