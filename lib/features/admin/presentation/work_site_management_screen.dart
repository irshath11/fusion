import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_cubit.dart';
import '../domain/work_site_entity.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';

class WorkSiteManagementScreen extends StatelessWidget {
  const WorkSiteManagementScreen({super.key});

  void _showSiteForm(BuildContext context, [WorkSiteEntity? site]) {
    final nameController = TextEditingController(text: site?.siteName ?? 'Dubai Harbor Construction Site');
    final clientController = TextEditingController(text: site?.clientName ?? 'Meraas Real Estate');
    final addressController = TextEditingController(text: site?.address ?? 'Dubai Marina Coastline');
    final latController = TextEditingController(text: (site?.latitude ?? 25.0772).toString());
    final lngController = TextEditingController(text: (site?.longitude ?? 55.1332).toString());
    final radiusController = TextEditingController(text: (site?.radiusMeters ?? 300.0).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalCtx) {
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
                const SizedBox(height: 12),
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state is AdminDataLoaded) {
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
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
