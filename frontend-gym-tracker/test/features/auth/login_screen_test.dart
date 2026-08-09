import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/auth/presentation/screens/login_screen.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  late FakeAuthRepository authRepo;
  late FakeSessionStore sessionStore;

  setUp(() {
    authRepo = FakeAuthRepository(users: [testUser()]);
    sessionStore = FakeSessionStore();
  });

  List<Override> overrides() => [
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionStoreProvider.overrideWithValue(sessionStore),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        settingsBoxProvider.overrideWithValue(FakeJsonBox()),
      ];


  /// The brand logo makes the form taller than the test viewport, so the
  /// button must be scrolled into view before it can be tapped.
  Future<void> submit(WidgetTester tester) async {
    final button = find.text('Sign In');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation errors when submitting an empty form',
      (tester) async {
    await pumpApp(tester, const LoginScreen(), overrides: overrides());

    await submit(tester);

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('rejects a malformed email', (tester) async {
    await pumpApp(tester, const LoginScreen(), overrides: overrides());

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await submit(tester);

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('surfaces an error for wrong credentials', (tester) async {
    await pumpApp(tester, const LoginScreen(), overrides: overrides());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alex@example.com');
    await tester.enterText(fields.at(1), 'wrongpassword1');
    await tester.ensureVisible(find.text('Sign In'));
    await submit(tester);

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(sessionStore.currentUserId, isNull);
  });

  testWidgets('valid credentials sign the user in and honor Remember Me',
      (tester) async {
    await pumpApp(tester, const LoginScreen(), overrides: overrides());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alex@Example.com');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.ensureVisible(find.text('Sign In'));
    await submit(tester);

    expect(sessionStore.currentUserId, 'u1');
    expect(sessionStore.rememberMe, isTrue);
  });

  testWidgets('unchecking Remember Me is respected', (tester) async {
    await pumpApp(tester, const LoginScreen(), overrides: overrides());

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alex@example.com');
    await tester.enterText(fields.at(1), 'secret123');
    await submit(tester);

    expect(sessionStore.rememberMe, isFalse);
  });
}
