import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_cubit.dart';
import '../domain/work_site_entity.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/animated_widgets.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isError
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: isError ? AppColors.warning : AppColors.success,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isError ? 'GPS Signal Notice' : 'GPS Telemetry Acquired',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700),
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
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Please ensure location services are enabled on this handset.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            ] else ...[
              Text('Latitude: ${loc.latitude.toStringAsFixed(6)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Longitude: ${loc.longitude.toStringAsFixed(6)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Accuracy: ±${loc.accuracy.toStringAsFixed(1)}m',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13)),
              const Divider(height: 16),
              Text(
                'Geocoded Address:\n${loc.address}',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ],
          ],
        ),
        actions: [
          if (isError)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                if (loc.address.contains('Permission')) {
                  Geolocator.openAppSettings();
                } else {
                  Geolocator.openLocationSettings();
                }
              },
              child: Text(
                loc.address.contains('Permission')
                    ? 'App Settings'
                    : 'Turn On GPS',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          AppButton(
            text: 'Dismiss',
            width: 100,
            height: 38,
            borderRadius: 8,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    );
  }

  void _showSiteForm(BuildContext context, [WorkSiteEntity? site]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(
        text: site?.siteName ?? 'Dubai Harbor Construction Site');
    final clientController =
        TextEditingController(text: site?.clientName ?? 'Meraas Real Estate');
    final addressController =
        TextEditingController(text: site?.address ?? 'Dubai Marina Coastline');
    final latController =
        TextEditingController(text: (site?.latitude ?? 25.0772).toString());
    final lngController =
        TextEditingController(text: (site?.longitude ?? 55.1332).toString());
    final radiusController =
        TextEditingController(text: (site?.radiusMeters ?? 300.0).toString());

    bool isLocating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 22,
                left: 22,
                right: 22,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          site == null
                              ? 'Register Work Site'
                              : 'Edit Work Site',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    CustomTextField(
                        controller: nameController, label: 'Work Site Name'),
                    const SizedBox(height: 12),
                    CustomTextField(
                        controller: clientController, label: 'Client Name'),
                    const SizedBox(height: 12),
                    CustomTextField(
                        controller: addressController,
                        label: 'Site Location Address'),
                    const SizedBox(height: 16),

                    AppButton(
                      text: isLocating
                          ? 'Acquiring GPS Signal...'
                          : 'Capture Live GPS Coordinates',
                      variant: AppButtonVariant.secondary,
                      isLoading: isLocating,
                      icon: Icons.my_location_rounded,
                      height: 46,
                      borderRadius: 12,
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
                              } finally {
                                if (modalCtx.mounted) {
                                  setModalState(() => isLocating = false);
                                }
                              }
                            },
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
                      hint: 'Default 300m',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      text: 'Save Work Site',
                      icon: Icons.check_rounded,
                      onPressed: () {
                        context.read<AdminCubit>().saveWorkSite(
                              id: site?.id,
                              siteName: nameController.text,
                              clientName: clientController.text,
                              address: addressController.text,
                              latitude:
                                  double.tryParse(latController.text) ??
                                      25.0772,
                              longitude:
                                  double.tryParse(lngController.text) ??
                                      55.1332,
                              radiusMeters:
                                  double.tryParse(radiusController.text) ??
                                      300.0,
                            );
                        Navigator.pop(modalCtx);
                      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state is AdminDataLoaded) {
          return Scaffold(
            backgroundColor:
                isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'add_site_fab',
              onPressed: () => _showSiteForm(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_business_rounded, color: Colors.white),
              label: Text(
                'Register Site',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            body: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: state.workSites.length,
              itemBuilder: (context, index) {
                final site = state.workSites[index];
                return GlassSurfaceCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: AppColors.secondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              site.siteName,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Client: ${site.clientName}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              site.address,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showSiteForm(context, site),
                      ),
                    ],
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
