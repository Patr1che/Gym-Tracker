/// Where the API lives, and whether to talk to it at all.
///
/// Both come from `--dart-define` so a build can be pointed at a local server
/// without editing code:
///
/// ```
/// flutter run -d chrome --web-port 5555 \
///   --dart-define=API_BASE_URL=http://localhost:8097
/// ```
///
/// The web port matters: the API's CORS_ORIGINS must list the exact origin the
/// browser reports, and 5555 is the port the project pins.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gymtracker-api-e6o6.onrender.com',
  );

  /// Set `--dart-define=SYNC_ENABLED=false` to run fully local, exactly as the
  /// app behaved before the backend existed. Useful for offline development and
  /// for isolating whether a bug is in the app or in sync.
  static const bool syncEnabled = bool.fromEnvironment(
    'SYNC_ENABLED',
    defaultValue: true,
  );

  static const String apiPrefix = '/api/v1';

  /// Render's free tier spins down after ~15 minutes idle, and a cold JVM on a
  /// fraction of a CPU can take the better part of a minute to answer. This is
  /// deliberately generous so a first request after idle succeeds rather than
  /// failing and leaving the record dirty.
  static const Duration coldStartTimeout = Duration(seconds: 90);

  static const Duration normalTimeout = Duration(seconds: 20);
}
