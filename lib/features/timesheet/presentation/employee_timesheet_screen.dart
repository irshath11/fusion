import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/utils/timesheet_calculator.dart';
import '../../../database/local_database_service.dart';
import '../../admin/domain/employee_entity.dart';
import 'timesheet_cubit.dart';
import '../domain/timesheet_entry.dart';

class EmployeeTimesheetScreen extends StatefulWidget {
  final String? employeeId;
  final String? employeeName;

  const EmployeeTimesheetScreen({
    super.key,
    this.employeeId,
    this.employeeName,
  });

  @override
  State<EmployeeTimesheetScreen> createState() =>
      _EmployeeTimesheetScreenState();
}

class _EmployeeTimesheetScreenState extends State<EmployeeTimesheetScreen> {
  String _activeFilter = 'all'; // 'all', 'regular', 'overtime'

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TimesheetCubit()
        ..fetchEmployeeTimesheet(employeeId: widget.employeeId),
      child: BlocBuilder<TimesheetCubit, TimesheetState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.employeeName != null
                  ? '${widget.employeeName} - Timesheet'
                  : 'My Work Timesheet'),
              actions: [
                if (state is TimesheetLoaded)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadPdf(context, state),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                      label: const Text('Download PDF',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: Builder(
              builder: (context) {
                if (state is TimesheetLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is TimesheetError) {
                  return Center(
                    child: Text(
                      state.message,
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 16),
                    ),
                  );
                } else if (state is TimesheetLoaded) {
                  final filteredEntries = state.entries.where((e) {
                    if (_activeFilter == 'overtime') return e.overtimeHours > 0;
                    if (_activeFilter == 'regular') return e.regularHours > 0;
                    return true;
                  }).toList();

                  return SafeArea(
                    child: RefreshIndicator(
                      onRefresh: () => context
                          .read<TimesheetCubit>()
                          .fetchEmployeeTimesheet(
                              employeeId: widget.employeeId),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Interactive Executive Timesheet KPI Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Regular Hrs',
                                    value:
                                        '${state.totalRegularHours.toStringAsFixed(1)} hrs',
                                    subtitle: 'Max 8h/day (Tap)',
                                    icon: Icons.access_time_rounded,
                                    color: AppColors.primary,
                                    isSelected: _activeFilter == 'regular',
                                    onTap: () {
                                      setState(() {
                                        _activeFilter =
                                            _activeFilter == 'regular'
                                                ? 'all'
                                                : 'regular';
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Overtime (OT)',
                                    value:
                                        '${state.totalOvertimeHours.toStringAsFixed(1)} hrs',
                                    subtitle: 'Beyond 8.0h (Tap)',
                                    icon: Icons.more_time_rounded,
                                    color: Colors.orange.shade800,
                                    isSelected: _activeFilter == 'overtime',
                                    onTap: () {
                                      setState(() {
                                        _activeFilter =
                                            _activeFilter == 'overtime'
                                                ? 'all'
                                                : 'overtime';
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Total Hours',
                                    value:
                                        '${state.totalCombinedHours.toStringAsFixed(1)} hrs',
                                    subtitle: 'Reg + OT Combined',
                                    icon: Icons.timer_rounded,
                                    color: AppColors.success,
                                    isSelected: _activeFilter == 'all',
                                    onTap: () {
                                      setState(() {
                                        _activeFilter = 'all';
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Days Worked',
                                    value: '${state.totalDaysWorked} Days',
                                    subtitle: 'Logged Shifts',
                                    icon: Icons.calendar_month_rounded,
                                    color: Colors.indigo,
                                    isSelected: false,
                                    onTap: () {
                                      setState(() {
                                        _activeFilter = 'all';
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Site / Client Man-Hours Breakdown Card
                            () {
                              final allRecords = LocalDatabaseService().getAttendanceRecords();
                              final targetId = widget.employeeId ?? LocalDatabaseService().currentUser?.id;
                              if (targetId == null) return const SizedBox.shrink();

                              final siteBreakdown = TimesheetCalculator.calculateEmployeeSiteHours(targetId, allRecords);
                              if (siteBreakdown.isEmpty) return const SizedBox.shrink();

                              final totalSiteHrs = siteBreakdown.values.fold(0.0, (a, b) => a + b);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
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
                                        const Row(
                                          children: [
                                            Icon(Icons.location_city_rounded, color: AppColors.primary, size: 18),
                                            SizedBox(width: 6),
                                            Text(
                                              'Site & Client Man-Hours Logged',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${totalSiteHrs.toStringAsFixed(1)} Site Hrs',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...siteBreakdown.entries.map((entry) {
                                      final cGroup = TimesheetCalculator.resolveClientGroup(entry.key);
                                      Color color = AppColors.primary;
                                      if (cGroup.contains('REELAM') || cGroup.contains('RELAAM')) {
                                        color = const Color(0xFF00897B);
                                      } else if (cGroup.contains('CARRIER')) {
                                        color = const Color(0xFF1E88E5);
                                      } else if (cGroup.contains('MOPA')) {
                                        color = const Color(0xFF5E35B1);
                                      } else if (cGroup.contains('MPM')) {
                                        color = const Color(0xFFFB8C00);
                                      } else if (cGroup.contains('ELV')) {
                                        color = const Color(0xFF8E24AA);
                                      } else if (cGroup.contains('OTHERS')) {
                                        color = const Color(0xFF546E7A);
                                      }
                                      final pct = totalSiteHrs > 0 ? (entry.value / totalSiteHrs).clamp(0.0, 1.0) : 0.0;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                                    const SizedBox(width: 6),
                                                    Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                                Text(
                                                  '${entry.value.toStringAsFixed(1)} hrs (${(pct * 100).toStringAsFixed(0)}%)',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: pct,
                                                minHeight: 4,
                                                backgroundColor: Colors.grey.shade100,
                                                valueColor: AlwaysStoppedAnimation<Color>(color),
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
                            const SizedBox(height: 10),

                            // Filter Label Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _activeFilter == 'overtime'
                                      ? 'Date-Wise Overtime (OT) Log'
                                      : _activeFilter == 'regular'
                                          ? 'Date-Wise Regular Hours Log'
                                          : 'Date-Wise Work Timesheet Log',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (_activeFilter != 'all')
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _activeFilter = 'all'),
                                    icon: const Icon(
                                        Icons.filter_alt_off_rounded,
                                        size: 14),
                                    label: const Text('Clear Filter',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (filteredEntries.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Center(
                                    child: Text(
                                      _activeFilter == 'overtime'
                                          ? 'No overtime (OT) hours logged yet.'
                                          : 'No timesheet entries recorded yet.',
                                      style: const TextStyle(
                                          color: AppColors.textSecondaryLight,
                                          fontSize: 14),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = filteredEntries[index];
                                  return _buildDailyTimesheetCard(
                                      context, entry);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, TimesheetLoaded state) async {
    final db = LocalDatabaseService();
    final currentUser = db.currentUser;

    final emp = db.getEmployees().firstWhere(
          (e) => e.id == widget.employeeId || e.name == widget.employeeName,
          orElse: () => EmployeeEntity(
            id: widget.employeeId ?? currentUser?.id ?? 'EMP',
            employeeCode: 'EMP',
            name: widget.employeeName ?? currentUser?.fullName ?? 'Employee',
            mobileNumber: '',
            email: currentUser?.email ?? '',
            designation: 'Field Staff',
            department: 'Operations',
          ),
        );

    final records = db.getAttendanceRecords().where((r) {
      return r.employeeId == emp.id ||
          r.employeeName.toLowerCase() == emp.name.toLowerCase();
    }).toList();

    try {
      await PdfExportService.downloadEmployeeAttendancePdfFile(
        organizationName: db.organization?.name ?? 'Fusion Enterprise',
        employee: emp,
        records: records,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timesheet PDF report ready for download/saving!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading timesheet PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTimesheetCard(
      BuildContext context, DailyTimesheetEntry entry) {
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final String checkInStr = entry.checkInTime != null
        ? timeFormat.format(entry.checkInTime!.toLocal())
        : '--:--';
    final String checkOutStr = entry.checkOutTime != null
        ? timeFormat.format(entry.checkOutTime!.toLocal())
        : '--:--';

    return InkWell(
      onTap: () => _showDateDetailModal(context, entry),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Completion Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(entry.date),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: entry.isAutoCompleted
                        ? Colors.blue.withValues(alpha: 0.1)
                        : (entry.isCompleted
                            ? AppColors.success.withValues(alpha: 0.1)
                            : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.isAutoCompleted
                        ? 'Auto Checked-Out (8h)'
                        : (entry.isCompleted ? 'Shift Complete' : 'In Progress'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: entry.isAutoCompleted
                          ? Colors.blue.shade800
                          : (entry.isCompleted
                              ? AppColors.success
                              : Colors.grey.shade700),
                    ),
                  ),
                )
              ],
            ),
            const Divider(height: 20),

            // Timestamps & Working Hour Pills
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('In / Out Time',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight)),
                      const SizedBox(height: 2),
                      Text(
                        '$checkInStr - $checkOutStr',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Regular Hours Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Regular',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.primary)),
                      Text(
                        '${entry.regularHours.toStringAsFixed(1)}h',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Overtime (OT) Hours Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: entry.overtimeHours > 0
                        ? Colors.orange.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: entry.overtimeHours > 0
                          ? Colors.orange.shade400
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'OT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: entry.overtimeHours > 0
                              ? Colors.orange.shade900
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '+${entry.overtimeHours.toStringAsFixed(1)}h',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: entry.overtimeHours > 0
                              ? Colors.orange.shade900
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDateDetailModal(BuildContext context, DailyTimesheetEntry entry) {
    final fullFormat = DateFormat('EEEE, dd MMMM yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final checkInStr = entry.checkInTime != null
        ? timeFormat.format(entry.checkInTime!.toLocal())
        : 'Pending';
    final checkOutStr = entry.checkOutTime != null
        ? timeFormat.format(entry.checkOutTime!.toLocal())
        : 'Pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fullFormat.format(entry.date),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildModalDetailRow('Check-In Time:', checkInStr,
                    Icons.login_rounded, AppColors.success),
                const SizedBox(height: 10),
                _buildModalDetailRow(
                    'Check-Out / Leaving Time:',
                    entry.isAutoCompleted
                        ? '$checkOutStr (Auto Check-Out - 8h Regular Shift)'
                        : checkOutStr,
                    Icons.logout_rounded,
                    entry.isAutoCompleted ? Colors.blue.shade700 : AppColors.primary),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Date-Wise Working Hours Breakdown',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownBox(
                        'Regular Time',
                        '${entry.regularHours.toStringAsFixed(1)} hrs',
                        'Max 8.0h / day',
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildBreakdownBox(
                        'Overtime (OT)',
                        '+${entry.overtimeHours.toStringAsFixed(1)} hrs',
                        'Beyond 8.0h',
                        Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                if (entry.siteVisits.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Job Sites Visited Today:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...entry.siteVisits.map((sv) {
                    final sIn = timeFormat.format(sv.checkInTime.toLocal());
                    final sOut = sv.checkOutTime != null
                        ? timeFormat.format(sv.checkOutTime!.toLocal())
                        : 'In Progress';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(sv.siteName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13))),
                          Text('$sIn - $sOut',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight)),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Combined Working Time:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success)),
                      Text(
                        '${entry.totalHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalDetailRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondaryLight)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBreakdownBox(
      String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}
