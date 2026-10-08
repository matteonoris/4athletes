const minimumSignupAge = 14;
const minimumSignupAgeMessage =
    'Per usare 4athletes devi aver compiuto 14 anni.';

/// Validate calendar dates strictly: DateTime.parse alone normalizes bad dates.
String? signupBirthDateError(String value, {DateTime? today}) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return 'Seleziona una data di nascita valida.';
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final birthDate = DateTime(year, month, day);
  final now = today ?? DateTime.now();
  final currentDate = DateTime(now.year, now.month, now.day);
  if (birthDate.year != year ||
      birthDate.month != month ||
      birthDate.day != day ||
      birthDate.isAfter(currentDate)) {
    return 'Seleziona una data di nascita valida.';
  }
  final minimumAgeBirthday = DateTime(year + minimumSignupAge, month, day);
  return currentDate.isBefore(minimumAgeBirthday)
      ? minimumSignupAgeMessage
      : null;
}
