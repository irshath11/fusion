import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/app_enums.dart';
import '../../auth/domain/user_entity.dart';

abstract class OwnershipTransferState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OwnershipTransferInitial extends OwnershipTransferState {}

class OwnershipTransferLoading extends OwnershipTransferState {}

class OwnershipTransferSuccess extends OwnershipTransferState {
  final String message;
  OwnershipTransferSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class OwnershipTransferError extends OwnershipTransferState {
  final String message;
  OwnershipTransferError(this.message);

  @override
  List<Object?> get props => [message];
}

class OwnershipTransferCubit extends Cubit<OwnershipTransferState> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final SupabaseService _supabase = SupabaseService();
  fb.FirebaseAuth? get _fbAuth {
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  OwnershipTransferCubit() : super(OwnershipTransferInitial());

  Future<void> executeOwnershipTransfer({
    required UserEntity currentSuperAdmin,
    required UserEntity targetAdmin,
    required String superAdminPassword,
  }) async {
    emit(OwnershipTransferLoading());
    try {
      // 1. Identity Verification: Re-authenticate Super Admin with password
      final currentUser = _fbAuth?.currentUser;
      if (currentUser != null && currentUser.email != null) {
        try {
          final cred = fb.EmailAuthProvider.credential(
            email: currentUser.email!,
            password: superAdminPassword,
          );
          await currentUser.reauthenticateWithCredential(cred);
        } on fb.FirebaseAuthException catch (e) {
          emit(OwnershipTransferError(
              'Identity verification failed: ${e.message ?? "Incorrect password"}'));
          return;
        }
      }

      final orgId = _db.organization?.id ?? currentSuperAdmin.organizationId;

      // 2. Execute Atomic Ownership Transfer in Supabase via RPC
      final success = await _supabase.transferOrganizationOwnership(
        orgId: orgId,
        currentSuperAdminId: currentSuperAdmin.id,
        targetAdminId: targetAdmin.id,
      );

      if (!success) {
        // Fallback: Perform direct updates & audit log if RPC not deployed yet
        await _supabase.updateUserInSupabase(
          userId: targetAdmin.id,
          orgId: orgId,
          fullName: targetAdmin.fullName,
          role: UserRole.superAdmin,
          actorUserId: currentSuperAdmin.id,
        );

        await _supabase.updateUserInSupabase(
          userId: currentSuperAdmin.id,
          orgId: orgId,
          fullName: currentSuperAdmin.fullName,
          role: UserRole.admin,
          actorUserId: currentSuperAdmin.id,
        );

        await _supabase.logActivity(
          orgId: orgId,
          actorUserId: currentSuperAdmin.id,
          targetUserId: targetAdmin.id,
          action: ActivityLogAction.ownershipTransferred.dbValue,
          details: {
            'previous_super_admin': currentSuperAdmin.email,
            'new_super_admin': targetAdmin.email,
          },
        );
      }

      // Update current user local session role to ADMIN
      final demotedUser = currentSuperAdmin.copyWith(role: UserRole.admin);
      _db.setCurrentUser(demotedUser);

      emit(OwnershipTransferSuccess(
          'Organization ownership successfully transferred to ${targetAdmin.fullName}. Your account role is now Administrator.'));
    } catch (e) {
      emit(OwnershipTransferError('Failed to transfer ownership: ${e.toString()}'));
    }
  }
}
