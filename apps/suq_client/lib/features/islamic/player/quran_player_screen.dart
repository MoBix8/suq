import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../quran_meta.dart';
import 'quran_player_audio.dart';
import 'quran_player_downloads.dart';
import 'quran_player_models.dart';

const _playerBackground = Color(0xFF0A1B15);
const _playerSurface = Color(0xFF12291F);

/// Full-screen Qur’an audio player.
class QuranPlayerSheet extends ConsumerStatefulWidget {
  const QuranPlayerSheet({super.key});

  @override
  ConsumerState<QuranPlayerSheet> createState() => _QuranPlayerSheetState();
}

class _QuranPlayerSheetState extends ConsumerState<QuranPlayerSheet> {
  bool _errorShown = false;
  late final QuranPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(quranPlayerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.setScreenOpen(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _controller.setScreenOpen(false);
      } catch (_) {
        // The provider may already be gone when the app shuts down.
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(quranPlayerProvider);
    final downloads = ref.watch(quranPlayerDownloadsProvider);

    return AnimatedBuilder(
      animation: Listenable.merge([controller, downloads]),
      builder: (context, _) {
        final reciter = controller.reciter;
        final chapter = controller.chapterMeta;
        final error = controller.error;
        if (error != null && !_errorShown) {
          _errorShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _errorShown = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
            controller.clearError();
          });
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: _playerBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: reciter == null || chapter == null
                  ? const _EmptyPlayer()
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopBar(
                            downloads: downloads,
                            controller: controller,
                            reciter: reciter,
                            chapter: chapter,
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _Artwork(chapter: chapter),
                                  const SizedBox(height: 22),
                                  Text(
                                    chapter.nameSimple,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Surah ${chapter.number} · ${chapter.meaning}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${reciter.name} · ${reciter.style}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.78),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _ProgressBar(controller: controller),
                                  const SizedBox(height: 10),
                                  _Controls(controller: controller),
                                  const SizedBox(height: 12),
                                  _Extras(controller: controller),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showQuranPlayerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => const QuranPlayerSheet(),
  );
}
class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.headphones_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing playing yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a reciter and a surah to start listening.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.downloads,
    required this.controller,
    required this.reciter,
    required this.chapter,
  });

  final QuranPlayerDownloads downloads;
  final QuranPlayerController controller;
  final QuranPlayerReciter reciter;
  final QuranChapter chapter;

