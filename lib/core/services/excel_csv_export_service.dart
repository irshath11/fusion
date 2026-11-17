import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../constants/wps_registry.dart';
import '../utils/salary_cycle_helper.dart';
import '../../features/admin/domain/employee_entity.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../../features/salary/domain/employee_salary_config.dart';
import '../../features/salary/domain/employee_salary_summary.dart';
import '../../features/salary/utils/salary_calculator.dart';

class ExcelCsvExportService {
  /// Generates CSV data for attendance logs (backward compatibility)
  static String generateCsv(List<AttendanceRecord> records) {
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln("Record ID,Employee ID,Workflow Step,Event Time,Latitude,Longitude,Address,Geofence Valid,Sync Status");

    for (final r in records) {
      csvBuffer.writeln(
        '"${r.id}","${r.employeeId}","${r.workflowStep.name}","${r.eventTimestamp}","${r.latitude}","${r.longitude}","${r.address}","${r.isGeofenceValid}","${r.syncStatus.name}"',
      );
    }
    return csvBuffer.toString();
  }

  static String generateExcelData(List<AttendanceRecord> records) {
    return generateCsv(records);
  }

  // ===========================================================================
  // OFFICIAL WPS EXCEL PAYROLL REPORT GENERATION
  // ===========================================================================

  /// Exports official WPS Excel file for Fusion Neo Division
  static Future<void> exportFusionNeoWpsExcel({
    required SalaryCycle cycle,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) async {
    final bytes = await buildWpsSalaryExcelBytes(
      division: 'Neo',
      companyName: 'FUSION NEO BUILDING CONTRACTING LLC',
      molNumber: '2846014',
      cycle: cycle,
      employees: employees,
      records: records,
      salaryConfigs: salaryConfigs,
    );

    final String padMonth = cycle.salaryMonth.toString().padLeft(2, '0');
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'Neo_employees-WPS_${padMonth}-${cycle.salaryYear}.xlsx',
    );
  }

  /// Exports official WPS Excel file for Fusion Electro Division (Fusion Electric)
  static Future<void> exportFusionElectroWpsExcel({
    required SalaryCycle cycle,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) async {
    final bytes = await buildWpsSalaryExcelBytes(
      division: 'Fusion',
      companyName: 'FUSION ELECTRO-MECHANICAL MAINTENANCE LLC',
      molNumber: '803095',
      cycle: cycle,
      employees: employees,
      records: records,
      salaryConfigs: salaryConfigs,
    );

    final String padMonth = cycle.salaryMonth.toString().padLeft(2, '0');
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'Fusion-electro-employees-WPS_${padMonth}-${cycle.salaryYear}.xlsx',
    );
  }

  /// Exports Master Estimated Payroll Details Excel report with executive summary and separate division sheets
  static Future<void> exportMasterEstimatedPayrollExcel({
    required SalaryCycle cycle,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) async {
    final bytes = await buildMasterEstimatedPayrollExcelBytes(
      cycle: cycle,
      employees: employees,
      records: records,
      salaryConfigs: salaryConfigs,
    );

    final String padMonth = cycle.salaryMonth.toString().padLeft(2, '0');
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'Total_Estimated_Payroll_Details_${padMonth}-${cycle.salaryYear}.xlsx',
    );
  }

