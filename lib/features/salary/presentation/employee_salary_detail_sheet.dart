import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/salary_cycle_helper.dart';
import '../../../core/widgets/employee_avatar.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../database/local_database_service.dart';
import '../domain/employee_salary_config.dart';
import '../domain/employee_salary_summary.dart';
import '../domain/daily_salary_record.dart';
import '../utils/salary_calculator.dart';
import 'edit_salary_dialog.dart';
import 'put_office_attendance_dialog.dart';

class EmployeeSalaryDetailSheet extends StatefulWidget {
  final EmployeeSalarySummary summary;
  final VoidCallback? onSalaryUpdated;

  const EmployeeSalaryDetailSheet({
    super.key,
    required this.summary,
    this.onSalaryUpdated,
  });

  @override
  State<EmployeeSalaryDetailSheet> createState() =>
      _EmployeeSalaryDetailSheetState();
}

class _EmployeeSalaryDetailSheetState extends State<EmployeeSalaryDetailSheet> {
  late EmployeeSalarySummary _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
  }

  void _openEditSalary() {
    showDialog(
      context: context,
      builder: (ctx) => EditSalaryDialog(
        existingConfig: _summary.config,
        onSaved: () {
          widget.onSalaryUpdated?.call();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _reloadAttendanceAndRecalculate() {
    final allRecords = LocalDatabaseService().getAttendanceRecords();
    final newSummary = SalaryCalculator.calculateEmployeeSalary(
      config: _summary.config,
      records: allRecords,
      cycle: _summary.cycle,
    );
    setState(() {
      _summary = newSummary;
    });
    widget.onSalaryUpdated?.call();
  }

  void _toggleOtIncludedInVariable(bool value) {
    final updatedConfig = _summary.config.copyWith(
      otIncludedInVariable: value,
    );
    LocalDatabaseService().saveEmployeeSalary(updatedConfig, persist: true);

    // Recalculate summary with all current attendance records for this employee
    final allRecords = LocalDatabaseService().getAttendanceRecords();
    final newSummary = SalaryCalculator.calculateEmployeeSalary(
      config: updatedConfig,
      records: allRecords,
      cycle: _summary.cycle,
    );

    setState(() {
      _summary = newSummary;
    });

    widget.onSalaryUpdated?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'OT calculation disabled for ${_summary.employeeName} (Fixed in Variable).'
              : 'OT calculation enabled for ${_summary.employeeName}.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cycle = _summary.cycle;
    final config = _summary.config;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Top App Bar / Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day-Wise Salary Calculation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cycle: ${cycle.shortPeriodLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _summary.isManualAttendance
                        ? Colors.purple[700]
                        : (_summary.daysWorked == 0 ? Colors.amber[700] : AppColors.primary),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    _summary.isManualAttendance
                        ? Icons.edit_calendar_rounded
                        : Icons.post_add_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _summary.isManualAttendance
                        ? 'Edit Dates'
                        : (_summary.daysWorked == 0 ? '+ Put Attendance' : 'Attendance'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    PutOfficeAttendanceDialog.show(
                      context,
                      summary: _summary,
                      onAttendanceSaved: _reloadAttendanceAndRecalculate,
                    );
                  },
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit Salary', style: TextStyle(fontSize: 12)),
                  onPressed: _openEditSalary,
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
                  tooltip: 'Download Payslip PDF',
                  onPressed: () async {
                    try {
                      await PdfExportService.exportEmployeeSalarySlipPdf(
                        organizationName: LocalDatabaseService().organization?.name ?? 'Fusion 360',
                        summary: _summary,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error generating payslip PDF: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 18),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // 1. Employee Profile & Base Rates Card
                _buildEmployeeHeaderCard(isDark),
                const SizedBox(height: 16),

                // 2. Cycle Totals & Pay Breakdown Card
                _buildCycleSummaryCard(isDark),
                const SizedBox(height: 20),

                // Manual Attendance Banner (if marked manually on calendar)
                if (_summary.isManualAttendance) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: isDark ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.edit_calendar_rounded, color: Colors.purple[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manual Calendar Attendance (${_summary.daysWorked} Days Marked)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.purple[200] : Colors.purple[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Attendance for ${_summary.employeeName} was entered manually via calendar selection. '
                                'This employee is maintained in the Manual Attendance tab. '
                                'Tap below to modify dates, add overtime, or clear attendance.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.3,
                                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  PutOfficeAttendanceDialog.show(
                                    context,
                                    summary: _summary,
                                    onAttendanceSaved: _reloadAttendanceAndRecalculate,
                                  );
                                },
                                icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                                label: const Text(
                                  'Edit Calendar Dates',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Office Staff Attendance Prompt (if 0 days logged and not manual)
                if (_summary.daysWorked == 0 && !_summary.isManualAttendance) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '0 Days Logged (Office Staff Attendance Needed)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_summary.employeeName} has 0 days of attendance recorded for ${_summary.cycle.shortPeriodLabel}. '
                                'Office staff do not clock in via the mobile application. '
                                'Use "Put Office Attendance" to bulk mark worked days (e.g., 26 days) or record specific dates to calculate salary automatically.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.3,
                                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  PutOfficeAttendanceDialog.show(
                                    context,
                                    summary: _summary,
                                    onAttendanceSaved: _reloadAttendanceAndRecalculate,
                                  );
                                },
                                icon: const Icon(Icons.post_add_rounded, size: 16),
                                label: const Text(
                                  'Put Office Attendance Now',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 2.5 Interim Overtime Pill (When viewing Nov 2026)
                _buildInterimOtPill(isDark),

                // 3. Day-Wise Ledger Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Day-by-Day Salary Ledger',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '${_summary.totalPayableDays} Payable Days Credited',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4. Daily List of Records
                ..._summary.dailyRecords.map(
                  (record) => _buildDailyRecordTile(record, isDark, config),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              EmployeeAvatar(
                photoUrl: null,
                fullName: _summary.employeeName,
                radius: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _summary.employeeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _summary.employeeCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_summary.department} Division',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Monthly Base',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    'AED ${_summary.monthlyBaseTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Rates Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric(
                label: 'Basic Salary (Fixed)',
                value: 'AED ${_summary.config.basicSalary.toStringAsFixed(0)}',
                subtext: '${_summary.config.dailyFixedRate.toStringAsFixed(2)}/day',
                isDark: isDark,
              ),
              _buildMiniMetric(
                label: 'Variable Allowance',
                value: 'AED ${_summary.config.variableSalary.toStringAsFixed(0)}',
                subtext: '${_summary.config.dailyVariableRate.toStringAsFixed(2)}/day',
                isDark: isDark,
              ),
              _buildMiniMetric(
                label: 'Hourly OT Rate',
                value: _summary.config.otIncludedInVariable
                    ? 'AED 0.00'
                    : 'AED ${_summary.hourlyOtRate.toStringAsFixed(2)}',
                subtext: _summary.config.otIncludedInVariable
                    ? 'Fixed in Var'
                    : '(Basic / Days) / 8h',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 1-Tap Toggle Button: OT Included in Variable (Zero OT)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _summary.config.otIncludedInVariable
                  ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _summary.config.otIncludedInVariable
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : (isDark ? Colors.white12 : Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _summary.config.otIncludedInVariable
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        size: 16,
                        color: _summary.config.otIncludedInVariable
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fixed OT in Variable Salary',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _summary.config.otIncludedInVariable
                                    ? AppColors.primary
                                    : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                              ),
                            ),
                            Text(
                              _summary.config.otIncludedInVariable
                                  ? 'Active: OT is AED 0.00 (already included in variable)'
                                  : 'Inactive: OT calculated strictly from Basic Salary',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _summary.config.otIncludedInVariable,
                  activeColor: AppColors.primary,
                  onChanged: _toggleOtIncludedInVariable,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _summary.config.otIncludedInVariable
                  ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08)
                  : Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _summary.config.otIncludedInVariable
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : Colors.amber.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _summary.config.otIncludedInVariable
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 13,
                  color: _summary.config.otIncludedInVariable
                      ? (isDark ? Colors.lightBlueAccent : AppColors.primary)
                      : (isDark ? Colors.amber[300] : Colors.amber[900]),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _summary.config.otIncludedInVariable
                        ? 'Overtime is fixed and included in variable salary. No separate OT is calculated (credited as AED 0.00).'
                        : (_summary.config.customMonthlyOtAmount != null
                            ? 'Manual Monthly Overtime: Fixed custom lump sum of AED ${_summary.config.customMonthlyOtAmount!.toStringAsFixed(2)} for the month.'
                            : 'OT Formula: (Basic AED ${_summary.config.basicSalary.toStringAsFixed(0)} / ${DateTime(_summary.cycle.salaryYear, _summary.cycle.salaryMonth + 1, 0).day} days) / 8 hrs = AED ${_summary.hourlyOtRate.toStringAsFixed(2)}/hr (Variable allowance is excluded)'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _summary.config.otIncludedInVariable
                          ? (isDark ? Colors.lightBlueAccent : AppColors.primary)
                          : (isDark ? Colors.amber[200] : Colors.amber[900]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Net Earned Salary',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_summary.totalPayableDays} Payable Days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'AED ${_summary.grossTotalSalary.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryPill(
                  label: 'Worked Days',
                  value: '${_summary.daysWorked}d',
                  color: Colors.white,
                ),
                _buildSummaryPill(
                  label: 'Paid Sundays',
                  value: '+${_summary.paidSundays}d',
                  color: const Color(0xFF93C5FD),
                ),
                _buildSummaryPill(
                  label: 'Fixed Earned',
                  value: 'AED ${_summary.earnedFixedSalary.toStringAsFixed(0)}',
                  color: Colors.white,
                ),
                _buildSummaryPill(
                  label: 'Variable Earned',
                  value: 'AED ${_summary.earnedVariableSalary.toStringAsFixed(0)}',
                  color: Colors.white,
                ),
                _buildSummaryPill(
                  label: _summary.config.customMonthlyOtAmount != null
                      ? 'Manual OT'
                      : 'OT (${_summary.totalOvertimeHours.toStringAsFixed(1)}h)',
                  value: '+AED ${_summary.earnedOtSalary.toStringAsFixed(0)}',
                  color: const Color(0xFFFDE047),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyRecordTile(
    DailySalaryRecord record,
    bool isDark,
    EmployeeSalaryConfig config,
  ) {
    final bool isSunday = record.isSunday;
    final bool isPayable = record.isPayable;
    final dateStr = DateFormat('dd MMM (EEE)').format(record.date);

    Color badgeColor;
    Color badgeTextColor;
    String statusTitle;

    switch (record.status) {
      case DailySalaryStatus.present:
        badgeColor = Colors.green.withValues(alpha: 0.12);
        badgeTextColor = isDark ? Colors.greenAccent : Colors.green[800]!;
        statusTitle = 'Present • ${record.regularHours.toStringAsFixed(1)}h reg';
        if (record.overtimeHours > 0) {
          statusTitle += ' + ${record.overtimeHours.toStringAsFixed(1)}h OT';
        }
        break;
      case DailySalaryStatus.paidSundayOff:
        badgeColor = Colors.blue.withValues(alpha: 0.15);
        badgeTextColor = isDark ? Colors.lightBlueAccent : Colors.blue[900]!;
        statusTitle = record.remarks?.isNotEmpty == true
            ? record.remarks!
            : 'Paid Sunday Off (Weekly Off Credited)';
        break;
      case DailySalaryStatus.sundayDuty:
        badgeColor = Colors.orange.withValues(alpha: 0.15);
        badgeTextColor = isDark ? Colors.orangeAccent : Colors.orange[900]!;
        statusTitle = 'Sunday Duty • ${record.overtimeHours.toStringAsFixed(1)}h OT';
        break;
      case DailySalaryStatus.absent:
        badgeColor = Colors.red.withValues(alpha: 0.1);
        badgeTextColor = isDark ? Colors.redAccent : Colors.red[800]!;
        statusTitle = 'Absent / Leave';
        break;
      case DailySalaryStatus.unpaidSundayOff:
        badgeColor = Colors.grey.withValues(alpha: 0.12);
        badgeTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
        statusTitle = 'Unpaid Sunday (Weekly Off)';
        break;
      case DailySalaryStatus.futureDay:
        badgeColor = Colors.grey.withValues(alpha: 0.08);
        badgeTextColor = Colors.grey;
        statusTitle = 'Upcoming Day';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: record.status == DailySalaryStatus.paidSundayOff
              ? AppColors.primary.withValues(alpha: 0.3)
              : (isDark ? Colors.white10 : Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Date Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSunday
                      ? Colors.amber.withValues(alpha: 0.12)
                      : (isDark ? AppColors.surfaceDark : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSunday
                        ? (isDark ? Colors.amberAccent : Colors.amber[900])
                        : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Status Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Day Salary Credit
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPayable
                        ? '+AED ${record.dailyTotalSalary.toStringAsFixed(2)}'
                        : 'AED 0.00',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isPayable
                          ? (isDark ? Colors.greenAccent : Colors.green[800])
                          : Colors.grey,
                    ),
                  ),
                  if (isPayable)
                    Text(
                      'Cumul: AED ${record.cumulativeSalary.toStringAsFixed(2)} (${record.cumulativePayableDays}d)',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Detailed Breakdown Row (Fixed, Variable, OT) if payable
          if (isPayable) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fixed: +${record.dailyFixedCredit.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    'Var: +${record.dailyVariableCredit.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  if (record.dailyOtCredit > 0)
                    Text(
                      'OT: +${record.dailyOtCredit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amberAccent : Colors.orange[800],
                      ),
                    ),
                  Text(
                    'Day Total: AED ${record.dailyTotalSalary.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required String subtext,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtext,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[500] : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildInterimOtPill(bool isDark) {
    if (_summary.cycle.salaryMonth != 11 || _summary.cycle.salaryYear != 2026) {
      return const SizedBox.shrink();
    }
    final allRecords = LocalDatabaseService().getAttendanceRecords();
    final interimCycle = SalaryCycle.octoberTransition();
    final interimSummary = SalaryCalculator.calculateEmployeeSalary(
      config: _summary.config,
      employee: null,
      records: allRecords,
      cycle: interimCycle,
      referenceDate: DateTime(2026, 11, 1),
    );

    if (interimSummary.totalOvertimeHours <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'October Transition Overtime (26 Oct – 31 Oct)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
                Text(
                  '${_summary.employeeName} earned ${interimSummary.totalOvertimeHours.toStringAsFixed(1)} hrs OT (AED ${interimSummary.earnedOtSalary.toStringAsFixed(2)}) during the 6-day interim period.',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${interimSummary.totalOvertimeHours.toStringAsFixed(1)}h OT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
