import 'work_shift_entity.dart';

class EmployeeShiftAssignmentEntity {
  final String id;
  final String employeeId;
  final String dateStr; // Format: YYYY-MM-DD
  final String shiftName;
  final String startTime; // "HH:mm" 24-hr format
  final String endTime; // "HH:mm" 24-hr format
  final int gracePeriodMinutes;

  EmployeeShiftAssignmentEntity({
    required this.id,
    required this.employeeId,
    required this.dateStr,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    this.gracePeriodMinutes = 15,
  });

  WorkShiftEntity toWorkShift() {
    return WorkShiftEntity(
      id: 'assigned-$id',
      name: shiftName,
      startTime: startTime,
      endTime: endTime,
      gracePeriodMinutes: gracePeriodMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'dateStr': dateStr,
        'shiftName': shiftName,
        'startTime': startTime,
        'endTime': endTime,
        'gracePeriodMinutes': gracePeriodMinutes,
      };

  factory EmployeeShiftAssignmentEntity.fromJson(Map<String, dynamic> json) =>
      EmployeeShiftAssignmentEntity(
        id: json['id'] ?? '',
        employeeId: json['employeeId'] ?? '',
        dateStr: json['dateStr'] ?? '',
        shiftName: json['shiftName'] ?? 'Custom Shift',
        startTime: json['startTime'] ?? '09:00',
        endTime: json['endTime'] ?? '18:00',
        gracePeriodMinutes: json['gracePeriodMinutes'] ?? 15,
      );
}
