# 08. Reports & Multi-Format Data Export Feature

## Overview
The **Reports & Multi-Format Data Export** feature allows Super Admins, managers, and auditors to analyze historical attendance records, inspect employee compliance, filter data by custom date ranges, and export production-ready reports in **CSV**, **Excel (.xlsx)**, and **PDF** formats.

---

## 1. Key Functionalities

1. **Flexible Filtering & Search Engine**:
   - Date range selector (Single Day, Date Range, Month-to-Date).
   - Employee selector & search filter.
   - Office Station filter.
   - Geofence compliance filter (`All`, `Geofence Valid Only`, `Violations Only`).

2. **CSV Export (`csv` package via `excel_csv_export_service.dart`)**:
   - Converts filtered attendance records into formatted CSV strings with headers: `Record ID, Employee Code, Employee Name, Workflow Step, Timestamp, Latitude, Longitude, Address, Geofence Valid, Sync Status`.
   - Saves file to device documents directory using `path_provider`.

3. **Excel (.xlsx) Export (`excel` package via `excel_csv_export_service.dart`)**:
   - Generates native multi-cell Excel spreadsheets with styled headers, custom column widths, and formatted timestamp cells.

4. **PDF Report Generation & Printing (`pdf` & `printing` packages via `pdf_export_service.dart`)**:
   - Constructs multi-page PDF documents featuring company headers, metadata summary blocks, styled data tables, and pagination footers.
   - Supports master attendance reports, individual employee attendance histories, and individual employee work timesheets.
   - Integrates with native printing/sharing dialogs (`Printing.sharePdf()`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/reports_analytics_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/reports_analytics_screen.dart) | Reports screen UI with filter bars, summary cards, and export action buttons. |
| [`lib/core/services/pdf_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/pdf_export_service.dart) | Service constructing multi-page PDF documents for attendance logs and timesheets using `pdf` & `printing`. |
| [`lib/core/services/excel_csv_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/excel_csv_export_service.dart) | Service generating native Excel (.xlsx) workbooks and formatted CSV files. |
