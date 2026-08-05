# 09. Employee Timesheet & Work Site Management Feature

## Overview
The **Employee Timesheet & Work Site Management** feature provides comprehensive daily shift duration tracking, regular versus overtime hour calculation, field site visit breakdowns, timesheet PDF exports, and centralized client work site / construction project registry management.

---

## 1. Key Functionalities

### A. Employee Work Timesheet Engine (`TimesheetCalculator`)
1. **Daily Work Shift Calculation**:
   - Evaluates attendance logs for each employee grouped by date (`yyyy-MM-dd`).
   - Identifies primary start time from `1. Office Check-In` (`OFFICE_CHECK_IN`) or fallback first site check-in.
   - Identifies primary end time from `4. Office Check-Out` (`OFFICE_CHECK_OUT`) or last site check-out.
   - Calculates total daily work duration (`totalWorkedDuration`).

2. **Regular vs. Overtime Hours Breakdown**:
   - Standard regular work hours are capped at **8.0 hours per day** (`standardRegularHoursPerDay = 8.0`).
   - If total worked hours $\le 8.0$, all hours are classified as **Regular Hours**.
   - If total worked hours $> 8.0$, **Regular Hours** = $8.0$ and **Overtime Hours** = $\text{Total Hours} - 8.0$.

3. **Site Visit Duration Breakdown (`SiteVisitSummary`)**:
   - Tracks individual site visits during the shift.
   - Measures time elapsed between `2. Site Check-In` and `3. Site Check-Out` for each site visit (e.g. `RELAAM (AMC)`, `CARRIER`).

4. **Executive Timesheet KPI Cards**:
   - **Total Worked Hours**: Aggregated hours across selected period.
   - **Regular Hours**: Cumulative regular shift hours.
   - **Overtime Hours**: Cumulative overtime hours.
   - **Days Worked**: Total active duty days.

5. **Timesheet PDF Download**:
   - Integrated with `PdfExportService.generateTimesheetPdf()`.
   - Renders formatted, printable timesheet documents featuring employee code, name, designation, daily breakdown table, regular vs overtime breakdown, site visit history, and total hours summary.

---

### B. Work Site & Construction Project Registry
1. **Work Site Registration (`WorkSiteManagementScreen`)**:
   - Allows Admins to register client project sites, construction locations, or field depots in the `work_sites` database table.
   - Captures **Work Site Name**, **Client Name**, **Physical Address**, **Latitude**, **Longitude**, and **Site Geofence Radius** (default `300.0m`).

2. **Dropdown Integration (`SiteNameDialog`)**:
   - Pre-populates site selection dropdowns during `2. Site Check-In` workflow step.
   - Ensures accurate site allocation and attendance reporting.

---

## 2. Technical Implementation & Data Structures

### Data Models (`DailyTimesheetEntry` & `SiteVisitSummary`)
```dart
class SiteVisitSummary {
  final String siteName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;

  Duration get duration {
    if (checkOutTime == null) return Duration.zero;
    return checkOutTime!.difference(checkInTime);
  }
}

class DailyTimesheetEntry {
  final DateTime date;
  final String employeeId;
  final String employeeName;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final Duration totalDuration;
  final double regularHours;
  final double overtimeHours;
  final int stepCount;
  final bool isCompleted;
  final List<SiteVisitSummary> siteVisits;
}
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/core/utils/timesheet_calculator.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/timesheet_calculator.dart) | Calculation utility aggregating attendance records into daily timesheets, regular/overtime hours, and site visits. |
| [`lib/features/timesheet/domain/timesheet_entry.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/domain/timesheet_entry.dart) | Timesheet entry and site visit domain models. |
| [`lib/features/timesheet/presentation/timesheet_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/presentation/timesheet_cubit.dart) | Cubit fetching attendance records and transforming them into timesheet states. |
| [`lib/features/timesheet/presentation/employee_timesheet_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/presentation/employee_timesheet_screen.dart) | Timesheet UI with KPI cards, shift filter tabs (`All`, `Regular`, `Overtime`), site visit timeline, and PDF export button. |
| [`lib/features/admin/presentation/work_site_management_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/work_site_management_screen.dart) | Admin UI screen for managing client work sites, GPS coordinates, and geofence radii. |
| [`lib/features/admin/domain/work_site_entity.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/domain/work_site_entity.dart) | Work site domain model. |
