import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../database/local_database_service.dart';

class SiteNameDialog extends StatefulWidget {
  const SiteNameDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SiteNameDialog(),
    );
  }

  @override
  State<SiteNameDialog> createState() => _SiteNameDialogState();
}

class _SiteNameDialogState extends State<SiteNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customDetailController = TextEditingController();

  static const List<String> _predefinedSites = [
    'RELAAM (AMC)',
    'RELAAM (WO)',
    'CARRIER',
    'MOPA',
    'MPM',
    'ELV',
    'OTHERS (AMC)',
    'OTHERS (WO)',
  ];

  String? _selectedSite;

  @override
  void initState() {
    super.initState();
    _selectedSite = _predefinedSites.first;
  }

  @override
  void dispose() {
    _customDetailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final registeredSites = LocalDatabaseService().getWorkSites();
    final List<String> allSiteOptions = List.from(_predefinedSites);
    for (final s in registeredSites) {
      final name = s.siteName.trim();
      if (name.isNotEmpty && !allSiteOptions.contains(name)) {
        allSiteOptions.add(name);
      }
    }

    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final fieldBgColor = isDark ? const Color(0xFF111726) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.business_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Work Site',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose the client project or field facility for your site visit log:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSite,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Site / Project Name',
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.domain_rounded,
                        color: AppColors.primary, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor, width: 0.8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: fieldBgColor,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  ),
                  items: allSiteOptions.map((site) {
                    return DropdownMenuItem<String>(
                      value: site,
                      child: Text(
                        site,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedSite = value),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Please select a site' : null,
                ),
                if (_selectedSite != null &&
                    _selectedSite!.startsWith('OTHERS')) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _customDetailController,
                    style: GoogleFonts.plusJakartaSans(
                        color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Specify Location (Optional)',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                      ),
                      hintText: 'e.g. Building 12, Villa 402',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.edit_location_alt_rounded,
                          color: AppColors.primary, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: fieldBgColor,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: 'Confirm Site',
                        icon: Icons.check_rounded,
                        height: 48,
                        borderRadius: 12,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final selected = _selectedSite!;
                            final extra = _customDetailController.text.trim();
                            final finalSiteName =
                                extra.isNotEmpty ? '$selected - $extra' : selected;
                            Navigator.pop(context, finalSiteName);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
