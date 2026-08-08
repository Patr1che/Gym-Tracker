import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/glass_card.dart';
import '../../measurements/presentation/measurement_providers.dart';
import '../../shell/presentation/app_shell.dart';
import '../../workout_session/presentation/session_controller.dart';
import '../domain/backup_service.dart';
import 'backup_controller.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final controller = ref.read(backupControllerProvider);
      final json = controller.buildExportJson();
      final name = controller.exportFileName();

      // SharePlus handles the platform differences: a share sheet on Android,
      // a file download in the browser.
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          subject: 'GymTracker backup',
        ),
      );
      if (mounted) showSuccessSnack(context, 'Backup ready — $name');
    } on MissingPluginException {
      // Same stale-native-binary case as import — fall back to the clipboard.
      if (mounted) {
        showErrorSnack(
            context,
            'Sharing needs a reinstall of the app. '
            'Use "Copy as text" for now.');
      }
    } on BackupException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      final json = ref.read(backupControllerProvider).buildExportJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) showSuccessSnack(context, 'Backup copied to clipboard');
    } on BackupException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // required on web, harmless elsewhere
      );
      if (picked == null || picked.files.isEmpty) return;

      final bytes = picked.files.first.bytes;
      if (bytes == null) {
        if (mounted) showErrorSnack(context, 'Could not read that file.');
        return;
      }
      await _applyJson(utf8.decode(bytes));
    } on MissingPluginException {
      // New plugins only register on a fresh install — a hot restart keeps the
      // old native binary, so the file picker channel isn't there yet.
      if (mounted) {
        await _showReinstallHelp();
      }
    } on BackupException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Plugin-free restore path: paste the JSON straight in. Always available,
  /// even when the file picker is unavailable.
  Future<void> _importFromText() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste backup text'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 8,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Paste the contents of your backup file here…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      await _applyJson(text);
    } on BackupException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shared parse → confirm → restore, used by both import paths.
  Future<void> _applyJson(String jsonText) async {
    final controller = ref.read(backupControllerProvider);
    final data = controller.parse(jsonText);

    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Restore this backup?',
      message: 'From ${formatShortDate(data.exportedAt, DateTime.now())}\n\n'
          '${data.workouts.length} workouts, '
          '${data.measurements.length} measurements, '
          '${data.favorites.length} favorites.\n\n'
          'Records with the same id will be overwritten. Nothing else is deleted.',
      confirmLabel: 'Restore',
    );
    if (!confirmed || !mounted) return;

    final summary = await controller.restore(data);
    if (!mounted) return;
    showSuccessSnack(
      context,
      'Restored ${summary.workouts} workouts and '
      '${summary.measurements} measurements',
    );
  }

  Future<void> _showReinstallHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File picker unavailable'),
        content: const Text(
          'This build of the app was started before the file picker was added, '
          'so the feature is not installed yet.\n\n'
          'Fully close and reinstall the app (a hot restart is not enough), '
          'or use "Paste backup text" instead — that works right now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(workoutLogsProvider).length;
    final measurements = ref.watch(measurementsControllerProvider).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Backup & Export')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
            AppSpacing.screenH, kBottomNavClearance),
        children: [
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.secondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Your data lives only on this device. Export a backup file '
                    'you can keep in cloud storage or move to a new phone.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Saves $workouts ${workouts == 1 ? 'workout' : 'workouts'} and '
                  '$measurements ${measurements == 1 ? 'measurement' : 'measurements'} '
                  'as a JSON file. Your password is never included.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Export backup file',
                  icon: Icons.ios_share_rounded,
                  loading: _busy,
                  onPressed: _export,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Copy as text',
                  icon: Icons.copy_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : _copyToClipboard,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Restore from a backup file. Workouts and measurements are '
                  'merged by id, so importing twice is safe.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Import backup file',
                  icon: Icons.file_open_outlined,
                  variant: AppButtonVariant.secondary,
                  loading: _busy,
                  onPressed: _import,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Paste backup text',
                  icon: Icons.content_paste_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : _importFromText,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 20, color: AppColors.warning),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'A backup contains your workout history and body '
                    'measurements in plain text. Store it somewhere private.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
