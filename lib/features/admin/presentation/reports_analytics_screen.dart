import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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
import '../../timesheet/domain/timesheet_entry.dart';
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
  int _employeeRecordFilterTab =
      0; // 0 = With Records, 1 = No Records
  int _empDetailSubTab =
      0; // 0 = Attendance & Timesheet Logs, 1 = Emergency Duty Details
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
        final currentLocal = _db.getEmployees();
        final Map<String, EmployeeEntity> merged = {};
        for (final ce in cloudEmployees) {
          merged[ce.id] = ce;
        }
        for (final le in currentLocal) {
          if (!merged.containsKey(le.id) &&
              !merged.values.any((e) =>
                  (le.email.isNotEmpty && e.email.toLowerCase() == le.email.toLowerCase()) ||
                  (le.name.isNotEmpty && e.name.toLowerCase() == le.name.toLowerCase()))) {
            merged[le.id] = le;
          }
        }
        _db.setEmployees(merged.values.toList());
      }

      // Consolidate any duplicate/phantom 'Anand' records into Anandh Veeramani
      await _db.sanitizeDuplicateEmployees();
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
        // Aliases: match 'Anand' or 'emp-anan' to 'Anandh Veeramani'
        if ((name.trim().toLowerCase() == 'anand' || id.toLowerCase() == 'emp-anan') &&
            (e.name.toLowerCase().contains('anandh') || e.email.toLowerCase() == 'anand@gmail.com')) {
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

      // Special alias: if record is tagged as 'anand' or 'emp-anan', map it to Anandh Veeramani
      final isAnandhAlias = (nameKey == 'anand' || idKey.toLowerCase() == 'emp-anan' || idKey.toLowerCase() == 'anand') &&
          employeeMap.values.any((e) =>
              e.name.toLowerCase().contains('anandh') ||
              e.email.toLowerCase() == 'anand@gmail.com');

      bool alreadyExists = isAnandhAlias || employeeMap.values.any((e) =>
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

    final list = employeeMap.values.where((e) {
      final eName = e.name.trim().toLowerCase();
      final eCode = e.employeeCode.trim().toUpperCase();
      // Completely remove phantom 'Anand' / 'EMP-ANAN' if 'Anandh Veeramani' is present
      if ((eName == 'anand' || eCode == 'EMP-ANAN') &&
          employeeMap.values.any((other) =>
              other.name.trim().toLowerCase().contains('anandh') ||
              other.email.trim().toLowerCase() == 'anand@gmail.com')) {
        return false;
      }
      return true;
    }).toList();
    list.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
    return list;
  }

  bool _recordMatchesEmployee(AttendanceRecord r, EmployeeEntity emp) {
    final rEmpId = r.employeeId.trim().toLowerCase();
    final rEmpName = r.employeeName.trim().toLowerCase();
    final eId = emp.id.trim().toLowerCase();
    final eName = emp.name.trim().toLowerCase();
    final eCode = emp.employeeCode.trim().toLowerCase();

    // 1. Match by exact ID
    if (eId.isNotEmpty && rEmpId.isNotEmpty && rEmpId == eId) {
      return true;
    }

    // 2. Match by Employee Code (exact)
    if (eCode.isNotEmpty && rEmpId.isNotEmpty && rEmpId == eCode) {
      return true;
    }

    // 3. Match by Name (exact match only - prevents partial string matches like krishnan vs ramakrishnan)
    if (eName.isNotEmpty && rEmpName.isNotEmpty && rEmpName == eName) {
      return true;
    }

    // 4. Anandh Veeramani alias matching for records logged under 'Anand' or 'emp-anan'
    if (eName.contains('anandh') || emp.email.trim().toLowerCase() == 'anand@gmail.com' || eCode == 'emp-ana') {
      if (rEmpName == 'anand' || rEmpId == 'emp-anan' || rEmpId == 'anand') {
        return true;
      }
    }

    return false;
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

    // If resolving 'anand' or 'emp-anan', resolve directly to Anandh Veeramani
    if (cleanId == 'anand' || cleanId == 'emp-anan') {
      final anandh = all.where((e) =>
          e.name.toLowerCase().contains('anandh') ||
          e.email.toLowerCase() == 'anand@gmail.com');
      if (anandh.isNotEmpty) return anandh.first;
    }

    // Exact matches by ID, code, name, or email
    final exactMatch = all.where((e) =>
        (e.id.isNotEmpty && e.id.toLowerCase() == cleanId) ||
        (e.employeeCode.isNotEmpty && e.employeeCode.toLowerCase() == cleanId) ||
        (e.name.isNotEmpty && e.name.toLowerCase().trim() == cleanId) ||
        (e.email.isNotEmpty && e.email.toLowerCase().trim() == cleanId));
    if (exactMatch.isNotEmpty) return exactMatch.first;

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

    // Segregate filtered employees into With Records vs No Records
    final employeesWithRecords = <MapEntry<EmployeeEntity, int>>[];
    final employeesWithoutRecords = <EmployeeEntity>[];

    for (final emp in filteredEmployees) {
      final empRecords = allRecords
          .where((r) => _recordMatchesEmployee(r, emp))
          .toList();
      final datesCount = empRecords
          .map((r) =>
              DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal()))
          .toSet()
          .length;

      if (datesCount > 0) {
        employeesWithRecords.add(MapEntry(emp, datesCount));
      } else {
        employeesWithoutRecords.add(emp);
      }
    }

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
            // 2 Segregation Tabs: With Records vs No Records
            AppAnimatedTabSwitcher(
              selectedIndex: _employeeRecordFilterTab,
              tabs: [
                TabItemData(
                  label: 'With Records (${employeesWithRecords.length})',
                  icon: Icons.assignment_turned_in_rounded,
                ),
                TabItemData(
                  label: 'No Records (${employeesWithoutRecords.length})',
                  icon: Icons.history_toggle_off_rounded,
                ),
              ],
              onTabChanged: (index) =>
                  setState(() => _employeeRecordFilterTab = index),
            ),
            const SizedBox(height: 16),

            if (_employeeRecordFilterTab == 0) ...[
              if (employeesWithRecords.isEmpty)
                Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final palette = AppTheme.currentColors;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark
                              ? palette.cardBorderDark
                              : Colors.grey.shade300,
                        ),
                      ),
                      elevation: 0,
                      color: isDark ? palette.surfaceDark : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 36),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assignment_late_outlined,
                                size: 48,
                                color: isDark
                                    ? palette.textSecondaryDark
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Employees with Attendance Records',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? palette.textPrimaryDark
                                      : palette.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No matching employees with records found for "$_searchQuery".'
                                    : 'None of the registered employees have attendance records logged yet.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? palette.textSecondaryDark
                                      : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: employeesWithRecords.length,
                  itemBuilder: (context, index) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final palette = AppTheme.currentColors;
                    final activePrimary = palette
                        .primaryFor(isDark ? Brightness.dark : Brightness.light);
                    final entry = employeesWithRecords[index];
                    final emp = entry.key;
                    final datesCount = entry.value;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? palette.cardBorderDark
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      elevation: 1,
                      color: isDark ? palette.surfaceDark : Colors.white,
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Department: ${emp.department.isNotEmpty ? emp.department : 'General'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? palette.textSecondaryDark
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(
                                      alpha: isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 13,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$datesCount Attendance Date(s) Logged',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
              if (employeesWithoutRecords.isEmpty)
                Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final palette = AppTheme.currentColors;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark
                              ? palette.cardBorderDark
                              : Colors.grey.shade300,
                        ),
                      ),
                      elevation: 0,
                      color: isDark ? palette.surfaceDark : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 36),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'All Employees Have Attendance Records',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? palette.textPrimaryDark
                                      : palette.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No pending employees found for "$_searchQuery".'
                                    : 'Every registered employee currently has attendance logs recorded.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? palette.textSecondaryDark
                                      : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: employeesWithoutRecords.length,
                  itemBuilder: (context, index) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final palette = AppTheme.currentColors;
                    final activePrimary = palette
                        .primaryFor(isDark ? Brightness.dark : Brightness.light);
                    final emp = employeesWithoutRecords[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? palette.cardBorderDark
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      elevation: 1,
                      color: isDark ? palette.surfaceDark : Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade400,
                          child: Text(
                            emp.name.isNotEmpty
                                ? emp.name.substring(0, 1).toUpperCase()
                                : 'E',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                emp.employeeCode,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Department: ${emp.department.isNotEmpty ? emp.department : 'General'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? palette.textSecondaryDark
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(
                                      alpha: isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off_rounded,
                                      size: 13,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'No Attendance Recorded',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _addNewDateEntryLogForEmployee(emp),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Log',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: activePrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 16, color: AppColors.textSecondaryLight),
                          ],
                        ),
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
            ],
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

  Widget _buildMisattributedLogsBanner(EmployeeEntity currentEmp, List<AttendanceRecord> records) {
    final users = _db.getUsers();
    final suspiciousRecords = <AttendanceRecord>[];
    String? detectedOwnerName;
    String? detectedOwnerId;

    for (final r in records) {
      if (r.deviceId.startsWith('device-hw-')) {
        final rawUid = r.deviceId.substring('device-hw-'.length);
        final match = users.where((u) => u.id == rawUid || (u.firebaseUid.isNotEmpty && u.firebaseUid == rawUid));
        if (match.isNotEmpty &&
            match.first.fullName.trim().toLowerCase() != currentEmp.name.trim().toLowerCase()) {
          suspiciousRecords.add(r);
          detectedOwnerName ??= match.first.fullName;
          detectedOwnerId ??= match.first.id;
        }
      }
    }

    if (suspiciousRecords.isEmpty || detectedOwnerName == null || detectedOwnerId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Misattributed Logs Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${suspiciousRecords.length} log(s) appear to have been captured from $detectedOwnerName\'s account instead of ${currentEmp.name}.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () async {
              final count = await _db.reassignEmployeeAttendanceRecords(
                fromEmployeeId: currentEmp.id,
                fromEmployeeName: currentEmp.name,
                toEmployeeId: detectedOwnerId!,
                toEmployeeName: detectedOwnerName!,
              );
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully transferred $count log(s) to $detectedOwnerName!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text('Transfer to $detectedOwnerName'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReassignRecordsDialog(EmployeeEntity sourceEmp, List<AttendanceRecord> records) async {
    final allEmployees = _getSynthesizedEmployees()
        .where((e) => e.id != sourceEmp.id && e.name.trim().toLowerCase() != sourceEmp.name.trim().toLowerCase())
        .toList();

    if (allEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other employee available to reassign records to.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String targetEmpId = allEmployees.first.id;
    String? selectedDateStr;

    final Set<String> dateStrs = {};
    for (final r in records) {
      dateStrs.add(DateFormat('yyyy-MM-dd').format(r.eventTimestamp.toLocal()));
    }
    final sortedDates = dateStrs.toList()..sort((a, b) => b.compareTo(a));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = AppTheme.currentColors;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? palette.surfaceDark : Colors.white,
            title: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.indigo.shade700),
                const SizedBox(width: 10),
                const Text('Reassign Attendance Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reassign attendance logs from ${sourceEmp.name} to another employee:',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                const Text('Target Employee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: targetEmpId,
                      isExpanded: true,
                      items: allEmployees.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.id,
                          child: Text('${e.name} (${e.employeeCode})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => targetEmpId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Date Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedDateStr,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Dates (All ${records.length} records)'),
                        ),
                        ...sortedDates.map((d) {
                          DateTime parsed = DateTime.parse(d);
                          return DropdownMenuItem<String?>(
                            value: d,
                            child: Text(DateFormat('dd MMM yyyy (EEEE)').format(parsed)),
                          );
                        }),
                      ],
                      onChanged: (val) => setDlgState(() => selectedDateStr = val),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white),
                child: const Text('Confirm & Reassign'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      final targetEmp = allEmployees.firstWhere((e) => e.id == targetEmpId);
      final count = await _db.reassignEmployeeAttendanceRecords(
        fromEmployeeId: sourceEmp.id,
        fromEmployeeName: sourceEmp.name,
        toEmployeeId: targetEmp.id,
        toEmployeeName: targetEmp.name,
        specificDate: selectedDateStr != null ? DateTime.parse(selectedDateStr!) : null,
      );

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully reassigned $count record(s) to ${targetEmp.name}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildLevel2DateListView() {
    final emp = _resolveEmployee(_selectedEmployeeId);

    final empRecords = _db
        .getAttendanceRecords()
        .where((r) => _recordMatchesEmployee(r, emp))
        .toList();

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
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => _showReassignRecordsDialog(emp, empRecords),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Reassign Logs',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Misattributed logs detection banner
          _buildMisattributedLogsBanner(emp, empRecords),

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

          const SizedBox(height: 4),
          // Sub-Tab Navigation Bar: Attendance & Timesheet Logs vs Emergency Duty Details
          AppAnimatedTabSwitcher(
            selectedIndex: _empDetailSubTab,
            tabs: const [
              TabItemData(
                label: 'Attendance & Timesheet Logs',
                icon: Icons.calendar_month_rounded,
              ),
              TabItemData(
                label: 'Emergency Duty Details',
                icon: Icons.warning_amber_rounded,
              ),
            ],
            onTabChanged: (index) {
              setState(() {
                _empDetailSubTab = index;
              });
            },
          ),
          const SizedBox(height: 12),

          if (_empDetailSubTab == 1)
            _buildEmergencyDutyDetailsView(
              emp,
              empRecords,
              timesheets,
              totalOtHours,
              isDark,
              palette,
              activePrimary,
            )
          else ...[
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
        ],
      ),
    );
  }

  Widget _buildEmergencyDutyDetailsView(
    EmployeeEntity emp,
    List<AttendanceRecord> empRecords,
    List<DailyTimesheetEntry> timesheets,
    double totalOtHours,
    bool isDark,
    dynamic palette,
    Color activePrimary,
  ) {
    // Calculate Emergency Duty OT vs Other OT
    double totalEmergencyOt = 0.0;
    for (final t in timesheets) {
      totalEmergencyOt += t.emergencyDutyHours;
    }
    double totalOtherOt = (totalOtHours - totalEmergencyOt);
    if (totalOtherOt < 0) totalOtherOt = 0.0;

    // Filter Emergency Duty Records
    final emergencyRecords = empRecords.where((r) {
      return r.workflowStep == WorkflowStep.emergencyCheckIn ||
          r.workflowStep == WorkflowStep.emergencyCheckOut;
    }).toList();
    emergencyRecords.sort((a, b) => b.eventTimestamp.compareTo(a.eventTimestamp));

    // Pair Emergency Sessions
    final List<Map<String, dynamic>> emergencySessions = [];
    final List<AttendanceRecord> checkIns = emergencyRecords
        .where((r) => r.workflowStep == WorkflowStep.emergencyCheckIn)
        .toList()
      ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    final List<AttendanceRecord> checkOuts = emergencyRecords
        .where((r) => r.workflowStep == WorkflowStep.emergencyCheckOut)
        .toList()
      ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

    final Set<String> pairedCheckoutIds = {};

    for (final inRec in checkIns) {
      AttendanceRecord? outRec;
      for (final o in checkOuts) {
        if (!pairedCheckoutIds.contains(o.id) &&
            o.eventTimestamp.isAfter(inRec.eventTimestamp)) {
          if (outRec == null ||
              o.eventTimestamp.isBefore(outRec.eventTimestamp)) {
            outRec = o;
          }
        }
      }
      if (outRec != null) {
        pairedCheckoutIds.add(outRec.id);
      }
      double durationHrs = 0.0;
      if (outRec != null) {
        durationHrs =
            outRec.eventTimestamp.difference(inRec.eventTimestamp).inMinutes /
                60.0;
      }
      emergencySessions.add({
        'in': inRec,
        'out': outRec,
        'durationHrs': durationHrs,
      });
    }

    // Sort sessions latest first
    emergencySessions.sort((a, b) {
      final aTime = (a['in'] as AttendanceRecord).eventTimestamp;
      final bTime = (b['in'] as AttendanceRecord).eventTimestamp;
      return bTime.compareTo(aTime);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. OT Breakdown Metric Banner / Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? palette.surfaceDark
                : Colors.orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? palette.cardBorderDark : Colors.orange.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Overtime (OT) Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? palette.textPrimaryDark
                          : palette.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Emergency Duty OT Tile
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.surfaceDark : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.red.shade900
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Emergency OT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${totalEmergencyOt.toStringAsFixed(1)} hrs',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('+',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey)),
                  const SizedBox(width: 4),
                  // Other OT Tile
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.orange.shade900
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Other OT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${totalOtherOt.toStringAsFixed(1)} hrs',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.orange.shade300
                                    : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('=',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey)),
                  const SizedBox(width: 4),
                  // Total OT Tile
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : activePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? palette.cardBorderDark
                              : activePrimary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Total OT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: activePrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${totalOtHours.toStringAsFixed(1)} hrs',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: activePrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Emergency OT (${totalEmergencyOt.toStringAsFixed(1)}h) + Other OT (${totalOtherOt.toStringAsFixed(1)}h) = Total OT (${totalOtHours.toStringAsFixed(1)}h)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Emergency Duty Logs (${emergencySessions.length} Session${emergencySessions.length != 1 ? "s" : ""})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? palette.textPrimaryDark
                      : palette.textPrimaryLight,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddEmergencyLogDialog(emp),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Add Emergency Log',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (emergencySessions.isEmpty)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No Emergency Duty records logged for ${emp.name}.',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEmergencyLogDialog(emp),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add First Emergency Log'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
            itemCount: emergencySessions.length,
            itemBuilder: (ctx, idx) {
              final session = emergencySessions[idx];
              final AttendanceRecord inRec = session['in'];
              final AttendanceRecord? outRec = session['out'];
              final double durationHrs = session['durationHrs'];
              final bool isSessionEdited =
                  inRec.isEdited || (outRec != null && outRec.isEdited);

              final formattedInTime = DateFormat('dd MMM yyyy • hh:mm a')
                  .format(inRec.eventTimestamp.toLocal());
              final formattedOutTime = outRec != null
                  ? DateFormat('hh:mm a')
                      .format(outRec.eventTimestamp.toLocal())
                  : 'In Progress';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: Colors.red, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        formattedInTime,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      if (isSessionEdited) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.purple
                                                    .withValues(alpha: 0.3)),
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
                                    ],
                                  ),
                                  Text(
                                    outRec != null
                                        ? 'Completed Session ($formattedOutTime)'
                                        : 'Active Emergency Callout',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: outRec != null
                                          ? Colors.green.shade700
                                          : Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  outRec != null
                                      ? '${durationHrs.toStringAsFixed(1)}h 100% OT'
                                      : 'ACTIVE OT',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: Colors.blueAccent),
                                tooltip: 'Edit Emergency Log',
                                onPressed: () => _showEditEmergencyLogDialog(
                                    emp, inRec, outRec),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.redAccent),
                                tooltip: 'Delete Session',
                                onPressed: () =>
                                    _deleteEmergencySession(inRec, outRec),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (inRec.photoBase64.isNotEmpty ||
                          (outRec != null && outRec.photoBase64.isNotEmpty)) ...[
                        Row(
                          children: [
                            if (inRec.photoBase64.isNotEmpty)
                              GestureDetector(
                                onTap: () => _showFullImageDialog(inRec),
                                child: Container(
                                  height: 60,
                                  width: 60,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade300),
                                  ),
                                  child: _buildPhotoWidget(inRec.photoBase64),
                                ),
                              ),
                            if (inRec.photoBase64.isNotEmpty &&
                                outRec != null &&
                                outRec.photoBase64.isNotEmpty)
                              const SizedBox(width: 10),
                            if (outRec != null && outRec.photoBase64.isNotEmpty)
                              GestureDetector(
                                onTap: () => _showFullImageDialog(outRec),
                                child: Container(
                                  height: 60,
                                  width: 60,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: _buildPhotoWidget(outRec.photoBase64),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (inRec.address.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                inRec.address,
                                style: TextStyle(
                                  fontSize: 11,
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
                      if (inRec.remarks != null &&
                          inRec.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.note_alt_outlined,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Note: ${inRec.remarks!}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
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

  Future<void> _deleteEmergencySession(
      AttendanceRecord inRec, AttendanceRecord? outRec) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Emergency Log'),
        content: const Text(
            'Are you sure you want to delete this emergency duty record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _db.deleteAttendanceRecord(inRec.id);
      if (outRec != null) {
        _db.deleteAttendanceRecord(outRec.id);
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency log deleted.')),
        );
      }
    }
  }

  Future<void> _showAddEmergencyLogDialog(EmployeeEntity emp) async {
    DateTime selectedDate = _selectedDate ?? DateTime.now();
    TimeOfDay checkInTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay checkOutTime = const TimeOfDay(hour: 10, minute: 0);
    bool isCompletedSession = true;
    final TextEditingController locationReasonController =
        TextEditingController(text: 'Emergency Duty');
    final TextEditingController remarksController =
        TextEditingController(text: 'Manual Emergency Duty Logged by Admin');

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final formattedDate =
                DateFormat('dd MMM yyyy').format(selectedDate);
            final formattedInTime = checkInTime.format(ctx);
            final formattedOutTime = checkOutTime.format(ctx);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Emergency Duty Log',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          emp.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selector
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Date: $formattedDate',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const Icon(Icons.calendar_today,
                                size: 18, color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Session completion toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Completed Session',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isCompletedSession
                            ? 'Log Check-In & Check-Out'
                            : 'Active Callout (Check-In Only)',
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: isCompletedSession,
                      activeThumbColor: Colors.red,
                      onChanged: (val) {
                        setDialogState(() {
                          isCompletedSession = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: checkInTime,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  checkInTime = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red.shade300),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.red.withValues(alpha: 0.05),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Check-In Time',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(formattedInTime,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isCompletedSession) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: checkOutTime,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    checkOutTime = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.green.withValues(alpha: 0.05),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Check-Out Time',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(formattedOutTime,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Callout Reason / Site
                    TextField(
                      controller: locationReasonController,
                      decoration: InputDecoration(
                        labelText: 'Location / Callout Reason',
                        hintText: 'e.g. Substation Transformer Repair',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Remarks
                    TextField(
                      controller: remarksController,
                      decoration: InputDecoration(
                        labelText: 'Admin Remarks',
                        hintText: 'Reason for manual entry',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final inDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      checkInTime.hour,
                      checkInTime.minute,
                    );

                    final outDateTime = isCompletedSession
                        ? DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            checkOutTime.hour,
                            checkOutTime.minute,
                          )
                        : null;

                    if (outDateTime != null &&
                        outDateTime.isBefore(inDateTime)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Check-Out time cannot be before Check-In time.')),
                      );
                      return;
                    }

                    final String siteReason =
                        locationReasonController.text.trim().isNotEmpty
                            ? locationReasonController.text.trim()
                            : 'Emergency Duty';
                    final String remarks =
                        remarksController.text.trim().isNotEmpty
                            ? remarksController.text.trim()
                            : 'Manual Emergency Duty Logged by Admin';

                    final offices = _db.getOffices();
                    double empLat = 0.0;
                    double empLng = 0.0;
                    if (!emp.useDefaultOffice && emp.assignedOfficeId != null) {
                      final matches =
                          offices.where((o) => o.id == emp.assignedOfficeId);
                      if (matches.isNotEmpty) {
                        empLat = matches.first.latitude;
                        empLng = matches.first.longitude;
                      } else if (offices.isNotEmpty) {
                        final defOffice = offices.firstWhere((o) => o.isDefault,
                            orElse: () => offices.first);
                        empLat = defOffice.latitude;
                        empLng = defOffice.longitude;
                      }
                    } else if (offices.isNotEmpty) {
                      final defOffice = offices.firstWhere((o) => o.isDefault,
                          orElse: () => offices.first);
                      empLat = defOffice.latitude;
                      empLng = defOffice.longitude;
                    }

                    final checkInRecord = AttendanceRecord(
                      id: const Uuid().v4(),
                      employeeId: emp.id,
                      employeeName: emp.name,
                      workflowStep: WorkflowStep.emergencyCheckIn,
                      eventTimestamp: inDateTime,
                      latitude: empLat,
                      longitude: empLng,
                      gpsAccuracy: 10.0,
                      address: siteReason,
                      deviceId: 'ADMIN_MANUAL_LOG',
                      photoBase64: '',
                      isGeofenceValid: true,
                      siteName: siteReason,
                      syncStatus: SyncStatus.pending,
                      remarks: remarks,
                      isEdited: true,
                      editedBy: 'Admin',
                    );

                    _db.saveAttendanceRecord(checkInRecord);

                    AttendanceRecord? checkOutRecord;
                    if (isCompletedSession && outDateTime != null) {
                      checkOutRecord = AttendanceRecord(
                        id: const Uuid().v4(),
                        employeeId: emp.id,
                        employeeName: emp.name,
                        workflowStep: WorkflowStep.emergencyCheckOut,
                        eventTimestamp: outDateTime,
                        latitude: empLat,
                        longitude: empLng,
                        gpsAccuracy: 10.0,
                        address: siteReason,
                        deviceId: 'ADMIN_MANUAL_LOG',
                        photoBase64: '',
                        isGeofenceValid: true,
                        siteName: siteReason,
                        syncStatus: SyncStatus.pending,
                        remarks: remarks,
                        isEdited: true,
                        editedBy: 'Admin',
                      );
                      _db.saveAttendanceRecord(checkOutRecord);
                    }

                    // Push to Supabase Cloud asynchronously
                    SupabaseService().saveAdminAttendanceOverride(
                      records: [
                        checkInRecord,
                        if (checkOutRecord != null) checkOutRecord,
                      ],
                    );

                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Save Emergency Log'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency Duty log saved for ${emp.name}.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showEditEmergencyLogDialog(
    EmployeeEntity emp,
    AttendanceRecord inRec,
    AttendanceRecord? outRec,
  ) async {
    DateTime selectedDate = inRec.eventTimestamp.toLocal();
    TimeOfDay checkInTime =
        TimeOfDay.fromDateTime(inRec.eventTimestamp.toLocal());
    TimeOfDay checkOutTime = outRec != null
        ? TimeOfDay.fromDateTime(outRec.eventTimestamp.toLocal())
        : TimeOfDay(
            hour: (inRec.eventTimestamp.toLocal().hour + 2) % 24,
            minute: inRec.eventTimestamp.toLocal().minute,
          );
    bool isCompletedSession = outRec != null;
    final TextEditingController locationReasonController =
        TextEditingController(
      text: inRec.siteName ?? inRec.address,
    );
    final TextEditingController remarksController = TextEditingController(
      text: inRec.remarks ??
          (outRec?.remarks ?? 'Manual Emergency Duty Logged by Admin'),
    );

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final allEmployees = _getSynthesizedEmployees();
    String selectedEmpId = emp.id;
    String selectedEmpName = emp.name;

    final bool? updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final formattedDate =
                DateFormat('dd MMM yyyy').format(selectedDate);
            final formattedInTime = checkInTime.format(ctx);
            final formattedOutTime = checkOutTime.format(ctx);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Emergency Duty Log',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          selectedEmpName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Assigned Employee
                    const Text(
                      'Assigned Employee',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: allEmployees.any((e) => e.id == selectedEmpId)
                              ? selectedEmpId
                              : (allEmployees.isNotEmpty ? allEmployees.first.id : null),
                          isExpanded: true,
                          items: allEmployees.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(
                                '${e.name} (${e.employeeCode})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final match = allEmployees.firstWhere((e) => e.id == val);
                              setDialogState(() {
                                selectedEmpId = match.id;
                                selectedEmpName = match.name;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date Selector
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Date: $formattedDate',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const Icon(Icons.calendar_today,
                                size: 18, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Session completion toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Completed Session',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isCompletedSession
                            ? 'Log Check-In & Check-Out'
                            : 'Active Callout (Check-In Only)',
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: isCompletedSession,
                      activeThumbColor: Colors.blue,
                      onChanged: (val) {
                        setDialogState(() {
                          isCompletedSession = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: checkInTime,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  checkInTime = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue.shade300),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.blue.withValues(alpha: 0.05),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Check-In Time',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(formattedInTime,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isCompletedSession) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: checkOutTime,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    checkOutTime = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.green.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.green.withValues(alpha: 0.05),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Check-Out Time',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(formattedOutTime,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Callout Reason / Site
                    TextField(
                      controller: locationReasonController,
                      decoration: InputDecoration(
                        labelText: 'Location / Callout Reason',
                        hintText: 'e.g. Substation Transformer Repair',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Remarks
                    TextField(
                      controller: remarksController,
                      decoration: InputDecoration(
                        labelText: 'Admin Remarks',
                        hintText: 'Reason for manual entry / modification',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final inDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      checkInTime.hour,
                      checkInTime.minute,
                    );

                    final outDateTime = isCompletedSession
                        ? DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            checkOutTime.hour,
                            checkOutTime.minute,
                          )
                        : null;

                    if (outDateTime != null &&
                        outDateTime.isBefore(inDateTime)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Check-Out time cannot be before Check-In time.')),
                      );
                      return;
                    }

                    final String siteReason =
                        locationReasonController.text.trim().isNotEmpty
                            ? locationReasonController.text.trim()
                            : (inRec.siteName ??
                                (inRec.address.isNotEmpty
                                    ? inRec.address
                                    : 'Emergency Duty'));
                    final String remarks =
                        remarksController.text.trim().isNotEmpty
                            ? remarksController.text.trim()
                            : (inRec.remarks ??
                                'Manual Emergency Duty Logged by Admin');

                    final updatedCheckIn = inRec.copyWith(
                      employeeId: selectedEmpId,
                      employeeName: selectedEmpName,
                      eventTimestamp: inDateTime,
                      siteName: siteReason,
                      address: siteReason,
                      remarks: remarks,
                      isEdited: true,
                      editedBy: 'Admin',
                      syncStatus: SyncStatus.pending,
                    );

                    _db.updateAttendanceRecord(updatedCheckIn);

                    AttendanceRecord? finalOutRecord;
                    if (isCompletedSession && outDateTime != null) {
                      if (outRec != null) {
                        finalOutRecord = outRec.copyWith(
                          employeeId: selectedEmpId,
                          employeeName: selectedEmpName,
                          eventTimestamp: outDateTime,
                          siteName: siteReason,
                          address: siteReason,
                          remarks: remarks,
                          isEdited: true,
                          editedBy: 'Admin',
                          syncStatus: SyncStatus.pending,
                        );
                        _db.updateAttendanceRecord(finalOutRecord);
                      } else {
                        finalOutRecord = AttendanceRecord(
                          id: const Uuid().v4(),
                          employeeId: selectedEmpId,
                          employeeName: selectedEmpName,
                          workflowStep: WorkflowStep.emergencyCheckOut,
                          eventTimestamp: outDateTime,
                          latitude: inRec.latitude,
                          longitude: inRec.longitude,
                          gpsAccuracy: inRec.gpsAccuracy,
                          address: siteReason,
                          deviceId: inRec.deviceId,
                          photoBase64: inRec.photoBase64,
                          isGeofenceValid: true,
                          siteName: siteReason,
                          syncStatus: SyncStatus.pending,
                          remarks: remarks,
                          isEdited: true,
                          editedBy: 'Admin',
                        );
                        _db.saveAttendanceRecord(finalOutRecord);
                      }
                    } else if (!isCompletedSession && outRec != null) {
                      // Converted from completed to active callout: remove outRec
                      _db.deleteAttendanceRecord(outRec.id);
                    }

                    // Push to Supabase Cloud asynchronously
                    SupabaseService().saveAdminAttendanceOverride(
                      records: [
                        updatedCheckIn,
                        if (finalOutRecord != null) finalOutRecord,
                      ],
                    );

                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true) {
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency Duty log updated for $selectedEmpName.'),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      }
    }
  }

  // ==========================================
  // LEVEL 3: DETAILED RECORD & PHOTO VIEW FOR SELECTED DATE
  // ==========================================
  Widget _buildLevel3DateDetailView() {
    final emp = _resolveEmployee(_selectedEmployeeId);

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    final dateRecords = _db.getAttendanceRecords().where((r) {
      final matchesUser = _recordMatchesEmployee(r, emp);
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
      case WorkflowStep.emergencyCheckIn:
        return Icons.warning_amber_rounded;
      case WorkflowStep.emergencyCheckOut:
        return Icons.warning_rounded;
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
      case WorkflowStep.emergencyCheckIn:
        return palette.error;
      case WorkflowStep.emergencyCheckOut:
        return palette.error;
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
      final empRecords = allRecords
          .where((r) => _recordMatchesEmployee(r, emp))
          .toList();

      final timesheets =
          TimesheetCalculator.calculateDailyTimesheets(empRecords);

      double regHours = 0.0;
      double otHours = 0.0;
      double emgHours = 0.0;

      for (final entry in timesheets) {
        regHours += entry.regularHours;
        otHours += entry.overtimeHours;
        emgHours += entry.emergencyDutyHours;
      }

      grandReg += regHours;
      grandOt += otHours;

      summaries.add(
        _EmpCumulativeData(
          employee: emp,
          regularHours: regHours,
          overtimeHours: otHours,
          emergencyDutyHours: emgHours,
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
  final double emergencyDutyHours;
  final double combinedHours;
  final int daysWorked;

  _EmpCumulativeData({
    required this.employee,
    required this.regularHours,
    required this.overtimeHours,
    this.emergencyDutyHours = 0.0,
    required this.combinedHours,
    required this.daysWorked,
  });
}