  @override
  Widget build(BuildContext context) {
    final downloaded = downloads.isDownloaded(reciter.key, chapter.number);
    final job = downloads.job;
    final downloading =
        job != null && job.reciterKey == reciter.key && job.chapter == chapter.number;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: Colors.white,
            iconSize: 30,
            tooltip: 'Close player',
          ),
          const Expanded(
            child: Text(
              'Now playing',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (downloaded)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.offline_pin_rounded,
                color: AppColors.profit,
                size: 22,
              ),
            )
          else
            IconButton(
              tooltip: 'Download this surah',
              onPressed: downloading
                  ? () => downloads.cancel()
                  : () => downloads.start(
                        reciterKey: reciter.key,
                        chapters: [chapter.number],
                        urlFor: reciter.urlFor,
                      ),
              icon: downloading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: job!.progress,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              color: Colors.white,
            ),
          IconButton(
            tooltip: 'Queue',
            onPressed: () =>
                _showQueue(context, controller, downloads, reciter),
            icon: const Icon(Icons.queue_music_rounded),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  void _showQueue(
    BuildContext context,
    QuranPlayerController controller,
    QuranPlayerDownloads downloads,
    QuranPlayerReciter reciter,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _playerSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return AnimatedBuilder(
              animation: Listenable.merge([controller, downloads]),
              builder: (context, _) {
                return ListView.builder(
                  controller: scrollController,
                  itemCount: reciter.chapters.length,
                  itemBuilder: (context, index) {
                    final number = reciter.chapters[index];
                    final meta = quranChapterByNumber(number);
                    final active = controller.chapter == number;
                    final offline = downloads.isDownloaded(reciter.key, number);
                    return ListTile(
                      onTap: () {
                        Navigator.of(context).pop();
                        controller.open(reciter, number);
                      },
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: active
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.08),
                        child: Text(
                          '$number',
                          style: TextStyle(
                            color: active ? AppColors.ink : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        meta.nameSimple,
                        style: TextStyle(
                          color: active ? AppColors.accent : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${meta.nameArabic} · ${meta.verseCount} ayah',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      trailing: offline
                          ? const Icon(
                              Icons.offline_pin_rounded,
                              color: AppColors.profit,
                              size: 18,
                            )
                          : null,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.chapter});

  final QuranChapter chapter;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C4B3A), Color(0xFF0D2B22)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              bottom: -28,
              child: Text(
                '${chapter.number}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.06),
                  fontSize: 150,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chapter.nameArabic,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'AmiriQuran',
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SURAH ${chapter.number}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.controller});

  final QuranPlayerController controller;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final total = controller.duration;
    final value = (_drag ?? controller.progress).clamp(0.0, 1.0).toDouble();
    final shown = total > Duration.zero
        ? Duration(milliseconds: (total.inMilliseconds * value).round())
        : controller.position;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
            thumbColor: AppColors.accent,
          ),
          child: Slider(
            value: value,
            onChanged: total > Duration.zero
                ? (next) => setState(() => _drag = next)
                : null,
            onChangeEnd: (next) {
              setState(() => _drag = null);
              controller.seek(
                Duration(milliseconds: (total.inMilliseconds * next).round()),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatQuranDuration(shown),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                total > Duration.zero
                    ? formatQuranDuration(total)
                    : '--:--',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final QuranPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: controller.toggleRepeat,
          tooltip: controller.repeatChapter
              ? 'Repeat is on'
              : 'Repeat this surah',
          icon: Icon(
            Icons.repeat_rounded,
            color: controller.repeatChapter
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
        IconButton(
          onPressed: controller.previous,
          iconSize: 34,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
        ),
        _PlayButton(controller: controller),
        IconButton(
          onPressed: controller.next,
          iconSize: 34,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
        ),
        IconButton(
          onPressed: () => _pickSpeed(context, controller),
          tooltip: 'Playback speed',
          icon: Text(
            '${controller.speed.toStringAsFixed(controller.speed % 1 == 0 ? 0 : 1)}×',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _pickSpeed(BuildContext context, QuranPlayerController controller) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _playerSurface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Playback speed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final speed in speeds)
                ListTile(
                  onTap: () {
                    controller.setSpeed(speed);
                    Navigator.of(context).pop();
                  },
                  leading: Icon(
                    speed == controller.speed
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: speed == controller.speed
                        ? AppColors.accent
                        : Colors.white38,
                  ),
                  title: Text(
                    '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}×',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.controller});

  final QuranPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final buffering = controller.isBuffering && !controller.isPlaying;
    return GestureDetector(
      onTap: controller.toggle,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: buffering
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.ink,
                ),
              )
            : Icon(
                controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: AppColors.ink,
                size: 40,
              ),
      ),
    );
  }
}

class _Extras extends StatelessWidget {
  const _Extras({required this.controller});

  final QuranPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Pill(
          icon: controller.isDownloaded
              ? Icons.offline_pin_rounded
              : Icons.cloud_queue_rounded,
          label: controller.isDownloaded ? 'Saved offline' : 'Streaming',
        ),
        const SizedBox(width: 10),
        _Pill(
          icon: controller.isPlaying
              ? Icons.graphic_eq_rounded
              : Icons.pause_circle_outline_rounded,
          label: controller.isBuffering
              ? 'Buffering'
              : controller.isPlaying
                  ? 'Playing'
                  : 'Paused',
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
