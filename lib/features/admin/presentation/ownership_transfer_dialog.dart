import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../database/local_database_service.dart';
import '../../auth/domain/user_entity.dart';
import 'ownership_transfer_cubit.dart';

class OwnershipTransferDialog extends StatefulWidget {
  final UserEntity? currentSuperAdmin;
  final List<UserEntity>? candidateAdmins;

  const OwnershipTransferDialog({
    super.key,
    this.currentSuperAdmin,
    this.candidateAdmins,
  });

  @override
  State<OwnershipTransferDialog> createState() =>
      _OwnershipTransferDialogState();
}

class _OwnershipTransferDialogState extends State<OwnershipTransferDialog> {
  UserEntity? _selectedAdmin;
  late final UserEntity _effectiveSuperAdmin;
  late final List<UserEntity> _effectiveCandidateAdmins;
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final db = LocalDatabaseService();
    _effectiveSuperAdmin = widget.currentSuperAdmin ??
        db.currentUser ??
        UserEntity(
          id: '00000000-0000-0000-0000-000000000001',
          firebaseUid: 'admin_uid',
          organizationId: '00000000-0000-0000-0000-000000000001',
          email: 'admin@enterprise.com',
          fullName: 'Super Admin',
          role: UserRole.superAdmin,
        );

    _effectiveCandidateAdmins = widget.candidateAdmins ??
        db
            .getUsers()
            .where((u) => u.role == UserRole.admin && u.isActive)
            .toList();

    if (_effectiveCandidateAdmins.isNotEmpty) {
      _selectedAdmin = _effectiveCandidateAdmins.first;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OwnershipTransferCubit(),
      child: BlocConsumer<OwnershipTransferCubit, OwnershipTransferState>(
        listener: (context, state) {
          if (state is OwnershipTransferSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.of(context).pop(true);
          } else if (state is OwnershipTransferError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is OwnershipTransferLoading;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('Transfer Ownership'),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'WARNING: Ownership Transfer is an irreversible action. The selected Administrator will become SUPER_ADMIN with master control over organization settings and user permissions. You will be demoted to ADMIN.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Target Administrator:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _effectiveCandidateAdmins.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'No eligible Administrators found. Please promote an Employee to ADMIN first before transferring ownership.',
                              style: TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          )
                        : DropdownButtonFormField<UserEntity>(
                            initialValue: _selectedAdmin,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            items: _effectiveCandidateAdmins.map((admin) {
                              return DropdownMenuItem(
                                value: admin,
                                child: Text(
                                  '${admin.fullName} (${admin.email})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedAdmin = val);
                            },
                          ),
                    const SizedBox(height: 20),
                    const Text(
                      'Verify Identity:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter your Super Admin password to authorize ownership transfer.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Current Super Admin Password',
                      isPassword: true,
                      prefixIcon: Icons.lock_person_outlined,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              if (_effectiveCandidateAdmins.isNotEmpty)
                AppButton(
                  text: 'Confirm Transfer',
                  isLoading: isLoading,
                  backgroundColor: AppColors.error,
                  onPressed: () {
                    if (_selectedAdmin == null ||
                        _passwordController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please select an Admin and enter your password.'),
                        ),
                      );
                      return;
                    }

                    context
                        .read<OwnershipTransferCubit>()
                        .executeOwnershipTransfer(
                          currentSuperAdmin: _effectiveSuperAdmin,
                          targetAdmin: _selectedAdmin!,
                          superAdminPassword: _passwordController.text.trim(),
                        );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
