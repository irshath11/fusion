import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/utils/geofence_calculator.dart';
import '../domain/attendance_record.dart';
import '../../admin/domain/employee_entity.dart';
import '../../admin/domain/office_entity.dart';

abstract class AttendanceState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {
  final WorkflowStep currentStep;
  AttendanceInitial(this.currentStep);

  @override
  List<Object?> get props => [currentStep];
}

class AttendanceProcessing extends AttendanceState {}

class AttendanceStepSuccess extends AttendanceState {
  final AttendanceRecord record;
  final WorkflowStep nextStep;
  AttendanceStepSuccess(this.record, this.nextStep);

  @override
  List<Object?> get props => [record, nextStep];
}

class GeofenceViolationError extends AttendanceState {
  final String message;
  final double distanceMeters;
  final double allowedRadiusMeters;

  GeofenceViolationError({
    required this.message,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
  });

  @override
  List<Object?> get props => [message, distanceMeters, allowedRadiusMeters];
}

class AttendanceFailure extends AttendanceState {
  final String errorMessage;
  AttendanceFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class LocationServicesDisabledError extends AttendanceState {
  final String message;
  final bool isPermissionDenied;

  LocationServicesDisabledError({
    required this.message,
    this.isPermissionDenied = false,
  });

  @override
  List<Object?> get props => [message, isPermissionDenied];
}

class AttendanceCubit extends Cubit<AttendanceState> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final Uuid _uuid = const Uuid();

  AttendanceCubit() : super(AttendanceInitial(LocalDatabaseService().getWorkflowStepForEmployee()));

