import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/constants/app_enums.dart';
import 'package:attendance_app/core/utils/employee_directory_helper.dart';
import 'package:attendance_app/core/utils/timesheet_calculator.dart';
import 'package:attendance_app/features/admin/domain/employee_entity.dart';
import 'package:attendance_app/features/attendance/domain/attendance_record.dart';

void main() {
  group('Employee Attendance Attribution & Timesheet Tests', () {
    final shabi = EmployeeEntity(
      id: 'emp-shabi-001',
      employeeCode: 'EMP001',
      name: 'Shabi',
      mobileNumber: '1234567890',
      email: 'shabi@test.com',
      designation: 'Technician',
      department: 'Operations',
    );

    final anandh = EmployeeEntity(
      id: 'emp-anand-002',
      employeeCode: 'EMP-ANA',
      name: 'Anandh Veeramani',
      mobileNumber: '9876543210',
      email: 'anand@gmail.com',
      designation: 'Supervisor',
      department: 'Field Engineering',
    );

    test('Strict matching ensures Shabi and Anandh records do not cross-contaminate', () {
      final now = DateTime(2026, 9, 3, 8, 0);

      final shabiCheckIn = AttendanceRecord(
        id: 'rec-1',
        employeeId: shabi.id,
        employeeName: shabi.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site A',
        deviceId: 'device-hw-shabi',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final anandhCheckIn = AttendanceRecord(
        id: 'rec-2',
        employeeId: anandh.id,
        employeeName: anandh.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: now.add(const Duration(minutes: 15)),
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site B',
        deviceId: 'device-hw-anand',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final allRecords = [shabiCheckIn, anandhCheckIn];

      // Verify TimesheetCalculator separates records strictly
      final shabiTimesheets = TimesheetCalculator.calculateDailyTimesheets(
        allRecords.where((r) => r.employeeId == shabi.id).toList(),
      );
      final anandhTimesheets = TimesheetCalculator.calculateDailyTimesheets(
        allRecords.where((r) => r.employeeId == anandh.id).toList(),
      );

      expect(shabiTimesheets.length, 1);
      expect(anandhTimesheets.length, 1);
      expect(shabiTimesheets.first.date, DateTime(2026, 9, 3));
      expect(anandhTimesheets.first.date, DateTime(2026, 9, 3));
    });

    test('Reassigning records from Shabi to Anandh updates identity and timesheet correctly', () {
      final checkInTime = DateTime(2026, 9, 3, 8, 0);
      final checkOutTime = DateTime(2026, 9, 3, 17, 0);

      final misattributedCheckIn = AttendanceRecord(
        id: 'rec-mis-in',
        employeeId: shabi.id,
        employeeName: shabi.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: checkInTime,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Substation Alpha',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final misattributedCheckOut = AttendanceRecord(
        id: 'rec-mis-out',
        employeeId: shabi.id,
        employeeName: shabi.name,
        workflowStep: WorkflowStep.officeCheckOut,
        eventTimestamp: checkOutTime,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Substation Alpha',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final records = [misattributedCheckIn, misattributedCheckOut];

      final reassignedRecords = records.map((r) {
        return r.copyWith(
          employeeId: anandh.id,
          employeeName: anandh.name,
          isEdited: true,
          editedBy: 'Admin Reassignment',
        );
      }).toList();

      for (final r in reassignedRecords) {
        expect(r.employeeId, anandh.id);
        expect(r.employeeName, anandh.name);
        expect(r.isEdited, isTrue);
        expect(r.editedBy, 'Admin Reassignment');
      }

      final anandhTimesheets = TimesheetCalculator.calculateDailyTimesheets(reassignedRecords);
      expect(anandhTimesheets.length, 1);
      expect(anandhTimesheets.first.regularHours, 8.0);
    });

    test('Consolidating legacy "Anand" records into Anandh Veeramani preserves all dates under Anandh', () {
      final day1 = DateTime(2026, 8, 1, 8, 0);
      final day2 = DateTime(2026, 8, 2, 8, 0);

      // Legacy record with short name "Anand" and fallback code
      final legacyRec = AttendanceRecord(
        id: 'rec-legacy-1',
        employeeId: 'emp-anan',
        employeeName: 'Anand',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: day1,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site A',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      // Official record under "Anandh Veeramani"
      final officialRec = AttendanceRecord(
        id: 'rec-official-2',
        employeeId: anandh.id,
        employeeName: anandh.name,
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: day2,
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site B',
        deviceId: 'device-hw-${anandh.id}',
        photoBase64: '',
        isGeofenceValid: true,
      );

      final allRecords = [legacyRec, officialRec];

      // Simulated migration: consolidate 'Anand' records into 'Anandh Veeramani'
      final consolidated = allRecords.map((r) {
        if (r.employeeName.toLowerCase() == 'anand' || r.employeeId == 'emp-anan') {
          return r.copyWith(
            employeeId: anandh.id,
            employeeName: anandh.name,
            isEdited: true,
            editedBy: 'System Consolidation',
          );
        }
        return r;
      }).toList();

      // All records are now under Anandh Veeramani
      for (final r in consolidated) {
        expect(r.employeeId, anandh.id);
        expect(r.employeeName, 'Anandh Veeramani');
      }

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(consolidated);
      expect(timesheets.length, 2);
    });

    test('Segregates employees into With Records vs No Records accurately', () {
      final empWithLogs = EmployeeEntity(
        id: 'emp-active-1',
        employeeCode: 'EMP001',
        name: 'Active Staff',
        mobileNumber: '111',
        email: 'active@test.com',
        designation: 'Tech',
        department: 'Ops',
      );

      final empWithoutLogs = EmployeeEntity(
        id: 'emp-new-2',
        employeeCode: 'EMP002',
        name: 'New Staff',
        mobileNumber: '222',
        email: 'new@test.com',
        designation: 'Apprentice',
        department: 'Training',
      );

      final records = [
        AttendanceRecord(
          id: 'rec-10',
          employeeId: empWithLogs.id,
          employeeName: empWithLogs.name,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(2026, 9, 3, 8, 0),
          latitude: 25.0,
          longitude: 55.0,
          gpsAccuracy: 5.0,
          address: 'Office',
          deviceId: 'dev-1',
          photoBase64: '',
          isGeofenceValid: true,
        ),
      ];

      final allEmployees = [empWithLogs, empWithoutLogs];

      final withRecords = allEmployees.where((e) {
        return records.any((r) => r.employeeId == e.id || r.employeeName.toLowerCase() == e.name.toLowerCase());
      }).toList();

      final withoutRecords = allEmployees.where((e) {
        return !records.any((r) => r.employeeId == e.id || r.employeeName.toLowerCase() == e.name.toLowerCase());
      }).toList();

      expect(withRecords.length, 1);
      expect(withRecords.first.id, 'emp-active-1');
      expect(withoutRecords.length, 1);
      expect(withoutRecords.first.id, 'emp-new-2');
    });

    test('Resolves previous short name "Shabi" to "Shabi Bismillah Bismillah" and matches all records under full name', () {
      final shabiOfficial = EmployeeDirectoryHelper.resolveOfficialRecord(name: 'Shabi');
      expect(shabiOfficial, isNotNull);
      expect(shabiOfficial!.fullName, 'Shabi Bismillah Bismillah');
      expect(shabiOfficial.employeeId, 'N-1004');

      // Check aliases match
      final matchesShort = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: 'emp-shabi',
        recordEmployeeName: 'Shabi',
        employeeId: 'N-1004',
        employeeName: 'Shabi Bismillah Bismillah',
      );
      expect(matchesShort, isTrue);

      final matchesOfficialId = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: 'N-1004',
        recordEmployeeName: 'Shabi',
        employeeName: 'Shabi Bismillah Bismillah',
      );
      expect(matchesOfficialId, isTrue);

      // Verify non-directory employee is preserved and returns null
      final asikOfficial = EmployeeDirectoryHelper.resolveOfficialRecord(
        name: 'Asik Saheel',
        email: 'asik@gmail.com',
      );
      expect(asikOfficial, isNull);
    });

    test('Strict log isolation: Irshath Ahamed (0 logs) never receives Mohamed Ali (Shaik) or other logs', () {
      // 1. Irshath Ahamed target identity
      const irshathId = 'N-1006';
      const irshathCode = 'N-1006';
      const irshathName = 'Irshath Ahamed Shaik Allavudin Shaik Allavudin';
      const irshathEmail = 'sr.irshath@gmail.com';

      // 2. Mohamed Ali records in various formats (ID 1038, full name, short alias Shaik, alias Mohamed Ali)
      final mohamedAliRecords = [
        {'id': '1038', 'name': 'Mohamed Ali Shaik Mohamed Mohamed Ali'},
        {'id': 'emp-1038', 'name': 'Mohamed Ali'},
        {'id': '1038', 'name': 'Shaik'},
        {'id': 'emp-shaik', 'name': 'Shaik'},
        {'id': '1038', 'name': 'Mohamed Ali Shaik'},
      ];

      for (final rec in mohamedAliRecords) {
        final matchesIrshath = EmployeeDirectoryHelper.matchesEmployeeIdentity(
          recordEmployeeId: rec['id']!,
          recordEmployeeName: rec['name']!,
          employeeId: irshathId,
          employeeCode: irshathCode,
          employeeName: irshathName,
          employeeEmail: irshathEmail,
        );
        expect(matchesIrshath, isFalse,
            reason: 'Record ${rec["id"]} / ${rec["name"]} must NOT match Irshath Ahamed');

        // Verify Mohamed Ali's records strictly match Mohamed Ali himself
        final matchesMohamedAli = EmployeeDirectoryHelper.matchesEmployeeIdentity(
          recordEmployeeId: rec['id']!,
          recordEmployeeName: rec['name']!,
          employeeId: '1038',
          employeeCode: '1038',
          employeeName: 'Mohamed Ali Shaik Mohamed Mohamed Ali',
          employeeEmail: 'shaik@gmail.com',
        );
        expect(matchesMohamedAli, isTrue,
            reason: 'Record ${rec["id"]} / ${rec["name"]} MUST match Mohamed Ali');
      }

      // 3. Mohamed Ali logs must NEVER leak to other employees sharing "Mohamed" or "Ali"
      // e.g. Raja Mohammed Mohammed Ali (1012)
      final matchesRaja = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: '1038',
        recordEmployeeName: 'Mohamed Ali',
        employeeId: '1012',
        employeeCode: '1012',
        employeeName: 'Raja Mohammed Mohammed Ali',
        employeeEmail: 'raja@gmail.com',
      );
      expect(matchesRaja, isFalse);

      // e.g. Mohamed Azarudheen Anvar Ali (1021)
      final matchesAzar = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: '1038',
        recordEmployeeName: 'Mohamed Ali',
        employeeId: '1021',
        employeeCode: '1021',
        employeeName: 'Mohamed Azarudheen Anvar Ali',
        employeeEmail: 'azar@gmail.com',
      );
      expect(matchesAzar, isFalse);

      // 4. Other name-sharing employees do NOT cross-contaminate:
      // Mohammed Iburahim Baseer Ahamed (1004) vs Irshath Ahamed (N-1006)
      final ibrahimMatchesIrshath = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: '1004',
        recordEmployeeName: 'Mohammed Iburahim Baseer Ahamed',
        employeeId: irshathId,
        employeeCode: irshathCode,
        employeeName: irshathName,
      );
      expect(ibrahimMatchesIrshath, isFalse);

      // Ahamed Meeran Sheik Abdul Kadar (N-1014) vs Irshath Ahamed (N-1006)
      final meeranMatchesIrshath = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: 'N-1014',
        recordEmployeeName: 'Ahamed Meeran',
        employeeId: irshathId,
        employeeCode: irshathCode,
        employeeName: irshathName,
      );
      expect(meeranMatchesIrshath, isFalse);

      // Sanjay Kumar (1049) vs Saji Kumar (N-1007)
      final sanjayMatchesSaji = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: '1049',
        recordEmployeeName: 'Sanjay Kumar',
        employeeId: 'N-1007',
        employeeCode: 'N-1007',
        employeeName: 'Saji Kumar Thankamani Thankamani',
      );
      expect(sanjayMatchesSaji, isFalse);

      // Muhammad Irfan (1048) vs Muhammed Riyas (N-1003)
      final irfanMatchesRiyas = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: '1048',
        recordEmployeeName: 'Muhammad Irfan',
        employeeId: 'N-1003',
        employeeCode: 'N-1003',
        employeeName: 'Muhammed Riyas Hussain Hussain Kasim',
      );
      expect(irfanMatchesRiyas, isFalse);
    });

    test('Relieved employee exclusion: Asik Saheel is completely excluded from identity resolution and directories', () {
      expect(EmployeeDirectoryHelper.isRelievedEmployee(name: 'Asik Saheel'), isTrue);
      expect(EmployeeDirectoryHelper.isRelievedEmployee(name: 'asik'), isTrue);
      expect(EmployeeDirectoryHelper.isRelievedEmployee(name: 'Saheel'), isTrue);
      expect(EmployeeDirectoryHelper.isRelievedEmployee(name: 'Ashik Sahil'), isTrue);
      expect(EmployeeDirectoryHelper.isRelievedEmployee(email: 'asik@gmail.com'), isTrue);
      expect(EmployeeDirectoryHelper.isRelievedEmployee(id: 'emp-asik'), isTrue);

      // Never matches identity or official record
      expect(EmployeeDirectoryHelper.resolveOfficialRecord(name: 'Asik Saheel'), isNull);
      expect(EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: 'emp-asik',
        recordEmployeeName: 'Asik Saheel',
        employeeId: 'emp-asik',
        employeeName: 'Asik Saheel',
      ), isFalse);

      // Legitimate staff are NOT relieved
      expect(EmployeeDirectoryHelper.isRelievedEmployee(name: 'Raja Mohammed Mohammed Ali', code: '1012'), isFalse);
      expect(EmployeeDirectoryHelper.isRelievedEmployee(name: 'Shabi Bismillah Bismillah', code: 'N-1004'), isFalse);
      expect(EmployeeDirectoryHelper.isRelievedEmployee(name: 'Irshath Ahamed Shaik Allavudin', code: 'N-1006'), isFalse);
    });

    test('Misattributed UUIDs never leak across official employees', () {
      const riyasUuid = '3cfd6206-e723-4225-a885-10b6e2a3f564';
      const kajaUuid = '5a956da2-0c58-4899-abaf-c5ec61790e25';

      // A record that had Kajamohideen name but was erroneously stored with Riyas UUID
      final corruptedRecord = AttendanceRecord(
        id: 'rec-corrupted-kaja',
        employeeId: riyasUuid,
        employeeName: 'Kajamohideen Samsudeen Samsudeen',
        workflowStep: WorkflowStep.officeCheckIn,
        eventTimestamp: DateTime(2026, 11, 10, 8, 30),
        latitude: 25.0,
        longitude: 55.0,
        gpsAccuracy: 5.0,
        address: 'Site A',
        deviceId: 'device-kaja',
        photoBase64: '',
        isGeofenceValid: true,
      );

      // Must NOT match Muhammed Riyas even though r.employeeId == riyasUuid
      final matchesRiyas = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: corruptedRecord.employeeId,
        recordEmployeeName: corruptedRecord.employeeName,
        employeeId: riyasUuid,
        employeeCode: 'N-1003',
        employeeName: 'Muhammed Riyas Hussain Hussain Kasim',
      );
      expect(matchesRiyas, isFalse);

      // Must match Kajamohideen Samsudeen
      final matchesKaja = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: corruptedRecord.employeeId,
        recordEmployeeName: corruptedRecord.employeeName,
        employeeId: kajaUuid,
        employeeCode: 'N-1008',
        employeeName: 'Kajamohideen Samsudeen Samsudeen',
      );
      expect(matchesKaja, isTrue);

      // Timesheet isolation
      final riyasTimesheets = TimesheetCalculator.calculateDailyTimesheets(
        [corruptedRecord],
        targetEmployeeId: riyasUuid,
        targetEmployeeName: 'Muhammed Riyas Hussain Hussain Kasim',
      );
      expect(riyasTimesheets.isEmpty, isTrue, reason: 'Riyas timesheet must not pull in Kajamohideen record');

      final kajaTimesheets = TimesheetCalculator.calculateDailyTimesheets(
        [corruptedRecord],
        targetEmployeeId: kajaUuid,
        targetEmployeeName: 'Kajamohideen Samsudeen Samsudeen',
      );
      expect(kajaTimesheets.length, 1, reason: 'Kajamohideen timesheet must correctly include his record');
    });
  });
}
