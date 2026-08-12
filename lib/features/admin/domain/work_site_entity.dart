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

  String get name => siteName;
  String get displayName => siteName;

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
        id: json['id'],
        siteName: json['siteName'],
        clientName: json['clientName'],
        address: json['address'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 200.0,
        assignedEmployeeIds: List<String>.from(json['assignedEmployeeIds'] ?? []),
      );
}