  /// Builds raw Excel byte array matching the exact company WPS format
  static Future<List<int>> buildWpsSalaryExcelBytes({
    required String division,
    required String companyName,
    required String molNumber,
    required SalaryCycle cycle,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) async {
    final excel = Excel.createExcel();
    final String sheetName = division.toUpperCase() == 'NEO' ? 'Fusion Neo WPS' : 'Fusion Electro WPS';
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
    final Sheet sheet = excel[sheetName];

    // Calculate workforce payroll summaries
    final workforce = SalaryCalculator.calculateWorkforcePayroll(
      employees: employees,
      salaryConfigs: salaryConfigs,
      records: records,
      cycle: cycle,
    );

    final summaryMap = _buildSummaryMap(workforce.employeeSummaries);

    _populateWpsSheet(
      sheet: sheet,
      division: division,
      companyName: companyName,
      molNumber: molNumber,
      cycle: cycle,
      summaryMap: summaryMap,
      salaryConfigs: salaryConfigs,
    );

    final List<int>? encodedBytes = excel.encode();
    return encodedBytes ?? [];
  }

  /// Builds master workbook containing Total Estimated Payroll Details overview + separate division WPS sheets
  static Future<List<int>> buildMasterEstimatedPayrollExcelBytes({
    required SalaryCycle cycle,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) async {
    final excel = Excel.createExcel();
    const String overviewSheetName = 'Payroll Overview';
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, overviewSheetName);
    final Sheet overviewSheet = excel[overviewSheetName];

    // Calculate workforce payroll summaries
    final workforce = SalaryCalculator.calculateWorkforcePayroll(
      employees: employees,
      salaryConfigs: salaryConfigs,
      records: records,
      cycle: cycle,
    );

    final summaryMap = _buildSummaryMap(workforce.employeeSummaries);

    final neoSummaries = workforce.employeeSummaries
        .where((s) => s.department.toLowerCase().contains('neo'))
        .toList();
    final fusionSummaries = workforce.employeeSummaries
        .where((s) => !s.department.toLowerCase().contains('neo'))
        .toList();

    final neoSummary = WorkforceSalarySummary.fromSummaries(cycle, neoSummaries);
    final fusionSummary = WorkforceSalarySummary.fromSummaries(cycle, fusionSummaries);

    // 1. Populate Overview Sheet with Total Estimated Payroll Details
    _populateOverviewSheet(
      sheet: overviewSheet,
      cycle: cycle,
      workforceSummary: workforce,
      fusionSummary: fusionSummary,
      neoSummary: neoSummary,
    );

    // 2. Populate Fusion Electric Sheet
    final Sheet electroSheet = excel['Fusion Electric WPS'];
    _populateWpsSheet(
      sheet: electroSheet,
      division: 'Fusion',
      companyName: 'FUSION ELECTRO-MECHANICAL MAINTENANCE LLC',
      molNumber: '803095',
      cycle: cycle,
      summaryMap: summaryMap,
      salaryConfigs: salaryConfigs,
    );

    // 3. Populate Fusion Neo Sheet
    final Sheet neoSheet = excel['Fusion Neo WPS'];
    _populateWpsSheet(
      sheet: neoSheet,
      division: 'Neo',
      companyName: 'FUSION NEO BUILDING CONTRACTING LLC',
      molNumber: '2846014',
      cycle: cycle,
      summaryMap: summaryMap,
      salaryConfigs: salaryConfigs,
    );

    final List<int>? encodedBytes = excel.encode();
    return encodedBytes ?? [];
  }

  // ===========================================================================
  // INTERNAL SHEET POPULATION HELPERS
  // ===========================================================================

  static Map<String, EmployeeSalarySummary> _buildSummaryMap(List<EmployeeSalarySummary> summaries) {
    final Map<String, EmployeeSalarySummary> summaryMap = {};
    for (final s in summaries) {
      summaryMap[s.employeeCode.toUpperCase()] = s;
      if (s.employeeId != null) summaryMap[s.employeeId!.toUpperCase()] = s;
      summaryMap[s.employeeName.trim().toLowerCase()] = s;
    }
    return summaryMap;
  }

  /// Populates the Executive Overview Sheet with Total Estimated Payroll Details
  static void _populateOverviewSheet({
    required Sheet sheet,
    required SalaryCycle cycle,
    required WorkforceSalarySummary workforceSummary,
    required WorkforceSalarySummary fusionSummary,
    required WorkforceSalarySummary neoSummary,
  }) {
    // Styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#1E3A8A'),
    );

    final subTitleStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#475569'),
    );

    final tableHeaderStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final cellTextStyle = CellStyle(
      fontSize: 10,
      verticalAlign: VerticalAlign.Center,
    );

