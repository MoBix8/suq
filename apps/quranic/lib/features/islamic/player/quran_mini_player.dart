import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import 'quran_player_audio.dart';
import 'quran_player_downloads.dart';
import 'quran_player_models.dart';
import 'quran_player_screen.dart';

/// Navigator used by the floating player. `MaterialApp.builder` sits above the
/// app's Navigator, so a key is the only way to push a route from there.
final quranRootNavigatorKey = GlobalKey<NavigatorState>();

/// Floating Qur'an controls that stay on screen over every page.
///
/// It lives in `MaterialApp.builder`, above the app's Navigator, so it cannot
/// use widgets that need an [Overlay] such as [Tooltip] or modal sheets.
class QuranMiniPlayer extends ConsumerStatefulWidget {
  const QuranMiniPlayer({super.key});

  @override
  ConsumerState<QuranMiniPlayer> createState() => _QuranMiniPlayerState();
}

class _QuranMiniPlayerState extends ConsumerState<QuranMiniPlayer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(quranPlayerProvider);
    final downloads = ref.watch(quranPlayerDownloadsProvider);

    return AnimatedBuilder(
      animation: Listenable.merge([controller, downloads]),
      builder: (context, _) {
        if (!controller.hasSession || controller.isScreenOpen) {
          _expanded = false;
          return const SizedBox.shrink();
        }
        if (MediaQuery.viewInsetsOf(context).bottom > 0) {
          _expanded = false;
          return const SizedBox.shrink();
        }

        final reciter = controller.reciter!;
        final chapter = controller.chapterMeta!;
        final offline = downloads.isDownloaded(reciter.key, chapter.number);

        if (!_expanded) {
          return _FloatingButton(
            controller: controller,
            offline: offline,
            onOpen: () => setState(() => _expanded = true),
          );
        }

        return _ExpandedControls(
          controller: controller,
          reciter: reciter,
          chapterName: chapter.nameSimple,
          offline: offline,
          onCollapse: () => setState(() => _expanded = false),
          onOpenPlayer: _openPlayer,
        );
      },
    );
  }

  void _openPlayer() {
    final context = quranRootNavigatorKey.currentContext;
    if (context == null) return;
    showQuranPlayerSheet(context);
  }
}

class _FloatingButton extends StatefulWidget {
  const _FloatingButton({
    required this.controller,
    required this.offline,
    required this.onOpen,
  });

  final QuranPlayerController controller;
  final bool offline;
  final VoidCallback onOpen;

  @override
  State<_FloatingButton> createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<_FloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _FloatingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.controller.isPlaying) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
      _wave.value = 0;
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final buffering = controller.isBuffering && !controller.isPlaying;

    return GestureDetector(
      onTap: widget.onOpen,
      child: SizedBox(
        width: 66,
        height: 66,
        child: CustomPaint(
          painter: _DashedCirclePainter(color: AppColors.seed, strokeWidth: 1.4),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: buffering
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.seed,
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _wave,
                      builder: (context, _) {
                        return _SoundWave(
                          playing: controller.isPlaying,
                          progress: _wave.value,
                          color: Colors.black87,
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundWave extends StatelessWidget {
  const _SoundWave({
    required this.playing,
    required this.progress,
    required this.color,
  });

  final bool playing;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (index) {
          final phase = progress * 2 * math.pi + index * 0.9;
          final height = playing
              ? 6 + 12 * (0.5 + 0.5 * math.sin(phase))
              : 8.0;
          return Container(
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    const dashCount = 20;
    final sweep = (2 * math.pi) / (dashCount * 2);
    for (var i = 0; i < dashCount; i++) {
      final start = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _ExpandedControls extends StatelessWidget {
  const _ExpandedControls({
    required this.controller,
    required this.reciter,
    required this.chapterName,
    required this.offline,
    required this.onCollapse,
    required this.onOpenPlayer,
  });

  final QuranPlayerController controller;
  final QuranPlayerReciter reciter;
  final String chapterName;
  final bool offline;
  final VoidCallback onCollapse;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      elevation: 14,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 288,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                QuranReciterAvatar(
                  reciter: reciter,
                  size: 42,
                  radius: 12,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onOpenPlayer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  chapterName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (offline) ...[
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.offline_pin_rounded,
                                  size: 13,
                                  color: AppColors.profit,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${reciter.name} · '
                            '${formatQuranDuration(controller.position)}'
                            ' / '
                            '${controller.duration > Duration.zero ? formatQuranDuration(controller.duration) : '--:--'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: onOpenPlayer,
                    iconSize: 17,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: onCollapse,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: controller.progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: controller.previous,
                  iconSize: 30,
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                _ExpandedPlayButton(controller: controller),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: controller.next,
                  iconSize: 30,
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedPlayButton extends StatelessWidget {
  const _ExpandedPlayButton({required this.controller});

  final QuranPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final buffering = controller.isBuffering && !controller.isPlaying;

    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: controller.toggle,
        child: SizedBox(
          width: 52,
          height: 52,
          child: buffering
              ? const Padding(
                  padding: EdgeInsets.all(16),
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
                  size: 30,
                ),
        ),
      ),
    );
  }
}

const _surface = Color(0xFF171208);
