import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'user_management_cubit.dart';
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
            final matchesSearch =
                u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    u.email.toLowerCase().contains(_searchQuery.toLowerCase());
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
                    icon: const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.warning, size: 18),
                    label: const Text(
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
                            hintText: 'Search by name or email...',
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
                  const Expanded(
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
                                                phoneNumber: phoneNumber,
                                                role: role,
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
                                            Text('Soft Delete User',
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
    );
  }

  void _confirmSoftDelete(
      BuildContext context, UserEntity user, UserManagementCubit cubit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soft Delete User?'),
        content: Text(
            'Are you sure you want to soft delete ${user.fullName}? Their account will be deactivated and marked as deleted in Supabase audit logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              cubit.softDeleteUser(user.id);
              Navigator.pop(ctx);
            },
            child: const Text('Soft Delete'),
          ),
        ],
      ),
    );
  }
}
