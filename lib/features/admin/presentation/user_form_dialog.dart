import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/supabase_service.dart';
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
  bool _isLoadingDetails = false;

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
    _codeController = TextEditingController(
        text: _resolveCleanCode(user?.employeeCode, user?.fullName, user?.id));
    _designationController = TextEditingController(
        text: (user?.designation != null && user!.designation!.isNotEmpty)
            ? user.designation!
            : 'Technician');
    _departmentController = TextEditingController(
        text: (user?.department != null && user!.department!.isNotEmpty)
            ? user.department!
            : 'Field Engineering');
    _tempPasswordController = TextEditingController();

    if (user != null) {
      _selectedRole = user.role;
      _codeController.text =
          _resolveCleanCode(user.employeeCode, user.fullName, user.id);
      if (user.designation != null && user.designation!.isNotEmpty) {
        _designationController.text = user.designation!;
      }
      if (user.department != null && user.department!.isNotEmpty) {
        _departmentController.text = user.department!;
      }

      final empList = LocalDatabaseService().getEmployees();
      final empMatches = empList.where((e) =>
          e.id == user.id ||
          (e.email.isNotEmpty &&
              e.email.trim().toLowerCase() == user.email.trim().toLowerCase()));
      if (empMatches.isNotEmpty) {
        final emp = empMatches.first;
        if (emp.employeeCode.isNotEmpty &&
            !_isHexFallback(emp.employeeCode, emp.id)) {
          _codeController.text = emp.employeeCode;
        }
        if (emp.designation.isNotEmpty) {
          _designationController.text = emp.designation;
        }
        if (emp.department.isNotEmpty) {
          _departmentController.text = emp.department;
        }
        if (emp.mobileNumber.isNotEmpty) {
          _phoneController.text = emp.mobileNumber;
        }
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

      // Fetch fresh, live details from Supabase
      _fetchEmployeeDetailsFromSupabase(user);
    }
  }

  static bool _isHexFallback(String? code, String? id) {
    if (code == null || code.isEmpty) return false;
    if (id != null &&
        id.length >= 4 &&
        code.toUpperCase() == 'EMP-${id.substring(0, 4).toUpperCase()}') {
      return true;
    }
    final reg = RegExp(r'^EMP-[0-9A-Fa-f]{4}$');
    if (reg.hasMatch(code) &&
        id != null &&
        id.toLowerCase().startsWith(code.substring(4).toLowerCase())) {
      return true;
    }
    return false;
  }

  static String _resolveCleanCode(String? rawCode, String? name, String? id) {
    if (rawCode != null &&
        rawCode.trim().isNotEmpty &&
        rawCode.trim() != 'EMP-000' &&
        !_isHexFallback(rawCode.trim(), id)) {
      return rawCode.trim();
    }
    final cleanName =
        (name ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleanName.isNotEmpty) {
      final prefix = cleanName.length >= 4
          ? cleanName.substring(0, 4)
          : (cleanName.length >= 3 ? cleanName.substring(0, 3) : cleanName);
      return 'EMP-$prefix';
    }
    if (id != null && id.length >= 4) {
      return 'EMP-${id.substring(0, 4).toUpperCase()}';
    }
    return 'EMP-001';
  }

  Future<void> _fetchEmployeeDetailsFromSupabase(UserEntity user) async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final remoteEmp = await SupabaseService().fetchEmployeeDetails(user.id);
      final remoteUser =
          await SupabaseService().fetchUserByFirebaseUid(user.id);

      if (!mounted) return;

      if (remoteEmp != null) {
        if (remoteEmp.name.isNotEmpty) _nameController.text = remoteEmp.name;
        if (remoteEmp.email.isNotEmpty) _emailController.text = remoteEmp.email;
        if (remoteEmp.mobileNumber.isNotEmpty) {
          _phoneController.text = remoteEmp.mobileNumber;
        }
        if (remoteEmp.employeeCode.isNotEmpty &&
            !_isHexFallback(remoteEmp.employeeCode, user.id)) {
          _codeController.text = remoteEmp.employeeCode;
        } else if (_isHexFallback(_codeController.text, user.id)) {
          _codeController.text =
              _resolveCleanCode(null, user.fullName, user.id);
        }
        if (remoteEmp.designation.isNotEmpty) {
          _designationController.text = remoteEmp.designation;
        }
        if (remoteEmp.department.isNotEmpty) {
          _departmentController.text = remoteEmp.department;
        }
        _useDefaultOffice = remoteEmp.useDefaultOffice;
        if (!_useDefaultOffice && remoteEmp.assignedOfficeId != null) {
          _selectedOfficeId = remoteEmp.assignedOfficeId!;
          _selectedOfficeName =
              remoteEmp.assignedOfficeName ?? 'Custom Location';
        }
      }

      if (remoteUser != null) {
        _selectedRole = remoteUser.role;
        if (_nameController.text.isEmpty && remoteUser.fullName.isNotEmpty) {
          _nameController.text = remoteUser.fullName;
        }
        if (_emailController.text.isEmpty && remoteUser.email.isNotEmpty) {
          _emailController.text = remoteUser.email;
        }
        if (_phoneController.text.isEmpty && remoteUser.phoneNumber != null) {
          _phoneController.text = remoteUser.phoneNumber!;
        }
      }
    } catch (e) {
      debugPrint('Error fetching employee details from Supabase: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
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
      title: Row(
        children: [
          Expanded(
            child: Text(
                isEditing ? 'Edit User Profile' : 'Add New User / Employee'),
          ),
          if (_isLoadingDetails)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingDetails) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_sync_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fetching live employee details from Supabase...',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              key: ValueKey('role_dropdown_$_selectedRole'),
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
              key: ValueKey('location_dropdown_$_selectedOfficeId'),
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
