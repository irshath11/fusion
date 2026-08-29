import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraCaptureResult {
  final String imagePath;
  final String base64Image;
  final int compressedSizeBytes;

  CameraCaptureResult({
    required this.imagePath,
    required this.base64Image,
    required this.compressedSizeBytes,
  });
}

/// Top-level isolate worker for CPU-intensive image resizing & compression
Uint8List _compressCameraImageWorker(Uint8List rawBytes) {
  try {
    final decodedImage = img.decodeImage(rawBytes);
    if (decodedImage != null) {
      img.Image resizedImage;
      if (decodedImage.width > 480 || decodedImage.height > 480) {
        if (decodedImage.width > decodedImage.height) {
          resizedImage = img.copyResize(decodedImage, width: 480);
        } else {
          resizedImage = img.copyResize(decodedImage, height: 480);
        }
      } else {
        resizedImage = decodedImage;
      }

      final compressedBytes = img.encodeJpg(resizedImage, quality: 65);
      return Uint8List.fromList(compressedBytes);
    }
  } catch (_) {}
  return rawBytes;
}

class CameraService {
  /// Processes, downscales, and compresses camera snapshots in a background isolate
  static Future<CameraCaptureResult> processXFile(XFile file) async {
    final rawBytes = await file.readAsBytes();

    // Offload CPU heavy image decoding and resizing to background isolate
    final processedBytes = await compute(_compressCameraImageWorker, rawBytes);

    try {
      final compressedFile = File(file.path);
      if (await compressedFile.exists()) {
        await compressedFile.writeAsBytes(processedBytes);
      }
    } catch (_) {}

    final base64Image = base64Encode(processedBytes);

    return CameraCaptureResult(
      imagePath: file.path,
      base64Image: base64Image,
      compressedSizeBytes: processedBytes.length,
    );
  }

  /// Fallback live photo capture when hardware camera is not accessible
  static Future<CameraCaptureResult> captureLivePhoto() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final mockImg = img.Image(width: 120, height: 120);
    img.fill(mockImg, color: img.ColorRgb8(14, 116, 144));
    final bytes = img.encodeJpg(mockImg, quality: 60);

    return CameraCaptureResult(
      imagePath:
          '/tmp/attendance_live_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      base64Image: base64Encode(bytes),
      compressedSizeBytes: bytes.length,
    );
  }
}
