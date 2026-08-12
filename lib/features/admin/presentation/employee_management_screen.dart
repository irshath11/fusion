import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_management_cubit.dart';
import 'user_form_dialog.dart';
import 'ownership_transfer_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/role_permissions.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../core/widgets/status_badge.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                content: Text(state.message,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is UserManagementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          List<UserEntity> users = [];
          if (state is UserManagementLoaded) {
            users = state.users;
          }

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
            backgroundColor:
                isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            appBar: AppBar(
              title: Text(
                'Staff & Roster Directory',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
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
                      if (result == true) setState(() {});
                    },
                    icon: const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.warning, size: 16),
                    label: Text(
                      'Transfer Ownership',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
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
              label: Text(
                'Provision Staff',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            body: Column(
              children: [
                // Filter & Search Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search staff by name or email...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.cardBorderDark
                                    : AppColors.cardBorderLight,
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.cardBorderDark
                                : AppColors.cardBorderLight,
                            width: 0.8,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRoleFilter,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            dropdownColor: isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            items: const [
                              DropdownMenuItem(
                                  value: 'ALL', child: Text('All Roles')),
                              DropdownMenuItem(
                                  value: 'SUPER_ADMIN',
                                  child: Text('Super Admin')),
                              DropdownMenuItem(
                                  value: 'ADMIN', child: Text('Admins')),
                              DropdownMenuItem(
                                  value: 'EMPLOYEE', child: Text('Staff')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRoleFilter = val);
                              }
                            },
                          ),
                        ),
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
                        'No employee records match the search filter.',
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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

                        return GlassSurfaceCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          borderRadius: 16,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    roleBadgeColor.withValues(alpha: 0.12),
                                child: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: roleBadgeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.fullName,
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                        ),
                                        StatusBadge(
                                          label: user.role.displayName,
                                          color: roleBadgeColor,
                                          fontSize: 10,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2.5),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.email,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textTertiaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          user.isActive
                                              ? Icons.check_circle_rounded
                                              : Icons.block_rounded,
                                          size: 13,
                                          color: user.isActive
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          user.isActive ? 'Active' : 'Disabled',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: user.isActive
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                        ),
                                        if (user.phoneNumber != null &&
                                            user.phoneNumber!.isNotEmpty) ...[
                                          const SizedBox(width: 10),
                                          Text(
                                            '• ${user.phoneNumber}',
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppColors.textTertiaryDark
                                                  : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelf)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: StatusBadge(
                                    label: 'You',
                                    color: AppColors.primary,
                                    fontSize: 10,
                                  ),
                                )
                              else
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded,
                                      size: 18),
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : Colors.white,
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
                                          Icon(Icons.edit_outlined, size: 16),
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
                                                : Icons.person_add_alt_outlined,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
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
                                              size: 16),
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
                                              size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Soft Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Soft Delete User?',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to soft delete ${user.fullName}? Their account will be deactivated and marked as deleted in Supabase audit logs.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
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
