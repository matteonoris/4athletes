import 'dart:math' as math;

/// Reconstructs table cells before flattening OCR into editable text. A name
/// can be vertically centred beside several prescription lines, on either side.
class WorkoutDocumentLayout {
  static final _sets = RegExp(r'^(?:[A-Z]\d?[.)]?\s+)?\d{1,3}\s*[x×*]\s*\d',
      caseSensitive: false);

  static String textFromPages(List<dynamic> pages) => pages.map((page) {
        final spans = (page as List)
            .whereType<Map>()
            .expand(_splitColumns)
            .where((span) => span.text.isNotEmpty)
            .toList()
          ..sort((a, b) => a.top.compareTo(b.top));
        return _lines(_restoreCells(spans));
      }).join('\n\n');

  static List<_Span> _splitColumns(Map item) {
    final line = _Span.fromMap(item);
    final words = (item['words'] as List?)
        ?.whereType<Map>()
        .map(_Span.fromMap)
        .where((word) => word.text.isNotEmpty && word.width > 0)
        .toList();
    if (words == null || words.length < 2) return [line];
    String normalized(String text) =>
        text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized(words.map((word) => word.text).join(' ')) !=
        normalized(line.text)) {
      return [line]; // Missing word boxes must never drop recognized text.
    }
    words.sort((a, b) => a.left.compareTo(b.left));
    final groups = <List<_Span>>[
      [words.first]
    ];
    for (final word in words.skip(1)) {
      final previous = groups.last.last;
      // Native OCR sometimes joins a label, prescription and exercise into one
      // observation. Only large physical gaps denote separate table cells.
      if (word.left - previous.right >
          math.max(word.height, previous.height) * 1.25) {
        groups.add([word]);
      } else {
        groups.last.add(word);
      }
    }
    return groups.length == 1
        ? [line]
        : groups.map((group) => _Span.merge(group, ' ')).toList();
  }

  static bool _metric(String text) {
    final remainder = text
        .replaceAll(RegExp(r'\d\s*RM', caseSensitive: false), '')
        .replaceAll(
            RegExp(
                r'\b(?:kg|min|minuti|sec|secondi|s|m|km|recupero|rec|rest|pausa|rpe|rir|del|di|peso|corporeo|body\s*weight|bw)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'''[\d\s.,:;()%/\-–—+="'’′″]'''), '');
    return remainder.isEmpty;
  }

  static bool isExerciseName(String text) =>
      RegExp(r'[\p{L}]{2}', unicode: true).hasMatch(text) &&
      !_sets.hasMatch(text) &&
      !_metric(text) &&
      !RegExp(r'^(?:recupero|rest|pausa|esercizi?o?|exercise|serie|ripetizioni|giorno|day|scheda|settimana|week|circuito|circuit|completo|canva|modelli|elementi|brand|caricamenti|progetti)\b|https?://|www\.|\.com/|%|\b1\s*RM\b',
              caseSensitive: false)
          .hasMatch(text);

  static List<_Span> _restoreCells(List<_Span> spans) {
    final anchors = spans.where((span) => _sets.hasMatch(span.text)).toList();
    final used = <_Span>{};
    final restored = <_Span>[];
    for (final anchor in anchors) {
      bool sameColumn(_Span span) =>
          (span.centerX - anchor.centerX).abs() <=
          math.max(anchor.width / 2, anchor.height * 1.5);
      final next = anchors
          .where((span) => span.top > anchor.top && sameColumn(span))
          .firstOrNull;
      final cell = <_Span>[anchor];
      for (final span in spans) {
        if (span.top <= anchor.top ||
            (next != null && span.centerY >= next.top) ||
            used.contains(span) ||
            !sameColumn(span) ||
            !_metric(span.text)) {
          continue;
        }
        final last = cell.last;
        if (span.top - last.bottom <=
            math.max(last.height, span.height) * 1.5) {
          cell.add(span);
        }
      }
      final metrics = _Span.merge(cell, ' ');
      final candidates = spans.where((span) {
        if (used.contains(span) || !isExerciseName(span.text)) return false;
        final padding = math.max(anchor.height, span.height) * .7;
        final outside = span.left >= metrics.right + anchor.height * .2 ||
            span.right <= metrics.left - anchor.height * .2;
        return outside &&
            span.centerY >= metrics.top - padding &&
            span.centerY <= metrics.bottom + padding &&
            (next == null || span.centerY < next.top);
      }).toList();
      if (candidates.isEmpty) continue; // Cropped rows stay unparsed.
      double score(_Span span) =>
          (span.centerY - metrics.centerY).abs() +
          math.min((span.left - metrics.right).abs(),
                  (metrics.left - span.right).abs()) *
              .1;
      candidates.sort((a, b) => score(a).compareTo(score(b)));
      final first = candidates.first;
      final names = candidates
          .where((span) =>
              (span.centerX > metrics.centerX) ==
                  (first.centerX > metrics.centerX) &&
              span.left < first.right &&
              span.right > first.left)
          .toList();
      final name = _lines(names).replaceAll('\n', ' ').replaceAll('\t', ' ');
      final labels = spans.where((span) =>
          !used.contains(span) &&
          RegExp(r'^[A-Z]\d?[.)]?$').hasMatch(span.text) &&
          span.right < math.min(metrics.left, first.left) &&
          span.centerY >= metrics.top &&
          span.centerY <= metrics.bottom);
      final prescription = metrics.text.replaceAllMapped(
          RegExp(r'(\d[%]?)\s*([-–])\s*(\d)'),
          (match) => '${match[1]}${match[2]}${match[3]}');
      restored.add(_Span(
          '$name\t$prescription${labels.isEmpty ? '' : '\tGruppo ${labels.first.text}'}',
          metrics.left,
          metrics.top,
          metrics.width,
          anchor.height));
      used.addAll([...cell, ...names, ...labels]);
    }
    return [...spans.where((span) => !used.contains(span)), ...restored];
  }

  static String _lines(List<_Span> spans) {
    spans.sort((a, b) => a.top.compareTo(b.top));
    final rows = <List<_Span>>[];
    for (final span in spans) {
      final first = rows.lastOrNull?.first;
      if (first != null &&
          (span.centerY - first.centerY).abs() <=
              math.min(span.height, first.height) * .55) {
        rows.last.add(span);
      } else {
        rows.add([span]);
      }
    }
    return rows.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      return row.map((span) => span.text).join('\t');
    }).join('\n');
  }
}

class _Span {
  final String text;
  final double left, top, width, height;
  const _Span(this.text, this.left, this.top, this.width, this.height);
  factory _Span.fromMap(Map item) {
    double number(String key) => (item[key] as num?)?.toDouble() ?? 0;
    final text = (item['text']?.toString() ?? '').trim();
    return _Span(
        text,
        number('left'),
        number('top'),
        item['width'] == null
            ? text.length * number('height') * .5
            : number('width'),
        number('height'));
  }
  factory _Span.merge(List<_Span> spans, String separator) {
    final left = spans.map((s) => s.left).reduce(math.min);
    final top = spans.map((s) => s.top).reduce(math.min);
    return _Span(
        spans.map((s) => s.text).join(separator),
        left,
        top,
        spans.map((s) => s.right).reduce(math.max) - left,
        spans.map((s) => s.bottom).reduce(math.max) - top);
  }
  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}