    final cellNumberStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final cellCenterStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final totalStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#FEF08A'),
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final totalTextStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#FEF08A'),
      fontColorHex: ExcelColor.fromHexString('#000000'),
      verticalAlign: VerticalAlign.Center,
    );

    // Row 1: Title
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('FUSION ENTERPRISE GROUP - TOTAL ESTIMATED PAYROLL REPORT')
      ..cellStyle = titleStyle;

    // Row 2: Subtitle
    final String monthAbbr = cycle.salaryMonthAbbr;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      ..value = TextCellValue('SALARY CYCLE: MONTH : $monthAbbr- ${cycle.salaryYear} (${cycle.shortPeriodLabel})')
      ..cellStyle = subTitleStyle;

    // Row 3: Timestamp
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
      ..value = TextCellValue('Generated: ${DateFormat("dd MMM yyyy, HH:mm").format(DateTime.now())}')
      ..cellStyle = subTitleStyle;

    // Row 5: Table Header
    final headers = [
      'COMPANY / DIVISION',
      'HEADCOUNT',
      'PAYABLE DAYS',
      'DAYS WORKED',
      'PAID SUNDAYS',
      'FIXED PORTION (AED)',
      'VARIABLE PORTION (AED)',
      'OT HOURS',
      'OT AMOUNT (AED)',
      'TOTAL ESTIMATED PAYROLL (AED)',
    ];

    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 5))
        ..value = TextCellValue(headers[col])
        ..cellStyle = tableHeaderStyle;
    }

    // Row 6: Fusion Electro (Electric)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6))
      ..value = TextCellValue('FUSION ELECTRO-MECHANICAL MAINTENANCE LLC (Fusion Electric)')
      ..cellStyle = cellTextStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.employeeSummaries.length)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.totalWorkforcePayableDays)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.totalWorkforceDaysWorked)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.totalWorkforcePaidSundays)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.totalFixedEarned.round())
      ..cellStyle = cellNumberStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.totalVariableEarned.round())
      ..cellStyle = cellNumberStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 6))
      ..value = TextCellValue(fusionSummary.totalOtHours.toStringAsFixed(1))
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.totalOtEarned.round())
      ..cellStyle = cellNumberStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 6))
      ..value = IntCellValue(fusionSummary.totalPayroll.round())
      ..cellStyle = cellNumberStyle;

    // Row 7: Fusion Neo
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 7))
      ..value = TextCellValue('FUSION NEO BUILDING CONTRACTING LLC (Fusion Neo)')
      ..cellStyle = cellTextStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 7))
      ..value = IntCellValue(neoSummary.employeeSummaries.length)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 7))
      ..value = IntCellValue(neoSummary.totalWorkforcePayableDays)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 7))
      ..value = IntCellValue(neoSummary.totalWorkforceDaysWorked)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 7))
      ..value = IntCellValue(neoSummary.totalWorkforcePaidSundays)
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 7))
      ..value = IntCellValue(neoSummary.totalFixedEarned.round())
      ..cellStyle = cellNumberStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 7))
      ..value = IntCellValue(neoSummary.totalVariableEarned.round())
      ..cellStyle = cellNumberStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 7))
      ..value = TextCellValue(neoSummary.totalOtHours.toStringAsFixed(1))
      ..cellStyle = cellCenterStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 7))
      ..value = IntCellValue(neoSummary.totalOtEarned.round())
      ..cellStyle = cellNumberStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 7))
      ..value = IntCellValue(neoSummary.totalPayroll.round())
      ..cellStyle = cellNumberStyle;

    // Row 8: Grand Total Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 8))
      ..value = TextCellValue('TOTAL COMBINED WORKFORCE')
      ..cellStyle = totalTextStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.employeeSummaries.length)
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.totalWorkforcePayableDays)
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.totalWorkforceDaysWorked)
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.totalWorkforcePaidSundays)
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.totalFixedEarned.round())
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.totalVariableEarned.round())
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 8))
      ..value = TextCellValue(workforceSummary.totalOtHours.toStringAsFixed(1))
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.totalOtEarned.round())
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 8))
      ..value = IntCellValue(workforceSummary.totalPayroll.round())
      ..cellStyle = totalStyle;

    // Row 10: Informational note
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 10))
      ..value = TextCellValue('Note: Detailed employee WPS registers are available in the "Fusion Electric WPS" and "Fusion Neo WPS" tabs.')
      ..cellStyle = CellStyle(italic: true, fontSize: 9, fontColorHex: ExcelColor.fromHexString('#64748B'));

    // Set Column Widths
    sheet.setColumnWidth(0, 52.0);
    sheet.setColumnWidth(1, 14.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 14.0);
    sheet.setColumnWidth(4, 14.0);
    sheet.setColumnWidth(5, 22.0);
    sheet.setColumnWidth(6, 24.0);
    sheet.setColumnWidth(7, 14.0);
    sheet.setColumnWidth(8, 20.0);
    sheet.setColumnWidth(9, 30.0);
  }

  /// Populates a single WPS division sheet matching the exact company WPS format
  static void _populateWpsSheet({
    required Sheet sheet,
    required String division,
    required String companyName,
    required String molNumber,
    required SalaryCycle cycle,
    required Map<String, EmployeeSalarySummary> summaryMap,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) {
    // Master WPS records for this division
    final wpsList = WpsMasterRegistry.getByDivision(division);

    // Format Month String e.g. "MONTH : Nov- 2026"
    final String monthAbbr = cycle.salaryMonthAbbr;
    final String monthHeader = 'MONTH : $monthAbbr- ${cycle.salaryYear}';

    // Cell Styles
    final headerTitleStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#1E3A8A'),
    );

    final tableHeaderStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final netSalaryHeaderStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#CBD5E1'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final dataTextStyle = CellStyle(
      fontSize: 10,
      verticalAlign: VerticalAlign.Center,
    );

    final dataNumberStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final dataCenterStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final totalStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#FEF08A'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // =========================================================================
    // Header block (Rows 0-3 empty, Rows 4-6 company info)
    // =========================================================================
    // Row 4: Name: NASURUDEEN | FUSION ... LLC | WPS
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4))
      ..value = TextCellValue('Name: NASURUDEEN')
      ..cellStyle = headerTitleStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 4))
      ..value = TextCellValue(companyName)
      ..cellStyle = headerTitleStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 4))
      ..value = TextCellValue('WPS')
      ..cellStyle = headerTitleStyle;

    // Row 5: Contact no: 050-3921876/ 050-5315847 | Mol No : {molNumber}
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5))
      ..value = TextCellValue('Contact no: 050-3921876/ 050-5315847')
      ..cellStyle = dataTextStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 5))
      ..value = TextCellValue('Mol No : $molNumber')
      ..cellStyle = dataTextStyle;

    // Row 6: nasuru@fusionmaint.com | MONTH : Nov- 2026
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6))
      ..value = TextCellValue('nasuru@fusionmaint.com')
      ..cellStyle = dataTextStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 6))
      ..value = TextCellValue(monthHeader)
      ..cellStyle = CellStyle(bold: true, fontSize: 10);

    // =========================================================================
    // Table Header (Row 7: Main Header, Row 8: Sub-header)
    // =========================================================================
    final headers = [
      'Sl.No',
      'NAME OF THE EMPLOYEE',
      'WORK PERMIT NO (8 DIGIT NO)',
      'PERSONAL NO (14 DIGIT NO)',
      'BANK NAME & ROUTING NO',
      'BANK ACCOUNT NO',
      'NO OF DAYS ABSENT',
      "Employee's Net Salary",
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 7));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = col == 7 ? netSalaryHeaderStyle : tableHeaderStyle;
    }

    // Merge Net Salary header across Col H, I, J (indexes 7, 8, 9)
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 7),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 7),
    );

    // Subheader row (Row 8)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 8))
      ..value = TextCellValue('Fixed Portion')
      ..cellStyle = tableHeaderStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 8))
      ..value = TextCellValue('Variable Portion')
      ..cellStyle = tableHeaderStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 8))
      ..value = TextCellValue('Total Payment')
      ..cellStyle = tableHeaderStyle;

    // =========================================================================
    // Employee Data Rows (Row 9 onwards)
    // =========================================================================
    int currentRow = 9;
    int grandTotalFixed = 0;
    int grandTotalVariable = 0;
    int grandTotalPayment = 0;

    for (int i = 0; i < wpsList.length; i++) {
      final wps = wpsList[i];

      // Skip owners if any were somehow registered
      if (SalaryCalculator.isExcludedOwner(name: wps.fullName, code: wps.employeeCode)) {
        continue;
      }

      // Find matching salary summary
      EmployeeSalarySummary? summary = summaryMap[wps.employeeCode.toUpperCase()] ??
          summaryMap[wps.fullName.trim().toLowerCase()];

      if (summary == null) {
        for (final entry in summaryMap.entries) {
          if (entry.value.employeeName.trim().toLowerCase() == wps.fullName.trim().toLowerCase() ||
              entry.value.employeeCode.toUpperCase() == wps.employeeCode.toUpperCase()) {
            summary = entry.value;
            break;
          }
        }
      }

      // 1. Fixed Portion: Basic Salary of the employee
      final int fixedPortion = summary != null
          ? summary.config.basicSalary.round()
          : wps.defaultBasicSalary.round();

      // 2. Variable Portion: Sum of Variable Salary and OT Salary
      final int variablePortion = summary != null
          ? (summary.earnedVariableSalary + summary.earnedOtSalary).round()
          : (salaryConfigs[wps.employeeCode]?.variableSalary.round() ?? 0);

      // 3. Total Payment: Sum of Fixed Portion and Variable Portion
      final int totalPayment = fixedPortion + variablePortion;

      // 4. No of days absent
      final int daysAbsent = summary?.absentDays ?? 0;

      // Write row cells
      // Col 0: Sl.No
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
        ..value = IntCellValue(i + 1)
        ..cellStyle = dataCenterStyle;

      // Col 1: NAME OF THE EMPLOYEE
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
        ..value = TextCellValue(wps.fullName)
        ..cellStyle = dataTextStyle;

      // Col 2: WORK PERMIT NO
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
        ..value = TextCellValue(wps.workPermitNo)
        ..cellStyle = dataCenterStyle;

      // Col 3: PERSONAL NO
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow))
        ..value = TextCellValue(wps.personalNo)
        ..cellStyle = dataCenterStyle;

      // Col 4: BANK NAME & ROUTING NO
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow))
        ..value = TextCellValue(wps.bankName)
        ..cellStyle = dataCenterStyle;

      // Col 5: BANK ACCOUNT NO
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow))
        ..value = TextCellValue(wps.bankAccountNo)
        ..cellStyle = dataCenterStyle;

      // Col 6: NO OF DAYS ABSENT
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow))
        ..value = IntCellValue(daysAbsent)
        ..cellStyle = dataCenterStyle;

      // Col 7: Fixed Portion
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow))
        ..value = IntCellValue(fixedPortion)
        ..cellStyle = dataNumberStyle;

      // Col 8: Variable Portion (Variable Salary + Overtime Salary)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow))
        ..value = IntCellValue(variablePortion)
        ..cellStyle = dataNumberStyle;

      // Col 9: Total Payment (Fixed + Variable)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow))
        ..value = IntCellValue(totalPayment)
        ..cellStyle = dataNumberStyle;

      grandTotalFixed += fixedPortion;
      grandTotalVariable += variablePortion;
      grandTotalPayment += totalPayment;

      currentRow++;
    }

    // =========================================================================
    // Total Row
    // =========================================================================
    // Empty row separator
    currentRow++;

    // "Total" label in Column 5
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow))
      ..value = TextCellValue('Total')
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

    // Sum of Fixed Portion in Col 7
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow))
      ..value = IntCellValue(grandTotalFixed)
      ..cellStyle = totalStyle;

    // Sum of Variable Portion in Col 8
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow))
      ..value = IntCellValue(grandTotalVariable)
      ..cellStyle = totalStyle;

    // Grand Total Payment in Col 9
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow))
      ..value = IntCellValue(grandTotalPayment)
      ..cellStyle = totalStyle;

    // Auto-fit column widths
    sheet.setColumnWidth(0, 8.0);
    sheet.setColumnWidth(1, 38.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 24.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 26.0);
    sheet.setColumnWidth(6, 16.0);
    sheet.setColumnWidth(7, 16.0);
    sheet.setColumnWidth(8, 16.0);
    sheet.setColumnWidth(9, 18.0);
  }

  // ===========================================================================
  // INTERIM OVERTIME EXCEL EXPORT (26 OCT - 31 OCT 2026)
  // ===========================================================================

  /// Exports dedicated Excel report for Interim Overtime (26 Oct - 31 Oct 2026)
  static Future<void> exportInterimOtExcel({
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) async {
    final cycle = SalaryCycle.octoberTransition();
    final bytes = await buildInterimOtExcelBytes(
      cycle: cycle,
      employees: employees,
      records: records,
      salaryConfigs: salaryConfigs,
    );

    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'Interim_OT_26-31_Oct_2026.xlsx',
    );
  }

  /// Builds Excel workbook bytes for Interim Overtime breakdown (26 Oct - 31 Oct 2026)
  static Future<List<int>> buildInterimOtExcelBytes({
    required SalaryCycle cycle,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) async {
    final excel = Excel.createExcel();

    // Active staff excluding owners
    final activeEmployees = employees.where((e) {
      return !SalaryCalculator.isExcludedOwner(
        name: e.name,
        code: e.employeeCode,
        email: e.email,
        id: e.id,
      );
    }).toList();

    const String sheetAll = 'All Staff Interim OT';
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetAll);

    // 1. All Staff Sheet
    _populateInterimOtSheet(
      sheet: excel[sheetAll],
      sheetTitle: 'ALL STAFF INTERIM OVERTIME (26 OCT – 31 OCT 2026)',
      cycle: cycle,
      employees: activeEmployees,
      records: records,
      salaryConfigs: salaryConfigs,
    );

    // 2. Fusion Neo Sheet
    final neoEmployees = activeEmployees
        .where((e) => e.department.toLowerCase().contains('neo'))
        .toList();
    _populateInterimOtSheet(
      sheet: excel['Fusion Neo OT'],
      sheetTitle: 'FUSION NEO BUILDING CONTRACTING - INTERIM OVERTIME (26–31 OCT)',
      cycle: cycle,
      employees: neoEmployees,
      records: records,
      salaryConfigs: salaryConfigs,
    );

    // 3. Fusion Electro Sheet
    final electroEmployees = activeEmployees
        .where((e) => !e.department.toLowerCase().contains('neo'))
        .toList();
    _populateInterimOtSheet(
      sheet: excel['Fusion Electro OT'],
      sheetTitle: 'FUSION ELECTRO-MECHANICAL - INTERIM OVERTIME (26–31 OCT)',
      cycle: cycle,
      employees: electroEmployees,
      records: records,
      salaryConfigs: salaryConfigs,
    );

    final List<int>? encodedBytes = excel.encode();
    return encodedBytes ?? [];
  }

  static void _populateInterimOtSheet({
    required Sheet sheet,
    required String sheetTitle,
    required SalaryCycle cycle,
    required List<EmployeeEntity> employees,
    required List<AttendanceRecord> records,
    required Map<String, EmployeeSalaryConfig> salaryConfigs,
  }) {
    // Styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: ExcelColor.fromHexString('#1E3A8A'),
    );
    final subTitleStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#64748B'),
    );
    final tableHeaderStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final cellCenterStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final cellTextStyle = CellStyle(
      fontSize: 10,
      verticalAlign: VerticalAlign.Center,
    );
    final cellNumberStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    final totalStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#FEF08A'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    final totalTextStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#FEF08A'),
      verticalAlign: VerticalAlign.Center,
    );

    // Row 1: Title
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue(sheetTitle)
      ..cellStyle = titleStyle;

    // Row 2: Subtitle
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      ..value = TextCellValue('6-Day Transition Period (26 Oct 2026 – 31 Oct 2026) | Regular Calendar Cycle Begins 1 Nov 2026')
      ..cellStyle = subTitleStyle;

    // Row 4: Headers
    final headers = [
      'SL NO',
      'EMP ID',
      'EMPLOYEE NAME',
      'DEPARTMENT',
      'BASIC SALARY (AED)',
      'OT RATE/HR (AED)',
      '26 OCT (MON)',
      '27 OCT (TUE)',
      '28 OCT (WED)',
      '29 OCT (THU)',
      '30 OCT (FRI)',
      '31 OCT (SAT)',
      'TOTAL OT HOURS',
      'TOTAL OT PAYABLE (AED)',
    ];

    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 4))
        ..value = TextCellValue(headers[col])
        ..cellStyle = tableHeaderStyle;
    }

    int currentRow = 5;
    double grandTotalBasic = 0.0;
    double grandTotalOtHours = 0.0;
    double grandTotalOtPay = 0.0;

    for (int i = 0; i < employees.length; i++) {
      final emp = employees[i];
      final config = SalaryCalculator.resolveConfig(employee: emp, salaryConfigs: salaryConfigs);
      final summary = SalaryCalculator.calculateEmployeeSalary(
        config: config,
        employee: emp,
        records: records,
        cycle: cycle,
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

      grandTotalBasic += config.basicSalary;
      grandTotalOtHours += summary.totalOvertimeHours;
      grandTotalOtPay += summary.earnedOtSalary;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
        ..value = IntCellValue(i + 1)
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
        ..value = TextCellValue(emp.employeeCode)
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
        ..value = TextCellValue(emp.name)
        ..cellStyle = cellTextStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow))
        ..value = TextCellValue(emp.department)
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow))
        ..value = DoubleCellValue(config.basicSalary)
        ..cellStyle = cellNumberStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow))
        ..value = config.otIncludedInVariable
            ? TextCellValue('Fixed OT')
            : DoubleCellValue(double.parse(summary.hourlyOtRate.toStringAsFixed(2)))
        ..cellStyle = cellNumberStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow))
        ..value = ot26 > 0 ? DoubleCellValue(ot26) : TextCellValue('-')
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow))
        ..value = ot27 > 0 ? DoubleCellValue(ot27) : TextCellValue('-')
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow))
        ..value = ot28 > 0 ? DoubleCellValue(ot28) : TextCellValue('-')
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow))
        ..value = ot29 > 0 ? DoubleCellValue(ot29) : TextCellValue('-')
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: currentRow))
        ..value = ot30 > 0 ? DoubleCellValue(ot30) : TextCellValue('-')
        ..cellStyle = cellCenterStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: currentRow))
        ..value = ot31 > 0 ? DoubleCellValue(ot31) : TextCellValue('-')
        ..cellStyle = cellCenterStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: currentRow))
        ..value = DoubleCellValue(double.parse(summary.totalOvertimeHours.toStringAsFixed(1)))
        ..cellStyle = cellNumberStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: currentRow))
        ..value = DoubleCellValue(double.parse(summary.earnedOtSalary.toStringAsFixed(2)))
        ..cellStyle = cellNumberStyle;

      currentRow++;
    }

    // Totals Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
      ..value = TextCellValue('Total')
      ..cellStyle = totalTextStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow))
      ..value = DoubleCellValue(double.parse(grandTotalBasic.toStringAsFixed(2)))
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: currentRow))
      ..value = DoubleCellValue(double.parse(grandTotalOtHours.toStringAsFixed(1)))
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: currentRow))
      ..value = DoubleCellValue(double.parse(grandTotalOtPay.toStringAsFixed(2)))
      ..cellStyle = totalStyle;

    // Column widths
    sheet.setColumnWidth(0, 8.0);
    sheet.setColumnWidth(1, 14.0);
    sheet.setColumnWidth(2, 30.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 16.0);
    sheet.setColumnWidth(6, 14.0);
    sheet.setColumnWidth(7, 14.0);
    sheet.setColumnWidth(8, 14.0);
    sheet.setColumnWidth(9, 14.0);
    sheet.setColumnWidth(10, 14.0);
    sheet.setColumnWidth(11, 14.0);
    sheet.setColumnWidth(12, 18.0);
    sheet.setColumnWidth(13, 22.0);
  }
}
