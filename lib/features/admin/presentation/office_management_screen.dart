import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_cubit.dart';
import '../domain/office_entity.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';

class OfficeManagementScreen extends StatelessWidget {
  const OfficeManagementScreen({super.key});

  void _showOfficeForm(BuildContext context, [OfficeEntity? office]) {
    final nameController =
        TextEditingController(text: office?.name ?? '');
    final addressController =
        TextEditingController(text: office?.address ?? '');
    final latController =
        TextEditingController(text: office != null ? office.latitude.toString() : '');
    final lngController =
        TextEditingController(text: office != null ? office.longitude.toString() : '');
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
                              final loc = await context
                                  .read<AdminCubit>()
                                  .captureCurrentLocationForOffice();
                              setModalState(() {
                                latController.text =
                                    loc.latitude.toStringAsFixed(6);
                                lngController.text =
                                    loc.longitude.toStringAsFixed(6);
                                addressController.text = loc.address;
                                isLocating = false;
                              });
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
                        Text(off.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        if (off.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
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
