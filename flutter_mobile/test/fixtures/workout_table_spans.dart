/// Manually annotated text/geometry from the supplied Canva screenshot.
/// This fixture tests layout reconstruction, not native OCR recognition quality.
List<Map<String, dynamic>> workoutTableSpans() {
  Map<String, dynamic> span(String text, num x, num y, num width,
          [num height = 36]) =>
      {'text': text, 'left': x, 'top': y, 'width': width, 'height': height};
  return [
    span('9:06', 90, 50, 80),
    span('canva.com/design/example', 210, 186, 460),
    span(
        "Recupero tra le serie di 2'-3' minuti circa (N.B.", 100, 501, 881, 43),
    span('in qualsiasi caso il recupero dovrà essere', 143, 561, 796, 43),
    span('completo)', 438, 622, 193, 42),
    // Deliberately column-ordered, as OCR engines can emit their observations.
    span('A', 130, 775, 28),
    span('A', 130, 961, 28),
    span('A', 130, 1144, 28),
    span('A', 130, 1363, 28),
    span('A', 130, 1675, 28),
    span('A', 130, 1960, 28),
    span('5×3 (65-', 278, 744, 153),
    span('75% 1RM)', 254, 808, 194),
    span('5X2 (65-', 278, 930, 154),
    span('80% 1RM)', 254, 994, 194),
    span('4X8 (40-', 271, 1116, 155),
    span('55% 1RM)', 254, 1180, 194),
    span('5X5', 310, 1300, 73),
    span('(65%-75%', 255, 1366, 188),
    span('1RM)', 300, 1430, 100),
    span('4X6 (70%', 260, 1551, 176),
    span('1RM) /', 284, 1615, 140),
    span('10% -20%', 255, 1678, 194),
    span('del peso', 268, 1740, 161),
    span('corporeo', 256, 1804, 175),
    span('4X5 ( 70%', 255, 1929, 187),
    span('1RM)', 300, 1993, 100),
    span('6X3', 310, 2117, 73), // Exercise name cropped out of the screenshot.
    span('Squat', 685, 775, 110, 40),
    span('Stacco', 684, 961, 122, 30),
    span('Cable pull-through', 571, 1144, 362, 43),
    span('Military press', 612, 1363, 258, 42),
    span('Lat machine / Trazioni', 533, 1646, 425, 32),
    span('con zavorra', 627, 1715, 224, 23),
    span('Panca Piana', 625, 1960, 230, 30),
    span('Canva AI', 34, 2289, 120, 21),
    span('Modelli', 239, 2288, 102, 22),
    span('Elementi', 424, 2288, 121, 22),
    span('Brand', 639, 2288, 80, 22),
    span('Caricamenti', 791, 2288, 169, 22),
  ];
}
