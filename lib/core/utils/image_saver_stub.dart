import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const MethodChannel _mediaScannerChannel =
    MethodChannel('com.fusion.attendance/media_scanner');

Future<void> _scanFileNative(String path) async {
  if (!Platform.isAndroid) return;
  try {
    await _mediaScannerChannel.invokeMethod('scanFile', {'filePath': path});
  } catch (e) {
    debugPrint('Native MediaScanner error: $e');
  }
}

/// Saves image bytes directly to local storage / gallery without launching PDF or share dialogs.
Future<String?> saveImageToDeviceImpl(Uint8List bytes, String filename) async {
  try {
    String? primarySavedPath;

    if (Platform.isAndroid) {
      // 1. Save directly to public Pictures folder ("FusionAttendance" album)
      // This immediately shows up in Android Gallery and Google Photos.
      final picturesDir = Directory('/storage/emulated/0/Pictures');
      if (picturesDir.existsSync()) {
        final albumDir = Directory('${picturesDir.path}/FusionAttendance');
        if (!albumDir.existsSync()) {
          try {
            albumDir.createSync(recursive: true);
          } catch (_) {}
        }
        final targetDir = albumDir.existsSync() ? albumDir : picturesDir;
        final file = File('${targetDir.path}/$filename');
        await file.writeAsBytes(bytes);
        primarySavedPath = file.path;

        // Instantly register with native Android MediaScannerConnection
        await _scanFileNative(file.path);
      }

      // 2. Save directly to public Downloads folder as secondary location
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) {
        final file = File('${downloadDir.path}/$filename');
        await file.writeAsBytes(bytes);
        primarySavedPath ??= file.path;

        await _scanFileNative(file.path);
      }

      // 3. Fallback to external app storage directory
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final file = File('${extDir.path}/$filename');
          await file.writeAsBytes(bytes);
          primarySavedPath ??= file.path;

          await _scanFileNative(file.path);
        }
      } catch (e) {
        debugPrint('Error saving to external storage: $e');
      }
    } else {
      // iOS / Desktop / Other platforms
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$filename');
        await file.writeAsBytes(bytes);
        primarySavedPath = file.path;
      } catch (e) {
        debugPrint('Error saving to docs dir: $e');
      }

      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final file = File('${downloadsDir.path}/$filename');
          await file.writeAsBytes(bytes);
          primarySavedPath ??= file.path;
        }
      } catch (e) {
        debugPrint('Error saving to downloads dir: $e');
      }
    }

    // Ultimate fallback if no primary path set
    if (primarySavedPath == null) {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/$filename');
      await file.writeAsBytes(bytes);
      primarySavedPath = file.path;
    }

    debugPrint('Saved photo to device: $primarySavedPath');
    return primarySavedPath;
  } catch (e) {
    debugPrint('Error saving photo to device: $e');
    return null;
  }
}
