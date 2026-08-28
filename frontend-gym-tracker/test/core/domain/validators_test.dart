import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/domain/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts valid emails', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('first.last+tag@sub.domain.co'), isNull);
    });

    test('rejects invalid emails', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@tld'), isNotNull);
      expect(Validators.email('@nodomain.com'), isNotNull);
      expect(Validators.email('spaces in@mail.com'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('accepts anything the user types', () {
      expect(Validators.password('abcd1234'), isNull);
      expect(Validators.password('Str0ngPass!'), isNull);
      expect(Validators.password('a'), isNull); // short is allowed
      expect(Validators.password('onlyletters'), isNull); // no digit needed
      expect(Validators.password('12345678'), isNull); // no letter needed
      expect(Validators.password(' '), isNull); // even whitespace
      expect(Validators.password('p' * 500), isNull); // no upper bound
    });

    test('rejects only an absent password', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('must match original', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
      expect(Validators.confirmPassword('abc12345', 'different1'), isNotNull);
      expect(Validators.confirmPassword('', 'abc12345'), isNotNull);
    });
  });

  group('Validators.numericRange', () {
    test('enforces bounds', () {
      expect(Validators.age('13'), isNull);
      expect(Validators.age('100'), isNull);
      expect(Validators.age('12'), isNotNull);
      expect(Validators.age('101'), isNotNull);
      expect(Validators.age('abc'), isNotNull);
      expect(Validators.age(''), isNotNull);
    });

    test('accepts comma decimal separator', () {
      expect(Validators.weightKg('76,5'), isNull);
    });

    test('allowEmpty passes blanks (body fat is optional)', () {
      expect(Validators.bodyFat(''), isNull);
      expect(Validators.bodyFat(null), isNull);
      expect(Validators.bodyFat('20'), isNull);
      expect(Validators.bodyFat('2'), isNotNull);
    });
  });

  group('Validators.name', () {
    test('requires 2+ characters', () {
      expect(Validators.name('Al'), isNull);
      expect(Validators.name('A'), isNotNull);
      expect(Validators.name('  '), isNotNull);
    });
  });
}
