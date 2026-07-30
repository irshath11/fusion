import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/supabase_service.dart';
import 'database/local_database_service.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_enums.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/setup/presentation/setup_wizard_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/attendance/presentation/attendance_cubit.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/employee/presentation/employee_dashboard_screen.dart';
import 'features/security/device_binding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await SupabaseService().init();

  final db = LocalDatabaseService();
  await db.init();

  runApp(const WorkforceApp());
}

class WorkforceApp extends StatelessWidget {
  const WorkforceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
            create: (context) => AuthCubit()..checkAuthStatus()),
        BlocProvider<AttendanceCubit>(create: (context) => AttendanceCubit()),
      ],
      child: MaterialApp(
        title: 'Workforce Tracking System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}

class RootRoleRouter extends StatelessWidget {
  const RootRoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabaseService();

    // 1. First-Time Setup Wizard Check
    if (!db.isSetupCompleted) {
      return const SetupWizardScreen();
    }

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // Register Device Binding upon successful login
          DeviceBindingService().registerDeviceBinding(state.user.id);
        }
      },
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is Authenticated) {
          // Role-Based Access Routing
          if (state.user.role == UserRole.superAdmin ||
              state.user.role == UserRole.admin) {
            return const AdminDashboardScreen();
          } else {
            return const EmployeeDashboardScreen();
          }
        }

        return const LoginScreen();
      },
    );
  }
}
