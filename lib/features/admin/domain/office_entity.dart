class OfficeEntity {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;
  final bool isDefault;

  OfficeEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.geofenceRadiusMeters = 200.0,
    this.isDefault = false,
  });

  String get displayName => name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'geofenceRadiusMeters': geofenceRadiusMeters,
        'isDefault': isDefault,
      };

  factory OfficeEntity.fromJson(Map<String, dynamic> json) => OfficeEntity(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        geofenceRadiusMeters:
            (json['geofenceRadiusMeters'] ?? json['geofence_radius_meters'] as num?)?.toDouble() ?? 200.0,
        isDefault: json['isDefault'] ?? json['is_default'] ?? false,
      );
}
