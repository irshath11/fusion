import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/database/local_database_service.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';
import 'package:attendance_app/features/auth/domain/user_entity.dart';
import 'package:attendance_app/core/utils/employee_directory_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Raja Attendance Check-in, Timeline Query & Isolation Tests', () {
    late LocalDatabaseService db;

    setUp(() {
      db = LocalDatabaseService();
      db.clearLocalAttendanceRecords();
    });

    test('Raja check-in log is captured, visible in timeline, and advances workflow step', () {
      final rajaUser = UserEntity(
        id: 'user-uuid-raja-98765',
        firebaseUid: 'user-uuid-raja-98765',
        email: 'raja@gmail.com',
        fullName: 'Raja Mohammed Mohammed Ali',
        role: UserRole.employee,
        organizationId: '00000000-0000-0000-0000-000000000001',
        employeeCode: '1012',
      );

      db.setCurrentUser(rajaUser);

      // Verify master directory resolution for Raja
      final official = EmployeeDirectoryHelper.resolveOfficialRecord(
        id: rajaUser.id,
        code: rajaUser.employeeCode,
        name: rajaUser.fullName,
        email: rajaUser.email,
      );
      expect(official, isNotNull);
      expect(official!.employeeId, '1012');

      // Before check-in: step is officeCheckIn, today records is empty
      expect(db.getWorkflowStepForEmployee(rajaUser.id), WorkflowStep.officeCheckIn);
      expect(db.getWorkflowStepForEmployee(official.employeeId), WorkflowStep.officeCheckIn);
      expect(db.getTodayAttendanceRecords(rajaUser.id), isEmpty);
      expect(db.getTodayAttendanceRecords(official.employeeId), isEmpty);

      // Execute Office Check-in for Raja
      final now = DateTime.now();
      final checkInRecord = AttendanceRecord(
        id: 'rec-raja-checkin-1',
        employeeId: official.employeeId, // '1012'
        employeeName: official.fullName, // 'Raja Mohammed Mohammed Ali'
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 24.365500,
        longitude: 54.500531,
        gpsAccuracy: 10.0,
        address: 'HQ Operations, Abu Dhabi',
        deviceId: 'device-hw-${rajaUser.id}',
        photoBase64: 'data:image/jpeg;base64,...',
        isGeofenceValid: true,
        siteName: 'Main Office',
        syncStatus: SyncStatus.pending,
      );

      db.addAttendanceRecord(checkInRecord);

      // 1. Check timeline using user UUID (as passed from employee_dashboard_screen)
      final timelineByUuid = db.getTodayAttendanceRecords(rajaUser.id);
      expect(timelineByUuid.isNotEmpty, isTrue);
      expect(timelineByUuid.length, 1);
      expect(timelineByUuid.first.id, 'rec-raja-checkin-1');

      // 2. Check timeline using canonical employee code ('1012')
      final timelineByCode = db.getTodayAttendanceRecords(official.employeeId);
      expect(timelineByCode.isNotEmpty, isTrue);
      expect(timelineByCode.length, 1);
      expect(timelineByCode.first.id, 'rec-raja-checkin-1');

      // 3. Check timeline without param (using currentUser)
      final timelineDefault = db.getTodayAttendanceRecords();
      expect(timelineDefault.isNotEmpty, isTrue);
      expect(timelineDefault.length, 1);
      expect(timelineDefault.first.id, 'rec-raja-checkin-1');

      // 4. Check workflow step: should advance to siteCheckIn (or siteCheckOut / break)
      expect(db.getWorkflowStepForEmployee(rajaUser.id), WorkflowStep.siteCheckIn);
      expect(db.getWorkflowStepForEmployee(official.employeeId), WorkflowStep.siteCheckIn);
      expect(db.getWorkflowStepForEmployee(), WorkflowStep.siteCheckIn);
    });

    test('pruneAttendanceRecordsForEmployee retains synced records for Raja and isolates other staff', () {
      final rajaUser = UserEntity(
        id: 'user-uuid-raja-98765',
        firebaseUid: 'user-uuid-raja-98765',
        email: 'raja@gmail.com',
        fullName: 'Raja Mohammed Mohammed Ali',
        role: UserRole.employee,
        organizationId: '00000000-0000-0000-0000-000000000001',
        employeeCode: '1012',
      );

      db.setCurrentUser(rajaUser);

      final now = DateTime.now();

      // Raja's synced check-in record
      final rajaRecord = AttendanceRecord(
        id: 'rec-raja-1',
        employeeId: '1012',
        employeeName: 'Raja Mohammed Mohammed Ali',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now.subtract(const Duration(hours: 2)),
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ Operations',
        deviceId: 'device-hw-${rajaUser.id}',
        photoBase64: 'https://cdn.example.com/photo.jpg',
        isGeofenceValid: true,
        syncStatus: SyncStatus.synced,
      );

      // Another employee's synced record (e.g. Azhar 1021)
      final otherEmpRecord = AttendanceRecord(
        id: 'rec-azhar-1',
        employeeId: '1021',
        employeeName: 'Mohamed Azarudheen Anvar Ali',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now.subtract(const Duration(hours: 3)),
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ Operations',
        deviceId: 'device-hw-other',
        photoBase64: 'https://cdn.example.com/other.jpg',
        isGeofenceValid: true,
        syncStatus: SyncStatus.synced,
      );

      db.addAttendanceRecord(rajaRecord);
      db.addAttendanceRecord(otherEmpRecord);

      // Prune records on device using Raja's UUID
      db.pruneAttendanceRecordsForEmployee(rajaUser.id, employeeName: rajaUser.fullName);

      // Raja's record must be retained!
      final todayRaja = db.getTodayAttendanceRecords(rajaUser.id);
      expect(todayRaja.length, 1);
      expect(todayRaja.first.id, 'rec-raja-1');

      // Azhar's record must be pruned from device cache
      final allOnDevice = db.getAttendanceRecords();
      expect(allOnDevice.any((r) => r.id == 'rec-azhar-1'), isFalse);
    });

    test('Strict isolation: Anand, Kuthoos, Azhar, Adham records never cross-pollinate with Raja', () {
      final now = DateTime.now();

      // Add records for multiple distinct employees
      final rajaRec = AttendanceRecord(
        id: 'rec-raja',
        employeeId: '1012',
        employeeName: 'Raja Mohammed Mohammed Ali',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ Operations',
        deviceId: 'dev-1',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final anandRec = AttendanceRecord(
        id: 'rec-anand',
        employeeId: '1005',
        employeeName: 'Anandakumar Shanmugavel Shanmugavel',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ Operations',
        deviceId: 'dev-2',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final kuthoosRec = AttendanceRecord(
        id: 'rec-kuthoos',
        employeeId: '1007',
        employeeName: 'Abdul Kuthoos Mohamed Sikkandar Sikkandar',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ Operations',
        deviceId: 'dev-3',
        photoBase64: '',
        isGeofenceValid: true,
      );

      db.addAttendanceRecord(rajaRec);
      db.addAttendanceRecord(anandRec);
      db.addAttendanceRecord(kuthoosRec);

      // Querying for Raja (1012) must ONLY return Raja
      final rajaResults = db.getTodayAttendanceRecords('1012');
      expect(rajaResults.length, 1);
      expect(rajaResults.first.id, 'rec-raja');

      // Querying for Anand (1005) must ONLY return Anand
      final anandResults = db.getTodayAttendanceRecords('1005');
      expect(anandResults.length, 1);
      expect(anandResults.first.id, 'rec-anand');

      // Querying for Kuthoos (1007) must ONLY return Kuthoos
      final kuthoosResults = db.getTodayAttendanceRecords('1007');
      expect(kuthoosResults.length, 1);
      expect(kuthoosResults.first.id, 'rec-kuthoos');
    });
  });
}