  /// Executes attendance action for current workflow step with camera & geofence validation
  Future<void> executeAttendanceStep({
    required WorkflowStep step,
    CameraCaptureResult? cameraResult,
    String? siteName,
  }) async {
    emit(AttendanceProcessing());
    try {
      final user = _db.currentUser;
      if (user == null) {
        emit(AttendanceFailure('User session not found. Please log in again.'));
        return;
      }

      // 1. Get Live GPS Location
      LocationDataResult location = await LocationService.getCurrentLocation();

      final bool isLocationError = !location.isSuccess ||
          (location.latitude == 0.0 && location.longitude == 0.0) ||
          location.address.contains('Disabled') ||
          location.address.contains('Permission') ||
          location.address.contains('GPS Error') ||
          location.address.contains('Timeout') ||
          location.address.contains('Unavailable');

      if (isLocationError) {
        emit(LocationServicesDisabledError(
          message: location.address.isNotEmpty
              ? location.address
              : 'Location Services Disabled. Please turn on Location (GPS) in your device settings.',
          isPermissionDenied: location.address.contains('Permission'),
        ));
        return;
      }

      // Ensure local offices & employee data are synced from Supabase cloud if missing
      if (_db.getOffices().isEmpty) {
        try {
          await SupabaseService().syncCloudDataToLocal();
        } catch (_) {}
      }

      // 2. Resolve target geofence bounds based on employee's assigned office / site
      final employees = _db.getEmployees();
      EmployeeEntity? matchedEmp;

      // 2a. Match by exact user ID or Firebase UID
      for (final e in employees) {
        if (e.id.isNotEmpty && (e.id == user.id || (user.firebaseUid.isNotEmpty && e.id == user.firebaseUid))) {
          matchedEmp = e;
          break;
        }
      }

      // 2b. Match by Email
      if (matchedEmp == null && user.email.trim().isNotEmpty) {
        for (final e in employees) {
          if (e.email.trim().isNotEmpty && e.email.trim().toLowerCase() == user.email.trim().toLowerCase()) {
            matchedEmp = e;
            break;
          }
        }
      }

      // 2c. Match by Full Name
      if (matchedEmp == null && user.fullName.trim().isNotEmpty) {
        for (final e in employees) {
          if (e.name.trim().isNotEmpty && e.name.trim().toLowerCase() == user.fullName.trim().toLowerCase()) {
            matchedEmp = e;
            break;
          }
        }
      }

      // 2d. If employee entity does not yet exist locally, construct from current user and save it
      // CRITICAL: NEVER fallback to employees.first, which mistakenly assigns logs to another person!
      if (matchedEmp == null) {
        final cleanName = user.fullName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
        final prefix = cleanName.length >= 4
            ? cleanName.substring(0, 4)
            : (cleanName.isNotEmpty ? cleanName : 'STAFF');
        final code = user.employeeCode ?? 'EMP-$prefix';

        matchedEmp = EmployeeEntity(
          id: user.id.isNotEmpty ? user.id : (user.firebaseUid.isNotEmpty ? user.firebaseUid : _uuid.v4()),
          employeeCode: code,
          name: user.fullName.trim().isNotEmpty ? user.fullName.trim() : user.email.split('@').first,
          mobileNumber: user.phoneNumber ?? '',
          email: user.email,
          designation: user.designation ?? 'Field Staff',
          department: user.department ?? 'Operations',
          isActive: true,
        );
        _db.saveEmployee(matchedEmp);
      }
      final emp = matchedEmp;

      double targetLat = 0.0;
      double targetLng = 0.0;
      double allowedRadius = 200.0;

      final offices = _db.getOffices();
      final defaultOffice = offices.isNotEmpty
          ? offices.firstWhere((o) => o.isDefault, orElse: () => offices.first)
          : OfficeEntity(
              id: 'office-default',
              name: 'Main Office',
              address: 'HQ Operations',
              latitude: 24.365500,
              longitude: 54.500531,
              geofenceRadiusMeters: 50000.0, // generous default radius
              isDefault: true,
            );
      final workSites = _db.getWorkSites();

      bool isGeofenceValid = true;

      // Geofence validation is ONLY enforced for the initial starting check-in (officeCheckIn)
      if (step == WorkflowStep.officeCheckIn) {
        if (!emp.useDefaultOffice && emp.assignedOfficeId != null) {
          final customOfficeMatches = offices.where((o) => o.id == emp.assignedOfficeId);
          if (customOfficeMatches.isNotEmpty) {
            targetLat = customOfficeMatches.first.latitude;
            targetLng = customOfficeMatches.first.longitude;
            allowedRadius = customOfficeMatches.first.geofenceRadiusMeters;
          } else {
            final siteMatches = workSites.where((s) => s.id == emp.assignedOfficeId);
            if (siteMatches.isNotEmpty) {
              targetLat = siteMatches.first.latitude;
              targetLng = siteMatches.first.longitude;
              allowedRadius = siteMatches.first.radiusMeters;
            } else {
              targetLat = defaultOffice.latitude;
              targetLng = defaultOffice.longitude;
              allowedRadius = defaultOffice.geofenceRadiusMeters;
            }
          }
        } else {
          targetLat = defaultOffice.latitude;
          targetLng = defaultOffice.longitude;
          allowedRadius = defaultOffice.geofenceRadiusMeters;
        }

        double distance = GeofenceCalculator.calculateDistanceInMeters(
          location.latitude,
          location.longitude,
          targetLat,
          targetLng,
        );

        isGeofenceValid = distance <= allowedRadius;

        if (!isGeofenceValid) {
          emit(GeofenceViolationError(
            message: 'You are outside your assigned office location geofence.',
            distanceMeters: distance,
            allowedRadiusMeters: allowedRadius,
          ));
          return;
        }
      }

      // 4. Resolve Location Place Name & GPS Coordinates
      String resolvedLocationName = '';
      if (siteName != null && siteName.trim().isNotEmpty) {
        resolvedLocationName = siteName.trim();
      } else if (step == WorkflowStep.officeCheckIn || step == WorkflowStep.officeCheckOut) {
        if (!emp.useDefaultOffice && emp.assignedOfficeId != null) {
          final customOfficeMatches = offices.where((o) => o.id == emp.assignedOfficeId);
          final siteMatches = workSites.where((s) => s.id == emp.assignedOfficeId);
          if (customOfficeMatches.isNotEmpty) {
            resolvedLocationName = customOfficeMatches.first.name;
          } else if (siteMatches.isNotEmpty) {
            resolvedLocationName = siteMatches.first.siteName;
          } else if (emp.assignedOfficeName != null && emp.assignedOfficeName!.trim().isNotEmpty) {
            resolvedLocationName = emp.assignedOfficeName!.trim();
          } else {
            resolvedLocationName = defaultOffice.name;
          }
        } else {
          resolvedLocationName = (emp.assignedOfficeName != null && emp.assignedOfficeName!.trim().isNotEmpty)
              ? emp.assignedOfficeName!.trim()
              : defaultOffice.name;
        }
      } else if (step == WorkflowStep.emergencyCheckIn ||
          step == WorkflowStep.emergencyCheckOut) {
        resolvedLocationName = 'Emergency Duty';
      } else {
        final activeSite = _db.getActiveSiteNameToday(emp.id);
        resolvedLocationName = (activeSite != null && activeSite.trim().isNotEmpty)
            ? activeSite.trim()
            : (workSites.isNotEmpty ? workSites.first.siteName : 'Work Site');
      }

      String? matchedWorkSiteId;
      if (step == WorkflowStep.siteCheckIn || step == WorkflowStep.siteCheckOut) {
        if (siteName != null && siteName.trim().isNotEmpty) {
          final matches = workSites.where((s) =>
              s.siteName.trim().toLowerCase() == siteName.trim().toLowerCase() ||
              siteName.trim().toLowerCase().startsWith(s.siteName.trim().toLowerCase()));
          if (matches.isNotEmpty) {
            matchedWorkSiteId = matches.first.id;
          }
        }
        if (matchedWorkSiteId == null && resolvedLocationName.isNotEmpty) {
          final matches = workSites.where((s) =>
              resolvedLocationName.toLowerCase().contains(s.siteName.toLowerCase()) ||
              s.siteName.toLowerCase().contains(resolvedLocationName.toLowerCase()));
          if (matches.isNotEmpty) {
            matchedWorkSiteId = matches.first.id;
          }
        }
        matchedWorkSiteId ??= (workSites.isNotEmpty ? workSites.first.id : null);
      }

      final String formattedAddress = location.address.isNotEmpty
          ? location.address
          : await LocationService.getAddressFromCoordinates(location.latitude, location.longitude);

      // 5. Create & Persist Attendance Record
      final record = AttendanceRecord(
        id: _uuid.v4(),
        employeeId: emp.id,
        employeeName: emp.name,
        workflowStep: step,
        eventTimestamp: DateTime.now(),
        latitude: location.latitude,
        longitude: location.longitude,
        gpsAccuracy: location.accuracy,
        address: formattedAddress,
        deviceId: 'device-hw-${user.id}',
        photoBase64: cameraResult?.base64Image ?? '',
        isGeofenceValid: isGeofenceValid,
        officeId: (step == WorkflowStep.officeCheckIn || step == WorkflowStep.officeCheckOut)
            ? (emp.assignedOfficeId ?? defaultOffice.id)
            : null,
        workSiteId: matchedWorkSiteId,
        siteName: resolvedLocationName,
        syncStatus: SyncStatus.pending,
      );

      _db.addAttendanceRecord(record);

      WorkflowStep next = _db.getWorkflowStepForEmployee();
      emit(AttendanceStepSuccess(record, next));
    } catch (e) {
      emit(AttendanceFailure('Attendance capture failed: ${e.toString()}'));
    }
  }

  void emitLocationError(String message, {bool isPermissionDenied = false}) {
    emit(LocationServicesDisabledError(
      message: message,
      isPermissionDenied: isPermissionDenied,
    ));
  }

  void resetState() {
    emit(AttendanceInitial(_db.getWorkflowStepForEmployee()));
  }
}
