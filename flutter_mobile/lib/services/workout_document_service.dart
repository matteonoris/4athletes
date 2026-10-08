import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/workout_document_import.dart';
import '../utils/workout_document_parser.dart';

enum WorkoutDocumentSource { camera, gallery, pdf }

class WorkoutDocumentService {
  static const channel = MethodChannel('com.4athletes/workout_document');
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<WorkoutDocumentImport?> read(WorkoutDocumentSource source) async {
    final XFile? file;
    if (source == WorkoutDocumentSource.pdf) {
      file = await openFile(acceptedTypeGroups: const [
        XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
            uniformTypeIdentifiers: ['com.adobe.pdf']),
      ]);
    } else {
      file = await ImagePicker().pickImage(
        source: source == WorkoutDocumentSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
        requestFullMetadata: false,
      );
    }
    if (file == null) return null;
    if (await file.length() > 15 * 1024 * 1024) {
      throw const FormatException('Scegli un documento di massimo 15 MB.');
    }
    final pages = await channel.invokeListMethod<dynamic>('recognize', {
      'path': file.path,
      'isPdf': source == WorkoutDocumentSource.pdf,
    });
    final text = WorkoutDocumentParser.textFromPages(pages ?? []);
    if (text.trim().isEmpty) {
      throw const FormatException(
          'Nessun testo leggibile. Prova una foto più nitida e ben illuminata.');
    }
    return WorkoutDocumentParser.parse(text);
  }
}
