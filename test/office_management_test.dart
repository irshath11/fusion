import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/features/admin/domain/office_entity.dart';
import 'package:attendance_app/features/admin/domain/employee_entity.dart';

void main() {
  group('OfficeEntity Tests', () {
    test('OfficeEntity serialization and deserialization match', () {
      final office = OfficeEntity(
        id: 'off-001',
        name: 'Mussafah Branch',
        address: 'Mussafah M12, Abu Dhabi, UAE',
        latitude: 24.3655,
        longitude: 54.5005,
        geofenceRadiusMeters: 250.0,
        isDefault: false,
      );

      final json = office.toJson();
      final parsed = OfficeEntity.fromJson(json);

      expect(parsed.id, 'off-001');
      expect(parsed.name, 'Mussafah Branch');
      expect(parsed.address, 'Mussafah M12, Abu Dhabi, UAE');
      expect(parsed.latitude, 24.3655);
      expect(parsed.longitude, 54.5005);
      expect(parsed.geofenceRadiusMeters, 250.0);
      expect(parsed.isDefault, isFalse);
    });

    test('OfficeEntity correctly parses default office flag from database', () {
      final json = {
        'id': 'off-hq',
        'name': 'Main Office',
        'address': 'HQ Address',
        'latitude': 24.0,
        'longitude': 54.0,
        'geofence_radius_meters': 200,
        'is_default': true,
      };

      final office = OfficeEntity.fromJson(json);
      expect(office.isDefault, isTrue);
    });
  });

  group('Office Deletion and Employee Reversion Logic Tests', () {
    test('Deleting an assigned branch office reverts employee to default office', () {
      final offices = <OfficeEntity>[
        OfficeEntity(
          id: 'off-main',
          name: 'Main HQ',
          address: 'HQ',
          latitude: 24.0,
          longitude: 54.0,
          geofenceRadiusMeters: 200,
          isDefault: true,
        ),
        OfficeEntity(
          id: 'off-branch-1',
          name: 'Branch 1',
          address: 'Branch Address',
          latitude: 24.5,
          longitude: 54.5,
          geofenceRadiusMeters: 150,
          isDefault: false,
        ),
      ];

      final employees = <EmployeeEntity>[
        EmployeeEntity(
          id: 'emp-1',
          employeeCode: 'EMP-001',
          name: 'Technician A',
          mobileNumber: '0501111111',
          email: 'techA@company.com',
          designation: 'Technician',
          department: 'Maintenance',
          useDefaultOffice: false,
          assignedOfficeId: 'off-branch-1',
          assignedOfficeName: 'Branch 1',
        ),
        EmployeeEntity(
          id: 'emp-2',
          employeeCode: 'EMP-002',
          name: 'Technician B',
          mobileNumber: '0502222222',
          email: 'techB@company.com',
          designation: 'Engineer',
          department: 'Engineering',
          useDefaultOffice: true,
          assignedOfficeId: null,
          assignedOfficeName: null,
        ),
      ];

      // Simulate office deletion of 'off-branch-1'
      const officeToDelete = 'off-branch-1';
      offices.removeWhere((o) => o.id == officeToDelete);

      for (int i = 0; i < employees.length; i++) {
        if (employees[i].assignedOfficeId == officeToDelete) {
          employees[i] = employees[i].copyWith(
            useDefaultOffice: true,
            clearAssignedOffice: true,
          );
        }
      }

      expect(offices.length, 1);
      expect(offices.first.id, 'off-main');
      expect(employees[0].useDefaultOffice, isTrue);
      expect(employees[0].assignedOfficeId, isNull);
      expect(employees[0].assignedOfficeName, isNull);
      expect(employees[1].useDefaultOffice, isTrue);
    });
  });
}
