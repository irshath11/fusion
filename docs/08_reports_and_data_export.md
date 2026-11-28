# 08. Reports & Multi-Format Data Export Feature

## Overview
The **Reports & Multi-Format Data Export** feature allows Super Admins, managers, and auditors to analyze historical attendance records, inspect employee compliance, filter data by custom date ranges, and export production-ready reports in **CSV**, **Excel (.xlsx)**, and **PDF** formats.

---

## 1. Key Functionalities

1. **Flexible Filtering & Search Engine**:
   - **Company Salary Cycle Selector**: Placed directly above the search bar on the main Employee Attendance Reports screen (`ReportsAnalyticsScreen`), Cumulative Summary, Leave Records, and Standalone `web_admin`. Dynamically resolves calendar months (Nov 2026+, e.g., `01 Nov – 30 Nov 2026`), the `26–31 Oct 2026` Interim OT cycle, and legacy 25th–24th cycles.
   - Custom Date range selector (Single Day, Custom Date Range, Month-to-Date).
   - Employee selector & search filter with strict identity isolation (`EmployeeDirectoryHelper.matchesEmployeeIdentity`).
   - Office Station & Client Work Site filter.
   - Geofence compliance filter (`All`, `Geofence Valid Only`, `Violations Only`).

2. **Leave Records & Site/Client Man-Hours Reporting**:
   - **Leave Records**: Tabulated calendar view of employee presence, unapproved leaves/absences, Sunday weekly off days, and Sunday duty worked.
   - **Site / Client Man-Hours**: Aggregates net site visit durations (excluding breaks) across individual project sites or standardized client groups (`REELAM`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS`).

3. **CSV Export (`csv` package via `excel_csv_export_service.dart`)**:
   - Converts filtered attendance records into formatted CSV strings with headers: `Record ID, Employee ID, Workflow Step, Event Time, Latitude, Longitude, Address, Geofence Valid, Sync Status`.
   - Saves file to device documents directory using `path_provider`.

4. **Excel (.xlsx) Export (`excel` package via `excel_csv_export_service.dart`)**:
   - Generates native multi-cell Excel spreadsheets with styled headers, custom column widths, and formatted cells:
     - **Fusion Neo WPS Excel (`exportFusionNeoWpsExcel`)**: Official Wage Protection System workbook for **Fusion Neo Building Contracting LLC** (MOL: `2846014`) -> `Neo_employees-WPS_MM-YYYY.xlsx`.
     - **Fusion Electro WPS Excel (`exportFusionElectroWpsExcel`)**: Official WPS workbook for **Fusion Electro-Mechanical Maintenance LLC** (MOL: `803095`) -> `Fusion-electro-employees-WPS_MM-YYYY.xlsx`. Uses prorated earned fixed salary, accurate absent days, and dynamically includes active division employees.
     - **Master Estimated Payroll Details (`exportMasterEstimatedPayrollExcel`)**: Executive summary + separate Fusion & Neo division breakdown sheets including November Interim OT rollover (`Total_Estimated_Payroll_Details_MM-YYYY.xlsx`).
     - **Interim Overtime Excel (`exportInterimOtExcel`)**: Dedicated `26–31 Oct 2026` day-by-day OT report.
     - **Cards Compliance Excel Export**: Exports comprehensive employee cards ledger (`Employee_Cards_Compliance_Report_YYYY-MM-DD.xlsx`) containing employee details, card types, card numbers, issue dates, expiry dates, and remaining days until expiration.

5. **PDF Report Generation & Printing (`pdf` & `printing` packages via `pdf_export_service.dart`)**:
   - Constructs multi-page PDF documents featuring company headers, metadata summary blocks, styled data tables, and pagination footers.
   - Supports master attendance reports, individual employee attendance histories, salary cycle timesheet reports, leave summaries, **Workforce Salary Payroll PDF (`exportWorkforceSalaryPdf`)**, **Individual Employee Payslip PDF (`exportEmployeeSalarySlipPdf`)**, and **Interim OT PDF (`exportInterimOtPdf`)**.
   - Integrates with native printing/sharing dialogs (`Printing.sharePdf()`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/reports_analytics_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/reports_analytics_screen.dart) | Reports screen UI with Salary Cycle selector above the search bar, summary cards, Leave Records tab, Site Man-Hours tab, and export action buttons. |
| [`lib/core/utils/salary_cycle_helper.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/salary_cycle_helper.dart) | Salary cycle resolution (calendar month, Oct Interim OT transition, legacy 25th–24th) and period calculation engine. |
| [`lib/core/utils/leave_calculator.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/leave_calculator.dart) | Ledger utility calculating employee working days, leave counts, and Sunday duty summaries. |
| [`lib/core/services/pdf_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/pdf_export_service.dart) | Service constructing multi-page PDF documents for attendance logs, timesheets, leave records, workforce payroll, payslips, and Interim OT. |
| [`lib/core/services/excel_csv_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/excel_csv_export_service.dart) | Service generating division WPS Excel workbooks, Master Payroll Excel, Interim OT Excel, Cards Compliance Excel, and CSV files. |

