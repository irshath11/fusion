import 'package:flutter/material.dart';

class WorkShiftEntity {
  final String id;
  final String name;
  final String startTime; // "HH:mm" 24-hour format
  final String endTime; // "HH:mm" 24-hour format
  final int gracePeriodMinutes;

  WorkShiftEntity({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.gracePeriodMinutes = 15,
  });

  int get startHour {
    final parts = startTime.split(':');
    return parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
  }

  int get startMinute {
    final parts = startTime.split(':');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  int get endHour {
    final parts = endTime.split(':');
    return parts.isNotEmpty ? int.tryParse(parts[0]) ?? 18 : 18;
  }

  int get endMinute {
    final parts = endTime.split(':');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  bool get isNightShift {
    final startTotal = startHour * 60 + startMinute;
    final endTotal = endHour * 60 + endMinute;
    return endTotal <= startTotal;
  }

  String formatTimeOfDay(int hour, int minute) {
    final tod = TimeOfDay(hour: hour, minute: minute);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }

  String get displayTimeRange {
    final startStr = formatTimeOfDay(startHour, startMinute);
    final endStr = formatTimeOfDay(endHour, endMinute);
    return isNightShift ? '$startStr - $endStr (+1d)' : '$startStr - $endStr';
  }

  bool isOnTime(DateTime punchTimestamp) {
    final punchTotalMinutes = punchTimestamp.hour * 60 + punchTimestamp.minute;
    final startTotalMinutes = startHour * 60 + startMinute;
    final maxAllowed = startTotalMinutes + gracePeriodMinutes;

    // Standard day shift
    if (!isNightShift) {
      return punchTotalMinutes <= maxAllowed;
    }

    // Night shift (e.g. 22:00 to 06:00)
    // Punch in is on-time if it occurs before/at start + grace (e.g. <= 22:15)
    // or early before shift start (e.g. >= 20:00)
    if (punchTimestamp.hour >= startHour || punchTimestamp.hour < endHour) {
      if (punchTimestamp.hour >= startHour) {
        return punchTotalMinutes <= maxAllowed || punchTimestamp.hour >= (startHour - 2);
      }
      return true;
    }
    return false;
  }

  /// Returns the 24-hour duty cycle date string (YYYY-MM-DD) for a given timestamp.
  /// For night shifts (e.g. 22:00 - 06:00), early morning punches before shift end (+4 hrs)
  /// belong to the shift that started on the previous calendar day.
  String getDutyDateStr(DateTime timestamp) {
    if (isNightShift) {
      if (timestamp.hour < (endHour + 4)) {
        final prevDay = timestamp.subtract(const Duration(days: 1));
        return "${prevDay.year.toString().padLeft(4, '0')}-${prevDay.month.toString().padLeft(2, '0')}-${prevDay.day.toString().padLeft(2, '0')}";
      }
    }
    return "${timestamp.year.toString().padLeft(4, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}";
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'gracePeriodMinutes': gracePeriodMinutes,
      };

  factory WorkShiftEntity.fromJson(Map<String, dynamic> json) => WorkShiftEntity(
        id: json['id'] ?? '',
        name: json['name'] ?? 'General Shift',
        startTime: json['startTime'] ?? '09:00',
        endTime: json['endTime'] ?? '18:00',
        gracePeriodMinutes: json['gracePeriodMinutes'] ?? 15,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkShiftEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
