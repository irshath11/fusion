import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'user_management_cubit.dart';
import 'admin_cubit.dart';
import 'user_form_dialog.dart';
import 'ownership_transfer_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/role_permissions.dart';
import '../../../database/local_database_service.dart';
import '../../auth/domain/user_entity.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  String _searchQuery = '';
  String _selectedRoleFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final currentUser = _db.currentUser;
    final userRole = currentUser?.role ?? UserRole.employee;
    final isSuperAdmin = RolePermissions.isSuperAdmin(userRole);

    return BlocProvider(
      create: (context) => UserManagementCubit()..fetchUsers(),
      child: BlocListener<AdminCubit, AdminState>(
        listener: (context, state) {
          if (state is AdminDataLoaded) {
            try {
              context.read<UserManagementCubit>().fetchUsers();
            } catch (_) {}
          }
        },
        child: BlocConsumer<UserManagementCubit, UserManagementState>(
        listener: (context, state) {
          if (state is UserManagementActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (state is UserManagementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          List<UserEntity> users = [];
          if (state is UserManagementLoaded) {
            users = state.users;
          }

          // Apply filters
          final filteredUsers = users.where((u) {
            final q = _searchQuery.toLowerCase().trim();
            final matchesSearch = q.isEmpty ||
                u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                (u.employeeCode != null &&
                    u.employeeCode!.toLowerCase().contains(q)) ||
                (u.designation != null &&
                    u.designation!.toLowerCase().contains(q)) ||
                (u.department != null &&
                    u.department!.toLowerCase().contains(q));
            final matchesRole = _selectedRoleFilter == 'ALL' ||
                u.role.nameString == _selectedRoleFilter;
            return matchesSearch && matchesRole;
          }).toList();

          filteredUsers.sort((a, b) =>
              a.fullName.trim().toLowerCase().compareTo(b.fullName.trim().toLowerCase()));

          final candidateAdmins = users
              .where((u) => u.role == UserRole.admin && u.isActive)
              .toList();

          return Scaffold(
            appBar: AppBar(
              title: const Text('User & Employee Management'),
              centerTitle: true,
              actions: [
                if (isSuperAdmin)
                  TextButton.icon(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => OwnershipTransferDialog(
                          currentSuperAdmin: currentUser!,
                          candidateAdmins: candidateAdmins,
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.workspace_premium_rounded,
                        color: AppColors.warning, size: 18),
                    label: Text(
                      'Transfer Ownership',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'add_employee_fab',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => UserFormDialog(
                    onSubmit: ({
                      required fullName,
                      required email,
                      phoneNumber,
                      required role,
                      required employeeCode,
                      required designation,
                      required department,
                      temporaryPassword,
                      required useDefaultOffice,
                      assignedOfficeId,
                      assignedOfficeName,
                    }) {
                      context.read<UserManagementCubit>().createUser(
                            fullName: fullName,
                            email: email,
                            phoneNumber: phoneNumber,
                            role: role,
                            employeeCode: employeeCode,
                            designation: designation,
                            department: department,
                            temporaryPassword: temporaryPassword,
                            useDefaultOffice: useDefaultOffice,
                            assignedOfficeId: assignedOfficeId,
                            assignedOfficeName: assignedOfficeName,
                          );
                    },
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label:
                  const Text('Add User', style: TextStyle(color: Colors.white)),
            ),
            body: Column(
              children: [
                // Filter & Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search by name, code or email...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _selectedRoleFilter,
                        items: const [
                          DropdownMenuItem(
                              value: 'ALL', child: Text('All Roles')),
                          DropdownMenuItem(
                              value: 'SUPER_ADMIN', child: Text('Super Admin')),
                          DropdownMenuItem(
                              value: 'ADMIN', child: Text('Admins')),
                          DropdownMenuItem(
                              value: 'EMPLOYEE', child: Text('Employees')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRoleFilter = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                if (state is UserManagementLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredUsers.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No user records found matching criteria.',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredUsers.length,
                      itemBuilder: (ctx, index) {
                        final user = filteredUsers[index];
                        final isSelf = user.id == currentUser?.id;
                        final displayCode = _resolveCleanCode(
                            user.employeeCode, user.fullName, user.id);

                        Color roleBadgeColor;
                        switch (user.role) {
                          case UserRole.superAdmin:
                            roleBadgeColor = AppColors.warning;
                            break;
                          case UserRole.admin:
                            roleBadgeColor = AppColors.primary;
                            break;
                          case UserRole.employee:
                            roleBadgeColor = AppColors.success;
                            break;
                        }

                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final palette = AppTheme.currentColors;
                        final officeName = user.assignedOfficeName != null &&
                                user.assignedOfficeName!.isNotEmpty
                            ? user.assignedOfficeName!
                            : (user.useDefaultOffice
                                ? 'Default Office'
                                : 'Unassigned');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? palette.cardBorderDark
                                  : palette.cardBorderLight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Header Row: Avatar + Name & Designation + Role & Menu
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Avatar with Status Dot Indicator
                                    Stack(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: roleBadgeColor
                                                .withValues(alpha: 0.15),
                                            border: Border.all(
                                              color: roleBadgeColor
                                                  .withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            user.fullName.isNotEmpty
                                                ? user.fullName[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: roleBadgeColor,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: user.isActive
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              border: Border.all(
                                                color:
                                                    Theme.of(context).cardColor,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),

                                    // Name & Designation
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  user.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isSelf) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'You',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (user.designation != null &&
                                                    user.designation!
                                                        .isNotEmpty)
                                                ? '${user.designation}${user.department != null && user.department!.isNotEmpty ? ' • ${user.department}' : ''}'
                                                : 'Employee',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? palette.textSecondaryDark
                                                  : palette.textSecondaryLight,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Role Badge & Action Button
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: roleBadgeColor
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: roleBadgeColor
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            user.role.displayName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: roleBadgeColor,
                                            ),
                                          ),
                                        ),
                                        if (isSelf)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4.0),
                                            child: Icon(Icons.person,
                                                color: AppColors.primary,
                                                size: 20),
                                          )
                                        else
                                          PopupMenuButton<String>(
                                            icon: const Icon(
                                                Icons.more_vert_rounded,
                                                size: 20),
                                            onSelected: (val) {
                                              final cubit = context.read<
                                                  UserManagementCubit>();
                                              if (val == 'edit') {
                                                showDialog(
                                                  context: context,
                                                  builder: (dialogCtx) =>
                                                      UserFormDialog(
                                                    userToEdit: user,
                                                    onSubmit: ({
                                                      required fullName,
                                                      required email,
                                                      phoneNumber,
                                                      required role,
                                                      required employeeCode,
                                                      required designation,
                                                      required department,
                                                      temporaryPassword,
                                                      required useDefaultOffice,
                                                      assignedOfficeId,
                                                      assignedOfficeName,
                                                    }) {
                                                      cubit.updateUser(
                                                        userId: user.id,
                                                        fullName: fullName,
                                                        email: email,
                                                        phoneNumber: phoneNumber,
                                                        role: role,
                                                        employeeCode:
                                                            employeeCode,
                                                        designation: designation,
                                                        department: department,
                                                        useDefaultOffice:
                                                            useDefaultOffice,
                                                        assignedOfficeId:
                                                            assignedOfficeId,
                                                        assignedOfficeName:
                                                            assignedOfficeName,
                                                      );
                                                    },
                                                  ),
                                                );
                                              } else if (val ==
                                                  'toggle_status') {
                                                cubit.setUserActiveStatus(
                                                    user.id, !user.isActive);
                                              } else if (val == 'reset_pass') {
                                                cubit.sendPasswordReset(
                                                    user.email, user.id);
                                              } else if (val == 'soft_delete') {
                                                _confirmSoftDelete(
                                                    context, user, cubit);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined,
                                                        size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Edit Profile'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'toggle_status',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      user.isActive
                                                          ? Icons
                                                              .person_off_outlined
                                                          : Icons
                                                              .person_add_alt_outlined,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(user.isActive
                                                        ? 'Disable User'
                                                        : 'Activate User'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'reset_pass',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                        Icons.lock_reset_outlined,
                                                        size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Reset Password'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'soft_delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline,
                                                        size: 18,
                                                        color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Delete User',
                                                        style: TextStyle(
                                                            color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                const Divider(height: 1, thickness: 0.8),
                                const SizedBox(height: 12),

                                // Bottom Details Chips: Code, Email, Phone, Office, Status Pill
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (displayCode.isNotEmpty)
                                      _buildInfoChip(
                                        icon: Icons.badge_outlined,
                                        label: displayCode,
                                        bgColor: Colors.blueGrey
                                            .withValues(alpha: 0.12),
                                        textColor: Colors.blueGrey.shade700,
                                        isBold: true,
                                      ),
                                    _buildInfoChip(
                                      icon: Icons.email_outlined,
                                      label: user.email,
                                      textColor: isDark
                                          ? palette.textSecondaryDark
                                          : palette.textSecondaryLight,
                                    ),
                                    if (user.phoneNumber != null &&
                                        user.phoneNumber!.isNotEmpty)
                                      _buildInfoChip(
                                        icon: Icons.phone_android_outlined,
                                        label: user.phoneNumber!,
                                        textColor: isDark
                                            ? palette.textSecondaryDark
                                            : palette.textSecondaryLight,
                                      ),
                                    _buildInfoChip(
                                      icon: Icons.business_outlined,
                                      label: officeName,
                                      textColor: isDark
                                          ? palette.textSecondaryDark
                                          : palette.textSecondaryLight,
                                    ),
                                    _buildInfoChip(
                                      icon: user.isActive
                                          ? Icons.check_circle_rounded
                                          : Icons.block_rounded,
                                      label:
                                          user.isActive ? 'Active' : 'Disabled',
                                      bgColor: (user.isActive
                                              ? AppColors.success
                                              : AppColors.error)
                                          .withValues(alpha: 0.12),
                                      textColor: user.isActive
                                          ? AppColors.success
                                          : AppColors.error,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
  }

  void _confirmSoftDelete(
      BuildContext context, UserEntity user, UserManagementCubit cubit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
            'Are you sure you want to delete ${user.fullName}? Their account will be removed and marked as deleted in Supabase.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              cubit.softDeleteUser(user.id,
                  email: user.email, fullName: user.fullName);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? bgColor,
    required Color textColor,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
