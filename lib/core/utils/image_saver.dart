import 'dart:typed_data';
import 'image_saver_stub.dart'
    if (dart.library.js_interop) 'image_saver_web.dart';

class ImageSaver {
  /// Saves image bytes directly to device storage / browser downloads automatically.
  /// Returns the saved file path or location string on success, or null on failure.
  static Future<String?> saveImageToDevice(Uint8List bytes, String filename) async {
    return saveImageToDeviceImpl(bytes, filename);
  }
}
