import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../auth_controller.dart';
import '../widgets/auth_brand.dart';

/// Confirms the six-digit code mailed at registration.
///
/// Mandatory: the router sends any signed-in, unconfirmed account straight back
/// here, so there is no route around it. The only way out without a code is to
/// sign out - which exists because a mistyped address would otherwise lock the
/// account out of the app permanently, with no way to reach a working inbox.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  bool _verifying = false;
  bool _resending = false;

  /// Mirrors the server's own resend cooldown so the button explains the wait
  /// instead of letting the user tap into a 429.
  static const _cooldown = Duration(minutes: 5);
  Duration _remaining = _cooldown;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _remaining = _cooldown);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining -= const Duration(seconds: 1));
      if (_remaining <= Duration.zero) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _verifying = true);

    String? error;
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(_code.text);
    } on Object catch (e) {
      // The message is the server's, and it is written to be shown: how many
      // attempts remain, or that a new code is needed.
      error = e.toString();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }

    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    showSuccessSnack(context, 'Email confirmed - your data will sync now.');
    _leave();
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    String? error;
    try {
      await ref.read(authControllerProvider.notifier).resendVerificationCode();
    } on Object catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => _resending = false);
    }

    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    _startCooldown();
    showSuccessSnack(context, 'A new code is on its way.');
  }

  /// Only reached once verified. The router would redirect anyway; going
  /// straight there avoids a visible bounce.
  void _leave() {
    final onboarded = ref.read(authControllerProvider).onboarded;
    context.go(onboarded ? Routes.home : Routes.onboarding);
  }

  /// The escape hatch for a mistyped address. Not a way to skip verification -
  /// it ends the session, so the next sign-in still has to confirm.
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Use a different email?'),
            content: const Text(
                'This signs you out. Your account keeps the address you '
                'registered with, so you can register again with the right one.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go(Routes.login);
  }

  String? _validateCode(String? value) {
    final digits = (value ?? '').trim();
    if (digits.isEmpty) return 'Enter the code from your email';
    if (digits.length != 6) return 'The code is 6 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).user?.email ?? 'your email';
    final waiting = _remaining > Duration.zero;

    return AuthScaffold(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrand(
              title: 'Confirm your email',
              subtitle: 'Enter the 6-digit code we sent you',
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'We sent a code to $email. Confirm it to finish setting '
                      'up your account and sync across devices.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Verification code',
              controller: _code,
              hint: '123456',
              prefixIcon: Icons.password_rounded,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verify(),
              validator: _validateCode,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Confirm email',
              loading: _verifying,
              onPressed: _verifying ? null : _verify,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: waiting
                  ? 'Resend in ${_remaining.inMinutes}:'
                      '${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}'
                  : 'Send a new code',
              variant: AppButtonVariant.secondary,
              loading: _resending,
              onPressed: waiting || _resending ? null : _resend,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _verifying ? null : _signOut,
              child: const Text('Wrong email? Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
