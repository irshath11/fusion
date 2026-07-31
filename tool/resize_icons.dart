import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/company_logo.png');
  if (!file.existsSync()) {
    print('Error: company_logo.png not found');
    return;
  }
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  final sizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in sizes.entries) {
    final resized =
        img.copyResize(image, width: entry.value, height: entry.value);
    final outFile = File(entry.key);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(img.encodePng(resized));
    print('SUCCESS: Generated ${entry.key} (${entry.value}x${entry.value} px)');
  }
}
