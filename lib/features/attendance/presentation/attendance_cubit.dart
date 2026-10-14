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
import '../../../core/utils/employee_directory_helper.dart';

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

      // 2. Resolve employee entity accurately matching authenticated user
      final employees = _db.getEmployees();
      EmployeeEntity? matchedEmp;
      final cleanUserId = user.id.trim().toLowerCase();
      final cleanUserFirebaseUid = user.firebaseUid.trim().toLowerCase();
      final cleanUserEmail = user.email.trim().toLowerCase();
      final cleanUserCode = user.employeeCode?.trim().toLowerCase() ?? '';

      for (final e in employees) {
        final eId = e.id.trim().toLowerCase();
        final eEmail = e.email.trim().toLowerCase();
        final eCode = e.employeeCode.trim().toLowerCase();
        if (eId == cleanUserId ||
            (cleanUserFirebaseUid.isNotEmpty && eId == cleanUserFirebaseUid) ||
            (cleanUserEmail.isNotEmpty && eEmail == cleanUserEmail) ||
            (cleanUserCode.isNotEmpty && (eCode == cleanUserCode || eId == cleanUserCode)) ||
            EmployeeDirectoryHelper.matchesEmployeeIdentity(
              recordEmployeeId: e.id,
              recordEmployeeName: e.name,
              employeeId: user.id,
              employeeCode: user.employeeCode,
              employeeName: user.fullName,
              employeeEmail: user.email,
            )) {
          matchedEmp = e;
          break;
        }
      }

      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        code: user.employeeCode,
        name: user.fullName,
        email: user.email,
        id: user.id,
      );

      final emp = matchedEmp ??
          EmployeeEntity(
            id: official?.employeeId ??
                ((user.employeeCode != null && user.employeeCode!.trim().isNotEmpty)
                    ? user.employeeCode!.trim()
                    : user.id),
            employeeCode: official?.employeeId ??
                ((user.employeeCode != null && user.employeeCode!.trim().isNotEmpty)
                    ? user.employeeCode!.trim()
                    : 'EMP-DEFAULT'),
            name: official?.fullName ??
                (user.fullName.trim().isNotEmpty ? user.fullName : 'Employee'),
            mobileNumber: user.phoneNumber ?? '',
            email: user.email,
            designation: official?.designation ??
                ((user.designation != null && user.designation!.trim().isNotEmpty)
                    ? user.designation!.trim()
                    : 'Staff'),
            department: official?.department ??
                ((user.department != null && user.department!.trim().isNotEmpty)
                    ? user.department!.trim()
                    : 'General'),
            useDefaultOffice: user.useDefaultOffice,
            assignedOfficeId: user.assignedOfficeId,
            assignedOfficeName: user.assignedOfficeName,
          );

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

      WorkflowStep next = _db.getWorkflowStepForEmployee(emp.id);
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
    final user = _db.currentUser;
    emit(AttendanceInitial(
        _db.getWorkflowStepForEmployee(user?.id ?? user?.firebaseUid)));
  }
}
