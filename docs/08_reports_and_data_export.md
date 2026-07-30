# 08. Reports & Multi-Format Data Export Feature

## Overview
The **Reports & Multi-Format Data Export** feature allows Super Admins and managers to analyze historical attendance records, inspect employee compliance, filter data by custom date ranges, and export production-ready reports in **CSV**, **Excel (.xlsx)**, and **PDF** formats.

---

## 1. Key Functionalities

1. **Flexible Filtering & Search Engine**:
   - Date range selector (Single Day, Date Range, Month-to-Date).
   - Employee selector & search filter.
   - Office Station filter.
   - Geofence compliance filter (`All`, `Geofence Valid Only`, `Violations Only`).

2. **CSV Export (`csv` package)**:
   - Converts filtered attendance records into formatted CSV strings with headers: `Record ID, Employee Code, Employee Name, Workflow Step, Timestamp, Latitude, Longitude, Address, Geofence Valid, Sync Status`.
   - Saves file to device documents directory using `path_provider`.

3. **Excel (.xlsx) Export (`excel` package)**:
   - Generates native multi-cell Excel spreadsheets with styled headers, custom column widths, and formatted timestamp cells.

4. **PDF Report Generation & Printing (`pdf` & `printing` packages)**:
   - Constructs multi-page PDF documents featuring company headers, metadata summary blocks, styled data tables, and pagination footers.
   - Integrates with native printing/sharing dialogs (`Printing.sharePdf()`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/reports/presentation/reports_screen.dart`](file:///c:/Users/srirs\.gemini\antigravity-ide\scratch\attendance_app\lib\features\reports\presentation\reports_screen.dart) | Reports screen UI with filter bars, summary cards, and export action buttons. |
| [`lib/features/reports/presentation/reports_cubit.dart`](file:///c:/Users/srirs\.gemini\antigravity-ide\scratch\attendance_app\lib\features\reports\presentation\reports_cubit.dart) | Business logic cubit handling data filtering, CSV generation, Excel building, and PDF rendering. |
