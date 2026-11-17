import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/salary_cycle_helper.dart';
import '../../../core/widgets/employee_avatar.dart';
import '../../../database/local_database_service.dart';
import '../../admin/domain/employee_entity.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/employee_salary_config.dart';
import '../domain/employee_salary_summary.dart';
import '../utils/salary_calculator.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/excel_csv_export_service.dart';
import '../../../core/services/supabase_service.dart';
import 'edit_salary_dialog.dart';
import 'employee_salary_detail_sheet.dart';
import 'put_office_attendance_dialog.dart';
import 'interim_ot_breakdown_dialog.dart';

class SalaryPayrollScreen extends StatefulWidget {
  const SalaryPayrollScreen({super.key});

  @override
  State<SalaryPayrollScreen> createState() => _SalaryPayrollScreenState();
}

class _SalaryPayrollScreenState extends State<SalaryPayrollScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();

  late List<SalaryCycle> _availableCycles;
  late SalaryCycle _selectedCycle;

  String _searchQuery = '';
  String _selectedDepartmentFilter = 'ALL'; // 'ALL', 'Fusion', 'Neo'
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'ACTIVE', 'ZERO_DAYS'

  @override
  void initState() {
    super.initState();
    _availableCycles = SalaryCycle.getRecentCycles();
    _selectedCycle = SalaryCycle.current();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() {});
    try {
      final cloudRecords = await SupabaseService().fetchAttendanceRecordsFromSupabase();
      if (cloudRecords.isNotEmpty) {
        _db.saveAttendanceRecordsBatch(cloudRecords);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _openAddSalaryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => EditSalaryDialog(onSaved: _refresh),
    );
  }

  void _openEmployeeSalaryDetail(EmployeeSalarySummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: EmployeeSalaryDetailSheet(
          summary: summary,
          onSalaryUpdated: _refresh,
        ),
      ),
    );
  }

  Future<void> _exportWpsExcel({required String division}) async {
    try {
      final allEmployees = _db
          .getEmployees()
          .where((e) => !SalaryCalculator.isExcludedOwner(
                name: e.name,
                code: e.employeeCode,
                email: e.email,
                id: e.id,
              ))
          .toList();
      final allRecords = _db.getAttendanceRecords();
      final salaryMap = _db.getEmployeeSalaryMap();

      final isNeo = division.toUpperCase().contains('NEO');
      if (isNeo) {
        await ExcelCsvExportService.exportFusionNeoWpsExcel(
          cycle: _selectedCycle,
          employees: allEmployees,
          records: allRecords,
          salaryConfigs: salaryMap,
        );
      } else {
        await ExcelCsvExportService.exportFusionElectroWpsExcel(
          cycle: _selectedCycle,
          employees: allEmployees,
          records: allRecords,
          salaryConfigs: salaryMap,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isNeo ? "Fusion Neo" : "Fusion Electro"} WPS Excel generated for ${_selectedCycle.salaryMonthName}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating WPS Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportMasterPayrollExcel() async {
    try {
      final allEmployees = _db
          .getEmployees()
          .where((e) => !SalaryCalculator.isExcludedOwner(
                name: e.name,
                code: e.employeeCode,
                email: e.email,
                id: e.id,
              ))
          .toList();
      final allRecords = _db.getAttendanceRecords();
      final salaryMap = _db.getEmployeeSalaryMap();

      await ExcelCsvExportService.exportMasterEstimatedPayrollExcel(
        cycle: _selectedCycle,
        employees: allEmployees,
        records: allRecords,
        salaryConfigs: salaryMap,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total Estimated Payroll Details Excel generated for ${_selectedCycle.salaryMonthName}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating master payroll excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openInterimOtDialog({
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => InterimOtBreakdownDialog(
        employees: employees,
        records: records,
        salaryConfigs: salaryConfigs,
        onSwitchToTransitionCycle: () {
          final transitionCycle = _availableCycles.firstWhere(
            (c) => c.isTransition,
            orElse: () => SalaryCycle.octoberTransition(),
          );
          setState(() => _selectedCycle = transitionCycle);
        },
      ),
    );
  }

  Future<void> _exportInterimOtExcel() async {
    try {
      final allEmployees = _db
          .getEmployees()
          .where((e) => !SalaryCalculator.isExcludedOwner(
                name: e.name,
                code: e.employeeCode,
                email: e.email,
                id: e.id,
              ))
          .toList();
      final allRecords = _db.getAttendanceRecords();
      final salaryMap = _db.getEmployeeSalaryMap();

      await ExcelCsvExportService.exportInterimOtExcel(
        employees: allEmployees,
        records: allRecords,
        salaryConfigs: salaryMap,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Interim Overtime Excel (26-31 Oct 2026) generated successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating Interim OT Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter out owners (Nasurudeen, Sirajudeen) who are not involved in monthly salary
    final allEmployees = _db
        .getEmployees()
        .where((e) => !SalaryCalculator.isExcludedOwner(
              name: e.name,
              code: e.employeeCode,
              email: e.email,
              id: e.id,
            ))
        .toList();
    final allRecords = _db.getAttendanceRecords();
    final salaryMap = _db.getEmployeeSalaryMap();

    // Calculate workforce payroll for the selected cycle
    final workforceSummary = SalaryCalculator.calculateWorkforcePayroll(
      employees: allEmployees,
      salaryConfigs: salaryMap,
      records: allRecords,
      cycle: _selectedCycle,
    );

    final allSummaries = workforceSummary.employeeSummaries;

    // Separate workforce summaries for Fusion Electric (Electro) and Fusion Neo
    final fusionSummaries = allSummaries
        .where((s) => !s.department.toLowerCase().contains('neo'))
        .toList();
    final neoSummaries = allSummaries
        .where((s) => s.department.toLowerCase().contains('neo'))
        .toList();

    final fusionSummary = WorkforceSalarySummary.fromSummaries(_selectedCycle, fusionSummaries);
    final neoSummary = WorkforceSalarySummary.fromSummaries(_selectedCycle, neoSummaries);

    // 1. Manual Attendance: Employees whose attendance was entered strictly via the calendar date dialog
    final manualEmployees = allSummaries.where((s) => s.isManualAttendance).toList();

    // 2. Clocked: Mobile app staff who clocked in (strictly excludes calendar-date office staff)
    final clockedEmployees = allSummaries.where((s) => !s.isManualAttendance && s.daysWorked > 0).toList();

    // 3. 0 Days Logged: Regular employees with 0 days logged and no calendar attendance yet
    final zeroDaysEmployees = allSummaries.where((s) => !s.isManualAttendance && s.daysWorked == 0).toList();

    // 4. All Staffs: Regular mobile app workforce (strictly excludes calendar-date office staff)
    final regularStaffEmployees = allSummaries.where((s) => !s.isManualAttendance).toList();

    // Pick source list based on status filter
    List<EmployeeSalarySummary> sourceList;
    if (_selectedStatusFilter == 'MANUAL') {
      sourceList = manualEmployees;
    } else if (_selectedStatusFilter == 'CLOCKED') {
      sourceList = clockedEmployees;
    } else if (_selectedStatusFilter == 'ZERO_DAYS') {
      sourceList = zeroDaysEmployees;
    } else {
      // 'ALL': All Staffs (regular staff, manual attendance employees excluded)
      sourceList = regularStaffEmployees;
    }

    // Apply department & search filters
    final filteredSummaries = sourceList.where((s) {
      if (_selectedDepartmentFilter != 'ALL') {
        if (!s.department.toLowerCase().contains(_selectedDepartmentFilter.toLowerCase())) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = s.employeeName.toLowerCase().contains(q);
        final codeMatch = s.employeeCode.toLowerCase().contains(q);
        final deptMatch = s.department.toLowerCase().contains(q);
        if (!nameMatch && !codeMatch && !deptMatch) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Salary & Payroll Module'),
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
            tooltip: 'Interim OT (26-31 Oct 2026)',
            onPressed: () => _openInterimOtDialog(
              employees: allEmployees,
              records: allRecords,
              salaryConfigs: salaryMap,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export Payroll PDF',
            onPressed: () async {
              try {
                await PdfExportService.exportWorkforceSalaryPdf(
                  organizationName: _db.organization?.name ?? 'Fusion 360',
                  employees: allEmployees,
                  records: allRecords,
                  cycle: _selectedCycle,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error generating PDF: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'Export Payroll Excel Reports',
            onSelected: (val) {
              if (val == 'MASTER') {
                _exportMasterPayrollExcel();
              } else if (val == 'NEO') {
                _exportWpsExcel(division: 'Neo');
              } else if (val == 'ELECTRO') {
                _exportWpsExcel(division: 'Fusion');
              } else if (val == 'INTERIM_OT') {
                _exportInterimOtExcel();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'MASTER',
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Total Estimated Payroll Details (.xlsx)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'NEO',
                child: Row(
                  children: [
                    Icon(Icons.table_view_rounded, color: Color(0xFF0F9D58), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Fusion Neo WPS (.xlsx)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ELECTRO',
                child: Row(
                  children: [
                    Icon(Icons.table_view_rounded, color: Color(0xFF1A73E8), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Fusion Electric WPS (.xlsx)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'INTERIM_OT',
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Interim OT Report (26-31 Oct) (.xlsx)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Configure Employee Salary',
            onPressed: _openAddSalaryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Payroll Calculations',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Controls Bar: Salary Cycle Filter & Department Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey[200]!,
                ),
              ),
            ),
            child: Column(
              children: [
                // Salary Cycle Dropdown Selector
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<SalaryCycle>(
                          value: _selectedCycle,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: _availableCycles.map((c) {
                            final isCur = c == SalaryCycle.current();
                            return DropdownMenuItem<SalaryCycle>(
                              value: c,
                              child: Text(
                                '${c.salaryMonthName} (${c.shortPeriodLabel})${isCur ? " • Current" : ""}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newCycle) {
                            if (newCycle != null) {
                              setState(() => _selectedCycle = newCycle);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Department filter chips & Search input
                Row(
                  children: [
                    _buildDeptFilterChip('ALL', 'All Dept (${allEmployees.length})'),
                    const SizedBox(width: 6),
                    _buildDeptFilterChip('Fusion', 'Fusion'),
                    const SizedBox(width: 6),
                    _buildDeptFilterChip('Neo', 'Neo'),
                    const Spacer(),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search employee...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.search_rounded, size: 16),
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Dedicated WPS & Master Excel Export Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_view_rounded, size: 14, color: Color(0xFF0F9D58)),
                        label: const Text(
                          'Neo WPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F9D58),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          side: const BorderSide(color: Color(0xFF0F9D58), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: const Color(0xFF0F9D58).withValues(alpha: 0.08),
                        ),
                        onPressed: () => _exportWpsExcel(division: 'Neo'),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_view_rounded, size: 14, color: Color(0xFF1A73E8)),
                        label: const Text(
                          'Electric WPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          side: const BorderSide(color: Color(0xFF1A73E8), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: const Color(0xFF1A73E8).withValues(alpha: 0.08),
                        ),
                        onPressed: () => _exportWpsExcel(division: 'Fusion'),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.analytics_rounded, size: 14, color: Colors.white),
                        label: const Text(
                          'Total Payroll',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                        onPressed: _exportMasterPayrollExcel,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.bolt_rounded, size: 15, color: Colors.white),
                        label: const Text(
                          'Interim OT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          backgroundColor: const Color(0xFFD97706),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                        onPressed: () => _openInterimOtDialog(
                          employees: allEmployees,
                          records: allRecords,
                          salaryConfigs: salaryMap,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Attendance Status Separation Filter (All Staffs, Clocked, Manual Attendance, 0 Days Logged)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('ALL', 'All Staffs (${regularStaffEmployees.length})', null),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'CLOCKED',
                        'Clocked (${clockedEmployees.length})',
                        Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'MANUAL',
                        'Manual Attendance (${manualEmployees.length})',
                        Icons.edit_calendar_rounded,
                        isHighlight: manualEmployees.isNotEmpty,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'ZERO_DAYS',
                        '0 Days Logged (${zeroDaysEmployees.length})',
                        Icons.pending_actions_rounded,
                        isWarning: zeroDaysEmployees.isNotEmpty,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transition Period Notice Banner (when viewing Nov 2026 or when Transition cycle is active)
          if (_selectedCycle.isTransition || (_selectedCycle.salaryMonth == 11 && _selectedCycle.salaryYear == 2026))
            _buildTransitionNoticeBanner(
              context: context,
              employees: allEmployees,
              records: allRecords,
              salaryConfigs: salaryMap,
              isDark: isDark,
            ),

          // 2. Executive Payroll Summary Banner (Combined + Fusion Electric + Fusion Neo)
          _buildWorkforceMetricBanner(
            workforceSummary: workforceSummary,
            fusionSummary: fusionSummary,
            neoSummary: neoSummary,
            isDark: isDark,
          ),

          // 3. Employee Salary List (Separated with status sections and attendance action)
          Expanded(
            child: _buildSalaryList(filteredSummaries, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionNoticeBanner({
    required BuildContext context,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
    required bool isDark,
  }) {
    final isTransitionActive = _selectedCycle.isTransition;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isTransitionActive
            ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
            : const Color(0xFF3B82F6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTransitionActive
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : const Color(0xFF3B82F6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTransitionActive ? Icons.bolt_rounded : Icons.info_outline_rounded,
            color: isTransitionActive ? const Color(0xFFD97706) : const Color(0xFF2563EB),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTransitionActive
                      ? 'Viewing Interim Overtime (26 Oct – 31 Oct 2026)'
                      : 'Salary Cycle Changed to Calendar Month (01 Nov – 30 Nov)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isTransitionActive ? const Color(0xFFB45309) : const Color(0xFF1E40AF),
                  ),
                ),
                Text(
                  isTransitionActive
                      ? '6-day transition window before new calendar cycle began on 1 Nov.'
                      : 'Attendance data from 26 Oct – 31 Oct is tracked under separate Interim OT.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 14),
            label: const Text('View 26-31 Oct OT'),
            onPressed: () => _openInterimOtDialog(
              employees: employees,
              records: records,
              salaryConfigs: salaryConfigs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptFilterChip(String deptKey, String label) {
    final isSelected = _selectedDepartmentFilter == deptKey;
    return InkWell(
      onTap: () => setState(() => _selectedDepartmentFilter = deptKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(
    String statusKey,
    String label,
    IconData? icon, {
    bool isWarning = false,
    bool isHighlight = false,
  }) {
    final isSelected = _selectedStatusFilter == statusKey;
    final Color activeColor = isWarning
        ? Colors.amber[800]!
        : (isHighlight ? Colors.purple[700]! : AppColors.primary);

    final Color chipBg = isSelected
        ? activeColor
        : (isWarning
            ? Colors.amber.withValues(alpha: 0.12)
            : (isHighlight
                ? Colors.purple.withValues(alpha: 0.1)
                : Colors.transparent));

    final Color borderColor = isSelected
        ? activeColor
        : (isWarning
            ? Colors.amber.withValues(alpha: 0.5)
            : (isHighlight
                ? Colors.purple.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.3)));

    final Color? textColor = isSelected
        ? Colors.white
        : (isWarning
            ? Colors.amber[900]
            : (isHighlight ? Colors.purple[800] : null));

    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = statusKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryList(
    List<EmployeeSalarySummary> summaries,
    bool isDark,
  ) {
    if (summaries.isEmpty) {
      String emptyMsg = 'No employee salary records found';
      if (_selectedStatusFilter == 'MANUAL') {
        emptyMsg = 'No manual attendance employees for this cycle.\nYou can add attendance for office staff from the "0 Days Logged" tab.';
      } else if (_selectedStatusFilter == 'CLOCKED') {
        emptyMsg = 'No clocked-in staff found for this cycle.';
      } else if (_selectedStatusFilter == 'ZERO_DAYS') {
        emptyMsg = 'No employees with 0 days logged.';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedStatusFilter == 'MANUAL'
                  ? Icons.edit_calendar_outlined
                  : Icons.search_off_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              emptyMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // 1. When viewing Manual Attendance tab specifically
    if (_selectedStatusFilter == 'MANUAL') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildManualAttendanceBanner(summaries.length, isDark),
          const SizedBox(height: 12),
          ...summaries.map((s) => _buildEmployeeSalaryCard(s, isDark)),
        ],
      );
    }

    // 2. When viewing 0 Days tab specifically
    if (_selectedStatusFilter == 'ZERO_DAYS') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildZeroDaysInfoBanner(summaries.length, isDark),
          const SizedBox(height: 12),
          ...summaries.map((s) => _buildEmployeeSalaryCard(s, isDark)),
        ],
      );
    }

    // 3. When viewing Clocked In tab specifically
    if (_selectedStatusFilter == 'CLOCKED') {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: summaries.length,
        itemBuilder: (ctx, index) => _buildEmployeeSalaryCard(summaries[index], isDark),
      );
    }

    // 4. When viewing All Staffs (regular workforce, excluding manual attendance employees)
    final activeRegular = summaries.where((s) => s.daysWorked > 0).toList();
    final zeroRegular = summaries.where((s) => s.daysWorked == 0).toList();

    if (activeRegular.isNotEmpty && zeroRegular.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            title: 'Clocked In Staff (${activeRegular.length})',
            subtitle: 'Employees with mobile app attendance logs for this cycle',
            badgeColor: Colors.green,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          ...activeRegular.map((s) => _buildEmployeeSalaryCard(s, isDark)),
          const SizedBox(height: 16),
          _buildSectionHeader(
            title: 'Not Clocked In (${zeroRegular.length})',
            subtitle: 'Employees with 0 days logged for this cycle',
            badgeColor: Colors.amber[700]!,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          ...zeroRegular.map((s) => _buildEmployeeSalaryCard(s, isDark)),
        ],
      );
    }

    // Standard list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summaries.length,
      itemBuilder: (ctx, index) => _buildEmployeeSalaryCard(summaries[index], isDark),
    );
  }

  Widget _buildManualAttendanceBanner(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_calendar_rounded, color: Colors.purple[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual Attendance Records ($count ${count == 1 ? "Employee" : "Employees"})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.purple[200] : Colors.purple[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These office employees have their attendance recorded manually on the calendar. '
                  'They are maintained exclusively in this tab and kept separate from mobile app clocked staff. '
                  'Tap "Edit Dates" on any employee card to update their calendar working days.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZeroDaysInfoBanner(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Office Staff - 0 Days Logged ($count ${count == 1 ? "Employee" : "Employees"})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                ),
                const SizedBox(height: 4),
                Text(
                  'These employees do not use the mobile attendance app. '
                  'Tap "+ Put Attendance" on each employee card to record their days worked (e.g. full month 26 days or specific shifts), and their salary will calculate automatically.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color badgeColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkforceMetricBanner({
    required WorkforceSalarySummary workforceSummary,
    required WorkforceSalarySummary fusionSummary,
    required WorkforceSalarySummary neoSummary,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Overall Combined Workforce Estimated Payroll
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL ESTIMATED PAYROLL (ALL ENTITIES)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AED ${workforceSummary.totalPayroll.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${workforceSummary.totalWorkforcePayableDays} Payable Days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${workforceSummary.totalWorkforceDaysWorked}d worked + ${workforceSummary.totalWorkforcePaidSundays}d Sun off',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWorkforceMetricCol(
                'Fixed Earned',
                'AED ${workforceSummary.totalFixedEarned.toStringAsFixed(0)}',
              ),
              _buildWorkforceMetricCol(
                'Variable Earned',
                'AED ${workforceSummary.totalVariableEarned.toStringAsFixed(0)}',
              ),
              _buildWorkforceMetricCol(
                'Overtime (${workforceSummary.totalOtHours.toStringAsFixed(1)}h)',
                'AED ${workforceSummary.totalOtEarned.toStringAsFixed(0)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),

          // 2. Separate Division Summary Cards: Fusion Electric vs Fusion Neo
          Row(
            children: [
              // Fusion Electric Card
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDepartmentFilter =
                          _selectedDepartmentFilter == 'Fusion' ? 'ALL' : 'Fusion';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedDepartmentFilter == 'Fusion'
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDepartmentFilter == 'Fusion'
                            ? const Color(0xFF93C5FD)
                            : Colors.white.withValues(alpha: 0.15),
                        width: _selectedDepartmentFilter == 'Fusion' ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '⚡ Fusion Electric',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${fusionSummary.employeeSummaries.length} Staff',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AED ${fusionSummary.totalPayroll.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fixed: AED ${fusionSummary.totalFixedEarned.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          'Var: AED ${fusionSummary.totalVariableEarned.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          'OT: AED ${fusionSummary.totalOtEarned.toStringAsFixed(0)} (${fusionSummary.totalOtHours.toStringAsFixed(1)}h)',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Fusion Neo Card
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDepartmentFilter =
                          _selectedDepartmentFilter == 'Neo' ? 'ALL' : 'Neo';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedDepartmentFilter == 'Neo'
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDepartmentFilter == 'Neo'
                            ? const Color(0xFF86EFAC)
                            : Colors.white.withValues(alpha: 0.15),
                        width: _selectedDepartmentFilter == 'Neo' ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '🏢 Fusion Neo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${neoSummary.employeeSummaries.length} Staff',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AED ${neoSummary.totalPayroll.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fixed: AED ${neoSummary.totalFixedEarned.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          'Var: AED ${neoSummary.totalVariableEarned.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          'OT: AED ${neoSummary.totalOtEarned.toStringAsFixed(0)} (${neoSummary.totalOtHours.toStringAsFixed(1)}h)',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkforceMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeSalaryCard(EmployeeSalarySummary summary, bool isDark) {
    final config = summary.config;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEmployeeSalaryDetail(summary),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Avatar, Name, Code, Dept, Edit action
                Row(
                  children: [
                    EmployeeAvatar(
                      photoUrl: null,
                      fullName: summary.employeeName,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.employeeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
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
                              const SizedBox(width: 6),
                              Text(
                                summary.department,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                                ),
                              ),
                              if (summary.isManualAttendance) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    'Manual Attendance',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple[800],
                                    ),
                                  ),
                                ),
                              ] else if (summary.daysWorked == 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    '0 Days (Office)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                              if (config.otIncludedInVariable) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Fixed OT (0 OT)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ] else if (config.customMonthlyOtAmount != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    'Manual OT (AED ${config.customMonthlyOtAmount!.toStringAsFixed(0)})',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal[800],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (summary.isManualAttendance || summary.daysWorked == 0) ...[
                      IconButton(
                        icon: Icon(
                          summary.isManualAttendance
                              ? Icons.edit_calendar_rounded
                              : Icons.post_add_rounded,
                          size: 20,
                          color: summary.isManualAttendance
                              ? Colors.purple[700]
                              : Colors.amber[700],
                        ),
                        tooltip: summary.isManualAttendance
                            ? 'Edit Calendar Attendance'
                            : 'Put Office Attendance',
                        onPressed: () {
                          PutOfficeAttendanceDialog.show(
                            context,
                            summary: summary,
                            onAttendanceSaved: _refresh,
                          );
                        },
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      tooltip: 'Edit Fixed & Variable Salary',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => EditSalaryDialog(
                            existingConfig: config,
                            onSaved: _refresh,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'AED ${summary.grossTotalSalary.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Base: AED ${summary.monthlyBaseTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          'Basic: AED ${config.basicSalary.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Manual Attendance Banner on Card
                if (summary.isManualAttendance) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: isDark ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event_available_rounded, size: 16, color: Colors.purple[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Manual: ${summary.daysWorked} days on calendar',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.purple[200] : Colors.purple[900],
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            PutOfficeAttendanceDialog.show(
                              context,
                              summary: summary,
                              onAttendanceSaved: _refresh,
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.edit_calendar_rounded, size: 13, color: Colors.purple[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit Dates',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Office Staff Attendance Prompt (if 0 days logged and not manual)
                if (summary.daysWorked == 0 && !summary.isManualAttendance) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_off_outlined, size: 20, color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '0 Days Logged (Office Staff)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'No mobile app clock-in. Tap to record working days & calculate salary.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            PutOfficeAttendanceDialog.show(
                              context,
                              summary: summary,
                              onAttendanceSaved: _refresh,
                            );
                          },
                          icon: const Icon(Icons.post_add_rounded, size: 15),
                          label: const Text(
                            '+ Put Attendance',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Days Summary Pill (Worked + Paid Sundays = Total Payable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '${summary.daysWorked}d worked',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          if (summary.paidSundays > 0) ...[
                            const SizedBox(width: 6),
                            const Text('+', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(width: 6),
                            const Icon(Icons.weekend_outlined, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              '${summary.paidSundays}d Sun off',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                          ],
                          const SizedBox(width: 6),
                          const Text('=', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(width: 6),
                          Text(
                            '${summary.totalPayableDays}d credited',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      Text(
                        'Tap for day-wise breakdown →',
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Breakdown: Basic + Variable + OT (from Basic)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRowItem('Basic Earned', 'AED ${summary.earnedFixedSalary.toStringAsFixed(2)}', isDark),
                    _buildRowItem('Var Earned', 'AED ${summary.earnedVariableSalary.toStringAsFixed(2)}', isDark),
                    _buildRowItem(
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
          ),
        ),
      ),
    );
  }

  Widget _buildRowItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
