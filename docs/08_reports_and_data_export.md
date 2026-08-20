# 08. Reports & Multi-Format Data Export Feature

## Overview
The **Reports & Multi-Format Data Export** feature (`ReportsAnalyticsScreen`) provides Super Admins, managers, and auditors with a 3-tab analytics suite, 3-level directory drilldown capabilities, cross-employee cumulative statistics, client/site man-hour aggregations, cloud attendance log synchronization, and production-ready data export in **CSV**, **Excel (.xlsx)**, and **PDF** formats.

---

## 1. Key Functionalities

### A. 3-Tab Advanced Analytics Suite (`AppAnimatedTabSwitcher`)

1. **Tab 0: Employee Directory & Duty Log Drilldown (3-Level View)**:
   - **Level 1 (Employee Directory List)**:
     - Real-time search bar filtering staff by Name, Employee Code (`EMP-XXXX`), or Department (`Operations`).
     - **Executive KPI Ticker Ribbon (`AppGlassCard`)**: Displays real-time metrics for *Total Staff*, *Active Duty*, *Attendance Rate (%)*, and *Geofence Audit Compliance (%)*.
     - **Cloud Log Refresh Button**: Trigger on-demand sync from Supabase with loading status indicator animation (`_isLoadingCloud`).
   - **Level 2 (Employee Date-Wise Duty Logs)**:
     - Lists all calendar dates where the selected employee recorded attendance events.
     - Displays check-in/out timestamps, total daily work shift hours, and site visit count badges.
   - **Level 3 (Date Detailed Inspection & Selfie Verification)**:
     - High-resolution camera selfie photo verification modal view.
     - Exact GPS coordinates (latitude, longitude, accuracy) and physical address text.
     - Geofence compliance badges (`VALID` / `VIOLATION`).
     - Timeline step breakdown (`1. Office Check-In`, `2. Site Check-In`, `3. Site Check-Out`, `4. Office Check-Out`).

2. **Tab 1: Cumulative Summary View**:
   - Cross-employee aggregate attendance statistics across the entire organization.
   - **Present / Absent Staff Count Ticker**: Instant count of active versus absent personnel for selected date ranges.
   - **Work Hour Aggregation**: Calculates net regular hours (capped at 8.0h/day) and overtime hours (>8.0h/day).
   - **Cumulative Site Visits**: Total site visits logged across all field client locations.
   - **Master Export Action Toolbar**: Direct trigger buttons to generate and download master attendance reports in PDF, Excel (.xlsx), or CSV.

3. **Tab 2: Site / Client Man-Hours Analytics View**:
   - Aggregates billable workforce man-hours by construction project site or client organization.
   - **Date Range Filters**: Filter analytics by `All Time`, `This Month`, `This Week`, or `Today`.
   - **Dynamic Grouping Toggle**: Switch between **Group by Client** (aggregates multiple project sites under a single client banner) and **Specific Site** view.
   - **Expandable Site / Client Cards**: Interactive cards (`_expandedSiteKeys`) revealing total workers deployed, total man-hours spent, total site visits, client name, and a nested worker table listing individual personnel and their specific hours on site.

---

### B. Cloud Attendance Log Sync & Local Auto-Merge Engine
- **Supabase Integration**: Calls `fetchAttendanceRecordsFromSupabase()` in `_loadCloudAttendanceRecords()`.
- **Deduplication & Local Persistence**: Checks existing record IDs in Hive local storage (`LocalDatabaseService`) and automatically merges new cloud records into local storage.
- **State Management & UI Loading**: Managed via `_isLoadingCloud` state flag. Displays a linear progress indicator (`LinearProgressIndicator`) and a spinner inside the refresh button while synchronization is active.

---

### C. Multi-Format Data Export Engine

1. **CSV Export (`csv` package via `excel_csv_export_service.dart`)**:
   - Converts filtered attendance records into formatted CSV strings with headers: `Record ID, Employee Code, Employee Name, Workflow Step, Timestamp, Latitude, Longitude, Address, Geofence Valid, Sync Status`.
   - Saves file to device documents directory using `path_provider`.

2. **Excel (.xlsx) Export (`excel` package via `excel_csv_export_service.dart`)**:
   - Generates native multi-cell Excel spreadsheets with styled headers, custom column widths, and formatted timestamp cells.

3. **PDF Report Generation & Printing (`pdf` & `printing` packages via `pdf_export_service.dart`)**:
   - Constructs multi-page PDF documents featuring company headers, metadata summary blocks, styled data tables, and pagination footers.
   - Supports master attendance reports, individual employee attendance histories, and individual employee work timesheets.
   - Integrates with native printing/sharing dialogs (`Printing.sharePdf()`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/reports_analytics_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/reports_analytics_screen.dart) | Comprehensive 3-tab analytics screen UI (Directory 3-Level drilldown, Cumulative Summary, Site/Client Man-Hours, Cloud Log Sync). |
| [`lib/core/services/pdf_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/pdf_export_service.dart) | Service constructing multi-page PDF documents for attendance logs and timesheets using `pdf` & `printing`. |
| [`lib/core/services/excel_csv_export_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/excel_csv_export_service.dart) | Service generating native Excel (.xlsx) workbooks and formatted CSV files. |
| [`lib/core/services/supabase_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/supabase_service.dart) | Supabase client service handling remote attendance record fetching (`fetchAttendanceRecordsFromSupabase()`). |
| [`lib/database/local_database_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/database/local_database_service.dart) | Hive local database service managing local attendance storage and record merging. |

