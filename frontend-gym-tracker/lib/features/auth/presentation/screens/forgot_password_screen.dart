import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/validators.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../auth_controller.dart';
import '../widgets/auth_brand.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await ref.read(authControllerProvider.notifier).resetPassword(
          email: _email.text,
          name: _name.text,
          newPassword: _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      showSuccessSnack(context, 'Password updated — sign in with it now');
      context.go(Routes.login);
    } else {
      showErrorSnack(context, 'No account matches that email and name');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrand(
              title: 'Reset password',
              subtitle: 'Verify your identity and pick a new password',
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Your account is stored on this device, so identity is '
                      'confirmed with your account name instead of an email link.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: 'Email',
              controller: _email,
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Account Name',
              controller: _name,
              hint: 'The name on your account',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, 'Account name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'New Password',
              controller: _password,
              hint: 'Any password you like',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: true,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Confirm New Password',
              controller: _confirm,
              hint: 'Repeat the new password',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => Validators.confirmPassword(v, _password.text),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Reset Password',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Remembered it?',
                    style: Theme.of(context).textTheme.bodyMedium),
                TextButton(
                  onPressed: () => context.go(Routes.login),
                  child: const Text('Back to Sign In'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
