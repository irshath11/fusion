import '../../../core/constants/app_enums.dart';

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final WorkflowStep workflowStep;
  final DateTime eventTimestamp; // Original attendance capture time
  final DateTime? syncTimestamp; // Time when synced to cloud
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String address;
  final String deviceId;
  final String photoBase64;
  final bool isGeofenceValid;
  final String? officeId;
  final String? workSiteId;
  final String? siteName;
  final SyncStatus syncStatus;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.workflowStep,
    required this.eventTimestamp,
    this.syncTimestamp,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.address,
    required this.deviceId,
    required this.photoBase64,
    required this.isGeofenceValid,
    this.officeId,
    this.workSiteId,
    this.siteName,
    this.syncStatus = SyncStatus.pending,
  });

  AttendanceRecord copyWith({
    SyncStatus? syncStatus,
    DateTime? syncTimestamp,
    String? siteName,
  }) {
    return AttendanceRecord(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      workflowStep: workflowStep,
      eventTimestamp: eventTimestamp,
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      address: address,
      deviceId: deviceId,
      photoBase64: photoBase64,
      isGeofenceValid: isGeofenceValid,
      officeId: officeId,
      workSiteId: workSiteId,
      siteName: siteName ?? this.siteName,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'workflowStep': workflowStep.dbValue,
        'eventTimestamp': eventTimestamp.toIso8601String(),
        'syncTimestamp': syncTimestamp?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'gpsAccuracy': gpsAccuracy,
        'address': address,
        'deviceId': deviceId,
        'photoBase64': photoBase64,
        'isGeofenceValid': isGeofenceValid,
        'officeId': officeId,
        'workSiteId': workSiteId,
        'siteName': siteName,
        'syncStatus': syncStatus.name,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'],
        employeeId: json['employeeId'],
        employeeName: json['employeeName'] ?? 'Unknown Employee',
        workflowStep: WorkflowStep.values.firstWhere(
          (e) => e.dbValue == json['workflowStep'] || e.name == json['workflowStep'],
          orElse: () => WorkflowStep.officeCheckIn,
        ),
        eventTimestamp: DateTime.parse(json['eventTimestamp']),
        syncTimestamp: json['syncTimestamp'] != null ? DateTime.parse(json['syncTimestamp']) : null,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        gpsAccuracy: (json['gpsAccuracy'] as num).toDouble(),
        address: json['address'] ?? '',
        deviceId: json['deviceId'] ?? '',
        photoBase64: json['photoBase64'] ?? '',
        isGeofenceValid: json['isGeofenceValid'] ?? true,
        officeId: json['officeId'] ?? json['office_id'],
        workSiteId: json['workSiteId'] ?? json['work_site_id'],
        siteName: json['siteName'] ?? json['site_name'],
        syncStatus: SyncStatus.values.firstWhere(
          (e) => e.name == json['syncStatus'],
          orElse: () => SyncStatus.pending,
        ),
      );
}
