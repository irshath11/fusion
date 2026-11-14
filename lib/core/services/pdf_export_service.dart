import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../../features/admin/domain/employee_entity.dart';
import '../../features/timesheet/domain/timesheet_entry.dart';
import '../utils/leave_calculator.dart';
import '../utils/salary_cycle_helper.dart';
import '../utils/timesheet_calculator.dart';
import '../utils/employee_directory_helper.dart';
import '../../features/salary/domain/employee_salary_config.dart';
import '../../features/salary/domain/daily_salary_record.dart';
import '../../features/salary/domain/employee_salary_summary.dart';
import '../../features/salary/utils/salary_calculator.dart';
import '../../database/local_database_service.dart';

class PdfExportService {
  /// Generates a formatted PDF binary document for cumulative employee hours report
  static Future<Uint8List> buildCumulativePdfBytes({
    required String organizationName,
    required List<dynamic> employees,
    required List<AttendanceRecord> records,
    String? salaryCyclePeriod,
    SalaryCycle? salaryCycle,
  }) async {
    final pdf = pw.Document();

    final List<Map<String, dynamic>> empRows = [];
    final activeCycle = salaryCycle ?? SalaryCycle.current();

    for (final emp in employees) {
      final empEntity = emp is EmployeeEntity
          ? emp
          : EmployeeEntity(
              id: emp.id ?? '',
              employeeCode: emp.employeeCode ?? '',
              name: emp.name ?? '',
              mobileNumber: emp.mobileNumber ?? '',
              email: emp.email ?? '',
              designation: emp.designation ?? '',
              department: emp.department ?? 'General',
            );

      final empRecords = records.where((r) {
        return EmployeeDirectoryHelper.matchesEmployeeIdentity(
          recordEmployeeId: r.employeeId,
          recordEmployeeName: r.employeeName,
          employeeId: empEntity.id,
          employeeCode: empEntity.employeeCode,
          employeeName: empEntity.name,
          employeeEmail: empEntity.email,
        );
      }).toList();

      // Strictly clamp attendance records to the salary cycle range
      final cycleRecords = empRecords
          .where((r) => activeCycle.contains(r.eventTimestamp))
          .toList();

      final timesheets = TimesheetCalculator.calculateDailyTimesheets(
        cycleRecords,
        targetEmployeeId: empEntity.id,
        targetEmployeeName: empEntity.name,
        startDate: activeCycle.startDate,
        endDate: activeCycle.endDate,
      );

      double regHours = 0.0;
      double otHours = 0.0;

      for (final t in timesheets) {
        regHours += t.regularHours;
        otHours += t.overtimeHours;
      }

      final leaveSummary = LeaveCalculator.calculateEmployeeLeave(
        empEntity,
        cycleRecords,
        activeCycle,
      );

      final int daysWorked = leaveSummary.daysWorked;

      empRows.add({
        'code': empEntity.employeeCode,
        'name': empEntity.name,
        'dept': empEntity.department.isNotEmpty ? empEntity.department : 'General',
        'days': daysWorked,
        'leaves': leaveSummary.leaveDays,
        'sundays': leaveSummary.sundayWeeklyOffs,
        'reg': regHours,
        'ot': otHours,
        'combined': regHours + otHours,
      });
    }

    // Split workforce into active staff (days > 0) and zero days staff (days == 0)
    final activeEmpRows = empRows.where((r) => (r['days'] as int) > 0).toList();
    final zeroDaysEmpRows = empRows.where((r) => (r['days'] as int) == 0).toList();

    double activeReg = 0.0;
    double activeOt = 0.0;
    int activeDays = 0;
    int activeLeaves = 0;
    int activeSundays = 0;
    for (final r in activeEmpRows) {
      activeReg += (r['reg'] as double);
      activeOt += (r['ot'] as double);
      activeDays += (r['days'] as int);
      activeLeaves += (r['leaves'] as int);
      activeSundays += (r['sundays'] as int);
    }
    final activeCombined = activeReg + activeOt;

    int zeroLeaves = 0;
    int zeroSundays = 0;
    for (final r in zeroDaysEmpRows) {
      zeroLeaves += (r['leaves'] as int);
      zeroSundays += (r['sundays'] as int);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'WORKFORCE CUMULATIVE WORK HOURS REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      organizationName,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (salaryCyclePeriod != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.indigo50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.indigo300, width: 0.5),
                        ),
                        child: pw.Text(
                          'SALARY CYCLE: $salaryCyclePeriod (25th - 24th Cutoff)',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.purple50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.purple300, width: 0.5),
                      ),
                      child: pw.Text(
                        'LEAVE POLICY: Sunday is the only day of leave in a week (Mon-Sat working days)',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple900,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Tab 1: Executive Summary - Employees with Working Days
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.indigo200, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.indigo900,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(5),
                        topRight: pw.Radius.circular(5),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'SUMMARY: EMPLOYEES WITH WORKING DAYS',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          '${activeEmpRows.length} Active Staff',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(children: [
                          pw.Text('Active Staff', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${activeEmpRows.length}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Days Worked', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${activeDays}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Leaves Taken', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${activeLeaves}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: activeLeaves > 0 ? PdfColors.red800 : PdfColors.green800)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Sunday Offs', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${activeSundays}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Regular Hours', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${activeReg.toStringAsFixed(1)}h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Overtime OT', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('+${activeOt.toStringAsFixed(1)}h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Combined Total', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${activeCombined.toStringAsFixed(1)}h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab 2: Executive Summary - Employees with Zero Working Days
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red50 : PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                  color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red200 : PdfColors.blueGrey200,
                  width: 0.8,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red900 : PdfColors.blueGrey700,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(5),
                        topRight: pw.Radius.circular(5),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'SUMMARY: EMPLOYEES WITH ZERO WORKING DAYS',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          '${zeroDaysEmpRows.length} Staff (0 Shifts Logged)',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(children: [
                          pw.Text('Zero Days Staff', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${zeroDaysEmpRows.length}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red900 : PdfColors.grey700)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Days Worked', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('0d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Leaves / Absent', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${zeroLeaves}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: zeroLeaves > 0 ? PdfColors.red800 : PdfColors.grey700)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Sunday Offs', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${zeroSundays}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Regular Hours', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('0.0h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Overtime OT', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('+0.0h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        ]),
                        pw.Column(children: [
                          pw.Text('Combined Total', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('0.0h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),

            // Section 1 Header: Active Workforce (Worked >= 1 Day)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ACTIVE CONTRIBUTING WORKFORCE (Worked >= 1 Day)',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.green300, width: 0.5),
                  ),
                  child: pw.Text(
                    '${activeEmpRows.length} Active Staff',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            if (activeEmpRows.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'No active employees logged work shifts during this salary cycle.',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Emp Code', 'Employee Name', 'Department', 'Worked', 'Leaves Taken', 'Sun Off', 'Regular', 'OT', 'Combined Total'],
                data: [
                  ...activeEmpRows.map((row) => [
                    row['code'],
                    row['name'],
                    row['dept'],
                    '${row['days']}d',
                    '${row['leaves']}d',
                    '${row['sundays']}d',
                    '${(row['reg'] as double).toStringAsFixed(1)}h',
                    '+${(row['ot'] as double).toStringAsFixed(1)}h',
                    '${(row['combined'] as double).toStringAsFixed(1)}h',
                  ]),
                  [
                    'SUBTOTAL',
                    '${activeEmpRows.length} Active Staff',
                    'Active Depts',
                    '${activeDays}d',
                    '${activeLeaves}d',
                    '${activeSundays}d',
                    '${activeReg.toStringAsFixed(1)}h',
                    '+${activeOt.toStringAsFixed(1)}h',
                    '${activeCombined.toStringAsFixed(1)}h',
                  ],
                ],
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.2),
                  2: pw.FlexColumnWidth(1.6),
                  3: pw.FlexColumnWidth(1.0),
                  4: pw.FlexColumnWidth(1.1),
                  5: pw.FlexColumnWidth(1.0),
                  6: pw.FlexColumnWidth(1.2),
                  7: pw.FlexColumnWidth(1.1),
                  8: pw.FlexColumnWidth(1.4),
                },
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 16),

            // Section 2 Header: Personnel with Zero Days Worked
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PERSONNEL WITH ZERO DAYS WORKED (0 Shifts Logged in Cycle)',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red900 : PdfColors.grey700,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red50 : PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(
                      color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red300 : PdfColors.green300,
                      width: 0.5,
                    ),
                  ),
                  child: pw.Text(
                    '${zeroDaysEmpRows.length} Staff (0 Days Worked)',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: zeroDaysEmpRows.isNotEmpty ? PdfColors.red900 : PdfColors.green900,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            if (zeroDaysEmpRows.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.green200, width: 0.5),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'All ${employees.length} registered employees have active attendance logged in this salary cycle.',
                    style: pw.TextStyle(fontSize: 8.5, color: PdfColors.green900, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Emp Code', 'Employee Name', 'Department', 'Worked', 'Leaves / Absent', 'Sunday Off', 'Status / Remarks'],
                data: [
                  ...zeroDaysEmpRows.map((row) => [
                    row['code'],
                    row['name'],
                    row['dept'],
                    '0d',
                    '${row['leaves']}d',
                    '${row['sundays']}d',
                    '0 Shifts Recorded (Zero Duty Hours)',
                  ]),
                  [
                    'SUBTOTAL',
                    '${zeroDaysEmpRows.length} Staff',
                    'All Depts',
                    '0d',
                    '${zeroLeaves}d',
                    '${zeroSundays}d',
                    'No logged attendance in cycle',
                  ],
                ],
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.2),
                  2: pw.FlexColumnWidth(1.6),
                  3: pw.FlexColumnWidth(1.0),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(1.0),
                  6: pw.FlexColumnWidth(2.6),
                },
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 16),

            // Site / Client Man-Hours Breakdown in Cumulative Report
            () {
              final siteSummaries = TimesheetCalculator.calculateSiteManHours(records);
              final totalSiteHours = siteSummaries.fold(0.0, (acc, s) => acc + s.totalHours);

              if (siteSummaries.isEmpty) return pw.SizedBox.shrink();

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SITE & CLIENT MAN-HOURS BREAKDOWN',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.TableHelper.fromTextArray(
                    headers: ['Site / Client Name', 'Category', 'Total Man-Hours', '% Share', 'Visits', 'Personnel Count'],
                    data: siteSummaries.map((s) {
                      final pct = totalSiteHours > 0 ? (s.totalHours / totalSiteHours * 100).toStringAsFixed(1) : '0.0';
                      return [
                        s.siteName,
                        s.clientGroup,
                        '${s.totalHours.toStringAsFixed(1)}h',
                        '$pct%',
                        '${s.totalVisits}',
                        '${s.distinctEmployeesCount} Staff',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                    cellStyle: const pw.TextStyle(fontSize: 8.5),
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ],
              );
            }(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a dedicated binary PDF document for Site & Client Man-Hours Report
  static Future<Uint8List> buildSiteManHoursPdfBytes({
    required String organizationName,
    required List<AttendanceRecord> records,
    DateTime? startDate,
    DateTime? endDate,
    bool groupByClient = false,
  }) async {
    final pdf = pw.Document();

    final summaries = TimesheetCalculator.calculateSiteManHours(
      records,
      startDate: startDate,
      endDate: endDate,
      groupByClient: groupByClient,
    );

    final totalManHours = summaries.fold(0.0, (acc, s) => acc + s.totalHours);
    final totalVisits = summaries.fold(0, (acc, s) => acc + s.totalVisits);
    final topSite = summaries.isNotEmpty ? summaries.first.siteName : 'None';

    String periodStr = 'All Recorded Time';
    if (startDate != null && endDate != null) {
      periodStr = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
    } else if (startDate != null) {
      periodStr = 'From ${DateFormat('dd MMM yyyy').format(startDate)}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      groupByClient
                          ? 'CLIENT MAN-HOURS EXECUTIVE REPORT'
                          : 'SITE & CLIENT MAN-HOURS DETAILED REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$organizationName | Period: $periodStr',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Summary Header Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blueGrey200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Text('Total Site Man-Hours', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${totalManHours.toStringAsFixed(1)}h', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Active Sites/Clients', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${summaries.length}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Total Site Visits', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('$totalVisits', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Top Client / Site', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(topSite, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Site & Client Table
            pw.TableHelper.fromTextArray(
              headers: ['Site / Client Name', 'Category', 'Total Man-Hours', '% Share', 'Visits', 'Staff Count', 'Top Contributing Personnel'],
              data: summaries.map((s) {
                final pct = totalManHours > 0 ? (s.totalHours / totalManHours * 100).toStringAsFixed(1) : '0.0';
                final topStaff = s.employeeContributions
                    .take(2)
                    .map((e) => '${e.employeeName} (${e.totalHours.toStringAsFixed(1)}h)')
                    .join(', ');

                return [
                  s.siteName,
                  s.clientGroup,
                  '${s.totalHours.toStringAsFixed(1)}h',
                  '$pct%',
                  '${s.totalVisits}',
                  '${s.distinctEmployeesCount}',
                  topStaff.isNotEmpty ? topStaff : '--',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers native download / print / share dialog for Site Man-Hours PDF
  static Future<void> downloadSiteManHoursPdfFile({
    required String organizationName,
    required List<AttendanceRecord> records,
    DateTime? startDate,
    DateTime? endDate,
    bool groupByClient = false,
  }) async {
    final pdfBytes = await buildSiteManHoursPdfBytes(
      organizationName: organizationName,
      records: records,
      startDate: startDate,
      endDate: endDate,
      groupByClient: groupByClient,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Site_and_Client_Man_Hours_Report.pdf',
    );
  }

  /// Triggers native download / print / share dialog for Cumulative PDF File
  static Future<void> downloadCumulativePdfFile({
    required String organizationName,
    required List<dynamic> employees,
    required List<AttendanceRecord> records,
    String? salaryCyclePeriod,
    SalaryCycle? salaryCycle,
  }) async {
    final pdfBytes = await buildCumulativePdfBytes(
      organizationName: organizationName,
      employees: employees,
      records: records,
      salaryCyclePeriod: salaryCyclePeriod,
      salaryCycle: salaryCycle,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Cumulative_Workforce_Attendance_Report.pdf',
    );
  }

  /// Generates a binary PDF document for an individual employee's detailed attendance report
  static Future<Uint8List> buildEmployeeAttendancePdfBytes({
    required String organizationName,
    required dynamic employee,
    required List<AttendanceRecord> records,
    String? salaryCyclePeriod,
    SalaryCycle? salaryCycle,
  }) async {
    final pdf = pw.Document();
    final activeCycle = salaryCycle ?? SalaryCycle.current();

    final String empName = employee.name ?? 'Employee';
    final String empCode = employee.employeeCode ?? 'EMP';
    final String department = employee.department ?? 'General';
    final String empId = employee.id ?? '';

    final empEntity = employee is EmployeeEntity
        ? employee
        : EmployeeEntity(
            id: empId,
            employeeCode: empCode,
            name: empName,
            mobileNumber: employee.mobileNumber ?? '',
            email: employee.email ?? '',
            designation: employee.designation ?? '',
            department: department,
          );

    // Filter records strictly belonging to this employee and strictly within activeCycle
    final cycleRecords = records.where((r) {
      final isEmp = EmployeeDirectoryHelper.matchesEmployeeIdentity(
        recordEmployeeId: r.employeeId,
        recordEmployeeName: r.employeeName,
        employeeId: empEntity.id,
        employeeCode: empEntity.employeeCode,
        employeeName: empEntity.name,
        employeeEmail: empEntity.email,
      );
      return isEmp && activeCycle.contains(r.eventTimestamp);
    }).toList();

    final timesheets = TimesheetCalculator.calculateDailyTimesheets(
      cycleRecords,
      targetEmployeeId: empEntity.id,
      targetEmployeeName: empEntity.name,
      startDate: activeCycle.startDate,
      endDate: activeCycle.endDate,
    );

    double totalReg = 0.0;
    double totalOt = 0.0;
    int totalBreakMinutes = 0;
    for (final t in timesheets) {
      totalReg += t.regularHours;
      totalOt += t.overtimeHours;
      totalBreakMinutes += t.breakDuration.inMinutes;
    }

    final empLeaveSummary = LeaveCalculator.calculateEmployeeLeave(
      empEntity,
      cycleRecords,
      activeCycle,
    );

    final employeeSiteHours = TimesheetCalculator.calculateEmployeeSiteHours(empId, cycleRecords);

    // Map daily timesheets by date string (yyyy-MM-dd)
    final Map<String, DailyTimesheetEntry> timesheetMap = {};
    for (final t in timesheets) {
      timesheetMap[DateFormat('yyyy-MM-dd').format(t.date)] = t;
    }

    // Prepare chronological ledger rows combining working days, leaves, and Sunday offs
    final List<List<String>> ledgerRows = [];
    final Set<String> processedDates = {};

    for (final d in empLeaveSummary.dailyRecords) {
      final dateStr = DateFormat('yyyy-MM-dd').format(d.date);
      final dayStr = DateFormat('EEE').format(d.date);
      processedDates.add(dateStr);

      final t = timesheetMap[dateStr];
      String statusStr;
      String inTime = '--:--';
      String outTime = '--:--';
      String regStr = '0.0h';
      String otStr = '+0.0h';
      String siteActivity = '';

      switch (d.type) {
        case LeaveDayType.present:
          statusStr = 'Present';
          if (t != null) {
            inTime = t.checkInTime != null ? DateFormat('HH:mm').format(t.checkInTime!) : '--:--';
            outTime = t.checkOutTime != null ? DateFormat('HH:mm').format(t.checkOutTime!) : '--:--';
            regStr = '${t.regularHours.toStringAsFixed(1)}h';
            otStr = '+${t.overtimeHours.toStringAsFixed(1)}h';
            final resolvedSites = records
                .where((r) => DateFormat('yyyy-MM-dd').format(r.eventTimestamp) == dateStr)
                .map((r) => TimesheetCalculator.resolveSiteName(r))
                .toSet()
                .where((s) => s.isNotEmpty && s != 'Work Site')
                .join(', ');
            final assignedName = (employee.assignedOfficeName != null && employee.assignedOfficeName.toString().trim().isNotEmpty)
                ? employee.assignedOfficeName.toString().trim()
                : 'Main Location';
            siteActivity = t.siteVisits.isNotEmpty
                ? t.siteVisits.map((sv) => sv.siteName).toSet().join(', ')
                : (resolvedSites.isNotEmpty ? resolvedSites : assignedName);
          }
          break;

        case LeaveDayType.leaveAbsent:
          statusStr = 'LEAVE TAKEN';
          siteActivity = 'Absence on Working Day';
          break;

        case LeaveDayType.sundayWeeklyOff:
          statusStr = 'Sunday Off';
          siteActivity = 'Designated Weekly Off';
          break;

        case LeaveDayType.sundayDuty:
          statusStr = 'Sunday Duty';
          if (t != null) {
            inTime = t.checkInTime != null ? DateFormat('HH:mm').format(t.checkInTime!) : '--:--';
            outTime = t.checkOutTime != null ? DateFormat('HH:mm').format(t.checkOutTime!) : '--:--';
            regStr = '${t.regularHours.toStringAsFixed(1)}h';
            otStr = '+${t.overtimeHours.toStringAsFixed(1)}h';
            final resolvedSites = records
                .where((r) => DateFormat('yyyy-MM-dd').format(r.eventTimestamp) == dateStr)
                .map((r) => TimesheetCalculator.resolveSiteName(r))
                .toSet()
                .where((s) => s.isNotEmpty && s != 'Work Site')
                .join(', ');
            siteActivity = t.siteVisits.isNotEmpty
                ? t.siteVisits.map((sv) => sv.siteName).toSet().join(', ')
                : (resolvedSites.isNotEmpty ? resolvedSites : 'Sunday Duty');
          }
          break;

        case LeaveDayType.futureDay:
          statusStr = 'Upcoming';
          regStr = '--';
          otStr = '--';
          siteActivity = 'Scheduled Working Day';
          break;
      }

      ledgerRows.add([dateStr, dayStr, statusStr, inTime, outTime, regStr, otStr, siteActivity]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EMPLOYEE ATTENDANCE & TIMESHEET REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$organizationName | $empName ($empCode)',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (salaryCyclePeriod != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.indigo50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.indigo300, width: 0.5),
                        ),
                        child: pw.Text(
                          'SALARY CYCLE: $salaryCyclePeriod (25th - 24th Cutoff)',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.purple50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.purple300, width: 0.5),
                      ),
                      child: pw.Text(
                        'LEAVE POLICY: Sunday is the only day of leave in a week (Mon-Sat working days)',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple900,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Employee Executive Summary Card with Leave Taken Data Count
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blueGrey200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Text('Department', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(department, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Work Days', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${empLeaveSummary.elapsedWorkingDays}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Days Worked', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${empLeaveSummary.daysWorked}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Leaves Taken', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${empLeaveSummary.leaveDays}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: empLeaveSummary.leaveDays > 0 ? PdfColors.red800 : PdfColors.green800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Sunday Offs', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${empLeaveSummary.sundayWeeklyOffs}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                  ]),
                  if (empLeaveSummary.sundayDutyDays > 0)
                    pw.Column(children: [
                      pw.Text('Sunday Duty', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('${empLeaveSummary.sundayDutyDays}d', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                    ]),
                  pw.Column(children: [
                    pw.Text('Attendance', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${empLeaveSummary.attendancePercentage.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Regular Hours', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${totalReg.toStringAsFixed(1)}h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Overtime OT', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('+${totalOt.toStringAsFixed(1)}h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                  ]),
                  if (totalBreakMinutes > 0)
                    pw.Column(children: [
                      pw.Text('Total Break', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text('${totalBreakMinutes}m', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                    ]),
                  pw.Column(children: [
                    pw.Text('Combined Total', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${(totalReg + totalOt).toStringAsFixed(1)}h', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Callout banner if leaves were taken
            if (empLeaveSummary.leaveDays > 0) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.red300, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LEAVES RECORDED (${empLeaveSummary.leaveDays} Days): ',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        empLeaveSummary.dailyRecords
                            .where((d) => d.type == LeaveDayType.leaveAbsent)
                            .map((d) => DateFormat('yyyy-MM-dd (EEE)').format(d.date))
                            .join(', '),
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.red900),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],

            // Daily Timesheet & Leave Records Table
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Day', 'Attendance / Leave Status', 'In Time', 'Out Time', 'Regular', 'OT', 'Site / Activity Note'],
              data: [
                ...ledgerRows,
                [
                  'TOTAL',
                  '${empLeaveSummary.elapsedDays} Days',
                  '${empLeaveSummary.workingDaysPresent} Worked | ${empLeaveSummary.leaveDays} Leaves | ${empLeaveSummary.sundayWeeklyOffs} Sun Offs',
                  '',
                  '',
                  '${totalReg.toStringAsFixed(1)}h',
                  '+${totalOt.toStringAsFixed(1)}h',
                  '${(totalReg + totalOt).toStringAsFixed(1)}h Net',
                ],
              ],
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(0.7),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FlexColumnWidth(0.9),
                4: pw.FlexColumnWidth(0.9),
                5: pw.FlexColumnWidth(1.0),
                6: pw.FlexColumnWidth(1.0),
                7: pw.FlexColumnWidth(2.5),
              },
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              cellAlignment: pw.Alignment.centerLeft,
            ),

            if (employeeSiteHours.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'SITE & CLIENT HOURS SUMMARY FOR ${empName.toUpperCase()}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Site / Client Name', 'Category', 'Logged Hours'],
                data: employeeSiteHours.entries.map((e) {
                  return [
                    e.key,
                    TimesheetCalculator.resolveClientGroup(e.key),
                    '${e.value.toStringAsFixed(1)}h',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers native download / print for individual Employee PDF
  static Future<void> downloadEmployeeAttendancePdfFile({
    required String organizationName,
    required dynamic employee,
    required List<AttendanceRecord> records,
    String? salaryCyclePeriod,
    SalaryCycle? salaryCycle,
  }) async {
    final pdfBytes = await buildEmployeeAttendancePdfBytes(
      organizationName: organizationName,
      employee: employee,
      records: records,
      salaryCyclePeriod: salaryCyclePeriod,
      salaryCycle: salaryCycle,
    );

    final String rawName = (employee.name ?? 'Employee');
    final safeName = rawName.replaceAll(RegExp(r'[^\w\s]+'), '_');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${safeName}_Attendance_Report.pdf',
    );
  }

  /// Generates a binary PDF document for workforce leave records report
  static Future<Uint8List> buildLeaveReportPdfBytes({
    required String organizationName,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required SalaryCycle cycle,
  }) async {
    final pdf = pw.Document();
    final summaries = LeaveCalculator.calculateWorkforceLeaveSummaries(
      employees,
      records,
      cycle,
    );
    final metrics = LeaveCalculator.calculateWorkforceMetrics(summaries, cycle);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'WORKFORCE LEAVE & ATTENDANCE RECORD',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$organizationName | Salary Cycle: ${cycle.shortPeriodLabel}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.purple50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.purple300, width: 0.5),
                      ),
                      child: pw.Text(
                        'POLICY: Sunday is the only day of leave in a week (Mon-Sat working days)',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple900,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Summary Header Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blueGrey200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Text('Total Staff', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${metrics.totalEmployees}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Working Days', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${metrics.totalWorkforceWorkingDays}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Days Worked', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${metrics.totalWorkforceDaysWorked}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Leaves (Absent)', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${metrics.totalWorkforceLeavesTaken}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Sunday Offs', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${metrics.totalWorkforceSundayOffs}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Avg Attendance', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('${metrics.averageAttendanceRate.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Workforce Leave Summary Table
            pw.TableHelper.fromTextArray(
              headers: ['Emp Code', 'Employee Name', 'Department', 'Working Days', 'Worked', 'Leaves', 'Sunday Off', 'Sun Duty', 'Attendance %'],
              data: summaries.map((s) => [
                s.employee.employeeCode,
                s.employee.name,
                s.employee.department,
                '${s.elapsedWorkingDays}',
                '${s.daysWorked}',
                '${s.leaveDays}',
                '${s.sundayWeeklyOffs}',
                '${s.sundayDutyDays}',
                '${s.attendancePercentage.toStringAsFixed(1)}%',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 16),

            // Detailed Leave Occurrences Section
            () {
              final employeesWithLeaves = summaries.where((s) => s.leaveDays > 0 || s.sundayDutyDays > 0).toList();
              if (employeesWithLeaves.isEmpty) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Perfect Attendance: No unexcused leaves recorded across the workforce for this cycle!',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                    ),
                  ),
                );
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EMPLOYEE LEAVE & ABSENCE OCCURRENCES (EXCLUDING SUNDAY WEEKLY OFFS)',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                  pw.SizedBox(height: 6),
                  ...employeesWithLeaves.map((s) {
                    final leaves = s.leaveDaysOnly;
                    final sunDuty = s.dailyRecords.where((d) => d.type == LeaveDayType.sundayDuty).toList();
                    final leaveDatesStr = leaves.isNotEmpty
                        ? leaves.map((l) => '${l.shortDayOfWeek} ${DateFormat('dd MMM').format(l.date)}').join(', ')
                        : 'None';
                    final sunDutyStr = sunDuty.isNotEmpty
                        ? sunDuty.map((sd) => '${DateFormat('dd MMM').format(sd.date)} (${sd.totalHours.toStringAsFixed(1)}h)').join(', ')
                        : 'None';

                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 140,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('${s.employee.name} (${s.employee.employeeCode})',
                                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                                pw.Text('${s.employee.department} | ${s.leaveDays} Leave Day(s)',
                                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Leaves / Absences: $leaveDatesStr',
                                    style: pw.TextStyle(fontSize: 8, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                                if (sunDuty.isNotEmpty)
                                  pw.Text('Sunday Duties Worked: $sunDutyStr',
                                      style: pw.TextStyle(fontSize: 7.5, color: PdfColors.orange900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers native download / print / share dialog for Workforce Leave Report PDF File
  static Future<void> downloadLeaveReportPdfFile({
    required String organizationName,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required SalaryCycle cycle,
  }) async {
    final pdfBytes = await buildLeaveReportPdfBytes(
      organizationName: organizationName,
      employees: employees,
      records: records,
      cycle: cycle,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Workforce_Leave_Record_Report_${cycle.id}.pdf',
    );
  }

  /// Legacy text-based cumulative generator
  static Future<String> generateCumulativePdfReport({
    required String organizationName,
    required List<dynamic> employees,
    required List<AttendanceRecord> records,
  }) async {
    final pdfBytes = await buildCumulativePdfBytes(
      organizationName: organizationName,
      employees: employees,
      records: records,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Cumulative_Workforce_Attendance_Report.pdf',
    );
    return 'Cumulative PDF report downloaded.';
  }

  // ===========================================================================
  // WORKFORCE SALARY & PAYROLL PDF GENERATION
  // ===========================================================================

  /// Builds a formatted workforce payroll sheet PDF for a salary cycle
  static Future<Uint8List> buildWorkforceSalaryPdfBytes({
    required String organizationName,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required SalaryCycle cycle,
    Map<String, EmployeeSalaryConfig>? salaryConfigs,
  }) async {
    final pdf = pw.Document();
    final configs = salaryConfigs ?? LocalDatabaseService().getEmployeeSalaryMap();

    final workforceSummary = SalaryCalculator.calculateWorkforcePayroll(
      employees: employees,
      salaryConfigs: configs,
      records: records,
      cycle: cycle,
    );

    final summaries = workforceSummary.employeeSummaries;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      organizationName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'OFFICIAL WORKFORCE SALARY & PAYROLL REGISTER',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'SALARY CYCLE: ${cycle.shortPeriodLabel}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo800,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat("dd MMM yyyy, HH:mm").format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Summary Financial Metrics Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.indigo200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Payroll Cost', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text(
                        'AED ${workforceSummary.totalPayroll.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Fixed Earned', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text(
                        'AED ${workforceSummary.totalFixedEarned.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Variable Earned', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text(
                        'AED ${workforceSummary.totalVariableEarned.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Overtime Earned (${workforceSummary.totalOtHours.toStringAsFixed(1)}h)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text(
                        'AED ${workforceSummary.totalOtEarned.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Payable Days', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text(
                        '${workforceSummary.totalWorkforcePayableDays}d (${workforceSummary.totalWorkforceDaysWorked}d worked + ${workforceSummary.totalWorkforcePaidSundays}d Sun)',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Main Payroll Table
            pw.TableHelper.fromTextArray(
              headers: [
                'Code',
                'Employee Name',
                'Dept',
                'Fixed',
                'Variable',
                'Worked',
                'Sun Off',
                'Payable',
                'Earned Fixed',
                'Earned Var',
                'OT Hours',
                'Earned OT',
                'Total Salary (AED)',
              ],
              data: [
                ...summaries.map((s) => [
                      s.employeeCode,
                      s.employeeName,
                      s.department,
                      s.config.fixedSalary.toStringAsFixed(0),
                      s.config.variableSalary.toStringAsFixed(0),
                      '${s.daysWorked}d',
                      '+${s.paidSundays}d',
                      '${s.totalPayableDays}d',
                      s.earnedFixedSalary.toStringAsFixed(2),
                      s.earnedVariableSalary.toStringAsFixed(2),
                      '${s.totalOvertimeHours.toStringAsFixed(1)}h',
                      s.earnedOtSalary.toStringAsFixed(2),
                      s.grossTotalSalary.toStringAsFixed(2),
                    ]),
                [
                  'TOTAL',
                  '${summaries.length} Employees',
                  '',
                  '',
                  '',
                  '${workforceSummary.totalWorkforceDaysWorked}d',
                  '${workforceSummary.totalWorkforcePaidSundays}d',
                  '${workforceSummary.totalWorkforcePayableDays}d',
                  workforceSummary.totalFixedEarned.toStringAsFixed(2),
                  workforceSummary.totalVariableEarned.toStringAsFixed(2),
                  '${workforceSummary.totalOtHours.toStringAsFixed(1)}h',
                  workforceSummary.totalOtEarned.toStringAsFixed(2),
                  workforceSummary.totalPayroll.toStringAsFixed(2),
                ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 14),

            // Policy & Footnote
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Salary Calculation Rules: Daily Basic = Basic/Days in Month • Daily Variable = Variable/Days in Month • Hourly OT Rate = (Basic Salary / Days in Month) / 8 hrs (Variable allowance is strictly excluded from OT rate calculation). '
                'In-between Sundays surrounded by worked days are credited as Paid Weekly Offs (e.g. 8 worked days + 1 in-between Sunday = 9 credited days). Total Salary = Earned Basic + Earned Variable + Earned OT.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports workforce salary PDF and opens native sharing dialog
  static Future<void> exportWorkforceSalaryPdf({
    required String organizationName,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required SalaryCycle cycle,
  }) async {
    final bytes = await buildWorkforceSalaryPdfBytes(
      organizationName: organizationName,
      employees: employees,
      records: records,
      cycle: cycle,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Workforce_Salary_Payroll_${cycle.id}.pdf',
    );
  }

  /// Exports individual employee payslip PDF with day-by-day calculations
  static Future<void> exportEmployeeSalarySlipPdf({
    required String organizationName,
    required EmployeeSalarySummary summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Company Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      organizationName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.Text('EMPLOYEE PAYSLIP & DAY-WISE LEDGER', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Period: ${summary.cycle.shortPeriodLabel}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateFormat("dd MMM yyyy").format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Employee Profile & Salary Base Details
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee Name: ${summary.employeeName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Employee Code: ${summary.employeeCode}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Department: ${summary.department}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Monthly Fixed: AED ${summary.config.fixedSalary.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Monthly Variable: AED ${summary.config.variableSalary.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Daily Rate: AED ${summary.config.dailyBaseRate.toStringAsFixed(2)}/day', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Hourly OT Rate: AED ${summary.hourlyOtRate.toStringAsFixed(2)}/hr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange900)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Pay Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.indigo200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NET SALARY CREDITED: AED ${summary.grossTotalSalary.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                  pw.Text(
                    '${summary.totalPayableDays} Payable Days (${summary.daysWorked}d worked + ${summary.paidSundays}d Sun off)',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Day-Wise Calculation Ledger Table
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Day', 'Status', 'Regular', 'OT Hours', 'Fixed', 'Variable', 'OT Credit', 'Day Total', 'Cumul Total'],
              data: summary.dailyRecords.map((r) => [
                    DateFormat('dd MMM').format(r.date),
                    DateFormat('EEE').format(r.date),
                    r.status.label,
                    '${r.regularHours.toStringAsFixed(1)}h',
                    '${r.overtimeHours.toStringAsFixed(1)}h',
                    r.isPayable ? r.dailyFixedCredit.toStringAsFixed(1) : '-',
                    r.isPayable ? r.dailyVariableCredit.toStringAsFixed(1) : '-',
                    r.dailyOtCredit > 0 ? r.dailyOtCredit.toStringAsFixed(1) : '-',
                    r.isPayable ? r.dailyTotalSalary.toStringAsFixed(2) : '-',
                    r.isPayable ? r.cumulativeSalary.toStringAsFixed(2) : '-',
                  ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Note: Hourly Overtime Rate is strictly derived from Basic Salary ONLY: (Basic Salary / Days in Month) / 8 hrs. Variable allowance is excluded from the OT rate calculation.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Payslip_${summary.employeeCode}_${summary.cycle.id}.pdf',
    );
  }
}

