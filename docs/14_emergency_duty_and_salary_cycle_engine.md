# 14. Emergency Duty & Salary Cycle Engine Feature

## Overview
The **Emergency Duty & Salary Cycle Engine** feature provides specialized operational handling for on-call/emergency workforce shifts and enterprise payroll calculation. It includes dedicated workflow steps for emergency dispatch, administrative management of emergency duty logs, and an organization-wide salary cycle engine that aligns reporting and timesheets with corporate cutoffs (25th of month to 24th of next month).

---

## 1. Key Functionalities

### A. Emergency Duty Workflow (`WorkflowStep.emergencyCheckIn` & `WorkflowStep.emergencyCheckOut`)
1. **On-Call & Emergency Shift Dispatch**:
   - Field engineers responding to out-of-hours emergencies, system breakdowns, or urgent facility incidents can log duty without violating standard 4-step sequence rules.
   - **Emergency Check-In (`EMERGENCY_CHECK_IN`)**: Records arrival at the emergency location with live camera selfie, timestamp, and GPS coordinates.
   - **Emergency Check-Out (`EMERGENCY_CHECK_OUT`)**: Records completion of emergency service and departure from the site.
   - Geofence restrictions can be dynamically relaxed or validated against the client site coordinates.

2. **Admin Add & Edit Emergency Logs**:
   - Administrators and Super Admins can manually add or adjust emergency duty records directly from the **Admin Dashboard** and **Reports & Analytics Screen** (`_showAddEmergencyLogDialog`).
   - Ensures accurate timesheet auditing when field staff respond to sudden power outages or night repairs.

3. **Dedicated Timesheet Hour Calculations (`TimesheetCalculator`)**:
   - Emergency shift durations are calculated independently from regular scheduled shifts.
   - Enables customized overtime or emergency hazard pay multiplier rules in payroll exports.

---

### B. Enterprise Salary Cycle Engine (`SalaryCycleHelper` & `SalaryCycle`)
1. **25th-to-24th Corporate Payroll Boundary**:
   - Standard business months do not match calendar months; corporate payroll runs from the **25th of the prior month to the 24th of the current month**.
   - Example: **September 2026 Salary Cycle** runs from **25 August 2026 (00:00:00)** through **24 September 2026 (23:59:59)**.
   - Automatic determination:
     - If current day $\ge 25$, the cycle belongs to next month's salary period (`start = 25th current month`, `end = 24th next month`).
     - If current day $< 25$, the cycle belongs to current month's salary period (`start = 25th previous month`, `end = 24th current month`).

2. **Active Salary Cycle Header & Ticker**:
   - Prominently displays the active salary cycle (e.g. `Active Salary Cycle: 25 Aug 2026 – 24 Sep 2026 (Sep 2026)`) across:
     - **Admin Dashboard**: Executive overview cards summarize attendance within the active cycle.
     - **Reports & Analytics Screen**: Dynamic salary cycle dropdown filter allows switching between current and historical payroll periods.
     - **Employee Timesheet Screen**: Timesheets aggregate hours strictly within the selected salary cycle.

3. **Earliest Cycle Boundary Enforcement**:
   - Sets `earliestSalaryYear = 2026` and `earliestSalaryMonth = 9` (Sep 2026 cycle: 25 Aug – 24 Sep).
   - Eliminates redundant or empty historical months prior to system deployment.

4. **Multi-File Filtering Helpers**:
   - `SalaryCycleHelper.filterAttendanceRecords(records, cycle)`: Filters attendance logs within exact cycle millisecond boundaries.
   - `SalaryCycleHelper.filterTimesheetEntries(entries, cycle)`: Filters daily timesheets within cycle boundaries.

---

## 2. Technical Implementation & Data Structures

### `SalaryCycle` Class
```dart
class SalaryCycle {
  final DateTime startDate;
  final DateTime endDate;
  final int salaryMonth;
  final int salaryYear;

  factory SalaryCycle.fromDate(DateTime date) { ... }
  factory SalaryCycle.forMonth(int year, int month) { ... }
  static SalaryCycle current([DateTime? referenceDate]) { ... }
  static List<SalaryCycle> getRecentCycles({int? count, DateTime? referenceDate}) { ... }
}
```

### Emergency Duty Workflow Steps
```dart
enum WorkflowStep {
  officeCheckIn,
  siteCheckIn,
  siteCheckOut,
  breakStart,
  breakEnd,
  officeCheckOut,
  completed,
  emergencyCheckIn,
  emergencyCheckOut,
}
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/core/utils/salary_cycle_helper.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/salary_cycle_helper.dart) | Core utility providing salary cycle boundary calculations, formatting, and record filtering. |
| [`test/salary_cycle_test.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/test/salary_cycle_test.dart) | Comprehensive unit tests verifying 25th-24th date boundary math and edge cases (month roll-overs, leap years). |
| [`test/emergency_duty_test.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/test/emergency_duty_test.dart) | Unit tests verifying emergency duty log creation, validation, timesheet impact, and admin editing. |
| [`lib/features/admin/presentation/admin_dashboard_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_dashboard_screen.dart) | Dashboard displaying Active Salary Cycle header and emergency duty actions. |
| [`lib/features/admin/presentation/reports_analytics_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/reports_analytics_screen.dart) | Reports screen with dynamic salary cycle selector and emergency log audit dialogs. |
| [`lib/features/timesheet/presentation/employee_timesheet_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/presentation/employee_timesheet_screen.dart) | Timesheet screen with cycle selector for payroll-accurate work duration auditing. |
