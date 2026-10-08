import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_mobile/services/workout_document_service.dart';
import 'package:flutter_mobile/utils/workout_document_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native OCR reads a transparent PNG and every PDF page',
      (tester) async {
    // Synthetic files only: no sign-in, live user data or third-party renderer.
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Test importazione scheda'))));
    final directory =
        await Directory.systemTemp.createTemp('workout_ocr_test_');
    try {
      final document = pw.Document();
      const lines = ['Squat 3 x 10 40 kg rec 90s', 'Plank 3 x 30 sec rec 20s'];
      for (final line in lines) {
        document.addPage(pw.Page(
            build: (_) =>
                pw.Text(line, style: const pw.TextStyle(fontSize: 24))));
      }
      final pdf = await File('${directory.path}/workout.pdf')
          .writeAsBytes(await document.save());
      final recording = ui.PictureRecorder();
      final canvas = Canvas(recording);
      final text = TextPainter(
          text: TextSpan(
              text: lines[0],
              style: const TextStyle(fontSize: 40, color: Colors.black)),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, const Offset(30, 40));
      final picture = recording.endRecording();
      final bitmap =
          await picture.toImage(1000, 150).timeout(const Duration(seconds: 30));
      final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      final image = await File('${directory.path}/workout.png')
          .writeAsBytes(png!.buffer.asUint8List());
      bitmap.dispose();
      picture.dispose();
      text.dispose();
      for (final file in [image, pdf]) {
        final pages = await WorkoutDocumentService.channel
            .invokeListMethod<dynamic>('recognize', {
          'path': file.path,
          'isPdf': file == pdf,
        }).timeout(const Duration(seconds: 90));
        final result = WorkoutDocumentParser.parse(
            WorkoutDocumentParser.textFromPages(pages!));
        expect(result.exercises, isNotEmpty,
            reason: 'OCR ${file.path}: ${result.text}; spans: $pages');
        expect(result.exercises.first.name, 'Squat');
        expect(result.exercises.first.series, 3);
        expect(result.exercises.first.repetitions, [10]);
        expect(result.exercises.first.kg, 40);
        expect(result.exercises.first.restSeconds, 90);
        if (file == pdf) {
          expect(result.exercises.length, 2);
          expect(result.exercises.last.durationSeconds, 30);
        }
      }
    } finally {
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
