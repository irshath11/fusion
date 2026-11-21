import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'admin_cubit.dart';
import '../domain/office_entity.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/custom_text_field.dart';

class OfficeManagementScreen extends StatelessWidget {
  const OfficeManagementScreen({super.key});

  void _showGpsResultDialog(BuildContext context, LocationDataResult loc) {
    final bool isError = loc.address.contains('Permission Denied') ||
        loc.address.contains('Disabled') ||
        loc.address.contains('GPS Error') ||
        loc.address.contains('Timeout');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: isError ? Colors.orange : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isError ? 'GPS Signal Warning' : 'GPS Captured Successfully',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isError) ...[
              Text(
                loc.address,
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please turn on GPS/Location services on your device and ensure location permission is allowed.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...[
              Text('Latitude: ${loc.latitude.toStringAsFixed(6)}'),
              const SizedBox(height: 4),
              Text('Longitude: ${loc.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 4),
              Text('Accuracy: ±${loc.accuracy.toStringAsFixed(1)}m'),
              const Divider(height: 16),
              Text(
                'Address:\n${loc.address}',
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (isError)
            OutlinedButton.icon(
              icon: const Icon(Icons.location_on_rounded, size: 18),
              label: Text(loc.address.contains('Permission')
                  ? 'Open App Settings'
                  : 'Turn On Location'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                if (loc.address.contains('Permission')) {
                  Geolocator.openAppSettings();
                } else {
                  Geolocator.openLocationSettings();
                }
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? Colors.orange : AppColors.primary,
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOfficeForm(BuildContext context, [OfficeEntity? office]) {
    final nameController =
        TextEditingController(text: office?.name ?? 'Store - 12');
    final addressController = TextEditingController(
        text: office?.address ??
            'Store - 12 - As Sakeenah 2 St - Musaffah - M12 - Abu Dhabi');
    final latController =
        TextEditingController(text: (office?.latitude ?? 24.365500).toString());
    final lngController = TextEditingController(
        text: (office?.longitude ?? 54.500531).toString());
    final radiusController = TextEditingController(
        text: (office?.geofenceRadiusMeters ?? 200.0).toString());

    bool isLocating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      office == null
                          ? 'Add Office Station'
                          : 'Edit Office Details',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    CustomTextField(
                        controller: nameController,
                        label: 'Office Station Name'),
                    const SizedBox(height: 12),
                    CustomTextField(
                        controller: addressController,
                        label: 'Physical Address'),
                    const SizedBox(height: 16),

                    // "Use Current Location" Button for Live GPS Capture
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isLocating
                          ? null
                          : () async {
                              setModalState(() => isLocating = true);
                              try {
                                final loc = await context
                                    .read<AdminCubit>()
                                    .captureCurrentLocationForOffice();
                                if (modalCtx.mounted) {
                                  setModalState(() {
                                    latController.text =
                                        loc.latitude.toStringAsFixed(6);
                                    lngController.text =
                                        loc.longitude.toStringAsFixed(6);
                                    if (loc.address.isNotEmpty &&
                                        !loc.address
                                            .contains('Permission Denied') &&
                                        !loc.address.contains('GPS Error')) {
                                      addressController.text = loc.address;
                                    }
                                  });
                                  _showGpsResultDialog(modalCtx, loc);
                                }
                              } catch (e) {
                                debugPrint(
                                    'Error capturing location for office: $e');
                              } finally {
                                if (modalCtx.mounted) {
                                  setModalState(() => isLocating = false);
                                }
                              }
                            },
                      icon: isLocating
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded),
                      label: Text(isLocating
                          ? 'Acquiring GPS Signal...'
                          : 'Use Current Location'),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                            child: CustomTextField(
                                controller: latController,
                                label: 'Latitude',
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: CustomTextField(
                                controller: lngController,
                                label: 'Longitude',
                                keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: radiusController,
                      label: 'Geofence Radius (Meters)',
                      hint: 'Default 200m',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        onPressed: () {
                          context.read<AdminCubit>().saveOffice(
                                id: office?.id,
                                name: nameController.text,
                                address: addressController.text,
                                latitude: double.tryParse(latController.text) ??
                                    25.2048,
                                longitude:
                                    double.tryParse(lngController.text) ??
                                        55.2708,
                                radiusMeters:
                                    double.tryParse(radiusController.text) ??
                                        200.0,
                                isDefault: office?.isDefault ?? false,
                              );
                          Navigator.pop(modalCtx);
                        },
                        child: const Text('Save Office Station'),
                      ),
                    ),
                    if (office != null && !office.isDefault) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: const Text('Delete This Office Station'),
                          onPressed: () {
                            Navigator.pop(modalCtx);
                            _confirmDeleteOffice(context, office);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteOffice(BuildContext context, OfficeEntity office) {
    if (office.isDefault) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cannot Delete Main Office',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            '${office.name} is configured as the default Main Office and central geofence for your organization.\n\nTo delete this location, please edit or create another office and mark it as the default Main Office first.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Office Station?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${office.name}" from your active office stations?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 ${office.address}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'GPS: ${office.latitude.toStringAsFixed(6)}, ${office.longitude.toStringAsFixed(6)} (Radius: ${office.geofenceRadiusMeters.toInt()}m)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Any employees currently assigned to this branch office will automatically revert to using the default Main Office.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<AdminCubit>().deleteOffice(office.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Office "${office.name}" removed successfully.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete Office'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state is AdminDataLoaded) {
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'add_office_fab',
              onPressed: () => _showOfficeForm(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_location_alt_rounded,
                  color: Colors.white),
              label: const Text('Add Office',
                  style: TextStyle(color: Colors.white)),
            ),
            body: state.offices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No office stations configured.',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.offices.length,
                    itemBuilder: (context, index) {
                      final off = state.offices[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: off.isDefault
                                ? AppColors.primary
                                : AppColors.secondary,
                            child: const Icon(Icons.business_rounded,
                                color: Colors.white),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  off.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (off.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('MAIN OFFICE',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary)),
                                )
                              ]
                            ],
                          ),
                          subtitle: Text(
                              '${off.address}\nGPS: ${off.latitude.toStringAsFixed(4)}, ${off.longitude.toStringAsFixed(4)} | Geofence: ${off.geofenceRadiusMeters}m'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: AppColors.primary),
                                tooltip: 'Edit Office Details',
                                onPressed: () => _showOfficeForm(context, off),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: off.isDefault
                                      ? Colors.grey.shade400
                                      : AppColors.error,
                                ),
                                tooltip: off.isDefault
                                    ? 'Cannot delete default Main Office'
                                    : 'Delete Office',
                                onPressed: () =>
                                    _confirmDeleteOffice(context, off),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
