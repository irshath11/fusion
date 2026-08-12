enum UserRole {
  superAdmin('SUPER_ADMIN', 'Super Admin'),
  admin('ADMIN', 'Administrator'),
  employee('EMPLOYEE', 'Employee');

  final String nameString;
  final String displayName;

  const UserRole(this.nameString, this.displayName);

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

extension UserRoleExtension on UserRole {
  String get nameString => this.nameString;
  String get displayName => this.displayName;

  static UserRole fromString(String role) => UserRole.fromString(role);
}

enum ActivityLogAction {
  orgSetup('ORG_SETUP'),
  employeeCreated('EMPLOYEE_CREATED'),
  employeeUpdated('EMPLOYEE_UPDATED'),
  employeeDisabled('EMPLOYEE_DISABLED'),
  employeeActivated('EMPLOYEE_ACTIVATED'),
  employeeDeleted('EMPLOYEE_DELETED'),
  passwordReset('PASSWORD_RESET'),
  ownershipTransferred('OWNERSHIP_TRANSFERRED'),
  deviceBound('DEVICE_BOUND');

  final String dbValue;

  const ActivityLogAction(this.dbValue);
}

extension ActivityLogActionExtension on ActivityLogAction {
  String get dbValue => this.dbValue;
}

enum WorkflowStep {
  officeCheckIn('1. Office Check-In', 'OFFICE_CHECK_IN'),
  siteCheckIn('2. Site Check-In', 'SITE_CHECK_IN'),
  siteCheckOut('3. Site Check-Out (Leaving Site)', 'SITE_CHECK_OUT'),
  officeCheckOut('4. Office Check-Out (Reach Office)', 'OFFICE_CHECK_OUT'),
  completed('Shift Completed', 'COMPLETED');

  final String displayName;
  final String dbValue;

  const WorkflowStep(this.displayName, this.dbValue);

  WorkflowStep? get nextStep {
    switch (this) {
      case WorkflowStep.officeCheckIn:
        return WorkflowStep.siteCheckIn;
      case WorkflowStep.siteCheckIn:
        return WorkflowStep.siteCheckOut;
      case WorkflowStep.siteCheckOut:
        return WorkflowStep.officeCheckOut;
      case WorkflowStep.officeCheckOut:
        return WorkflowStep.completed;
      case WorkflowStep.completed:
        return null;
    }
  }
}

extension WorkflowStepExtension on WorkflowStep {
  String get displayName => this.displayName;
  String get dbValue => this.dbValue;
  WorkflowStep? get nextStep => this.nextStep;
}

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
}
