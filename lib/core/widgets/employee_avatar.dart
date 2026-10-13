import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/employee_photo_data.dart';

class EmployeeAvatar extends StatelessWidget {
  final String? photoUrl;
  final String fullName;
  final double radius;
  final Color? borderColor;
  final Color? badgeColor;
  final bool showEditBadge;
  final VoidCallback? onTap;

  const EmployeeAvatar({
    super.key,
    this.photoUrl,
    required this.fullName,
    this.radius = 22,
    this.borderColor,
    this.badgeColor,
    this.showEditBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double size = radius * 2;
    final effectiveBorderColor = borderColor ?? AppColors.primary;
    final fallbackInitial = fullName.trim().isNotEmpty
        ? fullName.trim()[0].toUpperCase()
        : 'E';

    Widget imageContent = _buildImage(photoUrl, fallbackInitial, effectiveBorderColor);

    Widget avatarCore = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (badgeColor ?? effectiveBorderColor).withValues(alpha: 0.12),
        border: Border.all(
          color: effectiveBorderColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: ClipOval(child: imageContent),
    );

    if (showEditBadge || onTap != null) {
      avatarCore = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCore,
          if (showEditBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarCore,
      );
    }

    return avatarCore;
  }

  Widget _buildImage(String? url, String initial, Color color) {
    if (url == null || url.trim().isEmpty) {
      return _buildFallback(initial, color);
    }

    final cleanUrl = url.trim();

    // 1. Base64 Image
    if (cleanUrl.startsWith('data:image') || cleanUrl.length > 500) {
      try {
        String base64Data = cleanUrl;
        if (cleanUrl.contains(',')) {
          base64Data = cleanUrl.split(',').last;
        }
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(initial, color),
        );
      } catch (_) {
        return _buildFallback(initial, color);
      }
    }

    // 2. Embedded Enterprise Staff Photo (Direct memory decoding - 100% reliable on Web, Mobile, Desktop)
    final embeddedB64 = EmployeePhotoData.getBase64(cleanUrl);
    if (embeddedB64 != null && embeddedB64.isNotEmpty) {
      try {
        final bytes = base64Decode(embeddedB64);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(initial, color),
        );
      } catch (_) {}
    }

    // 3. Network URL
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return Image.network(
        cleanUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(initial, color),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: radius * 0.8,
              height: radius * 0.8,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    // 4. Local File
    if (cleanUrl.startsWith('/') || cleanUrl.contains('/data/user/') || cleanUrl.contains('file://')) {
      try {
        final filePath = cleanUrl.replaceFirst('file://', '');
        final file = File(filePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(initial, color),
          );
        }
      } catch (_) {}
    }

    // 5. Bundled Asset
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          final fallbackB64 = EmployeePhotoData.getBase64(cleanUrl);
          if (fallbackB64 != null) {
            try {
              final bytes = base64Decode(fallbackB64);
              return Image.memory(bytes, fit: BoxFit.cover);
            } catch (_) {}
          }
          return _buildFallback(initial, color);
        },
      );
    }

    return _buildFallback(initial, color);
  }

  Widget _buildFallback(String initial, Color color) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
          color: color,
        ),
      ),
    );
  }
}
