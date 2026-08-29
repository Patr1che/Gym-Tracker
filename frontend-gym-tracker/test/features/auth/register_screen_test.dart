import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/auth/presentation/screens/register_screen.dart';
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

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'New User',
    String email = 'new@example.com',
    String password = 'secret123',
    String? confirm,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), password);
    await tester.enterText(fields.at(3), confirm ?? password);
  }

  /// The form is taller than the test viewport, so the button must be
  /// scrolled into view before it can be tapped.
  Future<void> submit(WidgetTester tester) async {
    final button = find.text('Create Account');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('accepts a short, letters-only password', (tester) async {
    // Registration now routes to the verification screen, so a router must exist.
    await pumpApp(tester, const RegisterScreen(),
        overrides: overrides(), withRouter: true);
    await fillForm(tester, password: 'abc', confirm: 'abc');
    await submit(tester);

    expect(authRepo.findByEmail('new@example.com'), isNotNull);
  });

  testWidgets('flags an empty password', (tester) async {
    await pumpApp(tester, const RegisterScreen(), overrides: overrides());
    await fillForm(tester, password: '', confirm: '');
    await submit(tester);

    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('flags mismatched confirmation', (tester) async {
    await pumpApp(tester, const RegisterScreen(), overrides: overrides());
    await fillForm(tester, password: 'secret123', confirm: 'different123');
    await submit(tester);

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('surfaces a duplicate email error', (tester) async {
    await pumpApp(tester, const RegisterScreen(), overrides: overrides());
    await fillForm(tester, email: 'ALEX@example.com');
    await submit(tester);

    expect(find.text('An account with this email already exists'),
        findsOneWidget);
  });

  testWidgets('a valid form creates the account and signs in', (tester) async {
    await pumpApp(tester, const RegisterScreen(),
        overrides: overrides(), withRouter: true);
    await fillForm(tester);
    await submit(tester);

    final created = authRepo.findByEmail('new@example.com');
    expect(created, isNotNull);
    expect(created!.name, 'New User');
    expect(created.isOnboarded, isFalse); // onboarding comes next
    expect(sessionStore.currentUserId, created.id);
  });
}
