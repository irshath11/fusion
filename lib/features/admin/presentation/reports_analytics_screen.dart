import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/timesheet_calculator.dart';
import '../../admin/domain/employee_entity.dart';
import '../../attendance/domain/attendance_record.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();

  String? _selectedEmployeeId;
  DateTime? _selectedDate;
  String _searchQuery = '';
  bool _isLoadingCloud = false;
  int _activeTab = 0; // 0 = Directory, 1 = Cumulative Summary

  @override
  void initState() {
    super.initState();
    _loadCloudAttendanceRecords();
  }

  Future<void> _loadCloudAttendanceRecords() async {
    setState(() => _isLoadingCloud = true);
    try {
      final cloudRecords =
          await SupabaseService().fetchAttendanceRecordsFromSupabase();
      if (cloudRecords.isNotEmpty) {
        final existingRecords = _db.getAttendanceRecords();
        final existingIds = existingRecords.map((r) => r.id).toSet();
        for (final record in cloudRecords) {
          if (!existingIds.contains(record.id)) {
            _db.addAttendanceRecord(record);
          }
        }
      }
    } catch (e) {
      debugPrint('Cloud attendance fetch error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCloud = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedEmployeeId != null && _selectedDate != null) {
      return _buildLevel3DateDetailView();
    } else if (_selectedEmployeeId != null) {
      return _buildLevel2DateListView();
    } else {
      return _buildLevel1EmployeeListView();
    }
  }

  // ==========================================
  // LEVEL 1: EMPLOYEE LIST VIEW
  // ==========================================
  Widget _buildLevel1EmployeeListView() {
    final dbEmployees = _db.getEmployees();
    final allRecords = _db.getAttendanceRecords();

    // Synthesize employee list from both DB & Attendance Records
    final Map<String, EmployeeEntity> employeeMap = {};
    for (final e in dbEmployees) {
      final key = e.email.trim().isNotEmpty
          ? e.email.trim().toLowerCase()
          : e.name.trim().toLowerCase();
      employeeMap[key] = e;
    }

    for (final r in allRecords) {
      final nameKey = r.employeeName.trim().toLowerCase();
      final idKey = r.employeeId;

      bool alreadyExists = employeeMap.values.any((e) =>
          e.id == idKey ||
          (e.name.trim().toLowerCase() == nameKey && nameKey.isNotEmpty));

      if (!alreadyExists) {
        final shortId = r.employeeId.length >= 4
            ? r.employeeId.substring(0, 4).toUpperCase()
            : r.employeeId.toUpperCase();
        employeeMap[nameKey.isNotEmpty ? nameKey : idKey] = EmployeeEntity(
          id: r.employeeId,
          employeeCode: 'EMP-$shortId',
          name: r.employeeName,
          mobileNumber: '',
          email: '',
          designation: 'Field Staff',
          department: 'Operations',
        );
      }
    }

    final allEmployees = employeeMap.values.toList();

    final filteredEmployees = allEmployees.where((e) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.employeeCode.toLowerCase().contains(q) ||
          e.department.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee Attendance Reports',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Select an employee to view date-wise logs & photos',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                    tooltip: 'Refresh Cloud Logs',
                    onPressed: _loadCloudAttendanceRecords,
                  ),
                ],
              )
            ],
          ),
          if (_isLoadingCloud)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 12),

          // Tab Bar Switcher (Directory vs Cumulative Record)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _activeTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 18,
                            color: _activeTab == 0
                                ? AppColors.primary
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Employee Directory',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _activeTab == 0
                                  ? AppColors.primary
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _activeTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            size: 18,
                            color: _activeTab == 1
                                ? AppColors.primary
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cumulative Hours',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _activeTab == 1
                                  ? AppColors.primary
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search employee name, code, department...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          if (_activeTab == 0) ...[
            if (filteredEmployees.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(30.0),
                  child: Center(
                    child: Text('No employees found.'),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final emp = filteredEmployees[index];
                  final empRecords = allRecords
                      .where((r) =>
                          r.employeeId == emp.id ||
                          r.employeeName.toLowerCase() == emp.name.toLowerCase())
                      .toList();

                  // Distinct dates count
                  final datesCount = empRecords
                      .map((r) => DateFormat('yyyy-MM-dd').format(r.eventTimestamp))
                      .toSet()
                      .length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 1.5,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          emp.name.isNotEmpty
                              ? emp.name.substring(0, 1).toUpperCase()
                              : 'E',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              emp.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              emp.employeeCode,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Department: ${emp.department.isNotEmpty ? emp.department : 'General'}\n'
                          '${datesCount > 0 ? "$datesCount Attendance Date(s) Logged" : "No records recorded yet"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: AppColors.textSecondaryLight),
                      onTap: () {
                        setState(() {
                          _selectedEmployeeId = emp.id;
                          _selectedDate = null;
                        });
                      },
                    ),
                  );
                },
              ),
          ] else ...[
            _buildCumulativeSummaryView(filteredEmployees, allRecords),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // LEVEL 2: DATE LIST VIEW FOR SELECTED EMPLOYEE
  // ==========================================
  Widget _buildLevel2DateListView() {
    final emp = _db.getEmployees().firstWhere(
          (e) => e.id == _selectedEmployeeId,
          orElse: () => EmployeeEntity(
            id: _selectedEmployeeId!,
            employeeCode: 'EMP',
            name: 'Employee',
            mobileNumber: '',
            email: '',
            designation: 'Staff',
            department: 'General',
          ),
        );

    final empRecords = _db.getAttendanceRecords().where((r) {
      return r.employeeId == emp.id ||
          r.employeeName.toLowerCase() == emp.name.toLowerCase();
    }).toList();

    // Group records by date (yyyy-MM-dd)
    final Map<String, List<AttendanceRecord>> groupedByDate = {};
    for (final r in empRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(r.eventTimestamp);
      groupedByDate.putIfAbsent(dateKey, () => []).add(r);
    }

    final sortedDateKeys = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final timesheets = TimesheetCalculator.calculateDailyTimesheets(empRecords);

    double totalRegHours = 0.0;
    double totalOtHours = 0.0;

    for (final entry in timesheets) {
      totalRegHours += entry.regularHours;
      totalOtHours += entry.overtimeHours;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _selectedEmployeeId = null;
                    _selectedDate = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${emp.employeeCode} • ${emp.department} • Work Timesheet',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportPdfForEmployee(emp, empRecords),
                icon: const Icon(Icons.picture_as_pdf_rounded,
                    size: 14),
                label: const Text('Download PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Executive Timesheet Summary Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text('Regular', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${totalRegHours.toStringAsFixed(1)} hrs', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const Text('Max 8.0h/day', style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    children: [
                      Text('Overtime (OT)', style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${totalOtHours.toStringAsFixed(1)} hrs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                      const Text('Beyond 8.0h/day', style: TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text('Combined', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${(totalRegHours + totalOtHours).toStringAsFixed(1)} hrs', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
                      Text('${sortedDateKeys.length} Days Worked', style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (sortedDateKeys.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.event_busy_rounded,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No attendance logs recorded for ${emp.name} yet.',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDateKeys.length,
              itemBuilder: (context, index) {
                final dateKey = sortedDateKeys[index];
                final dateRecords = groupedByDate[dateKey]!;
                dateRecords.sort((a, b) =>
                    a.eventTimestamp.compareTo(b.eventTimestamp));

                final parsedDate = DateTime.parse(dateKey);
                final formattedDateStr =
                    DateFormat('EEEE, dd MMMM yyyy').format(parsedDate);

                final allValidGeofence =
                    dateRecords.every((r) => r.isGeofenceValid);
                final firstTime = DateFormat('hh:mm a')
                    .format(dateRecords.first.eventTimestamp);
                final lastTime = DateFormat('hh:mm a')
                    .format(dateRecords.last.eventTimestamp);

                final siteOutRecs = dateRecords.where((r) => r.workflowStep == WorkflowStep.siteCheckOut);
                final officeOutRecs = dateRecords.where((r) => r.workflowStep == WorkflowStep.officeCheckOut);
                final endRecordTime = officeOutRecs.isNotEmpty
                    ? officeOutRecs.last.eventTimestamp
                    : (siteOutRecs.isNotEmpty ? siteOutRecs.last.eventTimestamp : dateRecords.last.eventTimestamp);

                final siteCheckIns = dateRecords.where((r) => r.workflowStep == WorkflowStep.siteCheckIn && r.siteName != null && r.siteName!.isNotEmpty);
                final siteNamesStr = siteCheckIns.isNotEmpty
                    ? siteCheckIns.map((r) => r.siteName!).toSet().join(', ')
                    : null;

                final diff = endRecordTime.isAfter(dateRecords.first.eventTimestamp)
                    ? endRecordTime.difference(dateRecords.first.eventTimestamp)
                    : Duration.zero;
                final dayHrs = diff.inMinutes / 60.0;
                final dayReg = dayHrs <= 8.0 ? dayHrs : 8.0;
                final dayOt = dayHrs > 8.0 ? (dayHrs - 8.0) : 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 1.5,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            formattedDateStr,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${dayReg.toStringAsFixed(1)}h Reg',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            if (dayOt > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${dayOt.toStringAsFixed(1)}h OT',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                ),
                              ),
                            ]
                          ],
                        )
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '$firstTime - $lastTime (${dateRecords.length} Step Logs)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          if (siteNamesStr != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Sites: $siteNamesStr',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (allValidGeofence
                                          ? AppColors.success
                                          : AppColors.error)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  allValidGeofence
                                      ? 'VALID GEOFENCE'
                                      : 'GEOFENCE VIOLATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: allValidGeofence
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${dateRecords.where((r) => r.photoBase64.isNotEmpty).length} Photo(s)',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: AppColors.textSecondaryLight),
                    onTap: () {
                      setState(() {
                        _selectedDate = parsedDate;
                      });
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // LEVEL 3: DETAILED RECORD & PHOTO VIEW FOR SELECTED DATE
  // ==========================================
  Widget _buildLevel3DateDetailView() {
    final emp = _db.getEmployees().firstWhere(
          (e) => e.id == _selectedEmployeeId,
          orElse: () => EmployeeEntity(
            id: _selectedEmployeeId!,
            employeeCode: 'EMP',
            name: 'Employee',
            mobileNumber: '',
            email: '',
            designation: 'Staff',
            department: 'General',
          ),
        );

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    final dateRecords = _db.getAttendanceRecords().where((r) {
      final matchesUser = r.employeeId == emp.id ||
          r.employeeName.toLowerCase() == emp.name.toLowerCase();
      final matchesDate =
          DateFormat('yyyy-MM-dd').format(r.eventTimestamp) == selectedDateStr;
      return matchesUser && matchesDate;
    }).toList();

    dateRecords.sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    final formattedDateTitle =
        DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!);

    final dayTimesheets = TimesheetCalculator.calculateDailyTimesheets(dateRecords);
    double totalHrs = 0.0;
    double regHrs = 0.0;
    double otHrs = 0.0;

    if (dayTimesheets.isNotEmpty) {
      final tEntry = dayTimesheets.first;
      regHrs = tEntry.regularHours;
      otHrs = tEntry.overtimeHours;
      totalHrs = tEntry.totalHours;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _selectedDate = null;
                  });
                },
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formattedDateTitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Daily Timesheet Breakdown Card (Regular, OT, Combined)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timer_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Daily Timesheet Hours Summary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Regular Time', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${regHrs.toStringAsFixed(1)} hrs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                            const Text('Max 8.0h/day', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: otHrs > 0 ? Colors.orange.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overtime (OT)', style: TextStyle(fontSize: 10, color: otHrs > 0 ? Colors.orange.shade900 : Colors.grey.shade700, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('+${otHrs.toStringAsFixed(1)} hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: otHrs > 0 ? Colors.orange.shade900 : Colors.grey.shade700)),
                            const Text('Beyond 8.0h', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Combined Time', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${totalHrs.toStringAsFixed(1)} hrs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success)),
                            const Text('Reg + OT', style: TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Date Summary Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Workflow Steps Logged: ${dateRecords.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All steps verified via live front camera & GPS geofencing',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Timeline & Live Verification Photos',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (dateRecords.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No log details recorded for this date.')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dateRecords.length,
              itemBuilder: (context, index) {
                final r = dateRecords[index];
                final timeStr = DateFormat('hh:mm:ss a').format(r.eventTimestamp);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getStepColor(r.workflowStep)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getStepIcon(r.workflowStep),
                                    color: _getStepColor(r.workflowStep),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.workflowStep.displayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondaryLight),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (r.isGeofenceValid
                                        ? AppColors.success
                                        : AppColors.error)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.isGeofenceValid ? 'VALID' : 'VIOLATION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: r.isGeofenceValid
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 20),

                        // Location Details: Map Place Location Name & GPS Coordinates
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 18, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (r.siteName != null && r.siteName!.trim().isNotEmpty)
                                        ? r.siteName!.trim()
                                        : (r.workflowStep == WorkflowStep.officeCheckIn || r.workflowStep == WorkflowStep.officeCheckOut
                                            ? 'Main HQ Office'
                                            : LocationService.resolvePlaceName(r.latitude, r.longitude)),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'GPS Coordinates: ${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)} (Accuracy: ${r.gpsAccuracy.toStringAsFixed(1)}m)',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Site Name & Photo Section
                        () {
                          final String siteNameText = (r.siteName != null && r.siteName!.trim().isNotEmpty)
                              ? r.siteName!
                              : (r.workflowStep == WorkflowStep.officeCheckIn || r.workflowStep == WorkflowStep.officeCheckOut
                                  ? 'Main Office'
                                  : 'Assigned Site');

                          final hasPhoto = r.photoBase64.trim().isNotEmpty;

                          if (hasPhoto) {
                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.camera_alt_rounded,
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Verified Live Camera Snapshot',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.place_rounded,
                                                size: 12, color: AppColors.primary),
                                            const SizedBox(width: 3),
                                            Text(
                                              siteNameText,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => _showFullImageDialog(r),
                                      child: Container(
                                        height: 140,
                                        width: 140,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.primaryLight),
                                        ),
                                        child: _buildPhotoWidget(r.photoBase64),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () => _showFullImageDialog(r),
                                      icon: const Icon(Icons.fullscreen_rounded,
                                          size: 16),
                                      label: const Text(
                                        'Tap to Enlarge Verified Photo',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // Where image is not required: Display Site Name & Location Card
                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.15)),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.place_rounded,
                                      size: 22,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Job Site / Location',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textSecondaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          siteNameText,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (r.address.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            r.address,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }(),
                        const SizedBox(height: 10),

                        // Sync Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Device ID: ${r.deviceId}',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.cloud_done_rounded,
                                    size: 14, color: AppColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  r.syncStatus.name.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success),
                                ),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS & METHODS
  // ==========================================
  Widget _buildPhotoWidget(String photoStr) {
    final photo = photoStr.trim();
    if (photo.isEmpty) {
      return const Center(
          child: Icon(Icons.person_pin, size: 60, color: Colors.white70));
    }

    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return Image.network(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.white70),
        ),
      );
    }

    try {
      if (File(photo).existsSync()) {
        return Image.file(File(photo), fit: BoxFit.cover);
      }
      final cleanBase64 = photo.replaceAll(RegExp(r'[\r\n\s]+'), '');
      final decodedBytes = base64Decode(cleanBase64);
      return Image.memory(decodedBytes, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        color: Colors.blueGrey.shade800,
        child: const Center(
          child: Icon(Icons.person_pin, size: 65, color: Colors.white70),
        ),
      );
    }
  }

  void _showFullImageDialog(AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${record.employeeName} • ${record.workflowStep.displayName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const Divider(),
              Container(
                height: 280,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildPhotoWidget(record.photoBase64),
              ),
              const SizedBox(height: 12),
              Text(
                'Timestamp: ${DateFormat('dd MMM yyyy hh:mm:ss a').format(record.eventTimestamp)}',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Location: ${(record.siteName != null && record.siteName!.trim().isNotEmpty) ? record.siteName!.trim() : (record.workflowStep == WorkflowStep.officeCheckIn || record.workflowStep == WorkflowStep.officeCheckOut ? "Main Office" : "Work Site")} (${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)})',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStepIcon(WorkflowStep step) {
    switch (step) {
      case WorkflowStep.officeCheckIn:
        return Icons.login_rounded;
      case WorkflowStep.siteCheckIn:
        return Icons.location_on_rounded;
      case WorkflowStep.siteCheckOut:
        return Icons.directions_run_rounded;
      case WorkflowStep.officeCheckOut:
        return Icons.logout_rounded;
      case WorkflowStep.completed:
        return Icons.check_circle_rounded;
    }
  }

  Color _getStepColor(WorkflowStep step) {
    switch (step) {
      case WorkflowStep.officeCheckIn:
        return AppColors.success;
      case WorkflowStep.siteCheckIn:
        return AppColors.primary;
      case WorkflowStep.siteCheckOut:
        return AppColors.warning;
      case WorkflowStep.officeCheckOut:
        return Colors.purple;
      case WorkflowStep.completed:
        return AppColors.success;
    }
  }

  Future<void> _exportPdfForEmployee(
      EmployeeEntity emp, List<AttendanceRecord> records) async {
    try {
      await PdfExportService.downloadEmployeeAttendancePdfFile(
        organizationName: _db.organization?.name ?? 'Fusion Enterprise',
        employee: emp,
        records: records,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${emp.name} PDF report ready for download/saving!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading employee PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportCumulativePdf(
      List<EmployeeEntity> employees, List<AttendanceRecord> records) async {
    try {
      await PdfExportService.downloadCumulativePdfFile(
        organizationName: _db.organization?.name ?? 'Fusion Enterprise',
        employees: employees,
        records: records,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cumulative PDF report ready for download/saving!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==========================================
  // CUMULATIVE SUMMARY VIEW FOR ALL EMPLOYEES
  // ==========================================
  Widget _buildCumulativeSummaryView(
      List<EmployeeEntity> employees, List<AttendanceRecord> allRecords) {
    final List<_EmpCumulativeData> summaries = [];
    double grandReg = 0.0;
    double grandOt = 0.0;

    for (final emp in employees) {
      final empRecords = allRecords.where((r) {
        return r.employeeId == emp.id ||
            r.employeeName.toLowerCase() == emp.name.toLowerCase();
      }).toList();

      final timesheets =
          TimesheetCalculator.calculateDailyTimesheets(empRecords);

      double regHours = 0.0;
      double otHours = 0.0;

      for (final entry in timesheets) {
        regHours += entry.regularHours;
        otHours += entry.overtimeHours;
      }

      grandReg += regHours;
      grandOt += otHours;

      summaries.add(
        _EmpCumulativeData(
          employee: emp,
          regularHours: regHours,
          overtimeHours: otHours,
          combinedHours: regHours + otHours,
          daysWorked: timesheets.length,
        ),
      );
    }

    final grandCombined = grandReg + grandOt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive Grand Total Summary Cards
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.summarize_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Workforce Cumulative Summary',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryLight,
                                  fontSize: 14,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => _exportCumulativePdf(employees, allRecords),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                    label: const Text('Download PDF',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: 'Regular Hrs',
                      value: '${grandReg.toStringAsFixed(1)}h',
                      color: AppColors.primary,
                      icon: Icons.access_time_filled_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: 'Overtime OT',
                      value: '+${grandOt.toStringAsFixed(1)}h',
                      color: Colors.orange.shade800,
                      icon: Icons.more_time_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: 'Combined Total',
                      value: '${grandCombined.toStringAsFixed(1)}h',
                      color: Colors.indigo.shade800,
                      icon: Icons.av_timer_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (summaries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(30.0),
              child: Center(
                child: Text('No cumulative records found.'),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final item = summaries[index];
              final emp = item.employee;

              final double regPercent = item.combinedHours > 0
                  ? (item.regularHours / item.combinedHours).clamp(0.0, 1.0)
                  : 1.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              emp.name.isNotEmpty
                                  ? emp.name.substring(0, 1).toUpperCase()
                                  : 'E',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Dept: ${emp.department.isNotEmpty ? emp.department : "General"} • ${item.daysWorked} Logged Day(s)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              emp.employeeCode,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Metrics Cards Grid (Regular, OT, Combined)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildEmpMetricItem(
                              title: 'Regular Hours',
                              value: '${item.regularHours.toStringAsFixed(1)} hrs',
                              color: AppColors.primary,
                            ),
                            Container(
                                width: 1,
                                height: 28,
                                color: Colors.grey.shade300),
                            _buildEmpMetricItem(
                              title: 'OT Hours',
                              value: '+${item.overtimeHours.toStringAsFixed(1)} hrs',
                              color: Colors.orange.shade800,
                            ),
                            Container(
                                width: 1,
                                height: 28,
                                color: Colors.grey.shade300),
                            _buildEmpMetricItem(
                              title: 'Combined Total',
                              value: '${item.combinedHours.toStringAsFixed(1)} hrs',
                              color: Colors.indigo.shade900,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Ratio Progress Bar
                      if (item.combinedHours > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: regPercent,
                            minHeight: 6,
                            backgroundColor: Colors.orange.shade400,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Regular: ${(regPercent * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600),
                            ),
                            if (item.overtimeHours > 0)
                              Text(
                                'OT: ${((1 - regPercent) * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Action Button to Drill Down
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedEmployeeId = emp.id;
                              _selectedDate = null;
                            });
                          },
                          icon: const Icon(Icons.calendar_month_rounded,
                              size: 14),
                          label: const Text('View Daily Logs & Photos',
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSummaryMetricBadge({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpMetricItem({
    required String title,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Flexible(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmpCumulativeData {
  final EmployeeEntity employee;
  final double regularHours;
  final double overtimeHours;
  final double combinedHours;
  final int daysWorked;

  _EmpCumulativeData({
    required this.employee,
    required this.regularHours,
    required this.overtimeHours,
    required this.combinedHours,
    required this.daysWorked,
  });
}
