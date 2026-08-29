import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

Future<String?> saveImageToDeviceImpl(Uint8List bytes, String filename) async {
  try {
    Directory? dir;
    if (!kIsWeb && Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {
          dir = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      }
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      dir = await getApplicationDocumentsDirectory();
    } else if (!kIsWeb) {
      dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    if (dir != null) {
      final savePath = '${dir.path}/$filename';
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      return savePath;
    }
  } catch (e) {
    debugPrint('Error saving file natively: $e');
  }

  // Fallback to native share/print dialog if direct file save fails
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename);
    return 'Downloads';
  } catch (_) {
    return null;
  }
}
