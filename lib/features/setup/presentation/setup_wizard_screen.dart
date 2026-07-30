import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'setup_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
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

  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SetupCubit(),
      child: BlocConsumer<SetupCubit, SetupState>(
        listener: (context, state) {
          if (state is SetupSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Organization & Super Admin Setup Completed! Please Sign In.'),
                backgroundColor: AppColors.success,
              ),
            );

            // Clear session and navigate to Login Screen
            context.read<AuthCubit>().logout();

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => const LoginScreen()),
              (route) => false,
            );
          } else if (state is SetupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Organization Setup Wizard'),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Stepper(
                type: StepperType.horizontal,
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 1) {
                    setState(() => _currentStep++);
                  } else {
                    context.read<SetupCubit>().submitFirstTimeSetup(
                          orgName: _orgNameController.text,
                          orgAddress: _orgAddressController.text,
                          adminName: _adminNameController.text,
                          adminEmail: _adminEmailController.text,
                          adminMobile: _adminMobileController.text,
                          adminPassword: _adminPasswordController.text,
                        );
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep--);
                  }
                },
                steps: [
                  Step(
                    title: const Text('Organization'),
                    isActive: _currentStep >= 0,
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Organization Details',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your enterprise organization name and primary address to initialize workspace.',
                            style: TextStyle(color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            controller: _orgNameController,
                            label: 'Organization Name',
                            hint: 'e.g. Apex Global Logistics',
                            prefixIcon: Icons.business_rounded,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _orgAddressController,
                            label: 'Headquarters Address',
                            hint: 'e.g. Business Bay, Dubai',
                            prefixIcon: Icons.location_city_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Step(
                    title: const Text('Super Admin'),
                    isActive: _currentStep >= 1,
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Super Admin Credentials',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This account will be registered with Firebase Auth as master SUPER_ADMIN.',
                            style: TextStyle(color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 20),
                          CustomTextField(
                            controller: _adminNameController,
                            label: 'Super Admin Full Name',
                            prefixIcon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _adminEmailController,
                            label: 'Email Address',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_rounded,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _adminMobileController,
                            label: 'Mobile Number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_rounded,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _adminPasswordController,
                            label: 'Master Password',
                            isPassword: true,
                            prefixIcon: Icons.lock_rounded,
                          ),
                          const SizedBox(height: 20),
                          if (state is SetupLoading)
                            const Center(child: CircularProgressIndicator())
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
