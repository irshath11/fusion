import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart' as fb_core;
import 'package:uuid/uuid.dart';
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/domain/user_entity.dart';
import '../domain/employee_entity.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/employee_directory_helper.dart';

abstract class UserManagementState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {}

class UserManagementLoading extends UserManagementState {}

class UserManagementLoaded extends UserManagementState {
  final List<UserEntity> users;
  UserManagementLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UserManagementActionSuccess extends UserManagementState {
  final String message;
  UserManagementActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class UserManagementError extends UserManagementState {
  final String message;
  UserManagementError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserManagementCubit extends Cubit<UserManagementState> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final SupabaseService _supabase = SupabaseService();
  fb.FirebaseAuth? get _fbAuth {
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }
  final Uuid _uuid = const Uuid();

  UserManagementCubit() : super(UserManagementInitial());

  Future<void> fetchUsers() async {
    emit(UserManagementLoading());
    try {
      final orgId =
          _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
      final remoteUsers = await _supabase.fetchOrganizationUsers(orgId);
      if (_supabase.isInitialized) {
        _db.setUsers(remoteUsers);
      }

      final Map<String, UserEntity> userMap = {};

      for (final u in remoteUsers) {
        final key = u.email.trim().isNotEmpty
            ? u.email.trim().toLowerCase()
            : (u.fullName.trim().isNotEmpty
                ? u.fullName.trim().toLowerCase()
                : u.id);

        final completeName = EmployeeDirectoryHelper.getCompleteFullName(
          currentName: u.fullName,
          email: u.email,
          code: u.employeeCode,
          id: u.id,
        );
        final officialId = EmployeeDirectoryHelper.getEmployeeId(
          currentCode: u.employeeCode,
          name: u.fullName,
          email: u.email,
          id: u.id,
        );
        final photo = EmployeeDirectoryHelper.resolvePhoto(
          customPhotoUrl: u.photoUrl,
          employeeCode: u.employeeCode,
          fullName: u.fullName,
          email: u.email,
          id: u.id,
        );

        userMap[key] = u.copyWith(
          fullName: completeName,
          employeeCode: officialId,
          photoUrl: photo,
        );
      }

      // Always merge local employees into userMap so locally active/registered employees are never omitted
      final localEmployees = _db.getEmployees();
      for (final e in localEmployees) {
        final official = EmployeeDirectoryHelper.resolveOfficialRecord(
          code: e.employeeCode,
          name: e.name,
          email: e.email,
          id: e.id,
        );

        // Skip synthetic placeholders if actual user exists
        if (e.id.startsWith('emp-')) {
          final hasRealUser = userMap.values.any((u) =>
              !u.id.startsWith('emp-') &&
              (u.id == e.id ||
               (official != null && u.employeeCode?.toUpperCase() == official.employeeId.toUpperCase()) ||
               (official != null && u.fullName.trim().toLowerCase() == official.fullName.toLowerCase())));
          if (hasRealUser) continue;
        }

        final key = official != null
            ? official.employeeId.toUpperCase()
            : (e.email.trim().isNotEmpty
                ? e.email.trim().toLowerCase()
                : (e.name.trim().isNotEmpty
                    ? e.name.trim().toLowerCase()
                    : e.id));
        final alreadyPresent = userMap.containsKey(key) ||
            userMap.values.any((u) =>
                (u.id.isNotEmpty && u.id == e.id) ||
                (official != null &&
                 (u.employeeCode?.toUpperCase() == official.employeeId.toUpperCase() ||
                  u.fullName.trim().toLowerCase() == official.fullName.toLowerCase() ||
                  u.email.trim().toLowerCase() == official.email.toLowerCase())) ||
                (e.email.isNotEmpty &&
                    u.email.trim().toLowerCase() == e.email.trim().toLowerCase()) ||
                (e.name.isNotEmpty &&
                    u.fullName.trim().toLowerCase() == e.name.trim().toLowerCase()) ||
                EmployeeDirectoryHelper.matchesEmployeeIdentity(
                  recordEmployeeId: e.id,
                  recordEmployeeName: e.name,
                  employeeId: u.id,
                  employeeCode: u.employeeCode,
                  employeeName: u.fullName,
                  employeeEmail: u.email,
                ));

        if (!alreadyPresent) {
          final completeName = EmployeeDirectoryHelper.getCompleteFullName(
            currentName: e.name,
            email: e.email,
            code: e.employeeCode,
            id: e.id,
          );
          final officialId = EmployeeDirectoryHelper.getEmployeeId(
            currentCode: e.employeeCode,
            name: e.name,
            email: e.email,
            id: e.id,
          );
          final photo = EmployeeDirectoryHelper.resolvePhoto(
            customPhotoUrl: e.photoUrl,
            employeeCode: e.employeeCode,
            fullName: e.name,
            email: e.email,
            id: e.id,
          );

          final localUser = UserEntity(
            id: e.id,
            firebaseUid: e.id,
            email: e.email,
            fullName: completeName,
            phoneNumber: e.mobileNumber,
            employeeCode: officialId,
            designation: e.designation,
            department: e.department,
            role: UserRole.employee,
            organizationId: orgId,
            isActive: e.isActive,
            photoUrl: photo,
          );
          userMap[key] = localUser;
        } else {
          final existing = userMap[key] ??
              userMap.values.firstWhere((u) =>
                  (u.id.isNotEmpty && u.id == e.id) ||
                  (e.email.isNotEmpty &&
                      u.email.trim().toLowerCase() == e.email.trim().toLowerCase()) ||
                  (e.name.isNotEmpty &&
                      u.fullName.trim().toLowerCase() == e.name.trim().toLowerCase()));

          final existingKey =
              userMap.keys.firstWhere((k) => userMap[k] == existing, orElse: () => key);

          final completeName = EmployeeDirectoryHelper.getCompleteFullName(
            currentName: existing.fullName,
            email: existing.email,
            code: existing.employeeCode ?? e.employeeCode,
            id: existing.id,
          );
          final officialId = EmployeeDirectoryHelper.getEmployeeId(
            currentCode: existing.employeeCode ?? e.employeeCode,
            name: existing.fullName,
            email: existing.email,
            id: existing.id,
          );
          final photo = (existing.photoUrl != null &&
                  existing.photoUrl!.trim().isNotEmpty)
              ? existing.photoUrl
              : EmployeeDirectoryHelper.resolvePhoto(
                  customPhotoUrl: e.photoUrl,
                  employeeCode: existing.employeeCode ?? e.employeeCode,
                  fullName: existing.fullName,
                  email: existing.email,
                  id: existing.id,
                );

          userMap[existingKey] = existing.copyWith(
            fullName: completeName,
            employeeCode: officialId,
            photoUrl: photo,
          );
        }
      }

      final usersList = userMap.values.toList();
      usersList.sort((a, b) => a.fullName.trim().toLowerCase().compareTo(b.fullName.trim().toLowerCase()));
      emit(UserManagementLoaded(usersList));
    } catch (e) {
      emit(UserManagementError('Failed to fetch user list: ${e.toString()}'));
    }
  }

  Future<void> createUser({
    required String fullName,
    required String email,
    String? phoneNumber,
    required UserRole role,
    required String employeeCode,
    required String designation,
    required String department,
    String? temporaryPassword,
    bool useDefaultOffice = true,
    String? assignedOfficeId,
    String? assignedOfficeName,
    String? photoUrl,
  }) async {
    emit(UserManagementLoading());
    try {
      final orgId =
          _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
      final actorUserId = _db.currentUser?.id;

      String firebaseUid = 'user_${_uuid.v4()}';
      final passToUse =
          (temporaryPassword != null && temporaryPassword.trim().isNotEmpty)
              ? temporaryPassword.trim()
              : (employeeCode.trim().isNotEmpty ? employeeCode.trim() : 'Pass#${DateTime.now().millisecond}');

      // 1. Create Firebase Authentication user with temporary password using secondary app instance so Admin session remains active
      try {
        fb_core.FirebaseApp secondaryApp;
        try {
          secondaryApp = fb_core.Firebase.app('SecondaryAuthApp');
        } catch (_) {
          secondaryApp = await fb_core.Firebase.initializeApp(
            name: 'SecondaryAuthApp',
            options: fb_core.Firebase.app().options,
          );
        }
        final secondaryAuth = fb.FirebaseAuth.instanceFor(app: secondaryApp);
        final credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: passToUse,
        );
        if (credential.user != null) {
          firebaseUid = credential.user!.uid;
          await credential.user!.updateDisplayName(fullName.trim());
          await secondaryAuth.signOut();
        } else {
          emit(UserManagementError(
              'Failed to register employee authentication credentials.'));
          return;
        }
      } on fb.FirebaseAuthException catch (e) {
        debugPrint('Firebase createUser error: ${e.code} - ${e.message}');
        if (e.code == 'email-already-in-use') {
          emit(UserManagementError(
              'An account with this email address already exists.'));
          return;
        } else if (e.code == 'weak-password') {
          emit(UserManagementError(
              'Temporary password is too weak. Must be at least 6 characters.'));
          return;
        } else {
          emit(UserManagementError(
              'Authentication creation error (${e.code}): ${e.message}'));
          return;
        }
      } catch (e) {
        debugPrint('Secondary Firebase App error: $e');
        emit(UserManagementError(
            'Failed to create employee authentication: ${e.toString()}'));
        return;
      }

      // 2. Save locally in LocalDatabaseService so UI immediately updates
      final empCode = employeeCode.trim().isNotEmpty
          ? employeeCode.trim()
          : 'EMP-${_uuid.v4().substring(0, 4).toUpperCase()}';
      final newLocalEmp = EmployeeEntity(
        id: firebaseUid,
        employeeCode: empCode,
        name: fullName.trim(),
        mobileNumber: phoneNumber?.trim() ?? '',
        email: email.trim().toLowerCase(),
        designation:
            designation.trim().isNotEmpty ? designation.trim() : 'Team Member',
        department:
            department.trim().isNotEmpty ? department.trim() : 'Operations',
        useDefaultOffice: useDefaultOffice,
        assignedOfficeId: assignedOfficeId,
        assignedOfficeName: assignedOfficeName,
        isActive: true,
        photoUrl: photoUrl,
      );
      _db.saveEmployee(newLocalEmp);

      // 3. Insert into Supabase (users table + employees table)
      final createdUser = await _supabase.createUserInSupabase(
        firebaseUid: firebaseUid,
        orgId: orgId,
        email: email.trim().toLowerCase(),
        fullName: fullName.trim(),
        phoneNumber: phoneNumber?.trim(),
        role: role,
        requiresPasswordChange: false,
        employeeCode: empCode,
        designation: designation.trim(),
        department: department.trim(),
        useDefaultOffice: useDefaultOffice,
        assignedOfficeId: assignedOfficeId,
        assignedOfficeName: assignedOfficeName,
        actorUserId: actorUserId,
      );

      if (createdUser != null) {
        _db.deleteEmployee(firebaseUid);
        final officialLocalEmp = EmployeeEntity(
          id: createdUser.id,
          employeeCode: empCode,
          name: fullName.trim(),
          mobileNumber: phoneNumber?.trim() ?? '',
          email: email.trim().toLowerCase(),
          designation: designation.trim().isNotEmpty
              ? designation.trim()
              : 'Team Member',
          department:
              department.trim().isNotEmpty ? department.trim() : 'Operations',
          useDefaultOffice: useDefaultOffice,
          assignedOfficeId: assignedOfficeId,
          assignedOfficeName: assignedOfficeName,
          isActive: true,
          photoUrl: photoUrl,
        );
        _db.saveEmployee(officialLocalEmp);
        emit(UserManagementActionSuccess(
            'User ${fullName.trim()} created successfully.'));
      } else {
        emit(UserManagementActionSuccess('User profile created successfully.'));
      }

      await fetchUsers();
    } catch (e) {
      emit(UserManagementError('Failed to create user: ${e.toString()}'));
    }
  }

  Future<void> updateUser({
    required String userId,
    required String fullName,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? employeeCode,
    String? designation,
    String? department,
    bool? useDefaultOffice,
    String? assignedOfficeId,
    String? assignedOfficeName,
    String? photoUrl,
  }) async {
    emit(UserManagementLoading());
    try {
      final orgId =
          _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
      final actorUserId = _db.currentUser?.id;

      // Update local UserEntity if present
      final localUsers = _db.getUsers();
      final userIndex = localUsers.indexWhere((u) => u.id == userId || u.email == userId);
      if (userIndex >= 0) {
        final existingUser = localUsers[userIndex];
        final updatedUser = existingUser.copyWith(
          fullName: fullName.trim(),
          email: (email != null && email.trim().isNotEmpty) ? email.trim() : existingUser.email,
          phoneNumber: phoneNumber?.trim() ?? existingUser.phoneNumber,
          role: role ?? existingUser.role,
          photoUrl: photoUrl ?? existingUser.photoUrl,
        );
        _db.saveUser(updatedUser);
      }

      // Update local EmployeeEntity
      final localEmployees = _db.getEmployees();
      final existingEmp = localEmployees.firstWhere(
        (e) => e.id == userId || e.email == userId,
        orElse: () => EmployeeEntity(
          id: userId,
          employeeCode: employeeCode?.trim().isNotEmpty == true
              ? employeeCode!.trim()
              : 'EMP-000',
          name: fullName,
          mobileNumber: phoneNumber ?? '',
          email: email?.trim() ?? '',
          designation: designation ?? 'Team Member',
          department: department ?? 'Operations',
          photoUrl: photoUrl,
        ),
      );

      final updatedEmp = EmployeeEntity(
        id: existingEmp.id,
        employeeCode: (employeeCode != null && employeeCode.trim().isNotEmpty)
            ? employeeCode.trim()
            : existingEmp.employeeCode,
        name: fullName.trim(),
        mobileNumber: phoneNumber?.trim() ?? existingEmp.mobileNumber,
        email: (email != null && email.trim().isNotEmpty) ? email.trim() : existingEmp.email,
        designation: designation?.trim() ?? existingEmp.designation,
        department: department?.trim() ?? existingEmp.department,
        useDefaultOffice: useDefaultOffice ?? existingEmp.useDefaultOffice,
        assignedOfficeId: assignedOfficeId ?? existingEmp.assignedOfficeId,
        assignedOfficeName:
            assignedOfficeName ?? existingEmp.assignedOfficeName,
        isActive: existingEmp.isActive,
        photoUrl: photoUrl ?? existingEmp.photoUrl,
      );
      _db.saveEmployee(updatedEmp);

      await _supabase.updateUserInSupabase(
        userId: userId,
        orgId: orgId,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        role: role,
        employeeCode: employeeCode,
        designation: designation,
        department: department,
        useDefaultOffice: useDefaultOffice,
        assignedOfficeId: assignedOfficeId,
        actorUserId: actorUserId,
      );

      emit(UserManagementActionSuccess('User profile updated successfully.'));
      await fetchUsers();
    } catch (e) {
      emit(UserManagementError('Failed to update user: ${e.toString()}'));
    }
  }

  Future<void> updateEmployeePhoto(String userId, String photoUrl) async {
    try {
      final localUsers = _db.getUsers();
      final userIndex = localUsers.indexWhere((u) => u.id == userId || u.email == userId);
      if (userIndex >= 0) {
        final existingUser = localUsers[userIndex];
        _db.saveUser(existingUser.copyWith(photoUrl: photoUrl));
      }

      final localEmployees = _db.getEmployees();
      final empIndex = localEmployees.indexWhere((e) => e.id == userId || e.email == userId);
      if (empIndex >= 0) {
        final existingEmp = localEmployees[empIndex];
        _db.saveEmployee(existingEmp.copyWith(photoUrl: photoUrl));
      } else {
        final user = localUsers.firstWhere(
          (u) => u.id == userId || u.email == userId,
          orElse: () => _db.currentUser ??
              UserEntity(
                id: userId,
                firebaseUid: userId,
                email: '',
                fullName: 'Employee',
                role: UserRole.employee,
                organizationId: '',
                isActive: true,
              ),
        );
        _db.saveEmployee(EmployeeEntity(
          id: userId,
          employeeCode: user.employeeCode ?? 'EMP-001',
          name: user.fullName,
          mobileNumber: user.phoneNumber ?? '',
          email: user.email,
          designation: user.designation ?? 'Team Member',
          department: user.department ?? 'Operations',
          photoUrl: photoUrl,
        ));
      }

      emit(UserManagementActionSuccess('Employee photo attached successfully.'));
      await fetchUsers();
    } catch (e) {
      emit(UserManagementError('Failed to attach employee photo: ${e.toString()}'));
    }
  }

  Future<void> setUserActiveStatus(String userId, bool isActive) async {
    emit(UserManagementLoading());
    try {
      final orgId =
          _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
      final actorUserId = _db.currentUser?.id;

      // Update local storage
      final localEmployees = _db.getEmployees();
      final existingEmpIndex = localEmployees.indexWhere((e) => e.id == userId);
      if (existingEmpIndex >= 0) {
        final emp = localEmployees[existingEmpIndex];
        final updatedEmp = EmployeeEntity(
          id: emp.id,
          employeeCode: emp.employeeCode,
          name: emp.name,
          mobileNumber: emp.mobileNumber,
          email: emp.email,
          designation: emp.designation,
          department: emp.department,
          useDefaultOffice: emp.useDefaultOffice,
          assignedOfficeId: emp.assignedOfficeId,
          assignedOfficeName: emp.assignedOfficeName,
          isActive: isActive,
        );
        _db.saveEmployee(updatedEmp);
      }

      await _supabase.setUserActiveStatus(
        userId: userId,
        orgId: orgId,
        isActive: isActive,
        actorUserId: actorUserId,
      );

      final statusText = isActive ? 'activated' : 'disabled';
      emit(UserManagementActionSuccess('User account $statusText.'));
      await fetchUsers();
    } catch (e) {
      emit(UserManagementError(
          'Failed to update account status: ${e.toString()}'));
    }
  }

  Future<void> softDeleteUser(String userId, {String? email, String? fullName}) async {
    emit(UserManagementLoading());
    try {
      final orgId =
          _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
      final actorUserId = _db.currentUser?.id;

      // 1. Purge from local Hive storage immediately so user is removed from UI
      _db.deleteEmployee(userId);
      _db.deleteUser(userId);
      if (email != null && email.isNotEmpty) {
        _db.deleteEmployee(email);
        _db.deleteUser(email);
      }
      if (fullName != null && fullName.isNotEmpty) {
        _db.deleteEmployee(fullName);
        _db.deleteUser(fullName);
      }

      // 2. Soft delete in Supabase cloud database
      await _supabase.softDeleteUser(
        userId: userId,
        email: email,
        orgId: orgId,
        actorUserId: actorUserId,
      );

      // 3. Synchronize local DB cache with cloud
      await _supabase.syncCloudDataToLocal();

      emit(UserManagementActionSuccess('User deleted successfully.'));
      await fetchUsers();
    } catch (e) {
      emit(UserManagementError('Failed to delete user: ${e.toString()}'));
    }
  }

  Future<void> sendPasswordReset(String email, String userId) async {
    emit(UserManagementLoading());
    try {
      try {
        await _fbAuth?.sendPasswordResetEmail(email: email.trim().toLowerCase());
      } catch (_) {}

      // Set temporary password change flag in Supabase
      await _supabase.updateUserPasswordChangeStatus(userId, true);

      final orgId =
          _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
      await _supabase.logActivity(
        orgId: orgId,
        actorUserId: _db.currentUser?.id,
        targetUserId: userId,
        action: ActivityLogAction.passwordReset.dbValue,
        details: {'email': email},
      );

      emit(UserManagementActionSuccess(
          'Password reset link sent to $email. Required to change on next login.'));
      await fetchUsers();
    } catch (e) {
      emit(UserManagementError(
          'Failed to send password reset: ${e.toString()}'));
    }
  }
}
