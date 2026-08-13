import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final fieldBgColor = isDark ? AppColors.surfaceDark : Colors.grey.shade100;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.location_city_rounded,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Text(
            'Select Site Name',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please select the site location for your check-in:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSite,
                isExpanded: true,
                dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Site / Project Name',
                  labelStyle: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  prefixIcon: Icon(
                    Icons.business_center_rounded,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: fieldBgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: allSiteOptions.map((site) {
                  return DropdownMenuItem<String>(
                    value: site,
                    child: Text(
                      site,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSite = value;
                  });
                },
                validator: (val) => val == null || val.isEmpty ? 'Please select a site' : null,
              ),
              if (_selectedSite != null && _selectedSite!.startsWith('OTHERS')) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _customDetailController,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Specify Location Details (Optional)',
                    labelStyle: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    hintText: 'e.g. Building 12, Villa 402',
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark.withValues(alpha: 0.6) : Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(
                      Icons.edit_location_alt_rounded,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: fieldBgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final selected = _selectedSite!;
              final extra = _customDetailController.text.trim();
              final finalSiteName = extra.isNotEmpty ? '$selected - $extra' : selected;
              Navigator.pop(context, finalSiteName);
            }
          },
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Confirm Site'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
