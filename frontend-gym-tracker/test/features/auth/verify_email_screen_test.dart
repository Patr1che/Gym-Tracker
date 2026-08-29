import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/persistence/hive_boxes_provider.dart';
import 'package:gym_tracker/features/auth/presentation/auth_controller.dart';
import 'package:gym_tracker/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:gym_tracker/features/settings/presentation/settings_controller.dart';

import '../../helpers/fake_json_box.dart';
import '../../helpers/test_harness.dart';

void main() {
  late FakeAuthRepository authRepo;
  late FakeSessionStore sessionStore;

  setUp(() {
    authRepo = FakeAuthRepository(users: [testUser()]);
    // Signed in already: this screen is only reachable after registering.
    sessionStore = FakeSessionStore(userId: testUser().id, rememberMe: true);
  });

  List<Override> overrides() => [
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionStoreProvider.overrideWithValue(sessionStore),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        settingsBoxProvider.overrideWithValue(FakeJsonBox()),
        // Verifying kicks off a sync to upload whatever queued up while
        // unverified. That needs the whole network stack, which is not what
        // these tests are about, so the push is switched off here.
        localOnly,
      ];

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextFormField), code);
    final button = find.text('Confirm email');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('rejects anything that is not six digits before calling the API',
      (tester) async {
    await pumpApp(tester, const VerifyEmailScreen(),
        overrides: overrides(), withRouter: true);

    await enterCode(tester, '123');

    expect(find.text('The code is 6 digits'), findsOneWidget);
  });

  testWidgets('shows the server message when the code is wrong', (tester) async {
    authRepo.verificationCode = '654321';
    await pumpApp(tester, const VerifyEmailScreen(),
        overrides: overrides(), withRouter: true);

    await enterCode(tester, '111111');

    // The remaining-attempts count comes from the server and is worth showing.
    expect(find.textContaining('attempts left'), findsOneWidget);
  });

  testWidgets('a correct code verifies the account', (tester) async {
    authRepo.verificationCode = '654321';
    await pumpApp(tester, const VerifyEmailScreen(),
        overrides: overrides(), withRouter: true);

    await enterCode(tester, '654321');

    expect(authRepo.findById(testUser().id)!.emailVerified, isTrue);
  });

  // Verification is mandatory, so there must be no way past it but the code.
  testWidgets('offers no way to skip', (tester) async {
    await pumpApp(tester, const VerifyEmailScreen(),
        overrides: overrides(), withRouter: true);

    expect(find.text("I'll do this later"), findsNothing);
    expect(find.textContaining('Skip'), findsNothing);
  });

  // The one way out without a code. Without it a mistyped address would lock
  // the account out of the app for good, with no reachable inbox.
  testWidgets('signing out is offered for a mistyped address', (tester) async {
    await pumpApp(tester, const VerifyEmailScreen(),
        overrides: overrides(), withRouter: true);

    final signOut = find.text('Wrong email? Sign out');
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    // Confirms first - signing out by accident here loses the session.
    expect(find.text('Use a different email?'), findsOneWidget);
  });

  testWidgets('the resend button waits out the cooldown first', (tester) async {
    await pumpApp(tester, const VerifyEmailScreen(),
        overrides: overrides(), withRouter: true);

    // Mirrors the server's throttle, so the button explains the wait rather
    // than letting the user tap into a 429.
    expect(find.textContaining('Resend in'), findsOneWidget);
    expect(authRepo.resendCount, 0);
  });
}
