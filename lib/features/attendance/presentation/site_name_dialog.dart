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
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingSites = LocalDatabaseService().getWorkSites();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.location_city_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Enter Site Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please specify the name or location of the site you are checking in to:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Site Name / Job Location',
                  hintText: 'e.g. Musaffah Site B, Villa 402',
                  prefixIcon: const Icon(Icons.business_center_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a site name';
                  }
                  return null;
                },
              ),
              if (existingSites.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Or pick from registered sites:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: existingSites.map((site) {
                    return ActionChip(
                      avatar: const Icon(Icons.place_rounded, size: 14),
                      label: Text(site.siteName, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _controller.text = site.siteName;
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
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
