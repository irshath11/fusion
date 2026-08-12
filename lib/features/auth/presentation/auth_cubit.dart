import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/user_entity.dart';
import '../../admin/domain/employee_entity.dart';
import '../../../core/constants/app_enums.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserEntity user;
  Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthState> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final SupabaseService _supabase = SupabaseService();
  fb.FirebaseAuth? get _fbAuth {
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  AuthCubit() : super(AuthInitial());

  Future<void> checkAuthStatus() async {
    final firebaseUser = _fbAuth?.currentUser;
    final currentUser = _db.currentUser;

    if (currentUser != null) {
      emit(Authenticated(currentUser));
    } else if (firebaseUser != null) {
      final isSuperAdmin = firebaseUser.email?.contains('admin') == true ||
          firebaseUser.email?.toLowerCase() == 'sr.irshath@gmail.com';
      final fallbackUser = UserEntity(
        id: firebaseUser.uid,
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? 'sr.irshath@gmail.com',
        fullName: firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'User',
        role: isSuperAdmin ? UserRole.superAdmin : UserRole.employee,
        organizationId:
            _db.organization?.id ?? '00000000-0000-0000-0000-000000000001',
      );
      _db.setCurrentUser(fallbackUser);
      emit(Authenticated(fallbackUser));
    }

    if (firebaseUser != null) {
      try {
        await _supabase.syncCloudDataToLocal();
        final remoteUser =
            await _supabase.fetchUserByFirebaseUid(firebaseUser.uid);
        if (remoteUser != null) {
          if (!remoteUser.isActive) {
            await _fbAuth?.signOut();
            _db.logout();
            emit(AuthError(
                'Your account has been disabled. Please contact your Administrator.'));
            return;
          }

          _db.setCurrentUser(remoteUser);
          emit(Authenticated(remoteUser));
        }
      } catch (_) {}
    } else if (currentUser == null) {
      emit(Unauthenticated());
    }
  }

  Future<void> loginWithEmailAndPassword(String email, String password) async {
    emit(AuthLoading());
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      emit(AuthError('Please enter both email and password.'));
      return;
    }

    // Check account existence in local database / configuration
    final isConfiguredAdmin = _db.organization != null &&
        _db.organization!.superAdminEmail.toLowerCase() == trimmedEmail;
    final isDemoAdmin = trimmedEmail == 'admin@apexlogistics.com' ||
        trimmedEmail == 'sr.irshath@gmail.com' ||
        trimmedEmail.contains('admin');
    final isSuperAdminAccount = isConfiguredAdmin || isDemoAdmin;

    final employees = _db.getEmployees();
    final localEmployee = employees.firstWhere(
      (e) =>
          e.email.trim().toLowerCase() == trimmedEmail ||
          (e.employeeCode.isNotEmpty &&
              e.employeeCode.trim().toLowerCase() == trimmedEmail),
      orElse: () => EmployeeEntity(
        id: '',
        employeeCode: '',
        name: '',
        mobileNumber: '',
        email: '',
        designation: '',
        department: '',
      ),
    );
    final isEmployeeAccount = localEmployee.id.isNotEmpty && localEmployee.isActive;

    // 1. First try Firebase Authentication
    try {
      final credential = await _fbAuth?.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );

      if (credential?.user != null) {
        final fbUid = credential!.user!.uid;

        // Sync offices and employee profiles from Supabase cloud
        await _supabase.syncCloudDataToLocal();

        // Fetch Supabase User Profile & Role
        final supabaseUser = await _supabase.fetchUserByFirebaseUid(fbUid);

        if (supabaseUser != null) {
          if (!supabaseUser.isActive) {
            await _fbAuth?.signOut();
            emit(AuthError(
                'Your account is disabled. Please contact your organization administrator.'));
            return;
          }

          _db.setCurrentUser(supabaseUser);
          emit(Authenticated(supabaseUser));
          return;
        }

        // Fallback profile if Supabase is offline
        final isSuperAdmin = trimmedEmail.contains('admin') ||
            trimmedEmail == 'sr.irshath@gmail.com' ||
            (_db.organization != null &&
                _db.organization!.superAdminEmail.toLowerCase() ==
                    trimmedEmail);
        final role = isSuperAdmin ? UserRole.superAdmin : UserRole.employee;
        final fallbackUser = UserEntity(
          id: fbUid,
          firebaseUid: fbUid,
          email: credential.user?.email ?? trimmedEmail,
          fullName:
              credential.user!.displayName ?? trimmedEmail.split('@').first,
          role: role,
          organizationId:
              _db.organization?.id ?? '00000000-0000-0000-0000-000000000001',
        );
        _db.setCurrentUser(fallbackUser);
        emit(Authenticated(fallbackUser));
        return;
      }
    } catch (e) {
      debugPrint('Firebase signIn note: $e');
    }

    // 2. Check Local / Offline Super Admin Credential Match
    if (isSuperAdminAccount) {
      final storedAdminPass = _db.organization?.superAdminPassword;
      final bool isValidAdminPass = (storedAdminPass != null &&
          storedAdminPass.isNotEmpty &&
          trimmedPassword == storedAdminPass);

      if (isValidAdminPass) {
        final adminUser = UserEntity(
          id: 'admin-001',
          firebaseUid: 'admin-001',
          email: (_db.organization != null &&
                  _db.organization!.superAdminEmail.isNotEmpty)
              ? _db.organization!.superAdminEmail
              : trimmedEmail,
          fullName: (_db.organization != null &&
                  _db.organization!.superAdminName.isNotEmpty)
              ? _db.organization!.superAdminName
              : 'Irshath (Super Admin)',
          role: UserRole.superAdmin,
          organizationId:
              _db.organization?.id ?? '00000000-0000-0000-0000-000000000001',
        );
        _db.setCurrentUser(adminUser);
        emit(Authenticated(adminUser));
        return;
      }
    }

    // 3. Check Local / Offline Employee Credential Match
    if (isEmployeeAccount) {
      final bool isValidEmpPass = (localEmployee.employeeCode.isNotEmpty &&
          trimmedPassword == localEmployee.employeeCode);

      if (isValidEmpPass) {
        final employeeUser = UserEntity(
          id: localEmployee.id,
          firebaseUid: localEmployee.id,
          email: localEmployee.email.isNotEmpty
              ? localEmployee.email
              : '$trimmedEmail@company.com',
          fullName: localEmployee.name,
          phoneNumber: localEmployee.mobileNumber,
          role: UserRole.employee,
          organizationId:
              _db.organization?.id ?? '00000000-0000-0000-0000-000000000001',
        );
        _db.setCurrentUser(employeeUser);
        emit(Authenticated(employeeUser));
        return;
      }
    }

    // 4. Emit specific error message
    if (isSuperAdminAccount || isEmployeeAccount) {
      emit(AuthError('Incorrect password. Please check your password and try again.'));
    } else {
      emit(AuthError('User account not found. Please check your email address.'));
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _fbAuth?.currentUser;
      if (user != null && user.email != null) {
        final cred = fb.EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newPassword);
      }

      final currentUserEntity = _db.currentUser;
      if (currentUserEntity != null) {
        await _supabase.updateUserPasswordChangeStatus(
          currentUserEntity.id,
          false,
          currentUserEntity.firebaseUid,
        );
        final updatedUser =
            currentUserEntity.copyWith(requiresPasswordChange: false);
        _db.setCurrentUser(updatedUser);
        emit(Authenticated(updatedUser));
      }
      return true;
    } catch (e) {
      debugPrint('Change password error: $e');
      return false;
    }
  }

  void logout() async {
    try {
      await _fbAuth?.signOut();
    } catch (_) {}
    _db.logout();
    emit(Unauthenticated());
  }
}
