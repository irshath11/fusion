import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'user_management_cubit.dart';
import 'admin_cubit.dart';
import 'user_form_dialog.dart';
import 'ownership_transfer_dialog.dart';
import '../../../core/constants/app_colors.dart';
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

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  roleBadgeColor.withValues(alpha: 0.1),
                              child: Text(
                                user.fullName.isNotEmpty
                                    ? user.fullName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: roleBadgeColor,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (displayCode.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.blueGrey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      displayCode,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        roleBadgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
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
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (user.designation != null &&
                                    user.designation!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Text(
                                      '${user.designation}${user.department != null && user.department!.isNotEmpty ? ' • ${user.department}' : ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Text(user.email),
                                if (user.phoneNumber != null &&
                                    user.phoneNumber!.isNotEmpty)
                                  Text('Mobile: ${user.phoneNumber}',
                                      style: const TextStyle(fontSize: 11)),
                                const SizedBox(height: 4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          user.isActive
                                              ? Icons.check_circle_outline
                                              : Icons.block_outlined,
                                          size: 14,
                                          color: user.isActive
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          user.isActive ? 'Active' : 'Disabled',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: user.isActive
                                                ? AppColors.success
                                                : AppColors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: isSelf
                                ? const Tooltip(
                                    message: 'Current User Account',
                                    child: Icon(Icons.person,
                                        color: AppColors.primary),
                                  )
                                : PopupMenuButton<String>(
                                    onSelected: (val) {
                                      final cubit =
                                          context.read<UserManagementCubit>();
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
                                                employeeCode: employeeCode,
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
                                      } else if (val == 'toggle_status') {
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
                                            Icon(Icons.edit_outlined, size: 18),
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
                                                ? Icons.person_off_outlined
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
                                            Icon(Icons.lock_reset_outlined,
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
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete User',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
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
}
