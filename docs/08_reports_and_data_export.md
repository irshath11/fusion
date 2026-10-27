# 08. Reports & Multi-Format Data Export Feature

## Overview
The **Reports & Multi-Format Data Export** feature allows Super Admins, managers, and auditors to analyze historical attendance records, inspect employee compliance, filter data by custom date ranges, and export production-ready reports in **CSV**, **Excel (.xlsx)**, and **PDF** formats.

---

## 1. Key Functionalities

1. **Flexible Filtering & Search Engine**:
   - **Company Salary Cycle Selector**: One-click selection for payroll cycles running 25th of prior month to 24th of selected month (e.g. `25 Oct 2026 – 24 Nov 2026`).
   - Custom Date range selector (Single Day, Custom Date Range, Month-to-Date).
   - Employee selector & search filter with badge normalization (`EmployeeDirectoryHelper`).
   - Office Station & Client Work Site filter.
   - Geofence compliance filter (`All`, `Geofence Valid Only`, `Violations Only`).

2. **Leave Records Ledger Reporting**:
   - Tabulated calendar view of employee presence, unapproved leaves/absences, Sunday weekly off days, and Sunday duty worked.
   - Summarizes total scheduled working days, days attended, absent days, and net attendance compliance percentage.

3. **CSV Export (`csv` package via `excel_csv_export_service.dart`)**:
   - Converts filtered attendance records into formatted CSV strings with headers: `Record ID, Employee Code, Employee Name, Workflow Step, Timestamp, Latitude, Longitude, Address, Geofence Valid, Sync Status`.
   - Saves file to device documents directory using `path_provider`.

4. **Excel (.xlsx) Export (`excel` package via `excel_csv_export_service.dart`)**:
   - Generates native multi-cell Excel spreadsheets with styled headers, custom column widths, and formatted timestamp cells.
   - **Cards Compliance Excel Export**: Exports comprehensive employee cards ledger (`Employee_Cards_Compliance_Report_YYYY-MM-DD.xlsx`) containing employee details, card types, card numbers, issue dates, expiry dates, and remaining days until expiration.

5. **PDF Report Generation & Printing (`pdf` & `printing` packages via `pdf_export_service.dart`)**:
   - Constructs multi-page PDF documents featuring company headers, metadata summary blocks, styled data tables, and pagination footers.
   - Supports master attendance reports, individual employee attendance histories, 25th–24th salary cycle timesheet reports, and leave summaries.
   - Integrates with native printing/sharing dialogs (`Printing.sharePdf()`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/reports_analytics_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/reports_analytics_screen.dart) | Reports screen UI with Salary Cycle (25th–24th) selector, filter bars, summary cards, Leave Records tab, and export action buttons. |
| [`lib/core/utils/salary_cycle_helper.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/salary_cycle_helper.dart) | Salary cycle resolution and period calculation engine. |
| [`lib/core/utils/leave_calculator.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/leave_calculator.dart) | Ledger utility calculating employee working days, leave counts, and Sunday duty summaries. |
| [`lib/core/services/pdf_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/pdf_export_service.dart) | Service constructing multi-page PDF documents for attendance logs, salary cycle timesheets, and leave records. |
| [`lib/core/services/excel_csv_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/excel_csv_export_service.dart) | Service generating native Excel (.xlsx) workbooks and formatted CSV files. |

