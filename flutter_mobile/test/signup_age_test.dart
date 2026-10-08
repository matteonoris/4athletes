import 'package:flutter_mobile/core/signup_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 4, 23, 59);

  test('accepts the fourteenth birthday and older users', () {
    expect(signupBirthDateError('2012-10-04', today: today), isNull);
    expect(signupBirthDateError('2012-10-03', today: today), isNull);
    expect(signupBirthDateError('1998-05-06', today: today), isNull);
  });

  test('rejects the day before the fourteenth birthday and younger users', () {
    expect(signupBirthDateError('2012-10-05', today: today),
        minimumSignupAgeMessage);
    expect(signupBirthDateError('2020-01-01', today: today),
        minimumSignupAgeMessage);
  });

  test('requires a real date, including when missing or in the future', () {
    for (final value in [
      '',
      'not-a-date',
      '04/10/2012',
      '2012-02-30',
      '2012-13-01',
      '2012-10-00',
      '2026-10-05',
      '2012-10-04T00:00:00Z',
    ]) {
      expect(signupBirthDateError(value, today: today), isNotNull,
          reason: value);
    }
  });

  test('does not truncate age into days or count a leap birthday early', () {
    expect(signupBirthDateError('2012-02-29', today: DateTime(2026, 2, 28)),
        minimumSignupAgeMessage);
    expect(signupBirthDateError('2012-02-29', today: DateTime(2026, 3, 1)),
        isNull);
  });
}
