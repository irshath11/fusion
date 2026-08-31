import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/timesheet_calculator.dart';
import '../../../core/widgets/app_animated_tab_switcher.dart';
import '../../admin/domain/employee_entity.dart';
import '../../attendance/domain/attendance_record.dart';
import 'admin_edit_attendance_dialog.dart';

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
  int _activeTab =
      0; // 0 = Directory, 1 = Cumulative Summary, 2 = Site / Client Man-Hours
  String _siteDateFilter = 'all'; // 'all', 'month', 'week', 'today'
  bool _siteGroupByClient =
      false; // true = Group by Client, false = Specific Site
  final Set<String> _expandedSiteKeys = {};

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
        _db.clearAttendanceCache();
        for (final record in cloudRecords) {
          _db.saveAttendanceRecord(record);
        }
      }

      // Also ensure latest employee records and codes from Supabase are synced
      final orgId =
          _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
      final cloudUsers =
          await SupabaseService().fetchOrganizationUsers(orgId);
      if (cloudUsers.isNotEmpty) {
        _db.setUsers(cloudUsers);
      }
      final cloudEmployees =
          await SupabaseService().fetchEmployeesFromSupabase(orgId);
      if (cloudEmployees.isNotEmpty) {
        _db.setEmployees(cloudEmployees);
      }
    } catch (e) {
      debugPrint('Cloud attendance fetch error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCloud = false);
      }
    }
  }

  List<EmployeeEntity> _getSynthesizedEmployees() {
    final dbEmployees = _db.getEmployees();
    final dbUsers = _db.getUsers();
    final allRecords = _db.getAttendanceRecords();

    final Map<String, EmployeeEntity> employeeMap = {};

    bool isHexFallback(String code, String id) {
      if (id.length >= 4 &&
          code.toUpperCase() == 'EMP-${id.substring(0, 4).toUpperCase()}') {
        return true;
      }
      final reg = RegExp(r'^EMP-[0-9A-Fa-f]{4}$');
      if (reg.hasMatch(code) &&
          id.toLowerCase().startsWith(code.substring(4).toLowerCase())) {
        return true;
      }
      return false;
    }

    String resolveBestCode(String? rawCode, String name, String id) {
      if (rawCode != null &&
          rawCode.trim().isNotEmpty &&
          rawCode.trim() != 'EMP-000' &&
          !isHexFallback(rawCode.trim(), id)) {
        return rawCode.trim();
      }
      final cleanName =
          name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      if (cleanName.isNotEmpty) {
        final prefix = cleanName.length >= 4
            ? cleanName.substring(0, 4)
            : (cleanName.length >= 3 ? cleanName.substring(0, 3) : cleanName);
        return 'EMP-$prefix';
      }
      return id.length >= 4
          ? 'EMP-${id.substring(0, 4).toUpperCase()}'
          : 'EMP-001';
    }

    String? findMatchingKey(String id, String email, String name) {
      if (id.isNotEmpty && employeeMap.containsKey(id)) return id;
      for (final entry in employeeMap.entries) {
        final e = entry.value;
        if (id.isNotEmpty && e.id == id) return entry.key;
        if (email.isNotEmpty &&
            e.email.trim().toLowerCase() == email.trim().toLowerCase()) {
          return entry.key;
        }
        if (name.isNotEmpty &&
            e.name.trim().toLowerCase() == name.trim().toLowerCase()) {
          return entry.key;
        }
      }
      return null;
    }

    // 1. Add from dbUsers (which carry employeeCode, designation, department)
    for (final u in dbUsers) {
      final code = resolveBestCode(u.employeeCode, u.fullName, u.id);
      final emp = EmployeeEntity(
        id: u.id,
        employeeCode: code,
        name: u.fullName,
        mobileNumber: u.phoneNumber ?? '',
        email: u.email,
        designation: u.designation ?? 'Staff',
        department: u.department ?? 'General',
        isActive: u.isActive,
      );
      final key = u.id.isNotEmpty
          ? u.id
          : (u.email.trim().isNotEmpty
              ? u.email.trim().toLowerCase()
              : u.fullName.trim().toLowerCase());
      employeeMap[key] = emp;
    }

    // 2. Overlay / Merge with dbEmployees from Supabase employees table
    for (final e in dbEmployees) {
      final matchedKey = findMatchingKey(e.id, e.email, e.name);
      if (matchedKey != null && employeeMap.containsKey(matchedKey)) {
        final existing = employeeMap[matchedKey]!;
        final isECodeValid = e.employeeCode.isNotEmpty &&
            e.employeeCode != 'EMP-000' &&
            !isHexFallback(e.employeeCode, e.id);
        final isExistingCodeValid = existing.employeeCode.isNotEmpty &&
            existing.employeeCode != 'EMP-000' &&
            !isHexFallback(existing.employeeCode, existing.id);

        final finalCode = isECodeValid
            ? e.employeeCode
            : (isExistingCodeValid
                ? existing.employeeCode
                : resolveBestCode(e.employeeCode, e.name, e.id));

        employeeMap[matchedKey] = EmployeeEntity(
          id: e.id.isNotEmpty ? e.id : existing.id,
          employeeCode: finalCode,
          name: e.name.isNotEmpty ? e.name : existing.name,
          mobileNumber: e.mobileNumber.isNotEmpty
              ? e.mobileNumber
              : existing.mobileNumber,
          email: e.email.isNotEmpty ? e.email : existing.email,
          designation: e.designation.isNotEmpty
              ? e.designation
              : existing.designation,
          department:
              e.department.isNotEmpty ? e.department : existing.department,
          useDefaultOffice: e.useDefaultOffice,
          assignedOfficeId: e.assignedOfficeId ?? existing.assignedOfficeId,
          assignedOfficeName:
              e.assignedOfficeName ?? existing.assignedOfficeName,
          isActive: e.isActive,
        );
      } else {
        final code = resolveBestCode(e.employeeCode, e.name, e.id);
        final key = e.id.isNotEmpty
            ? e.id
            : (e.email.trim().isNotEmpty
                ? e.email.trim().toLowerCase()
                : e.name.trim().toLowerCase());
        employeeMap[key] = EmployeeEntity(
          id: e.id,
          employeeCode: code,
          name: e.name,
          mobileNumber: e.mobileNumber,
          email: e.email,
          designation: e.designation,
          department: e.department,
          useDefaultOffice: e.useDefaultOffice,
          assignedOfficeId: e.assignedOfficeId,
          assignedOfficeName: e.assignedOfficeName,
          isActive: e.isActive,
        );
      }
    }

    // 3. Check any attendance records that might have been logged by employee
    for (final r in allRecords) {
      final nameKey = r.employeeName.trim().toLowerCase();
      final idKey = r.employeeId;

      bool alreadyExists = employeeMap.values.any((e) =>
          e.id == idKey ||
          (e.employeeCode.isNotEmpty &&
              e.employeeCode.toLowerCase() == idKey.toLowerCase()) ||
          (e.name.trim().toLowerCase() == nameKey && nameKey.isNotEmpty));

      if (!alreadyExists && r.employeeName.trim().isNotEmpty) {
        final code = resolveBestCode(null, r.employeeName, r.employeeId);
        employeeMap[idKey.isNotEmpty ? idKey : nameKey] = EmployeeEntity(
          id: r.employeeId,
          employeeCode: code,
          name: r.employeeName,
          mobileNumber: '',
          email: '',
          designation: 'Field Staff',
          department: 'Operations',
        );
      }
    }

    return employeeMap.values.toList();
  }

  EmployeeEntity _resolveEmployee(String? employeeId) {
    if (employeeId == null || employeeId.isEmpty) {
      return EmployeeEntity(
        id: '',
        employeeCode: 'EMP',
        name: 'Employee',
        mobileNumber: '',
        email: '',
        designation: 'Staff',
        department: 'General',
      );
    }
    final all = _getSynthesizedEmployees();
    final cleanId = employeeId.trim().toLowerCase();
    final match = all.where((e) =>
        e.id.toLowerCase() == cleanId ||
        e.employeeCode.toLowerCase() == cleanId ||
        e.name.toLowerCase().trim() == cleanId ||
        e.email.toLowerCase().trim() == cleanId ||
        (cleanId.length >= 4 && e.id.toLowerCase().startsWith(cleanId)) ||
        (cleanId.length >= 4 &&
            e.employeeCode.toLowerCase().contains(cleanId)) ||
        (cleanId.isNotEmpty && e.name.toLowerCase().trim().contains(cleanId)) ||
        (cleanId.isNotEmpty &&
            cleanId.contains(e.name.toLowerCase().trim())));
    if (match.isNotEmpty) return match.first;

    return EmployeeEntity(
      id: employeeId,
      employeeCode: employeeId.startsWith('EMP-') ? employeeId : 'EMP',
      name: 'Employee',
      mobileNumber: '',
      email: '',
      designation: 'Staff',
      department: 'General',
    );
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
    final allRecords = _db.getAttendanceRecords();
    final allEmployees = _getSynthesizedEmployees();

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
                    icon: _isLoadingCloud
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.currentColors
                                  .primaryFor(Theme.of(context).brightness),
                            ),
                          )
                        : Icon(Icons.refresh_rounded,
                            color: AppTheme.currentColors
                                .primaryFor(Theme.of(context).brightness)),
                    tooltip: 'Refresh Cloud Logs',
                    onPressed:
                        _isLoadingCloud ? null : _loadCloudAttendanceRecords,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Bar Switcher (Directory vs Cumulative Record vs Site Man-Hours)
          AppAnimatedTabSwitcher(
            selectedIndex: _activeTab,
            tabs: const [
              TabItemData(label: 'Directory', icon: Icons.people_alt_rounded),
              TabItemData(label: 'Cumulative', icon: Icons.analytics_rounded),
              TabItemData(
                  label: 'Site Hours', icon: Icons.location_city_rounded),
            ],
            onTabChanged: (index) => setState(() => _activeTab = index),
          ),
          const SizedBox(height: 14),

          // Search Bar
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final palette = AppTheme.currentColors;
              final activePrimary = palette
                  .primaryFor(isDark ? Brightness.dark : Brightness.light);

              return TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? palette.textPrimaryDark
                      : palette.textPrimaryLight,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search employee name, code, department...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? palette.textSecondaryDark
                        : Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: activePrimary),
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
                    borderSide: BorderSide(
                      color: isDark
                          ? palette.cardBorderDark
                          : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? palette.cardBorderDark
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: activePrimary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? palette.surfaceDark : Colors.white,
                ),
              );
            },
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
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final palette = AppTheme.currentColors;
                  final activePrimary = palette
                      .primaryFor(isDark ? Brightness.dark : Brightness.light);
                  final emp = filteredEmployees[index];
                  final empRecords = allRecords
                      .where((r) =>
                          r.employeeId == emp.id ||
                          r.employeeName.toLowerCase() ==
                              emp.name.toLowerCase())
                      .toList();

                  // Distinct dates count
                  final datesCount = empRecords
                      .map((r) =>
                          DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal()))
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
                        backgroundColor: activePrimary,
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
                              color: activePrimary.withValues(
                                  alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              emp.employeeCode,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: activePrimary),
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
          ] else if (_activeTab == 1) ...[
            _buildCumulativeSummaryView(filteredEmployees, allRecords),
          ] else ...[
            _buildSiteManHoursView(allRecords),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // LEVEL 2: DATE LIST VIEW FOR SELECTED EMPLOYEE
  // ==========================================
  Future<void> _addNewDateEntryLogForEmployee(EmployeeEntity emp) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select Date for New Entry Log (${emp.name})',
    );

    if (selectedDate == null || !mounted) return;

    final ok = await AdminEditAttendanceDialog.show(
      context,
      employeeId: emp.id,
      employeeName: emp.name,
      date: selectedDate,
      initialCheckIn: DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 8, 0),
      initialCheckOut: DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, 17, 0),
      initialOtHours: 0.0,
      initialRemarks: 'New date entry log created by admin',
    );

    if (ok == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New date entry log created for ${emp.name} on ${DateFormat('dd MMM yyyy').format(selectedDate)}!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _buildLevel2DateListView() {
    final emp = _resolveEmployee(_selectedEmployeeId);

    final empRecords = _db.getAttendanceRecords().where((r) {
      final rEmpId = r.employeeId.trim().toLowerCase();
      final rEmpName = r.employeeName.trim().toLowerCase();
      final eId = emp.id.trim().toLowerCase();
      final eName = emp.name.trim().toLowerCase();
      final eCode = emp.employeeCode.trim().toLowerCase();
      return (eId.isNotEmpty && rEmpId == eId) ||
          (eName.isNotEmpty && rEmpName == eName) ||
          (eCode.isNotEmpty && rEmpId == eCode) ||
          (eId.length >= 4 && rEmpId.startsWith(eId)) ||
          (rEmpId.length >= 4 && eId.startsWith(rEmpId)) ||
          (eName.isNotEmpty &&
              (rEmpName.contains(eName) || eName.contains(rEmpName)));
    }).toList();

    // Group records by date (yyyy-MM-dd)
    final Map<String, List<AttendanceRecord>> groupedByDate = {};
    for (final r in empRecords) {
      final dateKey = DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal());
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final activePrimary =
        palette.primaryFor(isDark ? Brightness.dark : Brightness.light);

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
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => _addNewDateEntryLogForEmployee(emp),
                icon: const Icon(Icons.post_add_rounded, size: 16),
                label: const Text('+ Add Date Log',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activePrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => _exportPdfForEmployee(emp, empRecords),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Download PDF',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
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
                    color: isDark
                        ? palette.surfaceDark
                        : activePrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? palette.cardBorderDark
                          : activePrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('Regular',
                          style: TextStyle(
                              fontSize: 11,
                              color: activePrimary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${totalRegHours.toStringAsFixed(1)} hrs',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: activePrimary)),
                      Text('Max 8.0h/day',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? palette.textSecondaryDark
                                  : palette.textSecondaryLight)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.orange.shade800
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('Overtime (OT)',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange.shade900,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${totalOtHours.toStringAsFixed(1)} hrs',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange.shade900)),
                      Text('Beyond 10.0h/day',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.cardBorderDark
                          : AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text('Combined',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                          '${(totalRegHours + totalOtHours).toStringAsFixed(1)} hrs',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success)),
                      Text('${sortedDateKeys.length} Days Worked',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Individual Employee Site Breakdown Card
          () {
            final empSiteSummaries =
                TimesheetCalculator.calculateSiteManHours(empRecords);
            if (empSiteSummaries.isEmpty) return const SizedBox.shrink();

            final totalSiteHrs =
                empSiteSummaries.fold(0.0, (a, b) => a + b.totalHours);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? palette.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? palette.cardBorderDark : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 4,
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
                      Row(
                        children: [
                          Icon(Icons.location_city_rounded,
                              color: activePrimary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Site / Client Man-Hours Spent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? palette.textPrimaryDark
                                  : palette.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: activePrimary.withValues(
                              alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${totalSiteHrs.toStringAsFixed(1)} Site Hrs',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: activePrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...empSiteSummaries.map((s) {
                    final clientColor = _getClientColor(s.siteName);
                    final pct = totalSiteHrs > 0
                        ? (s.totalHours / totalSiteHrs).clamp(0.0, 1.0)
                        : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: clientColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        s.siteName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color:
                                            clientColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        s.clientGroup,
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: clientColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${s.totalHours.toStringAsFixed(1)} hrs (${s.totalVisits} visit${s.totalVisits > 1 ? "s" : ""})',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: clientColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 4,
                              backgroundColor: isDark
                                  ? AppColors.cardBorderDark
                                  : Colors.grey.shade100,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(clientColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }(),
          const Divider(height: 20),

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
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _addNewDateEntryLogForEmployee(emp),
                        icon: const Icon(Icons.post_add_rounded, size: 18),
                        label: const Text('Create New Date Entry Log',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activePrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
                dateRecords.sort(
                    (a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

                final parsedDate = DateTime.parse(dateKey);
                final formattedDateStr =
                    DateFormat('EEEE, dd MMMM yyyy').format(parsedDate);

                final allValidGeofence =
                    dateRecords.every((r) => r.isGeofenceValid);
                final firstTime = DateFormat('hh:mm a')
                    .format(dateRecords.first.eventTimestamp.toLocal());

                final siteOutRecs = dateRecords
                    .where((r) => r.workflowStep == WorkflowStep.siteCheckOut);
                final officeOutRecs = dateRecords.where(
                    (r) => r.workflowStep == WorkflowStep.officeCheckOut);
                final endRecordTime = officeOutRecs.isNotEmpty
                    ? officeOutRecs.last.eventTimestamp
                    : (siteOutRecs.isNotEmpty
                        ? siteOutRecs.last.eventTimestamp
                        : dateRecords.last.eventTimestamp);
                final lastTime = DateFormat('hh:mm a').format(endRecordTime.toLocal());

                final siteCheckIns = dateRecords.where((r) =>
                    r.workflowStep == WorkflowStep.siteCheckIn ||
                    (r.siteName != null && r.siteName!.trim().isNotEmpty));
                final siteNamesStr = siteCheckIns.isNotEmpty
                    ? siteCheckIns
                        .map((r) => TimesheetCalculator.resolveSiteName(r))
                        .toSet()
                        .join(', ')
                    : null;

                final dayTimesheets =
                    TimesheetCalculator.calculateDailyTimesheets(dateRecords);
                final dayEntry =
                    dayTimesheets.isNotEmpty ? dayTimesheets.first : null;
                final dayReg = dayEntry?.regularHours ?? 0.0;
                final dayOt = dayEntry?.overtimeHours ?? 0.0;
                final dayBreakMin = dayEntry?.breakDuration.inMinutes ?? 0;

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
                        color: activePrimary.withValues(
                            alpha: isDark ? 0.2 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          color: activePrimary),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: activePrimary.withValues(
                                    alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${dayReg.toStringAsFixed(1)}h Reg',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: activePrimary),
                              ),
                            ),
                            if (dayOt > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: isDark
                                      ? Border.all(
                                          color: Colors.orange.shade800)
                                      : null,
                                ),
                                child: Text(
                                  '+${dayOt.toStringAsFixed(1)}h OT',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade900),
                                ),
                              ),
                            ],
                            if (dayBreakMin > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: isDark
                                      ? Border.all(color: Colors.amber.shade800)
                                      : null,
                                ),
                                child: Text(
                                  '☕ ${dayBreakMin}m Break',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade900),
                                ),
                              ),
                            ],
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
                                  size: 14,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '$firstTime - $lastTime (${dateRecords.length} Step Logs)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          // Date-Specific Site Hours Chips
                          () {
                            final dateSiteSummaries =
                                TimesheetCalculator.calculateSiteManHours(
                                    dateRecords);
                            if (dateSiteSummaries.isEmpty) {
                              if (siteNamesStr != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 3.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.place_rounded,
                                          size: 14, color: activePrimary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Sites: $siteNamesStr',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: activePrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 5.0, bottom: 2.0),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: dateSiteSummaries.map((s) {
                                  final col = _getClientColor(s.siteName);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: col.withValues(
                                          alpha: isDark ? 0.18 : 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: col.withValues(
                                              alpha: isDark ? 0.4 : 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_city_rounded,
                                            size: 12, color: col),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${s.siteName}: ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                        Text(
                                          '${s.totalHours.toStringAsFixed(1)}h',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: col,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }(),
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
                              if (dayEntry != null && dayEntry.isEdited) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.purple.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'ADMIN MODIFIED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                '${dateRecords.where((r) => r.photoBase64.isNotEmpty).length} Photo(s)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : Colors.grey),
                              )
                            ],
                          ),
                          if (dayEntry != null &&
                              dayEntry.remarks != null &&
                              dayEntry.remarks!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.note_alt_rounded,
                                    size: 13, color: Colors.purple.shade400),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Remarks: ${dayEntry.remarks}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : Colors.grey.shade800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
    final emp = _resolveEmployee(_selectedEmployeeId);

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    final dateRecords = _db.getAttendanceRecords().where((r) {
      final rEmpId = r.employeeId.trim().toLowerCase();
      final rEmpName = r.employeeName.trim().toLowerCase();
      final eId = emp.id.trim().toLowerCase();
      final eName = emp.name.trim().toLowerCase();
      final eCode = emp.employeeCode.trim().toLowerCase();
      final matchesUser = (eId.isNotEmpty && rEmpId == eId) ||
          (eName.isNotEmpty && rEmpName == eName) ||
          (eCode.isNotEmpty && rEmpId == eCode) ||
          (eId.length >= 4 && rEmpId.startsWith(eId)) ||
          (rEmpId.length >= 4 && eId.startsWith(rEmpId)) ||
          (eName.isNotEmpty &&
              (rEmpName.contains(eName) || eName.contains(rEmpName)));
      final matchesDate =
          DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal()) == selectedDateStr;
      return matchesUser && matchesDate;
    }).toList();

    dateRecords.sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    final formattedDateTitle =
        DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!);

    final dayTimesheets =
        TimesheetCalculator.calculateDailyTimesheets(dateRecords);
    double totalHrs = 0.0;
    double regHrs = 0.0;
    double otHrs = 0.0;
    int breakMin = 0;

    if (dayTimesheets.isNotEmpty) {
      final tEntry = dayTimesheets.first;
      regHrs = tEntry.regularHours;
      otHrs = tEntry.overtimeHours;
      totalHrs = tEntry.totalHours;
      breakMin = tEntry.breakDuration.inMinutes;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final activePrimary =
        palette.primaryFor(isDark ? Brightness.dark : Brightness.light);

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
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? palette.textSecondaryDark
                              : palette.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final tEntry = dayTimesheets.isNotEmpty ? dayTimesheets.first : null;
                  final ok = await AdminEditAttendanceDialog.show(
                    context,
                    employeeId: emp.id,
                    employeeName: emp.name,
                    date: _selectedDate!,
                    initialCheckIn: tEntry?.checkInTime,
                    initialCheckOut: tEntry?.checkOutTime,
                    initialOtHours: tEntry?.manualOvertimeHours ?? tEntry?.overtimeHours,
                    initialRemarks: tEntry?.remarks,
                  );
                  if (ok == true && mounted) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                label: const Text('Adjust Shift & OT',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activePrimary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: activePrimary.withValues(alpha: 0.4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Daily Timesheet Breakdown Card (Regular, OT, Break, Combined)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? palette.surfaceDark
                  : activePrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? palette.cardBorderDark
                    : activePrimary.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_rounded, color: activePrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Daily Timesheet Hours Summary',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: activePrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: activePrimary.withValues(
                              alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Regular',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: activePrimary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${regHrs.toStringAsFixed(1)}h',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: activePrimary)),
                            Text('Max 8.0h',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    color: isDark
                                        ? palette.textSecondaryDark
                                        : Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: otHrs > 0
                              ? (isDark
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : Colors.orange.shade100)
                              : (isDark
                                  ? AppColors.backgroundDark
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10),
                          border: otHrs > 0 && isDark
                              ? Border.all(color: Colors.orange.shade800)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overtime',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: otHrs > 0
                                        ? (isDark
                                            ? Colors.orange.shade300
                                            : Colors.orange.shade900)
                                        : (isDark
                                            ? AppColors.textSecondaryDark
                                            : Colors.grey.shade700),
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('+${otHrs.toStringAsFixed(1)}h',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: otHrs > 0
                                        ? (isDark
                                            ? Colors.orange.shade300
                                            : Colors.orange.shade900)
                                        : (isDark
                                            ? AppColors.textSecondaryDark
                                            : Colors.grey.shade700))),
                            Text('Beyond 10.0h',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    if (breakMin > 0) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.amber.shade800
                                  : Colors.amber.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Break',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade900,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${breakMin}m',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade900)),
                              Text('Excluded',
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Net Time',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${totalHrs.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.success)),
                            Text('Reg + OT',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Daily Site / Client Hours Breakdown Card
          () {
            final daySiteSummaries =
                TimesheetCalculator.calculateSiteManHours(dateRecords);
            if (daySiteSummaries.isEmpty) return const SizedBox.shrink();

            final totalDaySiteHrs =
                daySiteSummaries.fold(0.0, (acc, s) => acc + s.totalHours);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? palette.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? palette.cardBorderDark : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 6,
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: activePrimary.withValues(
                                  alpha: isDark ? 0.2 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.location_city_rounded,
                                color: activePrimary, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Site-Wise Hours Spent on this Date',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? palette.textPrimaryDark
                                  : palette.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: activePrimary.withValues(
                              alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${totalDaySiteHrs.toStringAsFixed(1)} Site Hrs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: activePrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...daySiteSummaries.map((s) {
                    final clientColor = _getClientColor(s.siteName);
                    final pct = totalHrs > 0
                        ? (s.totalHours / totalHrs).clamp(0.0, 1.0)
                        : (totalDaySiteHrs > 0
                            ? (s.totalHours / totalDaySiteHrs).clamp(0.0, 1.0)
                            : 0.0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: clientColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        s.siteName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? palette.textPrimaryDark
                                              : palette.textPrimaryLight,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color:
                                            clientColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        s.clientGroup,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: clientColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${s.totalHours.toStringAsFixed(1)} hrs (${(pct * 100).toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: clientColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5,
                              backgroundColor: isDark
                                  ? palette.cardBorderDark
                                  : Colors.grey.shade100,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(clientColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }(),

          // Date Summary Banner
          Builder(
            builder: (context) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? palette.surfaceDark : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isDark ? palette.cardBorderDark : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_rounded,
                        color: activePrimary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Workflow Steps Logged: ${dateRecords.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? palette.textPrimaryDark
                                  : palette.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All steps verified via live front camera & GPS geofencing',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? palette.textSecondaryDark
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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
                final timeStr =
                    DateFormat('hh:mm:ss a').format(r.eventTimestamp.toLocal());

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
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight),
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
                            Icon(Icons.location_on_rounded,
                                size: 18, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TimesheetCalculator.resolveSiteName(r),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight),
                                  ),
                                  const SizedBox(height: 2),
                                  if (kIsWeb ||
                                      MediaQuery.of(context).size.width >
                                          600) ...[
                                    Text(
                                      'Address: ${TimesheetCalculator.resolveFullAddress(r)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    'GPS Coordinates: ${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)} (Accuracy: ${r.gpsAccuracy.toStringAsFixed(1)}m)',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Site Name & Photo Section
                        () {
                          final String siteNameText =
                              TimesheetCalculator.resolveSiteName(r);

                          final hasPhoto = r.photoBase64.trim().isNotEmpty;

                          if (hasPhoto) {
                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.backgroundDark
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.cardBorderDark
                                      : Colors.grey.shade300,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.camera_alt_rounded,
                                          size: 16, color: activePrimary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Verified Live Camera Snapshot',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: activePrimary),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: activePrimary.withValues(
                                              alpha: isDark ? 0.2 : 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.place_rounded,
                                                size: 12, color: activePrimary),
                                            const SizedBox(width: 3),
                                            Text(
                                              siteNameText,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: activePrimary),
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
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border:
                                              Border.all(color: activePrimary),
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
                                color: isDark
                                    ? palette.backgroundDark
                                    : activePrimary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? palette.cardBorderDark
                                      : activePrimary.withValues(alpha: 0.18),
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: activePrimary.withValues(
                                          alpha: isDark ? 0.2 : 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.place_rounded,
                                      size: 22,
                                      color: activePrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Job Site / Location',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? palette.textSecondaryDark
                                                : palette.textSecondaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          siteNameText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: activePrimary,
                                          ),
                                        ),
                                        if (r.address.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            r.address,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? palette.textSecondaryDark
                                                  : Colors.grey.shade700,
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
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Icon(Icons.cloud_done_rounded,
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
  Widget _buildPhotoWidget(String photoBase64) {
    final cleanPhoto = photoBase64.trim();
    if (cleanPhoto.isEmpty) {
      return Container(
        color: Colors.blueGrey.shade800,
        child: const Center(
          child: Icon(Icons.person_pin, size: 65, color: Colors.white70),
        ),
      );
    }

    try {
      if (cleanPhoto.startsWith('http://') ||
          cleanPhoto.startsWith('https://')) {
        return Image.network(
          cleanPhoto,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.blueGrey.shade800,
              child: const Center(
                child: Icon(Icons.broken_image_rounded,
                    size: 50, color: Colors.white70),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.blueGrey.shade900,
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70),
              ),
            );
          },
        );
      }

      if (!kIsWeb && File(cleanPhoto).existsSync()) {
        return Image.file(File(cleanPhoto), fit: BoxFit.cover);
      }

      String base64Str = cleanPhoto;
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',').last;
      }
      base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');

      final decodedBytes = base64Decode(base64Str);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                'Timestamp: ${DateFormat('dd MMM yyyy hh:mm:ss a').format(record.eventTimestamp.toLocal())}',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Location: ${TimesheetCalculator.resolveSiteName(record)} (${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)})',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
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
      case WorkflowStep.breakStart:
        return Icons.coffee_rounded;
      case WorkflowStep.breakEnd:
        return Icons.play_arrow_rounded;
      case WorkflowStep.officeCheckOut:
        return Icons.logout_rounded;
      case WorkflowStep.completed:
        return Icons.check_circle_rounded;
    }
  }

  Color _getStepColor(WorkflowStep step) {
    final palette = AppTheme.currentColors;
    switch (step) {
      case WorkflowStep.officeCheckIn:
        return palette.success;
      case WorkflowStep.siteCheckIn:
        return palette.primaryLight;
      case WorkflowStep.siteCheckOut:
        return palette.warning;
      case WorkflowStep.breakStart:
        return Colors.amber.shade800;
      case WorkflowStep.breakEnd:
        return Colors.teal.shade700;
      case WorkflowStep.officeCheckOut:
        return palette.secondary;
      case WorkflowStep.completed:
        return palette.success;
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
        final rEmpId = r.employeeId.trim().toLowerCase();
        final rEmpName = r.employeeName.trim().toLowerCase();
        final eId = emp.id.trim().toLowerCase();
        final eName = emp.name.trim().toLowerCase();
        final eCode = emp.employeeCode.trim().toLowerCase();
        return (eId.isNotEmpty && rEmpId == eId) ||
            (eName.isNotEmpty && rEmpName == eName) ||
            (eCode.isNotEmpty && rEmpId == eCode) ||
            (eId.length >= 4 && rEmpId.startsWith(eId)) ||
            (rEmpId.length >= 4 && eId.startsWith(rEmpId)) ||
            (eName.isNotEmpty &&
                (rEmpName.contains(eName) || eName.contains(rEmpName)));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final activePrimary =
        palette.primaryFor(isDark ? Brightness.dark : Brightness.light);
    final activeSecondary = palette.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive Grand Total Summary Cards
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? palette.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? palette.cardBorderDark : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                        Icon(Icons.summarize_rounded,
                            size: 18, color: activePrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Workforce Cumulative Summary',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? palette.textPrimaryDark
                                      : palette.textPrimaryLight,
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
                    onPressed: () =>
                        _exportCumulativePdf(employees, allRecords),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Download PDF',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                      color: activePrimary,
                      icon: Icons.access_time_filled_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: 'Overtime OT',
                      value: '+${grandOt.toStringAsFixed(1)}h',
                      color: Colors.orange.shade800,
                      icon: Icons.more_time_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: 'Combined Total',
                      value: '${grandCombined.toStringAsFixed(1)}h',
                      color: activeSecondary,
                      icon: Icons.av_timer_rounded,
                      isDark: isDark,
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
                            backgroundColor: activePrimary,
                            child: Text(
                              item.employee.name.isNotEmpty
                                  ? item.employee.name
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'E',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.employee.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.employee.employeeCode} • ${item.employee.department}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? palette.textSecondaryDark
                                          : palette.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: activePrimary.withValues(
                                  alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.daysWorked} Days',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: activePrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Metrics Cards Grid (Regular, OT, Combined)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? palette.backgroundDark
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? palette.cardBorderDark
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildEmpMetricItem(
                              title: 'Regular Hours',
                              value:
                                  '${item.regularHours.toStringAsFixed(1)} hrs',
                              color: activePrimary,
                              isDark: isDark,
                            ),
                            Container(
                                width: 1,
                                height: 28,
                                color: isDark
                                    ? palette.cardBorderDark
                                    : Colors.grey.shade300),
                            _buildEmpMetricItem(
                              title: 'OT Hours',
                              value:
                                  '+${item.overtimeHours.toStringAsFixed(1)} hrs',
                              color: Colors.orange.shade800,
                              isDark: isDark,
                            ),
                            Container(
                                width: 1,
                                height: 28,
                                color: isDark
                                    ? palette.cardBorderDark
                                    : Colors.grey.shade300),
                            _buildEmpMetricItem(
                              title: 'Combined Total',
                              value:
                                  '${item.combinedHours.toStringAsFixed(1)} hrs',
                              color: activeSecondary,
                              isBold: true,
                              isDark: isDark,
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(activePrimary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Regular: ${(regPercent * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey.shade600),
                            ),
                            if (item.overtimeHours > 0)
                              Text(
                                'OT: ${((1 - regPercent) * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Site-Wise Hours Spent Section for Employee
                      () {
                        final empRecs = allRecords
                            .where((r) =>
                                r.employeeId == emp.id ||
                                r.employeeName.toLowerCase() ==
                                    emp.name.toLowerCase())
                            .toList();
                        final empSiteBreakdown =
                            TimesheetCalculator.calculateSiteManHours(empRecs);
                        if (empSiteBreakdown.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final totalSiteTime = empSiteBreakdown.fold(
                            0.0, (acc, s) => acc + s.totalHours);

                        return Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.backgroundDark
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.cardBorderDark
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.location_city_rounded,
                                          size: 14,
                                          color: isDark
                                              ? AppColors.primaryLight
                                              : AppColors.primary),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Site Hours Spent:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: (isDark
                                              ? AppColors.primaryLight
                                              : AppColors.primary)
                                          .withValues(
                                              alpha: isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${totalSiteTime.toStringAsFixed(1)} Site Hrs',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.primaryLight
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: empSiteBreakdown.map((s) {
                                  final col = _getClientColor(s.siteName);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: col.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: col.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: col,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${s.siteName}: ',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: col,
                                          ),
                                        ),
                                        Text(
                                          '${s.totalHours.toStringAsFixed(1)}h',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }(),

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
                            foregroundColor: isDark
                                ? AppColors.primaryLight
                                : AppColors.primary,
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
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
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
              color:
                  isDark ? AppColors.textSecondaryDark : Colors.grey.shade700,
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
    bool isDark = false,
  }) {
    return Flexible(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color:
                  isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
            ),
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

  // ==========================================
  // LEVEL 1 TAB 3: SITE / CLIENT MAN-HOURS VIEW
  // ==========================================
  Widget _buildSiteManHoursView(List<AttendanceRecord> allRecords) {
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    if (_siteDateFilter == 'today') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_siteDateFilter == 'week') {
      startDate = now.subtract(const Duration(days: 7));
      endDate = now;
    } else if (_siteDateFilter == 'month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = now;
    }

    final siteSummaries = TimesheetCalculator.calculateSiteManHours(
      allRecords,
      startDate: startDate,
      endDate: endDate,
      groupByClient: _siteGroupByClient,
    );

    final filteredSummaries = siteSummaries.where((s) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return s.siteName.toLowerCase().contains(q) ||
          s.clientGroup.toLowerCase().contains(q) ||
          s.employeeContributions
              .any((e) => e.employeeName.toLowerCase().contains(q));
    }).toList();

    final grandTotalHours =
        filteredSummaries.fold(0.0, (acc, s) => acc + s.totalHours);
    final grandTotalVisits =
        filteredSummaries.fold(0, (acc, s) => acc + s.totalVisits);
    final totalPersonnel = filteredSummaries
        .expand((s) => s.employeeContributions.map((e) => e.employeeId))
        .toSet()
        .length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final activePrimary =
        palette.primaryFor(isDark ? Brightness.dark : Brightness.light);
    final activeSecondary = palette.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Executive Summary KPI Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? palette.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? palette.cardBorderDark : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.apartment_rounded,
                            size: 18, color: activePrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _siteGroupByClient
                                ? 'Client Man-Hours Overview'
                                : 'Site & Project Man-Hours Overview',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? palette.textPrimaryDark
                                      : palette.textPrimaryLight,
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
                    onPressed: () => _exportSiteManHoursPdf(
                      allRecords,
                      startDate: startDate,
                      endDate: endDate,
                      groupByClient: _siteGroupByClient,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Download PDF',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                      label: 'Total Man-Hours',
                      value: '${grandTotalHours.toStringAsFixed(1)}h',
                      color: activePrimary,
                      icon: Icons.timer_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: _siteGroupByClient ? 'Clients' : 'Sites/Projects',
                      value: '${filteredSummaries.length}',
                      color: Colors.teal.shade800,
                      icon: Icons.location_city_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: 'Total Visits',
                      value: '$grandTotalVisits',
                      color: Colors.orange.shade800,
                      icon: Icons.pin_drop_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryMetricBadge(
                      label: 'Field Staff',
                      value: '$totalPersonnel',
                      color: activeSecondary,
                      icon: Icons.groups_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Controls: Date Filter Pills & Grouping Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? palette.surfaceDark : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? palette.cardBorderDark : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              // Date Filter Row
              Row(
                children: [
                  Icon(Icons.date_range_rounded,
                      size: 16,
                      color: isDark
                          ? palette.textSecondaryDark
                          : palette.textSecondaryLight),
                  const SizedBox(width: 6),
                  Text('Period:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? palette.textSecondaryDark
                              : palette.textSecondaryLight)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDateFilterChip('All Time', 'all', isDark),
                          const SizedBox(width: 6),
                          _buildDateFilterChip('This Month', 'month', isDark),
                          const SizedBox(width: 6),
                          _buildDateFilterChip('This Week', 'week', isDark),
                          const SizedBox(width: 6),
                          _buildDateFilterChip('Today', 'today', isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: 12,
                color: isDark ? palette.cardBorderDark : Colors.grey.shade300,
              ),

              // Grouping Toggle Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                          _siteGroupByClient
                              ? Icons.category_rounded
                              : Icons.list_alt_rounded,
                          size: 16,
                          color: activePrimary),
                      const SizedBox(width: 6),
                      Text(
                        _siteGroupByClient
                            ? 'Mode: Grouped by Client'
                            : 'Mode: Detailed Sites',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Detailed',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? palette.textSecondaryDark
                                  : Colors.grey)),
                      Switch.adaptive(
                        value: _siteGroupByClient,
                        activeTrackColor: activePrimary,
                        activeThumbColor: Colors.white,
                        onChanged: (val) {
                          setState(() => _siteGroupByClient = val);
                        },
                      ),
                      Text('By Client',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: activePrimary)),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Visual Proportion Split Distribution
        if (grandTotalHours > 0 && filteredSummaries.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? palette.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? palette.cardBorderDark : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Man-Hours Share Distribution',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark
                              ? palette.textPrimaryDark
                              : palette.textPrimaryLight),
                    ),
                    Text(
                      'Total ${grandTotalHours.toStringAsFixed(1)} hrs',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: activePrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: filteredSummaries.map((s) {
                        final ratio = s.totalHours / grandTotalHours;
                        final color = _getClientColor(s.clientGroup);
                        return Expanded(
                          flex: (ratio * 1000).toInt().clamp(1, 1000),
                          child: Container(color: color),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: filteredSummaries.take(6).map((s) {
                    final color = _getClientColor(s.clientGroup);
                    final pct = (s.totalHours / grandTotalHours * 100)
                        .toStringAsFixed(0);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('${s.siteName}: $pct%',
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w500)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // List of Site Man-Hour Cards
        if (filteredSummaries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                    'No site check-in logs or man-hours recorded for this period.'),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSummaries.length,
            itemBuilder: (context, index) {
              final item = filteredSummaries[index];
              final clientColor = _getClientColor(item.clientGroup);
              final pctOfTotal = grandTotalHours > 0
                  ? (item.totalHours / grandTotalHours).clamp(0.0, 1.0)
                  : 0.0;
              final isExpanded = _expandedSiteKeys.contains(item.siteName);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: clientColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.business_center_rounded,
                                color: clientColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.siteName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            clientColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: clientColor.withValues(
                                                alpha: 0.2)),
                                      ),
                                      child: Text(
                                        item.clientGroup,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: clientColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.totalVisits} Visit(s) • ${item.distinctEmployeesCount} Staff Member(s)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Metrics Row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.backgroundDark
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.cardBorderDark
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                const Text('Total Time:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(width: 4),
                                Text(
                                  '${item.totalHours.toStringAsFixed(1)} hrs',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: clientColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(pctOfTotal * 100).toStringAsFixed(1)}% of all field hours',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: clientColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pctOfTotal,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? AppColors.cardBorderDark
                              : Colors.grey.shade100,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(clientColor),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Expand / Collapse Staff Breakdown
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedSiteKeys.remove(item.siteName);
                            } else {
                              _expandedSiteKeys.add(item.siteName);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isExpanded
                                    ? 'Hide Staff Details'
                                    : 'View Contributing Personnel (${item.employeeContributions.length})',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: clientColor),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: clientColor,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (isExpanded) ...[
                        Divider(
                          height: 16,
                          color: isDark
                              ? AppColors.cardBorderDark
                              : Colors.grey.shade300,
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: item.employeeContributions.length,
                          itemBuilder: (ctx, eIdx) {
                            final emp = item.employeeContributions[eIdx];
                            final empPct = item.totalHours > 0
                                ? (emp.totalHours / item.totalHours)
                                    .clamp(0.0, 1.0)
                                : 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.backgroundDark
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.cardBorderDark
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: clientColor,
                                    child: Text(
                                      emp.employeeName.isNotEmpty
                                          ? emp.employeeName
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : 'E',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emp.employeeName,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${emp.employeeCode} • ${emp.department} • ${emp.visitCount} visit(s)',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${emp.totalHours.toStringAsFixed(1)} hrs',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: clientColor),
                                      ),
                                      Text(
                                        '${(empPct * 100).toStringAsFixed(0)}% of site',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : Colors.grey.shade600),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDateFilterChip(String label, String value,
      [bool isDark = false]) {
    final palette = AppTheme.currentColors;
    final activePrimary =
        palette.primaryFor(isDark ? Brightness.dark : Brightness.light);
    final isSelected = _siteDateFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _siteDateFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activePrimary
              : (isDark ? palette.backgroundDark : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activePrimary
                : (isDark ? palette.cardBorderDark : Colors.transparent),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? palette.textPrimaryDark : Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Color _getClientColor(String clientGroup) {
    final upper = clientGroup.toUpperCase();
    if (upper.contains('REELAM') || upper.contains('RELAAM')) {
      return const Color(0xFF00897B); // Teal
    } else if (upper.contains('CARRIER')) {
      return const Color(0xFF1E88E5); // Blue
    } else if (upper.contains('MOPA')) {
      return const Color(0xFF5E35B1); // Deep Purple
    } else if (upper.contains('MPM')) {
      return const Color(0xFFFB8C00); // Amber / Dark Orange
    } else if (upper.contains('ELV')) {
      return const Color(0xFF8E24AA); // Purple
    } else if (upper.contains('OTHERS')) {
      return const Color(0xFF546E7A); // Blue Grey
    }
    return AppTheme.currentColors.primaryLight;
  }

  Future<void> _exportSiteManHoursPdf(
    List<AttendanceRecord> records, {
    DateTime? startDate,
    DateTime? endDate,
    bool groupByClient = false,
  }) async {
    try {
      await PdfExportService.downloadSiteManHoursPdfFile(
        organizationName: _db.organization?.name ?? 'Fusion Enterprise',
        records: records,
        startDate: startDate,
        endDate: endDate,
        groupByClient: groupByClient,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Site & Client Man-Hours PDF report ready for download/saving!'),
            backgroundColor:
                AppTheme.currentColors.primaryFor(Theme.of(context).brightness),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading Site PDF: $e');
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
