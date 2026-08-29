import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;

/// Picks gallery images on Web platform using package:web and dart:js_interop (Wasm compatible).
/// Automatically downscales and compresses images to optimize DB storage.
Future<List<String>> pickGalleryImagesImpl() async {
  final completer = Completer<List<String>>();

  final uploadInput = web.document.createElement('input') as web.HTMLInputElement;
  uploadInput.type = 'file';
  uploadInput.accept = 'image/*';
  uploadInput.multiple = true;
  uploadInput.click();

  uploadInput.onchange = ((web.Event event) {
    final files = uploadInput.files;
    if (files == null || files.length == 0) {
      completer.complete([]);
      return;
    }

    final List<String> resultList = [];
    final totalFiles = files.length;
    int loaded = 0;

    for (int i = 0; i < totalFiles; i++) {
      final file = files.item(i);
      if (file == null) {
        loaded++;
        if (loaded == totalFiles) completer.complete(resultList);
        continue;
      }

      final reader = web.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onloadend = ((web.Event _) {
        final result = reader.result;
        if (result != null) {
          final jsArrayBuffer = result as JSArrayBuffer;
          final Uint8List rawBytes = jsArrayBuffer.toDart.asUint8List();
          final Uint8List optimizedBytes = _optimizeImageBytes(rawBytes);
          resultList.add(base64Encode(optimizedBytes));
        }
        loaded++;
        if (loaded == totalFiles) {
          completer.complete(resultList);
        }
      }).toJS;
    }
  }).toJS;

  return completer.future;
}

/// Downscales image to max 800px and compresses JPEG to 75% quality (~95% DB storage savings).
Uint8List _optimizeImageBytes(Uint8List inputBytes, {int maxDimension = 800, int quality = 75}) {
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
    // If decoding/processing fails, return original bytes as fallback
    return inputBytes;
  }
}
