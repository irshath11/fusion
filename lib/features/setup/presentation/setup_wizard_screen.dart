import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'setup_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final _orgNameController = TextEditingController();
  final _orgAddressController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminMobileController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  @override
  void dispose() {
    _orgNameController.dispose();
    _orgAddressController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminMobileController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => SetupCubit(),
      child: BlocConsumer<SetupCubit, SetupState>(
        listener: (context, state) {
          if (state is SetupSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Organization setup completed successfully! Please sign in.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );

            context.read<AuthCubit>().logout();

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => const LoginScreen()),
              (route) => false,
            );
          } else if (state is SetupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is SetupLoading;

          return Scaffold(
            backgroundColor:
                isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            appBar: AppBar(
              title: Text(
                'Enterprise Provisioning',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Stepper Indicator
                          Row(
                            children: [
                              _buildStepIndicator(
                                stepNumber: 1,
                                title: 'Organization',
                                isActive: _currentStep >= 0,
                                isCompleted: _currentStep > 0,
                                isDark: isDark,
                              ),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: _currentStep > 0
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.cardBorderDark
                                          : AppColors.cardBorderLight),
                                ),
                              ),
                              _buildStepIndicator(
                                stepNumber: 2,
                                title: 'Super Admin',
                                isActive: _currentStep >= 1,
                                isCompleted: false,
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Step Form Content
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _currentStep == 0
                                ? _buildOrgStep(isDark)
                                : _buildAdminStep(isDark),
                          ),

                          const SizedBox(height: 28),

                          // Navigation Buttons
                          Row(
                            children: [
                              if (_currentStep > 0) ...[
                                Expanded(
                                  child: AppButton(
                                    text: 'Back',
                                    variant: AppButtonVariant.secondary,
                                    onPressed: isLoading
                                        ? null
                                        : () => setState(
                                            () => _currentStep = 0),
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                flex: 2,
                                child: AppButton(
                                  text: _currentStep == 0
                                      ? 'Continue to Admin'
                                      : 'Complete Setup',
                                  isLoading: isLoading,
                                  icon: _currentStep == 0
                                      ? Icons.arrow_forward_rounded
                                      : Icons.check_rounded,
                                  onPressed: () {
                                    if (_currentStep == 0) {
                                      if (_orgNameController.text
                                              .trim()
                                              .isEmpty ||
                                          _orgAddressController.text
                                              .trim()
                                              .isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Please fill in all organization details.'),
                                            backgroundColor: AppColors.warning,
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() => _currentStep = 1);
                                    } else {
                                      if (_adminNameController.text
                                              .trim()
                                              .isEmpty ||
                                          _adminEmailController.text
                                              .trim()
                                              .isEmpty ||
                                          _adminPasswordController.text
                                              .trim()
                                              .isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Please complete all admin account details.'),
                                            backgroundColor: AppColors.warning,
                                          ),
                                        );
                                        return;
                                      }
                                      context
                                          .read<SetupCubit>()
                                          .submitFirstTimeSetup(
                                            orgName: _orgNameController.text,
                                            orgAddress:
                                                _orgAddressController.text,
                                            adminName:
                                                _adminNameController.text,
                                            adminEmail:
                                                _adminEmailController.text,
                                            adminMobile:
                                                _adminMobileController.text,
                                            adminPassword:
                                                _adminPasswordController.text,
                                          );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepIndicator({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isCompleted,
    required bool isDark,
  }) {
    final color = isActive ? AppColors.primary : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppColors.primary
                : (isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? AppColors.surfaceDark : AppColors.surfaceLightElevated)),
            border: Border.all(
              color: isActive ? AppColors.primary : (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppColors.primary : color,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildOrgStep(bool isDark) {
    return GlassSurfaceCard(
      key: const ValueKey('org_step_card'),
      padding: const EdgeInsets.all(22),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organization Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set up your company workspace identity and primary headquarters.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 22),
          CustomTextField(
            controller: _orgNameController,
            label: 'Company / Organization Name',
            hint: 'e.g. Apex Global Logistics',
            prefixIcon: Icons.business_rounded,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _orgAddressController,
            label: 'Headquarters Location',
            hint: 'e.g. Business Bay, Tower 1, Dubai',
            prefixIcon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStep(bool isDark) {
    return GlassSurfaceCard(
      key: const ValueKey('admin_step_card'),
      padding: const EdgeInsets.all(22),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Super Administrator Account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create the master Super Admin user with complete organization control.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 22),
          CustomTextField(
            controller: _adminNameController,
            label: 'Administrator Full Name',
            hint: 'e.g. Irshath',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _adminEmailController,
            label: 'Official Email Address',
            hint: 'admin@company.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _adminMobileController,
            label: 'Mobile Contact Number',
            hint: '+971 50 123 4567',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _adminPasswordController,
            label: 'Master Access Password',
            hint: '••••••••',
            isPassword: true,
            prefixIcon: Icons.lock_outline_rounded,
          ),
        ],
      ),
    );
  }
}
