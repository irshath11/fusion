import '../../../core/constants/app_enums.dart';

class UserEntity {
  final String id;
  final String firebaseUid;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final UserRole role;
  final String organizationId;
  final bool isActive;
  final bool requiresPasswordChange;
  final bool isDeleted;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final bool useDefaultOffice;
  final String? assignedOfficeId;
  final String? assignedOfficeName;

  UserEntity({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
    required this.organizationId,
    this.isActive = true,
    this.requiresPasswordChange = false,
    this.isDeleted = false,
    this.employeeCode,
    this.designation,
    this.department,
    this.useDefaultOffice = true,
    this.assignedOfficeId,
    this.assignedOfficeName,
  });

  /// Convenience getter for name
  String get name => fullName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'firebase_uid': firebaseUid,
        'email': email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'role': role.nameString,
        'organization_id': organizationId,
        'is_active': isActive,
        'requires_password_change': requiresPasswordChange,
        'is_deleted': isDeleted,
        'employee_code': employeeCode,
        'designation': designation,
        'department': department,
        'use_default_office': useDefaultOffice,
        'assigned_office_id': assignedOfficeId,
        'assigned_office_name': assignedOfficeName,
      };

  factory UserEntity.fromJson(Map<String, dynamic> json) => UserEntity(
        id: json['id'] ?? '',
        firebaseUid: json['firebase_uid'] ?? json['id'] ?? '',
        email: json['email'] ?? '',
        fullName: json['full_name'] ?? json['fullName'] ?? '',
        phoneNumber: json['phone_number'] ?? json['phoneNumber'],
        role: UserRoleExtension.fromString(json['role'] ?? 'EMPLOYEE'),
        organizationId: json['organization_id'] ?? json['organizationId'] ?? '',
        isActive: json['is_active'] ?? json['isActive'] ?? true,
        requiresPasswordChange:
            json['requires_password_change'] ?? json['requiresPasswordChange'] ?? false,
        isDeleted: json['is_deleted'] ?? json['isDeleted'] ?? false,
        employeeCode: json['employee_code'] ?? json['employeeCode'],
        designation: json['designation'],
        department: json['department'],
        useDefaultOffice:
            json['use_default_office'] ?? json['useDefaultOffice'] ?? true,
        assignedOfficeId: json['assigned_office_id'] ?? json['assignedOfficeId'],
        assignedOfficeName: json['assigned_office_name'] ?? json['assignedOfficeName'],
      );

  UserEntity copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? fullName,
    String? phoneNumber,
    UserRole? role,
    String? organizationId,
    bool? isActive,
    bool? requiresPasswordChange,
    bool? isDeleted,
    String? employeeCode,
    String? designation,
    String? department,
    bool? useDefaultOffice,
    String? assignedOfficeId,
    String? assignedOfficeName,
  }) {
    return UserEntity(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      isActive: isActive ?? this.isActive,
      requiresPasswordChange: requiresPasswordChange ?? this.requiresPasswordChange,
      isDeleted: isDeleted ?? this.isDeleted,
      employeeCode: employeeCode ?? this.employeeCode,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      useDefaultOffice: useDefaultOffice ?? this.useDefaultOffice,
      assignedOfficeId: assignedOfficeId ?? this.assignedOfficeId,
      assignedOfficeName: assignedOfficeName ?? this.assignedOfficeName,
    );
  }
}
