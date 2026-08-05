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
    String? address,
    SyncStatus? syncStatus,
    DateTime? syncTimestamp,
    String? siteName,
    String? photoBase64,
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
      address: address ?? this.address,
      deviceId: deviceId,
      photoBase64: photoBase64 ?? this.photoBase64,
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

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final stepVal = json['workflowStep'] ?? json['workflow_step'] ?? 'officeCheckIn';
    final step = WorkflowStep.values.firstWhere(
      (e) => e.dbValue == stepVal || e.name == stepVal,
      orElse: () => WorkflowStep.officeCheckIn,
    );

    final rawEventTime = json['eventTimestamp'] ?? json['event_timestamp'];
    final eventTime = rawEventTime != null
        ? DateTime.parse(rawEventTime.toString())
        : DateTime.now();

    final rawSyncTime = json['syncTimestamp'] ?? json['sync_timestamp'];
    final syncTime = rawSyncTime != null
        ? DateTime.parse(rawSyncTime.toString())
        : null;

    final rawSyncStatus = json['syncStatus'] ?? json['sync_status'];
    final status = SyncStatus.values.firstWhere(
      (e) => e.name == rawSyncStatus,
      orElse: () => SyncStatus.pending,
    );

    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString() ?? 'Unknown Employee',
      workflowStep: step,
      eventTimestamp: eventTime,
      syncTimestamp: syncTime,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (json['gpsAccuracy'] ?? json['gps_accuracy'] as num?)?.toDouble() ?? 5.0,
      address: json['address']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? json['device_id']?.toString() ?? '',
      photoBase64: json['photoBase64']?.toString() ?? json['photo_url']?.toString() ?? json['photo_base64']?.toString() ?? '',
      isGeofenceValid: json['isGeofenceValid'] ?? json['is_geofence_valid'] ?? true,
      officeId: json['officeId']?.toString() ?? json['office_id']?.toString(),
      workSiteId: json['workSiteId']?.toString() ?? json['work_site_id']?.toString(),
      siteName: json['siteName']?.toString() ?? json['site_name']?.toString(),
      syncStatus: status,
    );
  }
}
