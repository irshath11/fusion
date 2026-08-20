import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'admin_cubit.dart';
import '../domain/work_site_entity.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/custom_text_field.dart';

class WorkSiteManagementScreen extends StatelessWidget {
  const WorkSiteManagementScreen({super.key});

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
              isError ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: isError ? Colors.orange : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isError ? 'GPS Signal Warning' : 'GPS Captured Successfully',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
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
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (isError)
            OutlinedButton.icon(
              icon: const Icon(Icons.location_on_rounded, size: 18),
              label: Text(loc.address.contains('Permission') ? 'Open App Settings' : 'Turn On Location'),
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

  void _showSiteForm(BuildContext context, [WorkSiteEntity? site]) {
    final nameController = TextEditingController(text: site?.siteName ?? 'Dubai Harbor Construction Site');
    final clientController = TextEditingController(text: site?.clientName ?? 'Meraas Real Estate');
    final addressController = TextEditingController(text: site?.address ?? 'Dubai Marina Coastline');
    final latController = TextEditingController(text: (site?.latitude ?? 25.0772).toString());
    final lngController = TextEditingController(text: (site?.longitude ?? 55.1332).toString());
    final radiusController = TextEditingController(text: (site?.radiusMeters ?? 300.0).toString());

    bool isLocating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      site == null ? 'Register Work Site' : 'Edit Work Site',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    CustomTextField(controller: nameController, label: 'Work Site Name'),
                    const SizedBox(height: 12),
                    CustomTextField(controller: clientController, label: 'Client Name'),
                    const SizedBox(height: 12),
                    CustomTextField(controller: addressController, label: 'Site Location Address'),
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
                                        !loc.address.contains('Permission Denied') &&
                                        !loc.address.contains('GPS Error')) {
                                      addressController.text = loc.address;
                                    }
                                  });
                                   _showGpsResultDialog(modalCtx, loc);
                                }
                              } catch (e) {
                                debugPrint('Error capturing location for site: $e');
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
                        Expanded(child: CustomTextField(controller: latController, label: 'Latitude', keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: CustomTextField(controller: lngController, label: 'Longitude', keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(controller: radiusController, label: 'Site Geofence Radius (Meters)', keyboardType: TextInputType.number),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {
                          context.read<AdminCubit>().saveWorkSite(
                                id: site?.id,
                                name: nameController.text,
                                clientName: clientController.text,
                                address: addressController.text,
                                latitude: double.tryParse(latController.text) ?? 25.0772,
                                longitude: double.tryParse(lngController.text) ?? 55.1332,
                                radius: double.tryParse(radiusController.text) ?? 300.0,
                              );
                          Navigator.pop(modalCtx);
                        },
                        child: const Text('Save Work Site'),
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
              heroTag: 'add_work_site_fab',
              onPressed: () => _showSiteForm(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_location_rounded, color: Colors.white),
              label: const Text('Add Work Site', style: TextStyle(color: Colors.white)),
            ),
            body: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.workSites.length,
              itemBuilder: (context, index) {
                final site = state.workSites[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.secondary,
                      child: Icon(Icons.construction_rounded, color: Colors.white),
                    ),
                    title: Text(site.siteName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Client: ${site.clientName}\nAddress: ${site.address} | Radius: ${site.radiusMeters}m'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => _showSiteForm(context, site),
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
