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
                  ],
                ),
              ),
            );
          },
        );
      },
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
            body: ListView.builder(
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
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
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => _showOfficeForm(context, off),
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
