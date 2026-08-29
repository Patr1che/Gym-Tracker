import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';
import '../../features/exercises/presentation/screens/exercise_detail_screen.dart';
import '../../features/exercises/presentation/screens/exercise_library_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/workout_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/measurements/presentation/measurements_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/programs/presentation/program_detail_screen.dart';
import '../../features/programs/presentation/screens/program_editor_screen.dart';
import '../../features/programs/presentation/programs_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/settings/presentation/screens/static_pages.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/workout_session/presentation/active_session_screen.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Bump a ValueNotifier on auth changes so redirects re-evaluate.
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      final onAuthPage = Routes.authPaths.contains(path);

      if (!auth.signedIn) return onAuthPage ? null : Routes.login;

      // Verification comes before everything else in the app. This is the
      // enforcement: removing the skip button alone would not be enough,
      // because any other route would still be reachable by URL.
      if (!auth.emailVerified) {
        return path == Routes.verifyEmail ? null : Routes.verifyEmail;
      }

      if (!auth.onboarded) {
        return path == Routes.onboarding ? null : Routes.onboarding;
      }
      if (onAuthPage || path == Routes.onboarding || path == Routes.verifyEmail) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Root-level so the active workout covers the bottom nav.
      GoRoute(
        path: Routes.session,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActiveSessionScreen(),
        routes: [
          // Pushed on the root navigator so it stacks on top of the live
          // session — popping lands back on the workout, not the library.
          GoRoute(
            path: 'exercise/:id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ExerciseDetailScreen(
              exerciseId: state.pathParameters['id']!,
              standalone: true,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.workouts,
              builder: (context, state) => const ProgramsScreen(),
              routes: [
                GoRoute(
                  path: 'exercises',
                  builder: (context, state) => const ExerciseLibraryScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => ExerciseDetailScreen(
                          exerciseId: state.pathParameters['id']!),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'program-new',
                  builder: (context, state) => const ProgramEditorScreen(),
                ),
                GoRoute(
                  path: 'program-edit/:id',
                  builder: (context, state) =>
                      ProgramEditorScreen(programId: state.pathParameters['id']),
                ),
                GoRoute(
                  path: 'program-copy/:id',
                  builder: (context, state) => ProgramEditorScreen(
                      copyFromId: state.pathParameters['id']),
                ),
                GoRoute(
                  path: 'program/:id',
                  builder: (context, state) => ProgramDetailScreen(
                      programId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.progress,
              builder: (context, state) => const ProgressScreen(),
              routes: [
                GoRoute(
                  path: 'measurements',
                  builder: (context, state) => const MeasurementsScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.history,
              builder: (context, state) => const HistoryScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      WorkoutDetailScreen(logId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'backup',
                      builder: (context, state) => const BackupScreen(),
                    ),
                    GoRoute(
                      path: 'privacy',
                      builder: (context, state) => const PrivacyScreen(),
                    ),
                    GoRoute(
                      path: 'terms',
                      builder: (context, state) => const TermsScreen(),
                    ),
                    GoRoute(
                      path: 'about',
                      builder: (context, state) => const AboutScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
