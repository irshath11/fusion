import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/app_bounceable.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_glass_card.dart';
import '../../../core/widgets/app_icon_widget.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Radial Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.2,
                  colors: [
                    palette.primaryFor(isDark ? Brightness.dark : Brightness.light).withValues(alpha: isDark ? 0.35 : 0.15),
                    palette.backgroundFor(isDark ? Brightness.dark : Brightness.light),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: ScaleTransition(
                                scale: _scaleAnim,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette
                                            .primaryFor(isDark ? Brightness.dark : Brightness.light)
                                            .withValues(alpha: isDark ? 0.5 : 0.25),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const AppIconWidget(
                                    size: 88,
                                    borderRadius: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: Text(
                                'Fusion 360',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : palette.primaryLight,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Enterprise Attendance & Workforce Management',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Glassmorphic Input Card
                            AppGlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  CustomTextField(
                                    controller: _emailController,
                                    label: 'Email Address',
                                    hint: 'Enter Your Email',
                                    prefixIcon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    hint: 'Enter Your Password',
                                    isPassword: true,
                                    prefixIcon: Icons.lock_outline_rounded,
                                  ),
                                  const SizedBox(height: 24),
                                  BlocConsumer<AuthCubit, AuthState>(
                                    listener: (context, state) {
                                      if (state is AuthError) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(state.message),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      } else if (state is Authenticated) {
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                              builder: (ctx) => const RootRoleRouter()),
                                          (route) => false,
                                        );
                                      }
                                    },
                                    builder: (context, state) {
                                      return AppBounceable(
                                        onTap: state is AuthLoading
                                            ? null
                                            : () {
                                                context.read<AuthCubit>().loginWithEmailAndPassword(
                                                      _emailController.text,
                                                      _passwordController.text,
                                                    );
                                              },
                                        child: AppButton(
                                          text: 'Sign In',
                                          isLoading: state is AuthLoading,
                                          icon: Icons.login_rounded,
                                          onPressed: () {
                                            context.read<AuthCubit>().loginWithEmailAndPassword(
                                                  _emailController.text,
                                                  _passwordController.text,
                                                );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Security Info Badge
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.info.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.shield_outlined,
                                      color: AppColors.info, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Public registration disabled. Contact your Administrator to provision accounts.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}
