import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../../core/widgets/status_badge.dart';
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
  String _activeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => TimesheetCubit()
        ..fetchEmployeeTimesheet(employeeId: widget.employeeId),
      child: BlocBuilder<TimesheetCubit, TimesheetState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor:
                isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            appBar: AppBar(
              title: Text(
                widget.employeeName != null
                    ? '${widget.employeeName} - Timesheet'
                    : 'Work Timesheets',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              actions: [
                if (state is TimesheetLoaded)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: BouncingButton(
                      onTap: () => _downloadPdf(context, state),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'PDF Report',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.error, fontSize: 15),
                    ),
                  );
                } else if (state is TimesheetLoaded) {
                  final filteredEntries = state.entries.where((e) {
                    if (_activeFilter == 'overtime') return e.overtimeHours > 0;
                    if (_activeFilter == 'regular') return e.regularHours > 0;
                    return true;
                  }).toList();

                  return RefreshIndicator(
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
                          // Interactive Executive KPI Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricTile(
                                  title: 'Regular Time',
                                  value:
                                      '${state.totalRegularHours.toStringAsFixed(1)}h',
                                  subtitle: 'Max 8h / Shift',
                                  icon: Icons.access_time_rounded,
                                  color: AppColors.primary,
                                  isSelected: _activeFilter == 'regular',
                                  isDark: isDark,
                                  onTap: () {
                                    setState(() {
                                      _activeFilter = _activeFilter == 'regular'
                                          ? 'all'
                                          : 'regular';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricTile(
                                  title: 'Overtime (OT)',
                                  value:
                                      '+${state.totalOvertimeHours.toStringAsFixed(1)}h',
                                  subtitle: 'Hours Beyond 8.0h',
                                  icon: Icons.more_time_rounded,
                                  color: Colors.amber.shade700,
                                  isSelected: _activeFilter == 'overtime',
                                  isDark: isDark,
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
                                child: _buildMetricTile(
                                  title: 'Total Hours',
                                  value:
                                      '${state.totalCombinedHours.toStringAsFixed(1)}h',
                                  subtitle: 'Reg + OT Combined',
                                  icon: Icons.timer_rounded,
                                  color: AppColors.success,
                                  isSelected: _activeFilter == 'all',
                                  isDark: isDark,
                                  onTap: () =>
                                      setState(() => _activeFilter = 'all'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricTile(
                                  title: 'Days Worked',
                                  value: '${state.totalDaysWorked}',
                                  subtitle: 'Logged Sessions',
                                  icon: Icons.calendar_month_rounded,
                                  color: AppColors.secondary,
                                  isSelected: false,
                                  isDark: isDark,
                                  onTap: () =>
                                      setState(() => _activeFilter = 'all'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Header with filter toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _activeFilter == 'overtime'
                                    ? 'Overtime Sessions'
                                    : _activeFilter == 'regular'
                                        ? 'Regular Shift Sessions'
                                        : 'Timesheet History',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              if (_activeFilter != 'all')
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _activeFilter = 'all'),
                                  icon: const Icon(
                                      Icons.filter_alt_off_rounded,
                                      size: 14),
                                  label: Text(
                                    'Clear Filter',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (filteredEntries.isEmpty)
                            GlassSurfaceCard(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  _activeFilter == 'overtime'
                                      ? 'No overtime (OT) hours logged.'
                                      : 'No timesheet entries recorded.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textSecondaryLight,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...filteredEntries.map((entry) =>
                                _buildDailyTimesheetCard(
                                    context, entry, isDark)),
                        ],
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
          SnackBar(
            content: Text(
              'Timesheet PDF report ready for download/saving!',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not generate PDF: $e',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark
                    ? AppColors.cardBorderDark
                    : AppColors.cardBorderLight),
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTimesheetCard(
      BuildContext context, DailyTimesheetEntry entry, bool isDark) {
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final String checkInStr = entry.checkInTime != null
        ? timeFormat.format(entry.checkInTime!.toLocal())
        : '--:--';
    final String checkOutStr = entry.checkOutTime != null
        ? timeFormat.format(entry.checkOutTime!.toLocal())
        : '--:--';

    return GlassSurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      onTap: () => _showDateDetailModal(context, entry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(entry.date),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              StatusBadge(
                label: entry.isAutoCompleted
                    ? 'Auto Checked-Out (8h)'
                    : (entry.isCompleted ? 'Shift Done' : 'In Progress'),
                color: entry.isAutoCompleted
                    ? AppColors.primary
                    : (entry.isCompleted
                        ? AppColors.success
                        : AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Span',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$checkInStr - $checkOutStr',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Regular Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Regular',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${entry.regularHours.toStringAsFixed(1)}h',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Overtime Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: entry.overtimeHours > 0
                      ? Colors.amber.withValues(alpha: 0.12)
                      : (isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'OT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: entry.overtimeHours > 0
                            ? Colors.amber.shade700
                            : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textSecondaryLight),
                      ),
                    ),
                    Text(
                      '+${entry.overtimeHours.toStringAsFixed(1)}h',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: entry.overtimeHours > 0
                            ? Colors.amber.shade700
                            : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDateDetailModal(BuildContext context, DailyTimesheetEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      backgroundColor:
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              _buildModalRow(
                  'Check-In Time:', checkInStr, Icons.login_rounded, isDark),
              const SizedBox(height: 10),
              _buildModalRow(
                'Check-Out Time:',
                entry.isAutoCompleted
                    ? '$checkOutStr (Auto 8h Cap)'
                    : checkOutStr,
                Icons.logout_rounded,
                isDark,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildBreakdownBox(
                      'Regular Time',
                      '${entry.regularHours.toStringAsFixed(1)} hrs',
                      'Max 8.0h / Day',
                      AppColors.primary,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildBreakdownBox(
                      'Overtime (OT)',
                      '+${entry.overtimeHours.toStringAsFixed(1)} hrs',
                      'Beyond 8.0h',
                      Colors.amber.shade700,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Shift Working Time:',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${entry.totalHours.toStringAsFixed(1)} hrs',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(
      String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownBox(
      String label, String value, String sub, Color color, bool isDark) {
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
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
