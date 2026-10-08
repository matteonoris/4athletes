import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Only app-scoped cache copies are removed. Gallery/Downloads/Health stores
/// are outside this directory; links are never followed.
Future<void> clearTemporaryAccountMedia(Directory directory) async {
  const extensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.webp',
    '.pdf'
  };
  if (!await directory.exists()) return;
  await for (final entry
      in directory.list(recursive: true, followLinks: false)) {
    if (entry is File && extensions.any(entry.path.toLowerCase().endsWith)) {
      await entry.delete();
    }
  }
}

Future<void> clearDeletedAccountDeviceCache() async {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await clearTemporaryAccountMedia(await getTemporaryDirectory());
  }
}
