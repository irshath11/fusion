import '../constants/app_enums.dart';

enum AppPermission {
  transferOwnership,
  manageAdmins,
  manageEmployees,
  resetEmployeePassword,
  manageOffices,
  manageWorkSites,
  viewAnalyticsReports,
  viewOwnAttendance,
  submitAttendance,
}

class RolePermissions {
  static bool canPerform(UserRole role, AppPermission permission) {
    switch (permission) {
      case AppPermission.transferOwnership:
      case AppPermission.manageAdmins:
        return role == UserRole.superAdmin;

      case AppPermission.manageEmployees:
      case AppPermission.resetEmployeePassword:
      case AppPermission.manageOffices:
      case AppPermission.manageWorkSites:
      case AppPermission.viewAnalyticsReports:
        return role == UserRole.superAdmin || role == UserRole.admin;

      case AppPermission.viewOwnAttendance:
      case AppPermission.submitAttendance:
        return true; // All authenticated users can view/submit their attendance
    }
  }

  static bool isSuperAdmin(UserRole role) => role == UserRole.superAdmin;
  static bool isAdminOrHigher(UserRole role) =>
      role == UserRole.superAdmin || role == UserRole.admin;
}
