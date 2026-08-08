import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/models/exercise.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/exercise_avatar.dart';

/// Video section of the exercise detail screen.
///
/// Embeds a YouTube player when the exercise has a curated [Exercise.videoId].
/// Otherwise it offers a YouTube search — the embedded player can only load a
/// specific video, since YouTube removed `listType=search` support in 2020.
class ExerciseVideo extends StatelessWidget {
  const ExerciseVideo({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    if (exercise.hasVideo) {
      return _EmbeddedPlayer(
        key: ValueKey(exercise.videoId),
        videoId: exercise.videoId!,
      );
    }
    return _SearchPlaceholder(exercise: exercise);
  }
}

class _EmbeddedPlayer extends StatefulWidget {
  const _EmbeddedPlayer({super.key, required this.videoId});

  final String videoId;

  @override
  State<_EmbeddedPlayer> createState() => _EmbeddedPlayerState();
}

class _EmbeddedPlayerState extends State<_EmbeddedPlayer> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      // Never autoplay — the user may be mid-set with sound on.
      autoPlay: false,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(controller: _controller),
      ),
    );
  }
}

/// Gradient panel with a "Watch on YouTube" action that opens a search.
class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder({required this.exercise});

  final Exercise exercise;

  Future<void> _openSearch(BuildContext context) async {
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': exercise.videoSearchQuery,
    });
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        showErrorSnack(context, 'Could not open YouTube.');
      }
    } catch (_) {
      if (context.mounted) {
        showErrorSnack(
            context, 'Could not open YouTube — reinstall the app and retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: AppColors.muscleGradient(exercise.imagePlaceholder),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            ExerciseAvatar.iconFor(exercise.imagePlaceholder),
            size: 72,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          Material(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => _openSearch(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_fill_rounded,
                        size: 22, color: Colors.white),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Watch on YouTube',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: AppSpacing.md,
            child: Text(
              'Opens a search for "${exercise.name}"',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }
}
