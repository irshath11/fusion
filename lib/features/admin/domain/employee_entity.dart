class EmployeeEntity {
  final String id;
  final String employeeCode;
  final String name;
  final String mobileNumber;
  final String email;
  final String designation;
  final String department;
  final bool useDefaultOffice;
  final String? assignedOfficeId;
  final String? assignedOfficeName;
  final bool isActive;

  EmployeeEntity({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.mobileNumber,
    required this.email,
    required this.designation,
    required this.department,
    this.useDefaultOffice = true,
    this.assignedOfficeId,
    this.assignedOfficeName,
    this.isActive = true,
  });

  String get fullName => name;
  String get displayName => name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeCode': employeeCode,
        'name': name,
        'mobileNumber': mobileNumber,
        'email': email,
        'designation': designation,
        'department': department,
        'useDefaultOffice': useDefaultOffice,
        'assignedOfficeId': assignedOfficeId,
        'assignedOfficeName': assignedOfficeName,
        'isActive': isActive,
      };

  factory EmployeeEntity.fromJson(Map<String, dynamic> json) => EmployeeEntity(
        id: json['id'],
        employeeCode: json['employeeCode'],
        name: json['name'],
        mobileNumber: json['mobileNumber'],
        email: json['email'],
        designation: json['designation'],
        department: json['department'],
        useDefaultOffice: json['useDefaultOffice'] ?? true,
        assignedOfficeId: json['assignedOfficeId'],
        assignedOfficeName: json['assignedOfficeName'],
        isActive: json['isActive'] ?? true,
      );
}
