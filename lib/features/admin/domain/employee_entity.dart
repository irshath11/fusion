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
  final String? photoUrl;

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
    this.photoUrl,
  });

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
        'photoUrl': photoUrl,
        'photo_url': photoUrl,
      };

  factory EmployeeEntity.fromJson(Map<String, dynamic> json) => EmployeeEntity(
        id: json['id'],
        employeeCode: json['employeeCode'] ?? json['employee_code'] ?? '',
        name: json['name'] ?? '',
        mobileNumber: json['mobileNumber'] ?? json['mobile_number'] ?? '',
        email: json['email'] ?? '',
        designation: json['designation'] ?? '',
        department: json['department'] ?? '',
        useDefaultOffice: json['useDefaultOffice'] ?? json['use_default_office'] ?? true,
        assignedOfficeId: json['assignedOfficeId'] ?? json['assigned_office_id'],
        assignedOfficeName: json['assignedOfficeName'] ?? json['assigned_office_name'],
        isActive: json['isActive'] ?? json['is_active'] ?? true,
        photoUrl: json['photoUrl'] ?? json['photo_url'],
      );

  EmployeeEntity copyWith({
    String? id,
    String? employeeCode,
    String? name,
    String? mobileNumber,
    String? email,
    String? designation,
    String? department,
    bool? useDefaultOffice,
    String? assignedOfficeId,
    String? assignedOfficeName,
    bool clearAssignedOffice = false,
    bool? isActive,
    String? photoUrl,
  }) {
    return EmployeeEntity(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      useDefaultOffice: useDefaultOffice ?? this.useDefaultOffice,
      assignedOfficeId: clearAssignedOffice
          ? null
          : (assignedOfficeId ?? this.assignedOfficeId),
      assignedOfficeName: clearAssignedOffice
          ? null
          : (assignedOfficeName ?? this.assignedOfficeName),
      isActive: isActive ?? this.isActive,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
