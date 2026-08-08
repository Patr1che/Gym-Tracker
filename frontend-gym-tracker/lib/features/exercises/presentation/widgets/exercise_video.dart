import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/domain/youtube_url_parser.dart';
import '../../../../core/models/exercise.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/exercise_avatar.dart';
import '../exercise_providers.dart';

/// Video section of the exercise detail screen.
///
/// Shows the video's thumbnail and hands playback to the YouTube app on tap.
///
/// Embedded playback was tried twice — youtube_player_iframe (HTML injected
/// into a WebView) and youtube_player_embed (InAppWebView). Both were
/// rejected by YouTube with referrer errors 152-4 and 153 on every video,
/// and the second crashed on Android. The videos themselves are fine
/// (`playableInEmbed` is true), so this is a WebView limitation, not a
/// content restriction. Opening YouTube directly is reliable and gives
/// proper fullscreen controls.
class ExerciseVideo extends ConsumerWidget {
  const ExerciseVideo({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoId = ref.watch(effectiveVideoIdProvider(exercise.id));
    if (videoId == null) {
      return _NoVideoPanel(exercise: exercise);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VideoThumbnail(
          videoId: videoId,
          muscleToken: exercise.imagePlaceholder,
          onTap: () => _openOnYouTube(context, videoId),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => showVideoDialog(context, ref, exercise),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Change video'),
            ),
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Remove video?',
                  message: 'You can add another any time.',
                  confirmLabel: 'Remove',
                  destructive: true,
                );
                if (!confirmed) return;
                await ref
                    .read(exerciseVideoControllerProvider.notifier)
                    .removeVideo(exercise.id);
                if (context.mounted) {
                  showSuccessSnack(context, 'Video removed');
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Opens a video in the YouTube app or browser.
Future<void> _openOnYouTube(BuildContext context, String videoId) async {
  try {
    await launchUrl(
      Uri.parse(YouTubeUrlParser.watchUrl(videoId)),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    if (context.mounted) showErrorSnack(context, 'Could not open YouTube.');
  }
}

/// YouTube thumbnail with a play badge. Falls back to the muscle-group
/// gradient when the image can't load (offline, or a deleted video).
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({
    required this.videoId,
    required this.muscleToken,
    required this.onTap,
  });

  final String videoId;
  final String muscleToken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.muscleGradient(muscleToken),
                ),
                child: Icon(
                  ExerciseAvatar.iconFor(muscleToken),
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.muscleGradient(muscleToken),
                      ),
                    ),
            ),
            // Scrim so the play badge stays legible on bright thumbnails.
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        size: 26, color: Colors.white),
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
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient panel offering to attach a video or search YouTube.
class _NoVideoPanel extends ConsumerWidget {
  const _NoVideoPanel({required this.exercise});

  final Exercise exercise;

  Future<void> _openSearch(BuildContext context) async {
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': exercise.videoSearchQuery,
    });
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) showErrorSnack(context, 'Could not open YouTube.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 190,
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
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillButton(
                    icon: Icons.add_link_rounded,
                    label: 'Add video',
                    onTap: () => showVideoDialog(context, ref, exercise),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PillButton(
                    icon: Icons.search_rounded,
                    label: 'Find on YouTube',
                    subdued: true,
                    onTap: () => _openSearch(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Paste any YouTube link — including a Short — to show it here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// Prompts for a YouTube link and saves the extracted id.
Future<void> showVideoDialog(
    BuildContext context, WidgetRef ref, Exercise exercise) async {
  final controller = TextEditingController(
    text: ref.read(effectiveVideoIdProvider(exercise.id)) ?? '',
  );
  String? errorText;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add exercise video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a YouTube link for ${exercise.name}. '
              'Normal videos and Shorts both work.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=…',
                errorText: errorText,
              ),
              onChanged: (_) {
                if (errorText != null) setState(() => errorText = null);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (YouTubeUrlParser.extractId(controller.text) == null) {
                setState(() => errorText =
                    'That does not look like a YouTube video link.');
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  final id = YouTubeUrlParser.extractId(controller.text);
  controller.dispose();
  if (saved != true || id == null) return;

  await ref
      .read(exerciseVideoControllerProvider.notifier)
      .setVideo(exercise.id, id);
  if (context.mounted) showSuccessSnack(context, 'Video added');
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subdued = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: subdued ? 0.3 : 0.5),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
