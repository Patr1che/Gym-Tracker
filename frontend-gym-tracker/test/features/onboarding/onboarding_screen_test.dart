import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/models/enums.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/onboarding/presentation/onboarding_screen.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  late FakeAuthRepository authRepo;

  List<Override> overrides() => [
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionStoreProvider.overrideWithValue(
            FakeSessionStore(userId: 'u1', rememberMe: true)),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        settingsBoxProvider.overrideWithValue(FakeJsonBox()),
      ];

  setUp(() {
    // A registered user who has not completed onboarding yet.
    authRepo = FakeAuthRepository(users: [testUser(onboarded: false)]);
  });

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('greets the user and asks for their stats first',
      (tester) async {
    await pumpApp(tester, const OnboardingScreen(), overrides: overrides());

    expect(find.text('Hey Alex Smith 👋'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
  });

  testWidgets('blocks the first step until gender and stats are valid',
      (tester) async {
    await pumpApp(tester, const OnboardingScreen(), overrides: overrides());

    await tapContinue(tester);
    expect(find.text('Select your gender to continue'), findsOneWidget);

    // Let the snackbar auto-dismiss; it covers the Continue button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();
    await tapContinue(tester);

    // Still on step 1 — the numeric fields are empty.
    expect(find.text('Age is required'), findsOneWidget);
    expect(find.text("What's your goal?"), findsNothing);
  });

  testWidgets('walks all four steps and saves the profile', (tester) async {
    await pumpApp(tester, const OnboardingScreen(), overrides: overrides());

    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '28');
    await tester.enterText(fields.at(1), '178');
    await tester.enterText(fields.at(2), '80');
    await tapContinue(tester);

    expect(find.text("What's your goal?"), findsOneWidget);
    await tester.tap(find.text('Build Muscle'));
    await tester.pumpAndSettle();
    await tapContinue(tester);

    expect(find.text('Your experience level?'), findsOneWidget);
    await tester.tap(find.text('Intermediate'));
    await tester.pumpAndSettle();
    await tapContinue(tester);

    expect(find.text('How often will you train?'), findsOneWidget);
    await tester.tap(find.text('4 days / week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    // The button shows an indeterminate spinner (the real app redirects away
    // at this point), so pumpAndSettle would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final profile = authRepo.findById('u1')!.profile;
    expect(profile, isNotNull);
    expect(profile!.gender, Gender.male);
    expect(profile.age, 28);
    expect(profile.heightCm, 178);
    expect(profile.weightKg, 80);
    expect(profile.goal, FitnessGoal.buildMuscle);
    expect(profile.experience, ExperienceLevel.intermediate);
    expect(profile.weeklyFrequency, 4);
  });

  testWidgets('the back button returns to the previous step', (tester) async {
    await pumpApp(tester, const OnboardingScreen(), overrides: overrides());

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '30');
    await tester.enterText(fields.at(1), '165');
    await tester.enterText(fields.at(2), '62');
    await tapContinue(tester);

    expect(find.text("What's your goal?"), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Hey Alex Smith 👋'), findsOneWidget);
  });
}
