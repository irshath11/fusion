import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/organization_setup.dart';
import '../../auth/domain/user_entity.dart';
import '../../../core/constants/app_enums.dart';

abstract class SetupState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SetupInitial extends SetupState {}
class SetupLoading extends SetupState {}
class SetupSuccess extends SetupState {
  final OrganizationSetup setup;
  SetupSuccess(this.setup);

  @override
  List<Object?> get props => [setup];
}
class SetupError extends SetupState {
  final String message;
  SetupError(this.message);

  @override
  List<Object?> get props => [message];
}

class SetupCubit extends Cubit<SetupState> {
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

  SetupCubit() : super(SetupInitial());

  Future<void> submitFirstTimeSetup({
    required String orgName,
    required String orgAddress,
    required String adminName,
    required String adminEmail,
    required String adminMobile,
    required String adminPassword,
  }) async {
    emit(SetupLoading());
    try {
      final trimmedOrgName = orgName.trim();
      final trimmedOrgAddress = orgAddress.trim();
      final trimmedAdminName = adminName.trim();
      final trimmedAdminEmail = adminEmail.trim().toLowerCase();
      final trimmedAdminMobile = adminMobile.trim();

      if (trimmedOrgName.isEmpty ||
          trimmedAdminEmail.isEmpty ||
          adminPassword.trim().isEmpty) {
        emit(SetupError('Please fill in all required setup fields.'));
        return;
      }

      String firebaseUid = 'super_admin_${_uuid.v4()}';

      // 1. Create Super Admin account in Firebase Authentication
      try {
        final auth = _fbAuth;
        if (auth != null) {
          final credential = await auth.createUserWithEmailAndPassword(
            email: trimmedAdminEmail,
            password: adminPassword,
          );
          if (credential.user != null) {
            firebaseUid = credential.user!.uid;
            await credential.user!.updateDisplayName(trimmedAdminName);
          }
        }
      } on fb.FirebaseAuthException catch (e) {
        // If email already in use or offline, log warning and use fallback UID
        if (e.code == 'email-already-in-use') {
          try {
            final auth = _fbAuth;
            if (auth != null) {
              final loginCred = await auth.signInWithEmailAndPassword(
                email: trimmedAdminEmail,
                password: adminPassword,
              );
              if (loginCred.user != null) {
                firebaseUid = loginCred.user!.uid;
              }
            }
          } catch (_) {}
        }
      } catch (e) {
        // Offline or unconfigured Firebase project fallback
      }

      final orgId = _uuid.v4();

      final setup = OrganizationSetup(
        id: orgId,
        name: trimmedOrgName,
        address: trimmedOrgAddress,
        superAdminName: trimmedAdminName,
        superAdminEmail: trimmedAdminEmail,
        mobileNumber: trimmedAdminMobile,
        superAdminPassword: adminPassword.trim(),
        createdAt: DateTime.now(),
      );

      // 2. Create Organization, Super Admin user record, and Main Office in Supabase
      await _supabase.saveOrganizationSetup(
        setup: setup,
        firebaseUid: firebaseUid,
      );

      // 3. Save locally
      await _db.completeFirstTimeSetup(setup);

      final superAdminUser = UserEntity(
        id: firebaseUid,
        firebaseUid: firebaseUid,
        email: trimmedAdminEmail,
        fullName: trimmedAdminName,
        phoneNumber: trimmedAdminMobile,
        role: UserRole.superAdmin,
        organizationId: setup.id,
        isActive: true,
        requiresPasswordChange: false,
      );
      _db.setCurrentUser(superAdminUser);

      emit(SetupSuccess(setup));
    } catch (e) {
      emit(SetupError('Failed to complete organization setup: ${e.toString()}'));
    }
  }
}
