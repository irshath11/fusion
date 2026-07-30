class OrganizationSetup {
  final String id;
  final String name;
  final String address;
  final String superAdminName;
  final String superAdminEmail;
  final String? mobileNumber;
  final String superAdminPassword;
  final DateTime createdAt;

  OrganizationSetup({
    required this.id,
    required this.name,
    required this.address,
    required this.superAdminName,
    required this.superAdminEmail,
    this.mobileNumber,
    required this.superAdminPassword,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'superAdminName': superAdminName,
        'superAdminEmail': superAdminEmail,
        'mobileNumber': mobileNumber,
        'superAdminPassword': superAdminPassword,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OrganizationSetup.fromJson(Map<String, dynamic> json) => OrganizationSetup(
        id: json['id'],
        name: json['name'],
        address: json['address'],
        superAdminName: json['superAdminName'],
        superAdminEmail: json['superAdminEmail'],
        mobileNumber: json['mobileNumber'],
        superAdminPassword: json['superAdminPassword'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
      );
}
