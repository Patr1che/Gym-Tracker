import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/youtube_url_parser.dart';

void main() {
  const id = 'aBcD1234_-x'; // 11 chars, exercises the full id alphabet

  group('accepts the URL shapes people actually paste', () {
    test('standard watch link', () {
      expect(YouTubeUrlParser.extractId('https://www.youtube.com/watch?v=$id'),
          id);
    });

    test('short youtu.be link', () {
      expect(YouTubeUrlParser.extractId('https://youtu.be/$id'), id);
    });

    test('YouTube Shorts link', () {
      expect(
          YouTubeUrlParser.extractId('https://www.youtube.com/shorts/$id'), id);
    });

    test('embed and live links', () {
      expect(
          YouTubeUrlParser.extractId('https://www.youtube.com/embed/$id'), id);
      expect(
          YouTubeUrlParser.extractId('https://www.youtube.com/live/$id'), id);
    });

    test('mobile and music hosts', () {
      expect(
          YouTubeUrlParser.extractId('https://m.youtube.com/watch?v=$id'), id);
      expect(
          YouTubeUrlParser.extractId('https://music.youtube.com/watch?v=$id'),
          id);
    });

    test('no scheme', () {
      expect(YouTubeUrlParser.extractId('youtube.com/watch?v=$id'), id);
      expect(YouTubeUrlParser.extractId('youtu.be/$id'), id);
    });

    test('extra query parameters and share suffixes', () {
      expect(
        YouTubeUrlParser.extractId(
            'https://www.youtube.com/watch?v=$id&t=42s&list=PLabc'),
        id,
      );
      expect(
        YouTubeUrlParser.extractId('https://youtu.be/$id?si=xyz&t=10'),
        id,
      );
      expect(
        YouTubeUrlParser.extractId(
            'https://www.youtube.com/shorts/$id?feature=share'),
        id,
      );
    });

    test('a bare id pasted alone', () {
      expect(YouTubeUrlParser.extractId(id), id);
    });

    test('surrounding whitespace from a clipboard paste', () {
      expect(YouTubeUrlParser.extractId('  https://youtu.be/$id \n'), id);
    });
  });

  group('rejects input with no usable id', () {
    test('empty and null', () {
      expect(YouTubeUrlParser.extractId(null), isNull);
      expect(YouTubeUrlParser.extractId(''), isNull);
      expect(YouTubeUrlParser.extractId('   '), isNull);
    });

    test('non-YouTube hosts, even with a v parameter', () {
      expect(YouTubeUrlParser.extractId('https://vimeo.com/123456'), isNull);
      expect(YouTubeUrlParser.extractId('https://evil.com/watch?v=$id'), isNull);
      // A lookalike domain must not pass.
      expect(YouTubeUrlParser.extractId('https://notyoutube.com/watch?v=$id'),
          isNull);
    });

    test('a YouTube URL with no video, such as a search or channel', () {
      expect(
        YouTubeUrlParser.extractId(
            'https://www.youtube.com/results?search_query=bench+press'),
        isNull,
      );
      expect(YouTubeUrlParser.extractId('https://www.youtube.com/@somechannel'),
          isNull);
      expect(YouTubeUrlParser.extractId('https://www.youtube.com'), isNull);
    });

    test('ids of the wrong length', () {
      expect(YouTubeUrlParser.extractId('https://youtu.be/tooshort'), isNull);
      expect(
        YouTubeUrlParser.extractId('https://youtu.be/waaaaaytoolongforanid'),
        isNull,
      );
    });

    test('ids containing characters outside the id alphabet', () {
      expect(YouTubeUrlParser.extractId('https://youtu.be/abc!@#\$%^&'), isNull);
    });

    test('plain prose', () {
      expect(YouTubeUrlParser.extractId('how to bench press'), isNull);
    });
  });

  group('isValidId', () {
    test('exactly 11 valid characters', () {
      expect(YouTubeUrlParser.isValidId(id), isTrue);
      expect(YouTubeUrlParser.isValidId('0123456789a'), isTrue);
    });

    test('anything else', () {
      expect(YouTubeUrlParser.isValidId(null), isFalse);
      expect(YouTubeUrlParser.isValidId(''), isFalse);
      expect(YouTubeUrlParser.isValidId('short'), isFalse);
      expect(YouTubeUrlParser.isValidId('twelvechars1'), isFalse);
      expect(YouTubeUrlParser.isValidId('has space12'), isFalse);
    });
  });

  test('watchUrl builds a canonical link', () {
    expect(YouTubeUrlParser.watchUrl(id), 'https://www.youtube.com/watch?v=$id');
    // Round trip: the canonical URL parses back to the same id.
    expect(YouTubeUrlParser.extractId(YouTubeUrlParser.watchUrl(id)), id);
  });
}
