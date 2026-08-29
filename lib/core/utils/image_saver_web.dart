import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String?> saveImageToDeviceImpl(Uint8List bytes, String filename) async {
  try {
    final jsArrayBuffer = bytes.buffer.toJS;
    final blob = web.Blob([jsArrayBuffer].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
    return 'Downloads';
  } catch (e) {
    return null;
  }
}
