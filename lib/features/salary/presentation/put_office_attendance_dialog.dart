import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/employee_directory_helper.dart';
import '../../../core/widgets/employee_avatar.dart';
import '../../../database/local_database_service.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/daily_salary_record.dart';
import '../domain/employee_salary_config.dart';
import '../domain/employee_salary_summary.dart';
import '../utils/salary_calculator.dart';

/// Dialog enabling administrators to select working dates directly from a calendar
/// for office staff and employees who do not use the mobile application,
/// automatically driving the day-wise salary calculations without manual time inputs.
class PutOfficeAttendanceDialog extends StatefulWidget {
  final EmployeeSalarySummary summary;
  final VoidCallback? onAttendanceSaved;

  const PutOfficeAttendanceDialog({
    super.key,
    required this.summary,
    this.onAttendanceSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    required EmployeeSalarySummary summary,
    VoidCallback? onAttendanceSaved,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PutOfficeAttendanceDialog(
        summary: summary,
        onAttendanceSaved: onAttendanceSaved,
      ),
    );
  }

  @override
  State<PutOfficeAttendanceDialog> createState() =>
      _PutOfficeAttendanceDialogState();
}

class _PutOfficeAttendanceDialogState extends State<PutOfficeAttendanceDialog> {
  final Set<String> _selectedDateKeys = {};
  double _totalOtHours = 0.0;
  final TextEditingController _otController = TextEditingController();

  late final List<DateTime> _cycleDates;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final cycle = widget.summary.cycle;
    final config = widget.summary.config;
    final empId = widget.summary.employeeId ?? config.employeeId ?? config.employeeCode;
    final empCode = widget.summary.employeeCode;
    final empName = widget.summary.employeeName;

    // Generate all dates in the salary cycle
    _cycleDates = [];
    final start = DateTime(
      cycle.startDate.year,
      cycle.startDate.month,
      cycle.startDate.day,
    );
    for (int i = 0; i < cycle.totalDays; i++) {
      _cycleDates.add(start.add(Duration(days: i)));
    }

