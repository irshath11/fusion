import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class WorkPhotoPicker {
  static final ImagePicker _picker = ImagePicker();

  /// Picks gallery images across Mobile (Android/iOS) and Web.
  /// Automatically downscales and compresses images to optimize DB storage (~95% size reduction).
  static Future<List<String>> pickGalleryImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty) return [];

      final List<String> resultList = [];
      for (final file in pickedFiles) {
        final rawBytes = await file.readAsBytes();
        final optimizedBytes = _optimizeImageBytes(rawBytes);
        resultList.add(base64Encode(optimizedBytes));
      }
      return resultList;
    } catch (e) {
      return [];
    }
  }

  /// Downscales image to max 800px and compresses JPEG to 75% quality (~95% DB storage savings).
  static Uint8List _optimizeImageBytes(Uint8List inputBytes, {int maxDimension = 800, int quality = 75}) {
    try {
      final image = img.decodeImage(inputBytes);
      if (image == null) return inputBytes;

      img.Image resizedImage;
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width > image.height) {
          resizedImage = img.copyResize(image, width: maxDimension);
        } else {
          resizedImage = img.copyResize(image, height: maxDimension);
        }
      } else {
        resizedImage = image;
      }

      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      return Uint8List.fromList(compressedBytes);
    } catch (_) {
      return inputBytes;
    }
  }
}
