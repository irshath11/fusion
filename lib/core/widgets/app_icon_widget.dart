import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Resilient App Icon Widget that loads the launcher icon from disk,
/// memory, or asset bundle with zero-crash fallbacks.
class AppIconWidget extends StatefulWidget {
  final double size;
  final double borderRadius;

  const AppIconWidget({
    super.key,
    this.size = 84.0,
    this.borderRadius = 22.0,
  });

  @override
  State<AppIconWidget> createState() => _AppIconWidgetState();
}

class _AppIconWidgetState extends State<AppIconWidget> {
  Uint8List? _iconBytes;

  @override
  void initState() {
    super.initState();
    _loadIconBytes();
  }

  void _loadIconBytes() {
    try {
      // 1. Check direct android res location (works on host machine during development)
      final androidResFile = File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');
      if (androidResFile.existsSync()) {
        final bytes = androidResFile.readAsBytesSync();
        // Sync to assets/images/app_icon.png for permanent bundling
        try {
          final assetTarget = File('assets/images/app_icon.png');
          if (!assetTarget.existsSync() || assetTarget.lengthSync() != bytes.length) {
            assetTarget.writeAsBytesSync(bytes);
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _iconBytes = bytes;
          });
          return;
        }
      }

      // 2. Check assets/images/app_icon.png on disk
      final assetsIconFile = File('assets/images/app_icon.png');
      if (assetsIconFile.existsSync()) {
        final bytes = assetsIconFile.readAsBytesSync();
        if (mounted) {
          setState(() {
            _iconBytes = bytes;
          });
          return;
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (_iconBytes != null) {
      imageWidget = Image.memory(
        _iconBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Image.asset(
        'assets/images/app_icon.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) {
          return Image.asset(
            'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (c2, e2, s2) {
              return Image.asset(
                'assets/images/company_logo.png',
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (c3, e3, s3) {
                  return Container(
                    width: widget.size,
                    height: widget.size,
                    color: AppColors.primary,
                    child: const Icon(
                      Icons.apps_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  );
                },
              );
            },
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: imageWidget,
    );
  }
}
