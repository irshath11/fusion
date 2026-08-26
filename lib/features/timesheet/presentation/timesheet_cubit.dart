import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/timesheet_calculator.dart';
import '../domain/timesheet_entry.dart';

abstract class TimesheetState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TimesheetInitial extends TimesheetState {}

class TimesheetLoading extends TimesheetState {}

class TimesheetLoaded extends TimesheetState {
  final List<DailyTimesheetEntry> entries;
  final double totalRegularHours;
  final double totalOvertimeHours;
  final double totalCombinedHours;
  final int totalDaysWorked;

  TimesheetLoaded({
    required this.entries,
    required this.totalRegularHours,
    required this.totalOvertimeHours,
    required this.totalCombinedHours,
    required this.totalDaysWorked,
  });

  @override
  List<Object?> get props => [
        entries,
        totalRegularHours,
        totalOvertimeHours,
        totalCombinedHours,
        totalDaysWorked,
      ];
}

class TimesheetError extends TimesheetState {
  final String message;
  TimesheetError(this.message);

  @override
  List<Object?> get props => [message];
}

class TimesheetCubit extends Cubit<TimesheetState> {
  final LocalDatabaseService _db = LocalDatabaseService();

  TimesheetCubit() : super(TimesheetInitial());

  Future<void> fetchEmployeeTimesheet({String? employeeId}) async {
    emit(TimesheetLoading());
    try {
      final currentUser = _db.currentUser;
      final empId = employeeId ?? currentUser?.id ?? currentUser?.firebaseUid;
      if (empId == null || empId.isEmpty) {
        emit(TimesheetError('User identity not found.'));
        return;
      }

      try {
        final cloudRecords = await SupabaseService().fetchAttendanceRecordsFromSupabase();
        if (cloudRecords.isNotEmpty) {
          for (final record in cloudRecords) {
            _db.saveAttendanceRecord(record);
          }
        }
      } catch (_) {}

      final allRecords = _db.getAttendanceRecords();
      final entries = TimesheetCalculator.calculateDailyTimesheets(
        allRecords,
        targetEmployeeId: empId,
        targetFirebaseUid: currentUser?.firebaseUid,
        targetEmployeeName: currentUser?.fullName,
      );

      double totalReg = 0.0;
      double totalOt = 0.0;

      for (final entry in entries) {
        totalReg += entry.regularHours;
        totalOt += entry.overtimeHours;
      }

      emit(
        TimesheetLoaded(
          entries: entries,
          totalRegularHours: totalReg,
          totalOvertimeHours: totalOt,
          totalCombinedHours: totalReg + totalOt,
          totalDaysWorked: entries.length,
        ),
      );
    } catch (e) {
      emit(TimesheetError('Failed to calculate timesheet: ${e.toString()}'));
    }
  }
}
