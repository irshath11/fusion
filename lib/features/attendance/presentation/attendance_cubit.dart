import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/utils/geofence_calculator.dart';
import '../../sync/data/sync_engine.dart';
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
  final SyncEngineResult syncResult;

  AttendanceStepSuccess({
    required this.record,
    required this.nextStep,
    required this.syncResult,
  });

  @override
  List<Object?> get props => [record, nextStep, syncResult];
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

      // Ensure local offices & employee data are synced from Supabase cloud if missing
      if (_db.getOffices().isEmpty) {
        try {
          await SupabaseService().syncCloudDataToLocal();
        } catch (_) {}
      }

      // 2. Resolve target geofence bounds based on employee's assigned office / site
      final employees = _db.getEmployees();
      final emp = employees.firstWhere(
        (e) => e.id == user.id || e.email == user.email,
        orElse: () => employees.isNotEmpty ? employees.first : EmployeeEntity(
          id: user.id,
          employeeCode: 'EMP-DEFAULT',
          name: user.fullName,
          mobileNumber: '',
          email: user.email,
          designation: 'Staff',
          department: 'General',
        ),
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
          resolvedLocationName = customOfficeMatches.isNotEmpty
              ? customOfficeMatches.first.name
              : defaultOffice.name;
        } else {
          resolvedLocationName = defaultOffice.name;
        }
      } else {
        resolvedLocationName = workSites.isNotEmpty ? workSites.first.siteName : 'Work Site';
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
        workSiteId: (step == WorkflowStep.siteCheckIn || step == WorkflowStep.siteCheckOut)
            ? (workSites.isNotEmpty ? workSites.first.id : null)
            : null,
        siteName: resolvedLocationName,
        syncStatus: SyncStatus.pending,
      );

      _db.addAttendanceRecord(record);

      // Await real-time sync to cloud database so record status is updated before emitting state
      final syncResult = await SyncEngine().performSync();

      final updatedRecord = _db.getAttendanceRecords().firstWhere(
        (r) => r.id == record.id,
        orElse: () => record,
      );

      WorkflowStep next = _db.getWorkflowStepForEmployee();
      emit(AttendanceStepSuccess(
        record: updatedRecord,
        nextStep: next,
        syncResult: syncResult,
      ));
    } catch (e) {
      emit(AttendanceFailure('Attendance capture failed: ${e.toString()}'));
    }
  }

  void resetState() {
    emit(AttendanceInitial(_db.getWorkflowStepForEmployee()));
  }
}
