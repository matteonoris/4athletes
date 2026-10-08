import 'dart:math' as math;

import '../data/exercises.dart';

/// Known names/aliases resolve identity. Similar names are suggestions only:
/// variants must not accidentally share historical records or one-rep maxes.
class ExerciseCatalogMatcher {
  static String normalize(String value) {
    var text = value.toLowerCase();
    const accents = {
      'à': 'a',
      'á': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'í': 'i',
      'ò': 'o',
      'ó': 'o',
      'ù': 'u',
      'ú': 'u'
    };
    for (final entry in accents.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static final _names = {
    for (final exercise in exerciseDatabase)
      exercise.id: [exercise.id, exercise.name, ...exercise.aliases]
          .map(normalize)
          .toSet()
          .toList(),
  };

  static ExerciseDef? byId(String id) =>
      exerciseDatabase.where((exercise) => exercise.id == id).firstOrNull;

  static ExerciseDef? match(String name) {
    final query = normalize(name).replaceAll(' ', '');
    if (query.isEmpty) return null;
    final matches = exerciseDatabase.where((exercise) => _names[exercise.id]!
        .any((alias) => alias.replaceAll(' ', '') == query));
    return matches.length == 1 ? matches.single : null;
  }

  static List<ExerciseDef> search(String name, {int? limit}) {
    final query = normalize(name);
    final ranked = <(ExerciseDef, double)>[];
    for (final exercise in exerciseDatabase) {
      final score = query.isEmpty
          ? 1.0
          : _names[exercise.id]!
              .map((alias) => _similarity(query, alias))
              .reduce(math.max);
      if (score >= .55) ranked.add((exercise, score));
    }
    ranked.sort((a, b) {
      final comparison = b.$2.compareTo(a.$2);
      return comparison == 0 ? a.$1.name.compareTo(b.$1.name) : comparison;
    });
    return ranked
        .take(limit ?? ranked.length)
        .map((entry) => entry.$1)
        .toList();
  }

  static double _similarity(String query, String alias) {
    final compactQuery = query.replaceAll(' ', '');
    final compactAlias = alias.replaceAll(' ', '');
    if (compactQuery == compactAlias) return 1;
    if (alias.contains(query)) return .9;
    if (alias.length >= 4 && ' $query '.contains(' $alias ')) return .8;
    final queryTokens = query.split(' ').toSet();
    final aliasTokens = alias.split(' ').toSet();
    final overlap = queryTokens.intersection(aliasTokens).length;
    final tokenScore = 2 * overlap / (queryTokens.length + aliasTokens.length);
    if (compactQuery.length > 100) return tokenScore;
    // OCR mistakes rank candidates but never establish an automatic identity.
    final characterScore = 1 -
        _distance(compactQuery, compactAlias) /
            math.max(compactQuery.length, compactAlias.length);
    return math.max(tokenScore, characterScore * .95);
  }

  static int _distance(String a, String b) {
    var previous = List.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = <int>[i + 1];
      for (var j = 0; j < b.length; j++) {
        current.add(math.min(math.min(current[j] + 1, previous[j + 1] + 1),
            previous[j] + (a[i] == b[j] ? 0 : 1)));
      }
      previous = current;
    }
    return previous.last;
  }
}
