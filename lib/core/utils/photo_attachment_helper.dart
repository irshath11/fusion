import 'package:flutter/material.dart';
import '../../features/attendance/presentation/camera_capture_modal.dart';
import '../constants/app_colors.dart';
import '../services/camera_service.dart';
import 'employee_directory_helper.dart';

class PhotoAttachmentHelper {
  /// Prompts user to attach or update employee photo via Camera or Company Directory
  static Future<String?> showPhotoSourceModal(BuildContext context) async {
    final String? sourceAction = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Attach Employee Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a method to attach or update the employee photo',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Capture with Live Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Take a live portrait now'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              const Divider(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.badge_rounded, color: AppColors.success),
                ),
                title: const Text('Choose from Official Directory Photos', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select from the 28 enterprise staff photos'),
                onTap: () => Navigator.pop(ctx, 'directory'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (sourceAction == 'camera') {
      CameraCaptureResult? captured;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => CameraCaptureModal(
          stepName: 'Employee Portrait',
          onPhotoCaptured: (res) {
            captured = res;
          },
        ),
      );

      if (captured != null && captured!.base64Image.isNotEmpty) {
        return 'data:image/jpeg;base64,${captured!.base64Image}';
      }
    } else if (sourceAction == 'directory') {
      return await _showDirectoryPhotoPicker(context);
    }

    return null;
  }

  static Future<String?> _showDirectoryPhotoPicker(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final records = EmployeeDirectoryHelper.masterDirectory;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select Company Staff Photo',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap an official portrait below to assign it to this employee',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: records.length,
                    itemBuilder: (gridCtx, index) {
                      final rec = records[index];
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final idBadgeColor = isDark ? const Color(0xFF38BDF8) : AppColors.primary;
                      return InkWell(
                        onTap: () => Navigator.pop(sheetCtx, rec.photoAsset),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: idBadgeColor.withValues(alpha: isDark ? 0.35 : 0.2),
                              width: 1,
                            ),
                            color: Theme.of(context).cardColor,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                  child: Image.asset(
                                    rec.photoAsset,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: idBadgeColor.withValues(alpha: isDark ? 0.20 : 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: isDark
                                            ? Border.all(
                                                color: idBadgeColor.withValues(alpha: 0.45),
                                                width: 0.8,
                                              )
                                            : null,
                                      ),
                                      child: Text(
                                        'ID: ${rec.employeeId}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: idBadgeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      rec.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
