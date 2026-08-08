import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/app.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/seed/seeder.dart';

import 'helpers/fake_json_box.dart';

/// End-to-end coverage of the real app: router redirects (signed out -> login,
/// signed in without a profile -> onboarding, onboarded -> shell), the real
/// repositories, and the real seed data.
///
/// Persistence uses in-memory boxes rather than Hive: testWidgets runs under
/// fake async, where Hive's disk I/O futures never complete.
void main() {
  late FakeJsonBox users;
  late FakeJsonBox session;
  late FakeJsonBox settings;
  late FakeJsonBox exercises;
  late FakeJsonBox programs;
  late FakeJsonBox favorites;
  late FakeJsonBox workoutLogs;
  late FakeJsonBox activeSession;
  late FakeJsonBox measurements;
  late FakeJsonBox meta;

  setUp(() async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(430, 932);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    users = FakeJsonBox();
    session = FakeJsonBox();
    settings = FakeJsonBox();
    exercises = FakeJsonBox();
    programs = FakeJsonBox();
    favorites = FakeJsonBox();
    workoutLogs = FakeJsonBox();
    activeSession = FakeJsonBox();
    measurements = FakeJsonBox();
    meta = FakeJsonBox();

    await runSeeder(
        exercises: exercises, programs: programs, meta: meta);
  });

  List<Override> overrides() => [
        usersBoxProvider.overrideWithValue(users),
        sessionBoxProvider.overrideWithValue(session),
        settingsBoxProvider.overrideWithValue(settings),
        exercisesBoxProvider.overrideWithValue(exercises),
        programsBoxProvider.overrideWithValue(programs),
        favoritesBoxProvider.overrideWithValue(favorites),
        workoutLogsBoxProvider.overrideWithValue(workoutLogs),
        activeSessionBoxProvider.overrideWithValue(activeSession),
        measurementsBoxProvider.overrideWithValue(measurements),
        metaBoxProvider.overrideWithValue(meta),
      ];

  Future<void> pumpAppRoot(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides(), child: const GymTrackerApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> registerUser(
    WidgetTester tester, {
    required String name,
    required String email,
  }) async {
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(3), 'secret123');

    final createButton = find.text('Create Account');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();
  }

  Future<void> completeOnboarding(
    WidgetTester tester, {
    required String gender,
    required String age,
    required String height,
    required String weight,
    required String goal,
    required String experience,
    required String frequency,
  }) async {
    await tester.tap(find.text(gender));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), age);
    await tester.enterText(fields.at(1), height);
    await tester.enterText(fields.at(2), weight);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(goal));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(experience));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(frequency));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-out visitor is redirected to login', (tester) async {
    await pumpAppRoot(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('register lands on onboarding, not the dashboard',
      (tester) async {
    await pumpAppRoot(tester);
    await registerUser(tester, name: 'Jordan Lee', email: 'jordan@example.com');

    expect(find.text('Hey Jordan Lee 👋'), findsOneWidget);
    // The shell must not be reachable until onboarding is done.
    expect(find.text("TODAY'S WORKOUT"), findsNothing);
  });

  testWidgets('finishing onboarding reveals the shell and its five tabs',
      (tester) async {
    await pumpAppRoot(tester);
    await registerUser(tester, name: 'Jordan Lee', email: 'jordan@example.com');
    await completeOnboarding(
      tester,
      gender: 'Male',
      age: '31',
      height: '180',
      weight: '84',
      goal: 'Build Muscle',
      experience: 'Beginner',
      frequency: '3 days / week',
    );

    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
    for (final tab in ['Home', 'Workouts', 'Progress', 'History', 'Profile']) {
      expect(find.text(tab), findsWidgets, reason: 'missing $tab tab');
    }
  });

  testWidgets('a relaunch restores the session when Remember Me is on',
      (tester) async {
    await pumpAppRoot(tester);
    await registerUser(tester, name: 'Jordan Lee', email: 'jordan@example.com');
    await completeOnboarding(
      tester,
      gender: 'Male',
      age: '31',
      height: '180',
      weight: '84',
      goal: 'Build Muscle',
      experience: 'Beginner',
      frequency: '3 days / week',
    );

    // A fresh widget tree over the same boxes = a browser refresh.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpAppRoot(tester);

    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
  });

  testWidgets('seeded programs, the library, and empty history are reachable',
      (tester) async {
    await pumpAppRoot(tester);
    await registerUser(tester, name: 'Sam Rivera', email: 'sam@example.com');
    await completeOnboarding(
      tester,
      gender: 'Female',
      age: '27',
      height: '167',
      weight: '61',
      goal: 'Lose Fat',
      experience: 'Beginner',
      frequency: '4 days / week',
    );

    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    expect(find.text('Beginner Full Body'), findsOneWidget);
    expect(find.text('Push Pull Legs'), findsOneWidget);

    await tester.tap(find.text('Exercise Library'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No workouts yet'), findsOneWidget);
  });
}
