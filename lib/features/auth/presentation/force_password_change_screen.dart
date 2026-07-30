import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/user_entity.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  final UserEntity user;

  const ForcePasswordChangeScreen({
    super.key,
    required this.user,
  });

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitNewPassword() {
    if (!_formKey.currentState!.validate()) return;

    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters long.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    context.read<AuthCubit>().completeFirstTimePasswordChange(
          user: widget.user,
          newPassword: newPass,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Temporary Password'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().logout(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome, ${widget.user.fullName}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account was created with a temporary password. You must establish a new secure password before continuing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  controller: _newPasswordController,
                  label: 'New Permanent Password',
                  hint: 'Min 6 characters',
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm New Password',
                  hint: 'Re-enter new password',
                  isPassword: true,
                  prefixIcon: Icons.lock_reset,
                ),
                const SizedBox(height: 32),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return AppButton(
                      text: 'Update Password & Access App',
                      isLoading: isLoading,
                      onPressed: _submitNewPassword,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
