import '../models/workout_document_import.dart';
import 'workout_document_layout.dart';

/// Conservative parser for common Italian/English workout prescriptions.
/// OCR is fallible: retain every source line and require review before saving.
class WorkoutDocumentParser {
  static final _prescription = RegExp(
    r'(\d{1,3})\s*[x×*]\s*(\d+(?:\s*[/\-–]\s*\d+)*)(?:\s*(min\b|sec\b|s\b|km\b|m\b|["″]|\x27))?(?:\s*(\d+)\s*["″])?',
    caseSensitive: false,
  );
  static final _header = RegExp(
    r'\b(esercizi?o?|exercise|serie|series|sets|ripetizioni|rip\.?|reps|peso|kg|carico|recupero|rec\.?|rest|durata|tempo|distanza|rpe|rir)\b',
    caseSensitive: false,
  );

  static String textFromPages(List<dynamic> pages) =>
      WorkoutDocumentLayout.textFromPages(pages);

  static const _restLabel =
      r'(?:recupero|rec\.?|rest|pausa)(?:\s+(?:tra|fra)\s+le\s+serie)?(?:\s+di)?';

  static WorkoutDocumentImport parse(String text) {
    final exercises = <ImportedWorkoutExercise>[];
    final unparsed = <String>[];
    List<String> columns = [];
    String? pendingName;
    String? sharedRest;
    var restParentheses = 0;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        columns = [];
        pendingName = null;
        sharedRest = null; // A new page/section must not inherit another rest.
        restParentheses = 0;
        continue;
      }
      if (RegExp(r'^' + _restLabel + r'\s*[:=]?\s*\d', caseSensitive: false)
          .hasMatch(line)) {
        sharedRest = line;
        restParentheses =
            '('.allMatches(line).length - ')'.allMatches(line).length;
        pendingName = null;
        unparsed.add(line);
        continue;
      }
      if (sharedRest != null &&
          restParentheses > 0 &&
          !_prescription.hasMatch(line)) {
        sharedRest = '$sharedRest $line';
        restParentheses +=
            '('.allMatches(line).length - ')'.allMatches(line).length;
        unparsed.add(line);
        continue;
      }
      if (RegExp(r'^(?:giorno|day|settimana|week|scheda)\b',
              caseSensitive: false)
          .hasMatch(line)) {
        sharedRest = null;
      }
      final header =
          _header.allMatches(line).map((match) => _column(match[0]!)).toList();
      if (header.contains('name') &&
          header.contains('series') &&
          header.length >= 3 &&
          !RegExp(r'\d').hasMatch(line)) {
        columns = header;
        pendingName = null;
        continue;
      }
      final table = columns.isEmpty ? null : _tableLine(line, columns);
      var exercise =
          _parseLine(table ?? line, source: line, sharedRest: sharedRest);
      if (exercise == null &&
          pendingName != null &&
          (_prescription.hasMatch(line) ||
              RegExp(r'^\d+\s+serie\b').hasMatch(line))) {
        exercise = _parseLine('$pendingName $line',
            source: '$pendingName\n$line', sharedRest: sharedRest);
        if (exercise != null) unparsed.removeLast();
      }
      if (exercise != null && exercises.length < 100) {
        exercises.add(exercise);
        pendingName = null;
        restParentheses = 0;
      } else {
        unparsed.add(line);
        pendingName = WorkoutDocumentLayout.isExerciseName(line) &&
                RegExp(r'^[\p{L}][\p{L}\s()\-/]{2,70}$', unicode: true)
                    .hasMatch(line)
            ? line
            : null;
      }
    }
    return WorkoutDocumentImport(
        text: text, exercises: exercises, unparsedLines: unparsed);
  }

  static String _column(String value) =>
      switch (value.toLowerCase().replaceAll('.', '')) {
        'esercizio' || 'esercizi' || 'exercise' => 'name',
        'serie' || 'series' || 'sets' => 'series',
        'ripetizioni' || 'rip' || 'reps' => 'reps',
        'peso' || 'kg' || 'carico' => 'kg',
        'recupero' || 'rec' || 'rest' => 'rest',
        'durata' || 'tempo' => 'duration',
        'distanza' => 'distance',
        final other => other,
      };

  static String? _tableLine(String line, List<String> columns) {
    var cells = line.split(RegExp(r'\t+|\s{2,}|\s*\|\s*'));
    if (cells.length != columns.length && columns.first == 'name') {
      // Only infer cell boundaries when each remaining column is one token.
      final words = line.split(RegExp(r'\s+'));
      if (words.length >= columns.length &&
          words.skip(words.length - columns.length + 1).every(
              (word) => RegExp(r'^[\d.,/\-–%"″\x27]+$').hasMatch(word))) {
        cells = [
          words.take(words.length - columns.length + 1).join(' '),
          ...words.skip(words.length - columns.length + 1)
        ];
      }
    }
    if (cells.length != columns.length ||
        columns.toSet().length != columns.length) {
      return null;
    }
    final values = Map.fromIterables(columns, cells);
    if (!RegExp(r'^\d+$').hasMatch(values['series'] ?? '')) return null;
    final parts = <String>[values['name'] ?? '', '${values['series']} serie'];
    for (final entry in values.entries) {
      final value = entry.value;
      if (value == '-' || value.trim().isEmpty) continue;
      parts.add(switch (entry.key) {
        'reps' => '$value reps',
        'kg' => value.contains('%') ? value : '$value kg',
        'rest' => 'rec $value',
        'duration' => 'durata $value',
        'distance' => 'distanza $value',
        'rpe' => 'RPE $value',
        'rir' => 'RIR $value',
        _ => '',
      });
    }
    return parts.join(' ');
  }

  static ImportedWorkoutExercise? _parseLine(String input,
      {required String source, String? sharedRest}) {
    var text =
        _nameFirst(input).replaceAll(RegExp('[’′]'), "'").replaceAll('″', '"');
    if (sharedRest != null &&
        !RegExp(r'\b' + _restLabel, caseSensitive: false).hasMatch(text)) {
      text = '$text ${sharedRest.replaceAll(RegExp('[’′]'), "'")}';
      source = '$source\n$sharedRest';
    }
    final compact = _prescription.firstMatch(text);
    final seriesMatch =
        RegExp(r'\b(\d+)\s*(?:serie|series|sets)\b', caseSensitive: false)
            .firstMatch(text);
    final countFirst = RegExp(r'\b(?:serie|series|sets)\s*[:=]?\s*(\d+)\b',
            caseSensitive: false)
        .firstMatch(text);
    final seriesMarker = seriesMatch ?? countFirst;
    if (compact == null && seriesMarker == null) return null;
    final start = compact?.start ?? seriesMarker!.start;
    final name = text
        .substring(0, start)
        .trim()
        .replaceFirst(RegExp(r'^(?:[•*\-]|\d+[.)]|[A-Z]\d[.)]?)\s*'), '')
        .replaceFirst(RegExp(r'[\s:|\-]+$'), '')
        .trim();
    if (!WorkoutDocumentLayout.isExerciseName(name)) return null;
    // Do not turn circuit/week headings into exercise records.
    if (RegExp(r'^(?:circuito|circuit|giorno|day|settimana|week|scheda)\b',
            caseSensitive: false)
        .hasMatch(name)) {
      return null;
    }
    final warnings = <String>[];
    var series = int.tryParse(compact?[1] ?? seriesMarker![1]!);
    if (series == null || series < 1 || series > 50) {
      series = null;
      warnings.add('Numero di serie da verificare.');
    }
    final remaining = text.substring((compact ?? seriesMarker!).end);
    final labeledReps = RegExp(
            r'\b(\d+(?:\s*[/\-–]\s*\d+)*)\s*(?:ripetizioni|rip\.?|reps)\b',
            caseSensitive: false)
        .firstMatch(remaining);
    final repsFirst = RegExp(
            r'\b(?:ripetizioni|rip\.?|reps)\s*[:=]?\s*(\d+(?:[/\-–]\d+)*)',
            caseSensitive: false)
        .firstMatch(remaining);
    final unit = compact?[3]?.toLowerCase();
    final repsText =
        unit == null ? (compact?[2] ?? labeledReps?[1] ?? repsFirst?[1]) : null;
    var repetitions = <int>[];
    if (RegExp(r'^\s*\+\s*\d').hasMatch(remaining)) {
      warnings.add(
          'Ripetizioni combinate conservate nelle note: verifica i valori.');
    } else if (repsText != null) {
      if (RegExp(r'[\-–]').hasMatch(repsText)) {
        warnings.add(
            'Intervallo di ripetizioni: indica quelle effettivamente svolte.');
      } else {
        repetitions = repsText
            .split('/')
            .map((value) => int.tryParse(value.trim()) ?? 0)
            .toList();
        if (repetitions.any((value) => value < 1 || value > 1000) ||
            (repetitions.length > 1 && repetitions.length != series)) {
          warnings.add('Progressione delle ripetizioni da verificare.');
          repetitions = [];
        }
      }
    }
    double? duration;
    double? distance;
    if (unit != null) {
      final amount = double.tryParse(compact![2]!);
      if (unit == 'm' || unit == 'km') {
        distance = amount == null ? null : amount * (unit == 'km' ? 1000 : 1);
      } else {
        duration = amount == null
            ? null
            : amount * (unit == 'min' || unit == "'" ? 60 : 1) +
                ((unit == 'min' || unit == "'")
                    ? double.tryParse(compact[4] ?? '') ?? 0
                    : 0);
      }
    }
    duration ??= _time(text, r'(?:durata|tempo)');
    final distanceMatch = RegExp(
            r'distanza\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(km|m)?\b',
            caseSensitive: false)
        .firstMatch(text);
    distance ??= distanceMatch == null
        ? null
        : _decimal(distanceMatch[1]!)! *
            (distanceMatch[2]?.toLowerCase() == 'km' ? 1000 : 1);
    final kgMatch = RegExp(
            r'(?<![\d.,\-])(\d+(?:[.,]\d+)?(?:\s*[/\-–]\s*\d+(?:[.,]\d+)?)*)\s*kg\b',
            caseSensitive: false)
        .firstMatch(text);
    final kg = kgMatch == null ? null : _decimal(kgMatch[1]!);
    if (kgMatch != null && kg == null) {
      warnings.add(
          'Carichi variabili conservati nelle note: verifica il peso di ogni serie.');
    }
    final rpe = _labelNumber(text, 'RPE');
    final rir = _labelNumber(text, 'RIR');
    if (text.contains('%')) {
      warnings.add(
          'Carico percentuale conservato nelle note: inserisci i kg se noti.');
    }
    final rest = _time(text, _restLabel)?.round();
    if (rest == null &&
        RegExp(r'\b' + _restLabel + r'\s*[:=]?\s*\d', caseSensitive: false)
            .hasMatch(text)) {
      warnings.add(
          'Recupero variabile conservato nelle note: indica i secondi effettivi.');
    }
    if (repetitions.isEmpty && duration == null && distance == null) {
      warnings.add('Ripetizioni o durata da completare.');
    }
    return ImportedWorkoutExercise(
      name: name,
      series: series,
      repetitions: repetitions,
      kg: kg,
      restSeconds: rest,
      durationSeconds: duration,
      distanceMeters: distance,
      rpe: rpe != null && rpe >= 0 && rpe <= 10 ? rpe : null,
      rir: rir != null && rir >= 0 && rir <= 100 && rir == rir.roundToDouble()
          ? rir.toInt()
          : null,
      notes: source,
      sourceText: source,
      warnings: warnings,
    );
  }

  /// Text editing can also produce prescription-first rows without geometry.
  /// Only reorder when a separate name cell (or an unambiguous suffix) exists.
  static String _nameFirst(String input) {
    final match = _prescription.firstMatch(input);
    if (match == null) return input;
    final prefix = input.substring(0, match.start).trim();
    if (prefix.isNotEmpty && !RegExp(r'^[A-Z]\d?[.)]?$').hasMatch(prefix)) {
      return input;
    }
    bool name(String value) =>
        RegExp(r'[\p{L}]{2}', unicode: true).hasMatch(value) &&
        !RegExp(r'%|\b\d*\s*RM\b|^(?:rec|rest|pausa|kg|rpe|rir|gruppo|del peso)\b',
                caseSensitive: false)
            .hasMatch(value) &&
        !_prescription.hasMatch(value);
    final cells = input.split(RegExp(r'\t+|\s{2,}|\s*\|\s*'));
    final names = cells.where((cell) => name(cell.trim())).toList();
    if (names.length == 1 && cells.length > 1) {
      return '${names.single.trim()} ${cells.where((cell) => cell != names.single && cell.trim() != prefix).join(' ')}';
    }
    final suffix = input.substring(match.end).trim();
    final trailing =
        suffix.replaceFirst(RegExp(r'^(?:\([^)]*\)\s*)+'), '').trim();
    if (name(trailing) && !RegExp(r'\d').hasMatch(trailing)) {
      return '$trailing ${input.substring(match.start, match.end)} ${suffix.substring(0, suffix.length - trailing.length)}';
    }
    return input;
  }

  static double? _decimal(String value) =>
      double.tryParse(value.replaceAll(',', '.'));

  static double? _labelNumber(String text, String label) {
    final match = RegExp('\\b$label\\s*[:=]?\\s*(\\d+(?:[.,]\\d+)?)',
            caseSensitive: false)
        .firstMatch(text);
    return match == null ? null : _decimal(match[1]!);
  }

  static double? _time(String text, String label) {
    final match = RegExp(
            '\\b$label\\s*[:=]?\\s*(\\d+(?:[.,]\\d+)?)(?:\\s*(min(?:uti)?\\b|sec(?:ondi)?\\b|s\\b|["\x27]))?(?:\\s*(\\d+)\\s*")?',
            caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    if (RegExp(r'^\s*[/\-–]\s*\d').hasMatch(text.substring(match.end))) {
      return null;
    }
    final minutes =
        match[2]?.toLowerCase().startsWith('min') == true || match[2] == "'";
    return _decimal(match[1]!)! * (minutes ? 60 : 1) +
        (minutes ? double.tryParse(match[3] ?? '') ?? 0 : 0);
  }
}
