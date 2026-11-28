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

2. **Regular, Food Break, Travel Tolerance & Overtime Hours Breakdown**:
   - Standard regular work hours are capped at **8.0 hours per day** (`standardRegularHoursPerDay = 8.0`) on Monday through Saturday.
   - **Up to 8.0 Gross Hours (≤ 480 mins)**: Logged break duration (`BREAK_START` to `BREAK_END`) is deducted from gross time; all net hours are classified as **Regular Hours** (`overtimeHours = 0.0`).
   - **Beyond 8.0 Gross Hours (> 480 mins)**:
     - **Default Food Break**: Deducts **1 hour (60 mins)** (or the logged break duration if greater than 60 mins).
     - **Travel Tolerance**: Allocates up to **1 hour (60 mins)** after regular hours + food break.
     - **Overtime Accrual**: Overtime begins after **10 gross hours** (8h regular + 1h food break + 1h travel tolerance).
   - **Emergency Duty (`EMERGENCY_CHECK_IN` / `EMERGENCY_CHECK_OUT`)**: 100% of emergency callout duration is added directly to **Overtime Hours**.
   - **Admin Attendance Edit & Manual OT Override (`AdminEditAttendanceDialog`)**: Admins can adjust check-in/out times or set `manualOvertimeHours` with `remarks` (`isEdited: true`, `editedBy`). For shifts with a manual OT override ($\ge 6\text{h}$ gross), regular hours normalize to `8.0h` (or `0.0h` on Sundays).

3. **Special Sunday 100% Overtime Conversion**:
   - Sunday is designated as the mandatory weekly off day in Gulf operations.
   - If an employee logs duty on Sunday, **100% of all worked hours are classified as Overtime Hours**:
     - $\text{Regular Hours} = 0.0\text{h}$
     - $\text{Overtime Hours} = \text{Total Worked Hours}$

4. **24-Hour Auto-Checkout Safety Guard**:
   - Shifts active under 24 hours remain in progress.
   - Any unclosed shift exceeding 24 hours without an official check-out is automatically capped at **8.0 standard regular hours** and **0.0 overtime hours** (`isAutoCompleted: true`), protecting timesheet totals against runaway shift duration.

5. **Configurable Salary Cycle Period Aggregation & Strict Identity Isolation**:
   - Supports calendar-month cycles (Nov 2026+), the `26–31 Oct 2026` Interim OT transition cycle, and legacy 25th–24th cycles via `TimesheetCalculator.calculateSalaryCycleSummary()`.
   - Strictly filters target employee logs via `EmployeeDirectoryHelper.matchesEmployeeIdentity()` so records from different staff never merge.

6. **Site Visit Duration & Client Man-Hours Breakdown (`SiteVisitSummary` & `calculateSiteManHours`)**:
   - Tracks individual site visits during the shift, measuring net duration between `2. Site Check-In` and `3. Site Check-Out` (excluding overlapping breaks).
   - Aggregates workforce man-hours per site or client group (`REELAM`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS`) via `calculateSiteManHours()`.

7. **Site Name & Physical Address Resolution**:
   - Multi-tier resolution hierarchy (`resolveSiteName` and `resolveFullAddress`): explicit `siteName` ➔ `work_sites` registry match ➔ `offices` match ➔ employee `assignedOfficeName` ➔ fallback workflow step label.

8. **Executive Timesheet KPI Cards**:
   - **Total Worked Hours**: Aggregated hours across selected period.
   - **Regular Hours**: Cumulative regular shift hours.
   - **Overtime Hours**: Cumulative overtime hours.
   - **Days Worked**: Total active duty days.

9. **Timesheet PDF Download**:
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
| [`lib/core/utils/timesheet_calculator.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/timesheet_calculator.dart) | Calculation utility aggregating attendance records into daily timesheets, 1h food break & 1h travel tolerance OT rules, emergency duty, Sunday duty conversions, and site man-hours. |
| [`lib/core/utils/salary_cycle_helper.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/salary_cycle_helper.dart) | Core utility managing calendar-month, Oct Interim OT transition, and legacy 25th–24th salary cycle resolution and period calculations. |
| [`lib/core/utils/leave_calculator.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/leave_calculator.dart) | Engine calculating daily presence, absences, Sunday weekly off days, and Sunday duties. |
| [`lib/features/timesheet/domain/timesheet_entry.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/domain/timesheet_entry.dart) | Timesheet entry, site visit, and site man-hour summary domain models. |
| [`lib/features/timesheet/presentation/timesheet_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/presentation/timesheet_cubit.dart) | Cubit fetching attendance records and transforming them into timesheet states. |
| [`lib/features/timesheet/presentation/employee_timesheet_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/presentation/employee_timesheet_screen.dart) | Timesheet UI with Salary Cycle selector, KPI cards, shift filter tabs (`All`, `Regular`, `Overtime`), site visit timeline, and PDF export button. |
| [`lib/features/admin/presentation/admin_edit_attendance_dialog.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_edit_attendance_dialog.dart) | Admin modal for editing check-in/out timestamps, manual OT hours, and remarks. |
| [`lib/features/admin/presentation/work_site_management_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/work_site_management_screen.dart) | Admin UI screen for managing client work sites, GPS coordinates, and geofence radii. |
| [`lib/features/admin/domain/work_site_entity.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/domain/work_site_entity.dart) | Work site domain model. |
| [`test/auto_checkout_24h_test.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/test/auto_checkout_24h_test.dart) | Unit test suite verifying 24-hour shift capping and 8h regular limit. |
| [`test/break_time_deduction_test.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/test/break_time_deduction_test.dart) | Unit test suite verifying 1h food break & 1h travel tolerance overtime rules. |
| [`test/emergency_duty_test.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/test/emergency_duty_test.dart) | Unit test suite verifying emergency duty 100% overtime calculation. |
| [`test/salary_cycle_test.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/test/salary_cycle_test.dart) | Unit tests verifying calendar-month, Oct transition, and legacy 25th-to-24th salary cycle boundaries. |

