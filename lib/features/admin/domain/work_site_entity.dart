class WorkSiteEntity {
  final String id;
  final String siteName;
  final String clientName;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final List<String> assignedEmployeeIds;

  WorkSiteEntity({
    required this.id,
    required this.siteName,
    required this.clientName,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 200.0,
    required this.assignedEmployeeIds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteName': siteName,
        'clientName': clientName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'assignedEmployeeIds': assignedEmployeeIds,
      };

  factory WorkSiteEntity.fromJson(Map<String, dynamic> json) => WorkSiteEntity(
        id: json['id']?.toString() ?? '',
        siteName: json['siteName']?.toString() ?? json['site_name']?.toString() ?? '',
        clientName: json['clientName']?.toString() ?? json['client_name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ??
            (json['radius_meters'] as num?)?.toDouble() ??
            200.0,
        assignedEmployeeIds: List<String>.from(
            json['assignedEmployeeIds'] ?? json['assigned_employee_ids'] ?? []),
      );
}
