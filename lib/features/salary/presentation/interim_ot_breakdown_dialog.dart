import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/excel_csv_export_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/utils/salary_cycle_helper.dart';
import '../../../core/widgets/employee_avatar.dart';
import '../../admin/domain/employee_entity.dart';
import '../../attendance/domain/attendance_record.dart';
import '../domain/employee_salary_config.dart';
import '../domain/employee_salary_summary.dart';
import '../utils/salary_calculator.dart';

/// Modal dialog displaying a dedicated breakdown of employee overtime for the
/// 6-day October transition period: 26 Oct 2026 to 31 Oct 2026.
class InterimOtBreakdownDialog extends StatefulWidget {
  final List<EmployeeEntity> employees;
  final List<AttendanceRecord> records;
  final Map<String, EmployeeSalaryConfig> salaryConfigs;
  final VoidCallback? onSwitchToTransitionCycle;

  const InterimOtBreakdownDialog({
    super.key,
    required this.employees,
    required this.records,
    required this.salaryConfigs,
    this.onSwitchToTransitionCycle,
  });

  @override
  State<InterimOtBreakdownDialog> createState() =>
      _InterimOtBreakdownDialogState();
}

class _InterimOtRowData {
  final EmployeeEntity employee;
  final EmployeeSalaryConfig config;
  final EmployeeSalarySummary summary;
  final double otOct26;
  final double otOct27;
  final double otOct28;
  final double otOct29;
  final double otOct30;
  final double otOct31;

  _InterimOtRowData({
    required this.employee,
    required this.config,
    required this.summary,
    required this.otOct26,
    required this.otOct27,
    required this.otOct28,
    required this.otOct29,
    required this.otOct30,
    required this.otOct31,
  });

  double get totalOtHours => summary.totalOvertimeHours;
  double get totalOtAmount => summary.earnedOtSalary;
  double get otHourlyRate => summary.hourlyOtRate;
  bool get isNeo => employee.department.toLowerCase().contains('neo');
}

class _InterimOtBreakdownDialogState extends State<InterimOtBreakdownDialog> {
  String _searchQuery = '';
  String _divisionFilter = 'ALL'; // 'ALL', 'NEO', 'ELECTRO'
  bool _onlyWithOt = false;

  late final List<_InterimOtRowData> _allRows;
  final SalaryCycle _cycle = SalaryCycle.octoberTransition();

  @override
  void initState() {
    super.initState();
    _computeRows();
  }

  void _computeRows() {
    final List<_InterimOtRowData> rows = [];

    // Filter out owners and excluded personnel
    final activeEmployees = widget.employees.where((e) {
      return !SalaryCalculator.isExcludedOwner(
        name: e.name,
        code: e.employeeCode,
        email: e.email,
        id: e.id,
      );
    }).toList();

    for (final emp in activeEmployees) {
      final config = SalaryCalculator.resolveConfig(
        employee: emp,
        salaryConfigs: widget.salaryConfigs,
      );

      final summary = SalaryCalculator.calculateEmployeeSalary(
        config: config,
        employee: emp,
        records: widget.records,
        cycle: _cycle,
        referenceDate: DateTime(2026, 11, 1),
      );

      double ot26 = 0.0;
      double ot27 = 0.0;
      double ot28 = 0.0;
      double ot29 = 0.0;
      double ot30 = 0.0;
      double ot31 = 0.0;

      for (final r in summary.dailyRecords) {
        if (r.date.year == 2026 && r.date.month == 10) {
          switch (r.date.day) {
            case 26:
              ot26 = r.overtimeHours;
              break;
            case 27:
              ot27 = r.overtimeHours;
              break;
            case 28:
              ot28 = r.overtimeHours;
              break;
            case 29:
              ot29 = r.overtimeHours;
              break;
            case 30:
              ot30 = r.overtimeHours;
              break;
            case 31:
              ot31 = r.overtimeHours;
              break;
          }
        }
      }

      rows.add(_InterimOtRowData(
        employee: emp,
        config: config,
        summary: summary,
        otOct26: ot26,
        otOct27: ot27,
        otOct28: ot28,
        otOct29: ot29,
        otOct30: ot30,
        otOct31: ot31,
      ));
    }

    // Sort by name
    rows.sort((a, b) => a.employee.name.toLowerCase().compareTo(b.employee.name.toLowerCase()));
    _allRows = rows;
  }

