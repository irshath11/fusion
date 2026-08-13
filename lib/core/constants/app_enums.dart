enum UserRole {
  superAdmin,
  admin,
  employee,
}

extension UserRoleExtension on UserRole {
  String get nameString {
    switch (this) {
      case UserRole.superAdmin:
        return 'SUPER_ADMIN';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.employee:
        return 'EMPLOYEE';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.employee:
        return 'Employee';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      case 'ADMIN':
        return UserRole.admin;
      case 'EMPLOYEE':
      default:
        return UserRole.employee;
    }
  }
}

enum ActivityLogAction {
  orgSetup,
  employeeCreated,
  employeeUpdated,
  employeeDisabled,
  employeeActivated,
  employeeDeleted,
  passwordReset,
  ownershipTransferred,
  deviceBound,
}

extension ActivityLogActionExtension on ActivityLogAction {
  String get dbValue {
    switch (this) {
      case ActivityLogAction.orgSetup:
        return 'ORG_SETUP';
      case ActivityLogAction.employeeCreated:
        return 'EMPLOYEE_CREATED';
      case ActivityLogAction.employeeUpdated:
        return 'EMPLOYEE_UPDATED';
      case ActivityLogAction.employeeDisabled:
        return 'EMPLOYEE_DISABLED';
      case ActivityLogAction.employeeActivated:
        return 'EMPLOYEE_ACTIVATED';
      case ActivityLogAction.employeeDeleted:
        return 'EMPLOYEE_DELETED';
      case ActivityLogAction.passwordReset:
        return 'PASSWORD_RESET';
      case ActivityLogAction.ownershipTransferred:
        return 'OWNERSHIP_TRANSFERRED';
      case ActivityLogAction.deviceBound:
        return 'DEVICE_BOUND';
    }
  }
}

enum WorkflowStep {
  officeCheckIn,
  siteCheckIn,
  siteCheckOut,
  breakStart,
  breakEnd,
  officeCheckOut,
  completed,
}

extension WorkflowStepExtension on WorkflowStep {
  String get displayName {
    switch (this) {
      case WorkflowStep.officeCheckIn:
        return '1. Office Check-In';
      case WorkflowStep.siteCheckIn:
        return '2. Site Check-In';
      case WorkflowStep.siteCheckOut:
        return '3. Site Check-Out (Leaving Site)';
      case WorkflowStep.breakStart:
        return 'Break Started';
      case WorkflowStep.breakEnd:
        return 'Break Ended';
      case WorkflowStep.officeCheckOut:
        return '4. Office Check-Out (Reach Office)';
      case WorkflowStep.completed:
        return 'Shift Completed';
    }
  }

  String get dbValue {
    switch (this) {
      case WorkflowStep.officeCheckIn:
        return 'OFFICE_CHECK_IN';
      case WorkflowStep.siteCheckIn:
        return 'SITE_CHECK_IN';
      case WorkflowStep.siteCheckOut:
        return 'SITE_CHECK_OUT';
      case WorkflowStep.breakStart:
        return 'BREAK_START';
      case WorkflowStep.breakEnd:
        return 'BREAK_END';
      case WorkflowStep.officeCheckOut:
        return 'OFFICE_CHECK_OUT';
      case WorkflowStep.completed:
        return 'COMPLETED';
    }
  }

  WorkflowStep? get nextStep {
    switch (this) {
      case WorkflowStep.officeCheckIn:
        return WorkflowStep.siteCheckIn;
      case WorkflowStep.siteCheckIn:
        return WorkflowStep.siteCheckOut;
      case WorkflowStep.siteCheckOut:
        return WorkflowStep.officeCheckOut;
      case WorkflowStep.breakStart:
        return WorkflowStep.breakEnd;
      case WorkflowStep.breakEnd:
        return WorkflowStep.siteCheckIn;
      case WorkflowStep.officeCheckOut:
        return WorkflowStep.completed;
      case WorkflowStep.completed:
        return null;
    }
  }
}

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
}