    // Load existing calendar records for this employee within this cycle
    final allRecords = LocalDatabaseService().getAttendanceRecords();
    final existingRecords = allRecords.where((r) {
      final matches = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: r.employeeId,
        recordEmployeeName: r.employeeName,
        employeeId: empId,
        employeeCode: empCode,
        employeeName: empName,
      );
      final isCalendarRecord = r.deviceId == 'OFFICE_CALENDAR_ENTRY' ||
          r.id.startsWith('office_') ||
          r.remarks == 'Office Attendance (Calendar)';
      return matches && cycle.contains(r.eventTimestamp) && isCalendarRecord;
    }).toList();

    double existingOt = 0.0;
    for (final r in existingRecords) {
      final key = DateFormat('yyyyMMdd').format(r.eventTimestamp);
      _selectedDateKeys.add(key);
      if (r.manualOvertimeHours != null && r.manualOvertimeHours! > 0) {
        existingOt += r.manualOvertimeHours!;
      }
    }

    if (existingOt > 0) {
      _totalOtHours = existingOt;
      _otController.text = _totalOtHours.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _otController.dispose();
    super.dispose();
  }

  String _dateToKey(DateTime d) => DateFormat('yyyyMMdd').format(d);

  void _toggleDate(DateTime date) {
    final key = _dateToKey(date);
    setState(() {
      if (_selectedDateKeys.contains(key)) {
        _selectedDateKeys.remove(key);
      } else {
        _selectedDateKeys.add(key);
      }
    });
  }

  void _selectWorkingDaysMonToSat() {
    setState(() {
      _selectedDateKeys.clear();
      for (final d in _cycleDates) {
        if (d.weekday != DateTime.sunday) {
          _selectedDateKeys.add(_dateToKey(d));
        }
      }
    });
  }

  void _selectAllDays() {
    setState(() {
      _selectedDateKeys.clear();
      for (final d in _cycleDates) {
        _selectedDateKeys.add(_dateToKey(d));
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedDateKeys.clear();
    });
  }

  // ===========================================================================
  // Projected Salary Calculation for Real-Time Feedback
  // ===========================================================================

  EmployeeSalarySummary _computeProjectedSummary() {
    final cycle = widget.summary.cycle;
    final config = widget.summary.config;
    final empId = widget.summary.employeeId ?? config.employeeId ?? config.employeeCode;
    final empName = widget.summary.employeeName;

    final List<AttendanceRecord> mockRecords = [];
    final double otPerDay = _selectedDateKeys.isNotEmpty && _totalOtHours > 0
        ? (_totalOtHours / _selectedDateKeys.length)
        : 0.0;

    for (final dateKey in _selectedDateKeys) {
      final year = int.parse(dateKey.substring(0, 4));
      final month = int.parse(dateKey.substring(4, 6));
      final day = int.parse(dateKey.substring(6, 8));
      final date = DateTime(year, month, day);

      mockRecords.add(
        AttendanceRecord(
          id: 'proj_${dateKey}_in',
          employeeId: empId,
          employeeName: empName,
          workflowStep: WorkflowStep.officeCheckIn,
          eventTimestamp: DateTime(date.year, date.month, date.day, 9, 0),
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 10.0,
          address: 'Office (Calendar Entry)',
          deviceId: 'OFFICE_CALENDAR_ENTRY',
          photoBase64: '',
          isGeofenceValid: true,
          manualOvertimeHours: otPerDay > 0 ? otPerDay : null,
        ),
      );
      mockRecords.add(
        AttendanceRecord(
          id: 'proj_${dateKey}_out',
          employeeId: empId,
          employeeName: empName,
          workflowStep: WorkflowStep.officeCheckOut,
          eventTimestamp: DateTime(date.year, date.month, date.day, 18, 0),
          latitude: 25.2048,
          longitude: 55.2708,
          gpsAccuracy: 10.0,
          address: 'Office (Calendar Entry)',
          deviceId: 'OFFICE_CALENDAR_ENTRY',
          photoBase64: '',
          isGeofenceValid: true,
          manualOvertimeHours: otPerDay > 0 ? otPerDay : null,
        ),
      );
    }

    return SalaryCalculator.calculateEmployeeSalary(
      config: config,
      records: mockRecords,
      cycle: cycle,
      referenceDate: DateTime(cycle.endDate.year, cycle.endDate.month, cycle.endDate.day, 23, 59),
    );
  }

  // ===========================================================================
  // Save Action
  // ===========================================================================

  void _saveAttendance() async {
    setState(() => _isSaving = true);

    try {
      final cycle = widget.summary.cycle;
      final config = widget.summary.config;
      final empId = widget.summary.employeeId ?? config.employeeId ?? config.employeeCode;
      final empName = widget.summary.employeeName;
      final empCode = widget.summary.employeeCode;

      // 1. Identify and remove any calendar records in this cycle whose date is NOT in _selectedDateKeys
      final allRecords = LocalDatabaseService().getAttendanceRecords();
      final existingForCycle = allRecords.where((r) {
        final matches = EmployeeDirectoryHelper.matchesEmployeeIdentity(
          recordEmployeeId: r.employeeId,
          recordEmployeeName: r.employeeName,
          employeeId: empId,
          employeeCode: empCode,
          employeeName: empName,
        );
        final isCalendarRecord = r.deviceId == 'OFFICE_CALENDAR_ENTRY' ||
            r.id.startsWith('office_') ||
            r.remarks == 'Office Attendance (Calendar)';
        return matches && cycle.contains(r.eventTimestamp) && isCalendarRecord;
      }).toList();

      final List<String> deletedRecordIds = [];
      for (final r in existingForCycle) {
        final key = DateFormat('yyyyMMdd').format(r.eventTimestamp);
        if (!_selectedDateKeys.contains(key)) {
          deletedRecordIds.add(r.id);
        }
      }

      // 2. Build attendance records for all selected dates (standard 9am - 6pm office day)
      final double otPerDay = _selectedDateKeys.isNotEmpty && _totalOtHours > 0
          ? (_totalOtHours / _selectedDateKeys.length)
          : 0.0;

      final List<AttendanceRecord> newRecords = [];
      const uuid = Uuid();

      for (final dateKey in _selectedDateKeys) {
        final year = int.parse(dateKey.substring(0, 4));
        final month = int.parse(dateKey.substring(4, 6));
        final day = int.parse(dateKey.substring(6, 8));
        final date = DateTime(year, month, day);

        final checkInDt = DateTime(date.year, date.month, date.day, 9, 0);
        final checkOutDt = DateTime(date.year, date.month, date.day, 18, 0);

        final inId = uuid.v5(Uuid.NAMESPACE_URL, 'office_${empCode}_${dateKey}_in');
        final outId = uuid.v5(Uuid.NAMESPACE_URL, 'office_${empCode}_${dateKey}_out');

        newRecords.add(
          AttendanceRecord(
            id: inId,
            employeeId: empId,
            employeeName: empName,
            workflowStep: WorkflowStep.officeCheckIn,
            eventTimestamp: checkInDt,
            syncTimestamp: DateTime.now(),
            latitude: 25.2048,
            longitude: 55.2708,
            gpsAccuracy: 10.0,
            address: 'Office (Calendar Entry)',
            deviceId: 'OFFICE_CALENDAR_ENTRY',
            photoBase64: '',
            isGeofenceValid: true,
            siteName: 'Main Office',
            manualOvertimeHours: otPerDay > 0 ? otPerDay : null,
            remarks: 'Office Attendance (Calendar)',
            isEdited: true,
            editedBy: 'Admin',
          ),
        );

        newRecords.add(
          AttendanceRecord(
            id: outId,
            employeeId: empId,
            employeeName: empName,
            workflowStep: WorkflowStep.officeCheckOut,
            eventTimestamp: checkOutDt,
            syncTimestamp: DateTime.now(),
            latitude: 25.2048,
            longitude: 55.2708,
            gpsAccuracy: 10.0,
            address: 'Office (Calendar Entry)',
            deviceId: 'OFFICE_CALENDAR_ENTRY',
            photoBase64: '',
            isGeofenceValid: true,
            siteName: 'Main Office',
            manualOvertimeHours: otPerDay > 0 ? otPerDay : null,
            remarks: 'Office Attendance (Calendar)',
            isEdited: true,
            editedBy: 'Admin',
          ),
        );
      }

      await LocalDatabaseService().saveOfficeAttendanceBatch(
        newRecords: newRecords,
        deletedRecordIds: deletedRecordIds,
      );

      widget.onAttendanceSaved?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked ${_selectedDateKeys.length} working days for $empName on calendar.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving calendar attendance: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearAttendanceForCycle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cycle Attendance?'),
        content: Text(
          'Are you sure you want to remove all attendance records for ${widget.summary.employeeName} in ${widget.summary.cycle.shortPeriodLabel}? Salary will recalculate to 0 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final cycle = widget.summary.cycle;
      final config = widget.summary.config;
      final empId = widget.summary.employeeId ?? config.employeeId ?? config.employeeCode;
      final empCode = widget.summary.employeeCode;
      final empName = widget.summary.employeeName;

      final allRecords = LocalDatabaseService().getAttendanceRecords();
      final toRemove = allRecords.where((r) {
        final matches = EmployeeDirectoryHelper.matchesEmployeeIdentity(
          recordEmployeeId: r.employeeId,
          recordEmployeeName: r.employeeName,
          employeeId: empId,
          employeeCode: empCode,
          employeeName: empName,
        );
        final isCalendarRecord = r.deviceId == 'OFFICE_CALENDAR_ENTRY' ||
            r.id.startsWith('office_') ||
            r.remarks == 'Office Attendance (Calendar)';
        return matches && cycle.contains(r.eventTimestamp) && isCalendarRecord;
      }).toList();

      final toRemoveIds = toRemove.map((r) => r.id).toList();
      await LocalDatabaseService().saveOfficeAttendanceBatch(
        newRecords: [],
        deletedRecordIds: toRemoveIds,
      );

      setState(() {
        _selectedDateKeys.clear();
        _totalOtHours = 0.0;
        _otController.clear();
        _isSaving = false;
      });

      widget.onAttendanceSaved?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared all attendance records for $empName.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing attendance: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // Build Methods
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = widget.summary;
    final config = summary.config;
    final cycle = summary.cycle;
    final projectedSummary = _computeProjectedSummary();

    // Calculate which Sundays are credited as paid weekly off
    final Set<String> paidSundayKeys = {};
    for (final r in projectedSummary.dailyRecords) {
      if (r.status == DailySalaryStatus.paidSundayOff) {
        paidSundayKeys.add(_dateToKey(r.date));
      }
    }

    final int nonSundayCount = _cycleDates.where((d) => d.weekday != DateTime.sunday).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Column(
          children: [
            // 1. Header with Employee Profile & Cycle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  EmployeeAvatar(
                    photoUrl: null,
                    fullName: summary.employeeName,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                summary.employeeName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                summary.employeeCode,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.department} • Cycle: ${cycle.shortPeriodLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Base: AED ${config.monthlyBaseTotal.toStringAsFixed(0)} (Basic: ${config.basicSalary.toStringAsFixed(0)} + Var: ${config.variableSalary.toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body: Quick Actions + Calendar Grid + Summary Card
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Quick Selection Actions Bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.green),
                        label: Text('Mon - Sat ($nonSundayCount Days)'),
                        onPressed: _selectWorkingDaysMonToSat,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.done_all_rounded, size: 15, color: AppColors.primary),
                        label: Text('Select All (${_cycleDates.length} Days)'),
                        onPressed: _selectAllDays,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedDateKeys.isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                          label: const Text('Clear'),
                          onPressed: _clearSelection,
                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                          labelStyle: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Calendar Instruction
                  Row(
                    children: [
                      const Icon(Icons.touch_app_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Tap calendar dates to toggle working attendance (Present / Off):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. Calendar Grid Container
                  _buildCalendarGrid(isDark, paidSundayKeys),
                  const SizedBox(height: 16),

                  // 4. Optional Overtime Input (No Times, Just Total Hours)
                  if (!config.otIncludedInVariable) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.backgroundDark : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.more_time_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cycle Overtime Hours (Optional)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Calculated from Basic salary only: (Basic / ${_cycleDates.length}) / 8',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 90,
                            height: 38,
                            child: TextField(
                              controller: _otController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '0.0',
                                suffixText: 'hrs',
                                suffixStyle: const TextStyle(fontSize: 10),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                filled: true,
                                fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _totalOtHours = double.tryParse(val.trim()) ?? 0.0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. Projected Live Salary Calculation Card
                  _buildProjectedSummaryCard(projectedSummary, isDark, config),
                ],
              ),
            ),

            // 6. Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_selectedDateKeys.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      onPressed: _isSaving ? null : _clearAttendanceForCycle,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Clear Cycle', style: TextStyle(fontSize: 11)),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSaving ? null : _saveAttendance,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 16),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : 'Save ${_selectedDateKeys.length} Days (AED ${projectedSummary.grossTotalSalary.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Calendar Grid Widget
  // ===========================================================================

  Widget _buildCalendarGrid(bool isDark, Set<String> paidSundayKeys) {
    // Days of the week header: Mon, Tue, Wed, Thu, Fri, Sat, Sun
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Align start of cycle to correct weekday column (Monday = 1, so offset = weekday - 1)
    final int leadingBlanks = _cycleDates.isNotEmpty ? (_cycleDates.first.weekday - 1) : 0;
    final int totalGridItems = leadingBlanks + _cycleDates.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Weekdays Header Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: weekdays.map((day) {
                final isSun = day == 'Sun';
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSun
                            ? Colors.blue[700]
                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Grid of Calendar Dates
          Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalGridItems,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                if (index < leadingBlanks) {
                  return const SizedBox.shrink();
                }

                final date = _cycleDates[index - leadingBlanks];
                final dateKey = _dateToKey(date);
                final bool isSelected = _selectedDateKeys.contains(dateKey);
                final bool isSunday = date.weekday == DateTime.sunday;
                final bool isPaidSunday = !isSelected && isSunday && paidSundayKeys.contains(dateKey);

                return _buildDateCell(
                  date: date,
                  dateKey: dateKey,
                  isSelected: isSelected,
                  isSunday: isSunday,
                  isPaidSunday: isPaidSunday,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell({
    required DateTime date,
    required String dateKey,
    required bool isSelected,
    required bool isSunday,
    required bool isPaidSunday,
    required bool isDark,
  }) {
    Color bgColor;
    Border? border;

    if (isSelected) {
      bgColor = isDark
          ? AppColors.primary.withValues(alpha: 0.35)
          : AppColors.primary.withValues(alpha: 0.15);
      border = Border.all(color: AppColors.primary, width: 1.5);
    } else if (isPaidSunday) {
      bgColor = Colors.blue.withValues(alpha: isDark ? 0.18 : 0.08);
      border = Border.all(color: Colors.blue.withValues(alpha: 0.4));
    } else if (isSunday) {
      bgColor = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50]!;
      border = Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!);
    } else {
      bgColor = isDark ? Colors.transparent : Colors.white;
      border = Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!);
    }

    final String dayNum = date.day.toString();
    final String monthAbbr = DateFormat('MMM').format(date);
    final bool showMonthTag = date.day == 1 || date == _cycleDates.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleDate(date),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showMonthTag)
                Text(
                  monthAbbr.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              Text(
                dayNum,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isSunday ? Colors.blue[600] : (isDark ? Colors.grey[300] : Colors.black87)),
                ),
              ),
              const SizedBox(height: 2),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '✓ Work',
                    style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              else if (isPaidSunday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Sun Off',
                    style: TextStyle(fontSize: 7.5, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Text(
                  isSunday ? 'Off' : 'Absent',
                  style: TextStyle(
                    fontSize: 8,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Projected Salary Summary Card
  // ===========================================================================

  Widget _buildProjectedSummaryCard(
    EmployeeSalarySummary summary,
    bool isDark,
    EmployeeSalaryConfig config,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROJECTED EARNED SALARY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AED ${summary.grossTotalSalary.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${summary.totalPayableDays} Payable Days',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${summary.daysWorked}d worked + ${summary.paidSundays}d Sun off',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem(
                'Fixed Earned',
                'AED ${summary.earnedFixedSalary.toStringAsFixed(2)}',
                isDark,
              ),
              _buildMetricItem(
                'Variable Earned',
                'AED ${summary.earnedVariableSalary.toStringAsFixed(2)}',
                isDark,
              ),
              _buildMetricItem(
                config.otIncludedInVariable
                    ? 'OT (Fixed)'
                    : (config.customMonthlyOtAmount != null
                        ? 'OT (Manual)'
                        : 'OT (${summary.totalOvertimeHours.toStringAsFixed(1)}h)'),
                config.otIncludedInVariable ? 'AED 0.00' : 'AED ${summary.earnedOtSalary.toStringAsFixed(2)}',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