  List<_InterimOtRowData> get _filteredRows {
    return _allRows.where((r) {
      if (_divisionFilter == 'NEO' && !r.isNeo) return false;
      if (_divisionFilter == 'ELECTRO' && r.isNeo) return false;
      if (_onlyWithOt && r.totalOtHours <= 0) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = r.employee.name.toLowerCase().contains(q);
        final codeMatch = r.employee.employeeCode.toLowerCase().contains(q);
        final deptMatch = r.employee.department.toLowerCase().contains(q);
        if (!nameMatch && !codeMatch && !deptMatch) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _exportExcel() async {
    try {
      await ExcelCsvExportService.exportInterimOtExcel(
        employees: widget.employees,
        records: widget.records,
        salaryConfigs: widget.salaryConfigs,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interim OT Excel (26-31 Oct 2026) exported successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      await PdfExportService.exportInterimOtPdf(
        employees: widget.employees,
        records: widget.records,
        salaryConfigs: widget.salaryConfigs,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredRows;

    // Totals for filtered list
    double filteredTotalOtHours = 0.0;
    double filteredTotalOtAmount = 0.0;
    int filteredEmployeesWithOt = 0;

    for (final r in filtered) {
      filteredTotalOtHours += r.totalOtHours;
      filteredTotalOtAmount += r.totalOtAmount;
      if (r.totalOtHours > 0) filteredEmployeesWithOt++;
    }

    // Totals for all staff
    double grandTotalOtHours = 0.0;
    double grandTotalOtAmount = 0.0;
    double neoTotalOtHours = 0.0;
    double neoTotalOtAmount = 0.0;
    double electroTotalOtHours = 0.0;
    double electroTotalOtAmount = 0.0;

    for (final r in _allRows) {
      grandTotalOtHours += r.totalOtHours;
      grandTotalOtAmount += r.totalOtAmount;
      if (r.isNeo) {
        neoTotalOtHours += r.totalOtHours;
        neoTotalOtAmount += r.totalOtAmount;
      } else {
        electroTotalOtHours += r.totalOtHours;
        electroTotalOtAmount += r.totalOtAmount;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1180,
          maxHeight: 880,
        ),
        child: Column(
          children: [
            // 1. Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFBBF24),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Interim Overtime Report (26 Oct – 31 Oct 2026)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '6-day transition window between legacy cycle (ended 25 Oct) and new calendar cycle (starts 1 Nov)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Excel Export Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9D58),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.table_view_rounded, size: 16),
                    label: const Text('Export Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _exportExcel,
                  ),
                  const SizedBox(width: 8),
                  // PDF Export Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _exportPdf,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Summary KPI Cards
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  _buildKpiCard(
                    title: 'Total Interim OT',
                    value: '${grandTotalOtHours.toStringAsFixed(1)} hrs',
                    subtitle: 'AED ${grandTotalOtAmount.toStringAsFixed(2)}',
                    icon: Icons.timer_outlined,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                    title: 'Fusion Neo OT',
                    value: '${neoTotalOtHours.toStringAsFixed(1)} hrs',
                    subtitle: 'AED ${neoTotalOtAmount.toStringAsFixed(2)}',
                    icon: Icons.business_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                    title: 'Fusion Electro OT',
                    value: '${electroTotalOtHours.toStringAsFixed(1)} hrs',
                    subtitle: 'AED ${electroTotalOtAmount.toStringAsFixed(2)}',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildKpiCard(
                    title: 'Staff with OT',
                    value: '$_staffWithOtCount / ${_allRows.length}',
                    subtitle: 'Active Earners',
                    icon: Icons.people_outline_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // 3. Toolbar & Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search employee name or code...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Division Filter Pills
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildFilterChip('All Staff', 'ALL', isDark),
                      _buildFilterChip('Fusion Neo', 'NEO', isDark),
                      _buildFilterChip('Fusion Electro', 'ELECTRO', isDark),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Only with OT Toggle
                  FilterChip(
                    label: const Text('OT > 0 Only', style: TextStyle(fontSize: 12)),
                    selected: _onlyWithOt,
                    selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFFF59E0B),
                    onSelected: (val) => setState(() => _onlyWithOt = val),
                  ),

                  const Spacer(),

                  if (widget.onSwitchToTransitionCycle != null)
                    TextButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('View Cycle in Main Screen', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onSwitchToTransitionCycle?.call();
                      },
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 4. Data Table
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No employee overtime logs found for 26 Oct – 31 Oct.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: 46,
                          dataRowMaxHeight: 52,
                          columnSpacing: 18,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          ),
                          columns: [
                            DataColumn(label: Text('SL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(label: Text('Division', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('Basic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('OT Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('26 Oct\n(Mon)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('27 Oct\n(Tue)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('28 Oct\n(Wed)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('29 Oct\n(Thu)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('30 Oct\n(Fri)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87))),
                            DataColumn(numeric: true, label: Text('31 Oct\n(Sat)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : Colors.black87))),
                            const DataColumn(numeric: true, label: Text('Total OT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706)))),
                            const DataColumn(numeric: true, label: Text('OT Pay (AED)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669)))),
                          ],
                          rows: List.generate(filtered.length, (idx) {
                            final row = filtered[idx];
                            final hasRowOt = row.totalOtHours > 0;

                            return DataRow(
                              color: WidgetStateProperty.resolveWith((states) {
                                if (idx.isOdd) {
                                  return isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.015);
                                }
                                return null;
                              }),
                              cells: [
                                DataCell(Text('${idx + 1}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      EmployeeAvatar(
                                        fullName: row.employee.name,
                                        photoUrl: row.employee.photoUrl,
                                        radius: 14,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            row.employee.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12.5,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            row.employee.employeeCode,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: isDark ? const Color(0xFF94A3B8) : Colors.grey[500],
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: row.isNeo
                                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                          : const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      row.isNeo ? 'Neo' : 'Electro',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: row.isNeo ? const Color(0xFF059669) : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(row.config.basicSalary.toStringAsFixed(0), style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87))),
                                DataCell(
                                  Text(
                                    row.config.otIncludedInVariable
                                        ? 'Fixed OT'
                                        : '${row.otHourlyRate.toStringAsFixed(2)}/h',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: row.config.otIncludedInVariable ? Colors.grey[500] : (isDark ? Colors.white70 : null),
                                    ),
                                  ),
                                ),
                                _buildDailyOtCell(row.otOct26),
                                _buildDailyOtCell(row.otOct27),
                                _buildDailyOtCell(row.otOct28),
                                _buildDailyOtCell(row.otOct29),
                                _buildDailyOtCell(row.otOct30),
                                _buildDailyOtCell(row.otOct31),
                                DataCell(
                                  Text(
                                    '${row.totalOtHours.toStringAsFixed(1)} h',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: hasRowOt ? const Color(0xFFD97706) : Colors.grey[400],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    NumberFormat('#,##0.00').format(row.totalOtAmount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: hasRowOt ? const Color(0xFF059669) : Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
            ),

            // 5. Grand Total Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Text(
                    'Showing ${filtered.length} employees ($filteredEmployeesWithOt with OT)',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFFCBD5E1) : Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'Total Interim OT:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${filteredTotalOtHours.toStringAsFixed(1)} hrs',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        'Total Payable:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'AED ${NumberFormat('#,##0.00').format(filteredTotalOtAmount)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
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

  int get _staffWithOtCount => _allRows.where((r) => r.totalOtHours > 0).length;

  DataCell _buildDailyOtCell(double hours) {
    if (hours <= 0) {
      return const DataCell(
        Text(
          '-',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      );
    }
    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${hours.toStringAsFixed(1)}h',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD97706),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _divisionFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
      onSelected: (selected) {
        if (selected) setState(() => _divisionFilter = value);
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
