import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/validators.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../auth_controller.dart';
import '../widgets/auth_brand.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  bool _loading = false;

  /// Shown once a request has been waiting long enough to look broken.
  ///
  /// The free hosting tier spins the API down after ~15 minutes idle, and a
  /// cold start can take most of a minute. Without this the button just spins
  /// and the app looks hung.
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _startSlowHint() {
    _slowTimer?.cancel();
    _slow = false;
    _slowTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _loading) setState(() => _slow = true);
    });
  }

  void _stopSlowHint() {
    _slowTimer?.cancel();
    _slow = false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    _startSlowHint();

    String? error;
    try {
      error = await ref.read(authControllerProvider.notifier).login(
            email: _email.text,
            password: _password.text,
            rememberMe: _rememberMe,
          );
    } catch (e) {
      // Belt and braces. The controller already turns failures into messages,
      // but anything unforeseen escaping here would strand the button in its
      // loading state with no way out, so the finally below always clears it.
      error = 'Something went wrong. Please try again.';
    } finally {
      _stopSlowHint();
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
    }
    // On success the router redirect navigates automatically.
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrand(
                title: 'Welcome back',
                subtitle: 'Sign in to continue your training',
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Password',
                controller: _password,
                hint: 'Your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password is required' : null,
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: AppSpacing.md),
              // Wrap, not Row: on a narrow phone "Forgot password?" needs its
              // own line rather than squeezing the checkbox label out.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          child: Text('Remember me',
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go(Routes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Sign In',
                loading: _loading,
                onPressed: _submit,
              ),
              if (_slow) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Waking the server — this can take up to a minute the first '
                  'time.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("Don't have an account?",
                      style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.go(Routes.register),
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
