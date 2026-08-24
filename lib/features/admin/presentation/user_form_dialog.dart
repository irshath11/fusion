import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../database/local_database_service.dart';
import '../../auth/domain/user_entity.dart';

class UserFormDialog extends StatefulWidget {
  final UserEntity? userToEdit;
  final Function({
    required String fullName,
    required String email,
    String? phoneNumber,
    required UserRole role,
    required String employeeCode,
    required String designation,
    required String department,
    String? temporaryPassword,
    required bool useDefaultOffice,
    String? assignedOfficeId,
    String? assignedOfficeName,
  }) onSubmit;

  const UserFormDialog({
    super.key,
    this.userToEdit,
    required this.onSubmit,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _codeController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _tempPasswordController;

  UserRole _selectedRole = UserRole.employee;
  bool _useDefaultOffice = true;
  String _selectedOfficeId = 'default_main';
  String _selectedOfficeName = 'Head Office (Main Office)';

  List<Map<String, String>> _availableLocations = [];

  @override
  void initState() {
    super.initState();

    final offices = LocalDatabaseService().getOffices();
    final sites = LocalDatabaseService().getWorkSites();

    _availableLocations = [
      {'id': 'default_main', 'name': 'Head Office (Main Office Check-In)'},
      ...offices
          .where((o) => !o.isDefault)
          .map((o) => {'id': o.id, 'name': 'Office: ${o.name}'}),
      ...sites.map(
          (s) => {'id': s.id, 'name': 'Site: ${s.siteName} (${s.clientName})'}),
    ];

    final user = widget.userToEdit;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _codeController = TextEditingController();
    _designationController = TextEditingController();
    _departmentController = TextEditingController();
    _tempPasswordController = TextEditingController();

    if (user != null) {
      _selectedRole = user.role;
      final empList = LocalDatabaseService().getEmployees();
      final empMatches = empList.where((e) =>
          e.id == user.id ||
          (e.email.isNotEmpty &&
              e.email.trim().toLowerCase() == user.email.trim().toLowerCase()));
      if (empMatches.isNotEmpty) {
        final emp = empMatches.first;
        _codeController.text = emp.employeeCode;
        _designationController.text = emp.designation;
        _departmentController.text = emp.department;
        _useDefaultOffice = emp.useDefaultOffice;
        if (!_useDefaultOffice && emp.assignedOfficeId != null) {
          _selectedOfficeId = emp.assignedOfficeId!;
          _selectedOfficeName = emp.assignedOfficeName ?? 'Custom Location';
        }
      } else {
        _codeController.text =
            'EMP-${1000 + DateTime.now().millisecond % 900}';
        _designationController.text = 'Technician';
        _departmentController.text = 'Field Engineering';
      }
    } else {
      _codeController.text =
          'EMP-${1000 + DateTime.now().millisecond % 900}';
      _designationController.text = 'Technician';
      _departmentController.text = 'Field Engineering';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _tempPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.userToEdit != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit User Profile' : 'Add New User / Employee'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: '',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: '',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              enabled: !isEditing,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _phoneController,
              label: 'Mobile Number',
              hint: '',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 16),
            const Text(
              'Role & Permissions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<UserRole>(
              initialValue: _selectedRole,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                  value: UserRole.employee,
                  child: Text('EMPLOYEE (Field Workforce)'),
                ),
                DropdownMenuItem(
                  value: UserRole.admin,
                  child: Text('ADMIN (Administrator Access)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Reporting & Check-In Location',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue:
                  _availableLocations.any((l) => l['id'] == _selectedOfficeId)
                      ? _selectedOfficeId
                      : 'default_main',
              isExpanded: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon:
                    Icon(Icons.location_on_outlined, color: AppColors.primary),
              ),
              items: _availableLocations.map((loc) {
                return DropdownMenuItem<String>(
                  value: loc['id'],
                  child: Text(
                    loc['name']!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedOfficeId = val;
                    _useDefaultOffice = (val == 'default_main');
                    final match =
                        _availableLocations.firstWhere((l) => l['id'] == val);
                    _selectedOfficeName = match['name']!;
                  });
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              _useDefaultOffice
                  ? '• Employee checks in at Head Office.'
                  : '• Direct site reporting: Employee checks in at $_selectedOfficeName.',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _codeController,
                    label: 'Employee Code',
                    prefixIcon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _departmentController,
                    label: 'Department',
                    prefixIcon: Icons.business_center_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _designationController,
              label: 'Designation / Title',
              prefixIcon: Icons.work_outline,
            ),
            if (!isEditing) ...[
              const SizedBox(height: 12),
              CustomTextField(
                controller: _tempPasswordController,
                label: 'Temporary Password',
                isPassword: true,
                prefixIcon: Icons.lock_clock_outlined,
              ),
              const SizedBox(height: 6),
              Text(
                'Employee must change this temporary password on first login.',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryLight),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty ||
                _emailController.text.trim().isEmpty) {
              return;
            }
            widget.onSubmit(
              fullName: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              role: _selectedRole,
              employeeCode: _codeController.text.trim(),
              designation: _designationController.text.trim(),
              department: _departmentController.text.trim(),
              temporaryPassword: _tempPasswordController.text.trim(),
              useDefaultOffice: _useDefaultOffice,
              assignedOfficeId: _useDefaultOffice ? null : _selectedOfficeId,
              assignedOfficeName:
                  _useDefaultOffice ? null : _selectedOfficeName,
            );
            Navigator.of(context).pop();
          },
          child: Text(isEditing ? 'Save Changes' : 'Create Account'),
        ),
      ],
    );
  }
}
