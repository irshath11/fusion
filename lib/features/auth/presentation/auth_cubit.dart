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

class RequiresPasswordChangeState extends AuthState {
  final UserEntity user;
  RequiresPasswordChangeState(this.user);

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
  final fb.FirebaseAuth _fbAuth = fb.FirebaseAuth.instance;

  AuthCubit() : super(AuthInitial());

  Future<void> checkAuthStatus() async {
    final firebaseUser = _fbAuth.currentUser;
    final currentUser = _db.currentUser;

    if (currentUser != null) {
      if (currentUser.requiresPasswordChange) {
        emit(RequiresPasswordChangeState(currentUser));
      } else {
        emit(Authenticated(currentUser));
      }
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
        final remoteUser =
            await _supabase.fetchUserByFirebaseUid(firebaseUser.uid);
        if (remoteUser != null) {
          if (!remoteUser.isActive) {
            await _fbAuth.signOut();
            _db.logout();
            emit(AuthError(
                'Your account has been disabled. Please contact your Administrator.'));
            return;
          }

          if (remoteUser.requiresPasswordChange) {
            emit(RequiresPasswordChangeState(remoteUser));
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

    try {
      // 1. Authenticate with Firebase Authentication
      final credential = await _fbAuth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );

      if (credential.user != null) {
        final fbUid = credential.user!.uid;

        // Fetch Supabase User Profile & Role
        final supabaseUser = await _supabase.fetchUserByFirebaseUid(fbUid);

        if (supabaseUser != null) {
          if (!supabaseUser.isActive) {
            await _fbAuth.signOut();
            emit(AuthError(
                'Your account is disabled. Please contact your organization administrator.'));
            return;
          }

          _db.setCurrentUser(supabaseUser);

          if (supabaseUser.requiresPasswordChange) {
            emit(RequiresPasswordChangeState(supabaseUser));
            return;
          }

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
          email: credential.user!.email ?? trimmedEmail,
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
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('Firebase signIn Exception: ${e.code} - ${e.message}');
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS' ||
          e.code == 'invalid-password') {
        emit(AuthError(
            'Incorrect password. Please check your credentials and try again.'));
        return;
      } else if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        emit(AuthError(
            'User account not found. Please check your email address.'));
        return;
      } else {
        emit(AuthError(
            'Incorrect email or password. Please check your credentials.'));
        return;
      }
    } catch (e) {
      debugPrint('Firebase signIn error: $e');
      emit(AuthError(
          'Authentication error. Please verify your credentials and try again.'));
      return;
    }

    // 2. Offline / Demo Super Admin Credential Fallback
    final isConfiguredAdmin = _db.organization != null &&
        _db.organization!.superAdminEmail.toLowerCase() == trimmedEmail;
    final isDemoAdmin = trimmedEmail == 'admin@apexlogistics.com' ||
        trimmedEmail == 'sr.irshath@gmail.com';

    if (isConfiguredAdmin || isDemoAdmin) {
      final storedAdminPass = _db.organization?.superAdminPassword;
      final isValidPass = (storedAdminPass != null &&
              storedAdminPass.isNotEmpty &&
              storedAdminPass == trimmedPassword) ||
          trimmedPassword == 'aa123456' ||
          trimmedPassword == 'AdminSecurePass123!';

      if (isValidPass) {
        final adminUser = UserEntity(
          id: 'admin-001',
          firebaseUid: 'admin-001',
          email: _db.organization?.superAdminEmail ?? trimmedEmail,
          fullName: _db.organization?.superAdminName ?? 'Irshath (Super Admin)',
          role: UserRole.superAdmin,
          organizationId:
              _db.organization?.id ?? '00000000-0000-0000-0000-000000000001',
        );
        _db.setCurrentUser(adminUser);
        emit(Authenticated(adminUser));
        return;
      } else {
        emit(AuthError('Invalid email or password. Please try again.'));
        return;
      }
    }

    // 3. Offline Employee Credential Fallback (Only when no internet / offline account)
    final employees = _db.getEmployees();
    final employee = employees.firstWhere(
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

    if (employee.id.isNotEmpty && employee.isActive) {
      emit(AuthError(
          'Invalid email or password. Please check your credentials.'));
      return;
    }

    emit(AuthError('Invalid email or password. Account not found.'));
  }

  Future<void> completeFirstTimePasswordChange({
    required UserEntity user,
    required String newPassword,
  }) async {
    emit(AuthLoading());
    try {
      // 1. Update Firebase Auth Password
      if (_fbAuth.currentUser != null) {
        await _fbAuth.currentUser!.updatePassword(newPassword);
      }

      // 2. Clear requires_password_change flag in Supabase
      await _supabase.updateUserPasswordChangeStatus(
          user.id, false, user.firebaseUid);

      final updatedUser = user.copyWith(requiresPasswordChange: false);
      _db.setCurrentUser(updatedUser);
      emit(Authenticated(updatedUser));
    } catch (e) {
      emit(AuthError('Failed to update password: ${e.toString()}'));
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _fbAuth.currentUser;
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
      await _fbAuth.signOut();
    } catch (_) {}
    _db.logout();
    emit(Unauthenticated());
  }
}
