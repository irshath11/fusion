import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/role_permissions.dart';
import 'package:attendance_app/features/auth/domain/user_entity.dart';

void main() {
  group('UserRole & RBAC Permissions Tests', () {
    test('UserRoleExtension maps strings correctly', () {
      expect(UserRoleExtension.fromString('SUPER_ADMIN'), UserRole.superAdmin);
      expect(UserRoleExtension.fromString('ADMIN'), UserRole.admin);
      expect(UserRoleExtension.fromString('EMPLOYEE'), UserRole.employee);
      expect(UserRoleExtension.fromString('unknown'), UserRole.employee);
    });

    test('Super Admin has all permissions including ownership transfer', () {
      expect(RolePermissions.canPerform(UserRole.superAdmin, AppPermission.transferOwnership), isTrue);
      expect(RolePermissions.canPerform(UserRole.superAdmin, AppPermission.manageAdmins), isTrue);
      expect(RolePermissions.canPerform(UserRole.superAdmin, AppPermission.manageEmployees), isTrue);
      expect(RolePermissions.canPerform(UserRole.superAdmin, AppPermission.resetEmployeePassword), isTrue);
    });

    test('Admin cannot transfer ownership or manage admins', () {
      expect(RolePermissions.canPerform(UserRole.admin, AppPermission.transferOwnership), isFalse);
      expect(RolePermissions.canPerform(UserRole.admin, AppPermission.manageAdmins), isFalse);
      expect(RolePermissions.canPerform(UserRole.admin, AppPermission.manageEmployees), isTrue);
      expect(RolePermissions.canPerform(UserRole.admin, AppPermission.resetEmployeePassword), isTrue);
    });

    test('Employee cannot manage employees or reset passwords', () {
      expect(RolePermissions.canPerform(UserRole.employee, AppPermission.transferOwnership), isFalse);
      expect(RolePermissions.canPerform(UserRole.employee, AppPermission.manageEmployees), isFalse);
      expect(RolePermissions.canPerform(UserRole.employee, AppPermission.resetEmployeePassword), isFalse);
      expect(RolePermissions.canPerform(UserRole.employee, AppPermission.submitAttendance), isTrue);
    });
  });

  group('UserEntity Serialization & CopyWith Tests', () {
    test('UserEntity toJson and fromJson match', () {
      final user = UserEntity(
        id: 'usr-123',
        firebaseUid: 'fb-uid-123',
        email: 'admin@enterprise.com',
        fullName: 'Jane Doe',
        phoneNumber: '+971501234567',
        role: UserRole.superAdmin,
        organizationId: 'org-999',
        isActive: true,
        requiresPasswordChange: true,
      );

      final json = user.toJson();
      final parsed = UserEntity.fromJson(json);

      expect(parsed.id, 'usr-123');
      expect(parsed.firebaseUid, 'fb-uid-123');
      expect(parsed.email, 'admin@enterprise.com');
      expect(parsed.fullName, 'Jane Doe');
      expect(parsed.role, UserRole.superAdmin);
      expect(parsed.requiresPasswordChange, isTrue);
    });

    test('UserEntity copyWith modifies specific fields', () {
      final user = UserEntity(
        id: 'usr-123',
        firebaseUid: 'fb-123',
        email: 'user@enterprise.com',
        fullName: 'John Smith',
        role: UserRole.admin,
        organizationId: 'org-001',
      );

      final demoted = user.copyWith(role: UserRole.employee, requiresPasswordChange: false);
      expect(demoted.role, UserRole.employee);
      expect(demoted.requiresPasswordChange, isFalse);
      expect(demoted.email, 'user@enterprise.com');
    });
  });

  group('ActivityLogAction Enum Tests', () {
    test('ActivityLogAction returns correct db values', () {
      expect(ActivityLogAction.orgSetup.dbValue, 'ORG_SETUP');
      expect(ActivityLogAction.ownershipTransferred.dbValue, 'OWNERSHIP_TRANSFERRED');
      expect(ActivityLogAction.passwordReset.dbValue, 'PASSWORD_RESET');
    });
  });
}
