import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'player/quran_player_library.dart';
import 'tasbih_screen.dart';
import 'quran_meta.dart';
import 'quran_page_cache.dart';
import 'quran_reader_screen.dart';

/// Entry point for the shop app's Islamic tools. The Qur’an reader is the
/// first tool; qibla, prayer times, tasbih and du'as can be added here later.
class IslamicToolsScreen extends ConsumerStatefulWidget {
  const IslamicToolsScreen({super.key});

  @override
  ConsumerState<IslamicToolsScreen> createState() =>
      _IslamicToolsScreenState();
}

class _IslamicToolsScreenState extends ConsumerState<IslamicToolsScreen> {
  int _lastPage() {
    final saved = ref.read(prefsProvider).getInt(quranLastPageKey) ?? 1;
    return saved.clamp(1, quranPageCount).toInt();
  }

  Future<void> _openQuran({int? page}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(initialPage: page),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear saved pages?'),
        content: const Text(
          'Pages saved on this device will be deleted. They load again the '
          'next time you open them, so keep them if you read offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(quranPageCacheProvider).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved pages cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = _lastPage();
    final chapter = quranChapterForPage(lastPage);

    return Scaffold(
      appBar: AppBar(title: const Text('Islamic tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuranHero(
                    lastPage: lastPage,
                    chapter: chapter,
                    onContinue: () => _openQuran(),
                    onStart: () => _openQuran(page: 1),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: ListTile(
                      leading: const Icon(Icons.library_music_rounded),
                      title: const Text('Qur’an player'),
                      subtitle: const Text(
                        'Hundreds of reciters, offline downloads, and playback '
                        'that keeps going while you use the app.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QuranPlayerLibraryScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: ListTile(
                      leading: const Icon(Icons.fingerprint_rounded),
                      title: const Text('Tasbih'),
                      subtitle: const Text(
                        'Dhikr counter with presets for 33, 34, 99 and 100. '
                        'Tap to count, reset anytime.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TasbihScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppColors.profit.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.offline_pin_rounded,
                                size: 20,
                                color: AppColors.profit,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Pages are saved on this device as you read, so '
                                'the Qur’an opens even without a connection. '
                                'Recitation can be downloaded surah by surah, '
                                'and page bookmarks are kept on this device.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: _clearCache,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Clear saved pages'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Coming next',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _UpcomingTool(
                        icon: Icons.explore_outlined,
                        label: 'Qibla',
                      ),
                      _UpcomingTool(
                        icon: Icons.access_time_rounded,
                        label: 'Prayer times',
                      ),
                      _UpcomingTool(
                        icon: Icons.menu_book_rounded,
                        label: 'Hadith',
                      ),
                      _UpcomingTool(
                        icon: Icons.auto_awesome_rounded,
                        label: '99 Names',
                      ),
                      _UpcomingTool(
                        icon: Icons.auto_stories_rounded,
                        label: 'Stories',
                      ),
                      _UpcomingTool(
                        icon: Icons.calculate_rounded,
                        label: 'Zakat',
                      ),
                      _UpcomingTool(
                        icon: Icons.shield_rounded,
                        label: 'Hisnul Muslim',
                      ),
                      _UpcomingTool(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Du\u2018as',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Uthmani text laid out on the 604 printed pages of the '
                    'Madinah mushaf in the Amiri Quran typeface. Qur’an text, '
                    'translations, tafsir and recitation from the Qur’an.com '
                    'API. Pages and downloaded recitation work offline; '
                    'translations, tafsir and streaming recitation need a '
                    'connection.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuranHero extends StatelessWidget {
  const _QuranHero({
    required this.lastPage,
    required this.chapter,
    required this.onContinue,
    required this.onStart,
  });

  final int lastPage;
  final QuranChapter chapter;
  final VoidCallback onContinue;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E6B4F), Color(0xFF083D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.seed.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'القرآن الكريم',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    Text(
                      'The Noble Qur’an · 604 pages',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Read the mushaf page by page, exactly as it is printed, or switch '
            'to the whole-surah list. Recitation follows the page with the word '
            'being recited highlighted, any verse opens its translations and '
            'tafsir, and a reciter can be downloaded for offline listening.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0E6B4F),
                ),
                onPressed: onContinue,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  lastPage > 1 ? 'Continue · Page $lastPage' : 'Start reading',
                ),
              ),
              if (lastPage > 1)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  onPressed: onStart,
                  icon: const Icon(Icons.first_page_rounded),
                  label: const Text('Start from page 1'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Resume: ${chapter.nameSimple} · page $lastPage',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTool extends StatelessWidget {
  const _UpcomingTool({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Soon',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
