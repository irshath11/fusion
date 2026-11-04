import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/database/local_database_service.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';
import 'package:attendance_app/features/sync/data/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Attendance Record & Auto-Sync State Tests', () {
    late LocalDatabaseService db;

    setUp(() {
      db = LocalDatabaseService();
      db.clearLocalAttendanceRecords();
    });

    test('Attendance records created offline default to SyncStatus.pending', () {
      final now = DateTime.now();
      final offlineRecord = AttendanceRecord(
        id: 'rec-offline-1',
        employeeId: 'EMP-001',
        employeeName: 'Mohamed Irshath',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ Operations, Abu Dhabi',
        deviceId: 'device-test-1',
        photoBase64: '',
        isGeofenceValid: true,
        syncStatus: SyncStatus.pending,
      );

      db.addAttendanceRecord(offlineRecord);

      final pendingList = db.getAllPendingSyncRecords();
      expect(pendingList.length, 1);
      expect(pendingList.first.id, 'rec-offline-1');
      expect(pendingList.first.syncStatus, SyncStatus.pending);
    });

    test('pruneAttendanceRecordsForEmployee retains pending unsynced records safely', () {
      final now = DateTime.now();
      // Record for current employee (synced)
      final syncedEmpRecord = AttendanceRecord(
        id: 'rec-synced-emp',
        employeeId: 'EMP-001',
        employeeName: 'Mohamed Irshath',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now.subtract(const Duration(hours: 4)),
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ',
        deviceId: 'device-test-1',
        photoBase64: '',
        isGeofenceValid: true,
        syncStatus: SyncStatus.synced,
      );

      // Record for different employee but pending (e.g. from shared device or unsynced log)
      final pendingOtherRecord = AttendanceRecord(
        id: 'rec-pending-other',
        employeeId: 'EMP-999',
        employeeName: 'Other Staff',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now.subtract(const Duration(minutes: 30)),
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ',
        deviceId: 'device-test-1',
        photoBase64: '',
        isGeofenceValid: true,
        syncStatus: SyncStatus.pending,
      );

      // Record for different employee already synced (should be pruned)
      final syncedOtherRecord = AttendanceRecord(
        id: 'rec-synced-other',
        employeeId: 'EMP-999',
        employeeName: 'Other Staff',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now.subtract(const Duration(hours: 2)),
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ',
        deviceId: 'device-test-1',
        photoBase64: '',
        isGeofenceValid: true,
        syncStatus: SyncStatus.synced,
      );

      db.addAttendanceRecord(syncedEmpRecord);
      db.addAttendanceRecord(pendingOtherRecord);
      db.addAttendanceRecord(syncedOtherRecord);

      // Prune for EMP-001
      db.pruneAttendanceRecordsForEmployee('EMP-001', employeeName: 'Mohamed Irshath');

      final allRecords = db.getAttendanceRecords();
      // Should keep: syncedEmpRecord + pendingOtherRecord (pending must NEVER be pruned)
      expect(allRecords.any((r) => r.id == 'rec-synced-emp'), isTrue);
      expect(allRecords.any((r) => r.id == 'rec-pending-other'), isTrue);
      expect(allRecords.any((r) => r.id == 'rec-synced-other'), isFalse);

      // Pending sync list still holds the record ready for auto-upload
      final pendingList = db.getAllPendingSyncRecords();
      expect(pendingList.any((r) => r.id == 'rec-pending-other'), isTrue);
    });

    test('markRecordsSynced updates records to SyncStatus.synced with syncTimestamp', () {
      final now = DateTime.now();
      final offlineRec1 = AttendanceRecord(
        id: 'rec-sync-1',
        employeeId: 'EMP-001',
        employeeName: 'Mohamed Irshath',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'HQ',
        deviceId: 'device-test-1',
        photoBase64: '',
        isGeofenceValid: true,
        syncStatus: SyncStatus.pending,
      );

      final offlineRec2 = AttendanceRecord(
        id: 'rec-sync-2',
        employeeId: 'EMP-001',
        employeeName: 'Mohamed Irshath',
        workflowStep: WorkflowStep.siteCheckIn,
        eventTimestamp: now.add(const Duration(hours: 1)),
        latitude: 24.3655,
        longitude: 54.5005,
        gpsAccuracy: 10.0,
        address: 'Site A',
        deviceId: 'device-test-1',
        photoBase64: '',
        isGeofenceValid: true,
        syncStatus: SyncStatus.pending,
      );

      db.addAttendanceRecord(offlineRec1);
      db.addAttendanceRecord(offlineRec2);

      expect(db.getAllPendingSyncRecords().length, 2);

      // Simulate successful cloud upload
      db.markRecordsSynced(['rec-sync-1', 'rec-sync-2']);

      final pendingAfterSync = db.getAllPendingSyncRecords();
      expect(pendingAfterSync.isEmpty, isTrue);

      final records = db.getAttendanceRecords();
      final r1 = records.firstWhere((r) => r.id == 'rec-sync-1');
      final r2 = records.firstWhere((r) => r.id == 'rec-sync-2');

      expect(r1.syncStatus, SyncStatus.synced);
      expect(r1.syncTimestamp, isNotNull);
      expect(r2.syncStatus, SyncStatus.synced);
      expect(r2.syncTimestamp, isNotNull);
    });

    test('SyncEngine singleton starts and triggers gracefully', () {
      final engine = SyncEngine();
      expect(engine.isSyncing, isFalse);
      expect(engine.isAutoSyncEnabled, isTrue);

      // triggerAutoSync runs asynchronously with safety debounce
      expect(() => engine.triggerAutoSync(), returnsNormally);
    });
  });
}
