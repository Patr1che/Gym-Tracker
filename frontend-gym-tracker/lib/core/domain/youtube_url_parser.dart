/// Extracts a YouTube video id from any of the URL shapes a user might paste.
///
/// Shorts are ordinary videos with a different URL prefix, so a Shorts link
/// yields an id the embedded player accepts like any other.
abstract final class YouTubeUrlParser {
  /// YouTube ids are exactly 11 chars from the URL-safe base64 alphabet.
  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static const _hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
    'youtu.be',
    'www.youtu.be',
  };

  /// Returns the video id, or null when [input] holds no usable id.
  ///
  /// Accepts a bare id, `watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`,
  /// `/live/`, and `/v/` forms, with or without a scheme.
  static String? extractId(String? input) {
    if (input == null) return null;
    final text = input.trim();
    if (text.isEmpty) return null;

    // A bare id pasted on its own.
    if (_id.hasMatch(text)) return text;

    final uri = _tryParse(text);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (!_hosts.contains(host)) return null;

    // youtu.be/<id>
    if (host.endsWith('youtu.be')) {
      return _validOrNull(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
    }

    // youtube.com/watch?v=<id>
    final queryId = uri.queryParameters['v'];
    if (queryId != null) return _validOrNull(queryId);

    // youtube.com/{shorts,embed,live,v}/<id>
    const pathPrefixes = {'shorts', 'embed', 'live', 'v'};
    final segments = uri.pathSegments;
    for (var i = 0; i < segments.length - 1; i++) {
      if (pathPrefixes.contains(segments[i].toLowerCase())) {
        return _validOrNull(segments[i + 1]);
      }
    }
    return null;
  }

  static bool isValidId(String? id) => id != null && _id.hasMatch(id);

  /// Canonical watch URL, for opening a video outside the app.
  static String watchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  static Uri? _tryParse(String text) {
    // Users paste 'youtube.com/...' without a scheme; Uri would read that as
    // a relative path with an empty host.
    final withScheme =
        text.startsWith(RegExp(r'https?://', caseSensitive: false))
            ? text
            : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    return (uri == null || uri.host.isEmpty) ? null : uri;
  }

  static String? _validOrNull(String? candidate) {
    if (candidate == null) return null;
    // Trailing junk such as 'ID?feature=share' is already split off by Uri,
    // but Shorts links sometimes carry a trailing slash segment.
    final trimmed = candidate.trim();
    return _id.hasMatch(trimmed) ? trimmed : null;
  }
}
