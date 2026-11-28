# 12. Enterprise Leave Records, Weekly Off Rules & Configurable Salary Cycles

## Overview
The **Leave Records & Salary Cycle Engine** aligns the workforce attendance tracking system with real-world enterprise operations in the Gulf / UAE region. Historically, payroll cycles operated from the **25th of the prior month to the 24th of the current month**; starting **November 2026**, the organization transitioned to **full Calendar-Month Cycles (1st to last day of month)** with a dedicated **6-day October Transition Interim Overtime Period (`26 Oct – 31 Oct 2026`)**. Operational regulations also designate **Sunday as the mandatory weekly off day**, with special compensation and overtime rules governing Sunday shifts.

---

## 1. Company Salary Cycle Engine (`SalaryCycle` & `SalaryCycleHelper`)

### Cycle History & Calendar Boundary Definition
`SalaryCycleHelper` (`SalaryCycle.fromDate` and `SalaryCycle.forMonth`) resolves cycles across three eras:
1. **November 2026 Onwards (Calendar Month Cycle)**:
   - Runs from **1st of month `00:00:00.000`** to **last day of month `23:59:59.999`** (e.g., `01 Nov 2026 – 30 Nov 2026`).
2. **26 Oct – 31 Oct 2026 (October Transition Interim OT Cycle)**:
   - 6-day bridge period (`SalaryCycle.octoberTransition()`, ID `'2026-10-transition'`) specifically tracking **Interim Overtime**, which is automatically rolled into November 2026's variable salary component (`SalaryCalculator`).
3. **Prior to 26 Oct 2026 (Legacy 25th-to-24th Cycle)**:
   - Historical cycles: `25 Aug – 24 Sep 2026` (Sep 2026) and `25 Sep – 25 Oct 2026` (Oct 2026).

### Dynamic Cycle Resolution Algorithm
When an operator or employee selects any reference date, `SalaryCycle.fromDate(DateTime date)` resolves the target cycle:
```dart
if (year > 2026 || (year == 2026 && month >= 11)) {
  // From 1 Nov 2026 onwards: calendar month cycle (1st to last day of month)
  return SalaryCycle.forMonth(year, month);
} else if (year == 2026 && month == 10 && day >= 26) {
  // October transition window: 26 Oct 2026 to 31 Oct 2026
  return SalaryCycle.octoberTransition();
} else if (day >= 25) {
  // Legacy 25th-to-24th cycle
  ...
}
```

### Salary Cycle Metrics (`SalaryCycleMetrics`)
Across any resolved salary cycle, the engine calculates:
- **`totalDays`**: Total calendar days within the period (e.g., 30/31 days, or 6 days for the Oct transition).
- **`daysWorked`**: Count of daily timesheet entries within the cycle.
- **`regularHours`**: Standard hours (capped at 8.0h per standard Mon–Sat working day).
- **`overtimeHours`**: Total overtime accrued (after break + travel tolerance on regular days, + emergency duty + 100% of Sunday duty).
- **`emergencyDutyHours`**: Total emergency callout hours logged.
- **`combinedHours`**: `regularHours + overtimeHours`.

> For full payroll computation, Paid Sunday Off rules, and UAE WPS exports, see [13. Salary, Payroll & WPS Export Module](13_salary_payroll_and_wps_module.md).

---

## 2. Leave Ledger & Attendance Categorization (`LeaveCalculator`)

The system automatically generates a daily compliance ledger for every calendar day in the cycle, classifying each day into one of five definitive statuses:

```mermaid
graph TD
    Day[Calendar Day in Cycle] --> IsFuture{Date > Today?}
    IsFuture -- Yes --> Future[LeaveDayType.futureDay<br/>Upcoming Day]
    IsFuture -- No --> IsSunday{Weekday == Sunday?}
    
    IsSunday -- Yes --> SundayWorked{Attendance Logged?}
    SundayWorked -- Yes --> SunDuty[LeaveDayType.sundayDuty<br/>Sunday Duty - 100% Overtime]
    SundayWorked -- No --> SunOff[LeaveDayType.sundayWeeklyOff<br/>Standard Weekly Off]
    
    IsSunday -- No --> WeekdayWorked{Attendance Logged?}
    WeekdayWorked -- Yes --> Present[LeaveDayType.present<br/>Regular Duty Present]
    WeekdayWorked -- No --> Absent[LeaveDayType.leaveAbsent<br/>Leave / Absent Day]
```

### Categorization Table (`LeaveDayType`)

| Enum Value | Label | Description & Calculation Rule |
| :--- | :--- | :--- |
| `present` | **Present** | Scheduled working day (Monday–Saturday) with at least one valid attendance check-in. |
| `leaveAbsent` | **Leave / Absent** | Scheduled working day (Monday–Saturday) where no attendance was logged. Counted as unapproved absence or approved leave. |
| `sundayWeeklyOff` | **Sunday (Weekly Off)** | Sunday with no attendance logged. Standard designated weekly rest day. Does not reduce attendance percentage. |
| `sundayDuty` | **Sunday Duty (Worked)** | Sunday where employee logged duty. Compensated with special overtime premium. |
| `futureDay` | **Upcoming** | Unreached calendar dates within the active cycle. Excluded from compliance ratios. |

### Aggregated Employee Leave Summary (`EmployeeLeaveSummary`)
For each employee, the `LeaveCalculator.calculateEmployeeLeaveSummary()` calculates:
- **Scheduled Working Days**: Total non-Sunday calendar days up to the current date.
- **Present Days**: Days with verified duty.
- **Leave / Absent Days**: Scheduled working days missed.
- **Sunday Weekly Offs**: Approved rest days enjoyed.
- **Sunday Duties**: Rest days worked in the field.
- **Attendance Percentage**: 

$$\text{Attendance Rate} = \left( \frac{\text{Present Days}}{\text{Scheduled Working Days to Date}} \right) \times 100\%$$

---

## 3. Sunday Overtime & Holiday Duty Rule

In standard Gulf workforce agreements, regular daily working hours on Monday through Saturday are capped at **8.0 hours** (`standardRegularHoursPerDay = 8.0`), with excess hours treated as standard overtime.

**Special Sunday Rule**:
1. Sunday is the official organizational weekly off day.
2. If an employee logs attendance on a Sunday (`r.eventTimestamp.weekday == DateTime.sunday`), the system automatically treats the entire shift duration as **100% Overtime Hours**:
   - **Regular Hours** = `0.0 hours`
   - **Overtime Hours** = `totalWorkedHours`
3. This guarantees accurate payroll overtime export without requiring manual timesheet adjustments by payroll administrators.

---

## 4. 24-Hour Auto-Checkout Safety Guard

To prevent timesheet distortion when field personnel forget to perform step `4. Office Check-Out`, the system enforces an automated 24-hour capping safeguard:

1. **Shift In-Progress vs. Stale Shift**:
   - If a shift has an `Office Check-In` with no check-out, and the elapsed duration is **under 24 hours**, the shift remains active in the UI as **In Progress**.
2. **24-Hour Overrun Capping**:
   - If an unclosed shift crosses **24 hours** from initial check-in time:
     - The shift is automatically finalized and marked as `isAutoCompleted: true`.
     - Daily work hours are safely capped at **8.0 standard regular hours**.
     - Overtime hours are strictly set to **0.0 hours**.
3. **Audit Trail**: The system records the synthetic check-out in local and cloud stores with the notation `Auto Check-Out (24-Hour Limit Reached)`, ensuring timesheet metrics are never corrupted by runaway durations (e.g. 72-hour continuous shifts).

---

## 5. Strict Employee Identity Reconciliation & Relieved Staff Exclusion (`EmployeeDirectoryHelper`)

In enterprise environments with legacy personnel data and diverse identification formats, records may reference employee codes with or without branch prefixes (e.g., `1004` vs `N-1004`), leading zeroes, or slight name spelling differences.

The [`EmployeeDirectoryHelper`](../lib/core/utils/employee_directory_helper.dart) provides unified, contamination-free identity matching:
1. **Strict Identity Matching (`matchesEmployeeIdentity`)**: Resolves official records for both target and attendance log entries first. Conflicting human names or distinct resolved official IDs never merge, preventing cross-employee log contamination.
2. **Relieved Staff Exclusion (`isRelievedEmployee`)**: Excludes former/relieved personnel (e.g., Asik Saheel) across directories, leave summaries, cards, and payroll calculations.
3. **Avatar Mapping**: Automatically links employee codes to official portrait assets (`assets/images/employees/1004.png` or `N-1003.png`) across both Flutter and Web Admin.

---

## 6. Key Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/core/utils/salary_cycle_helper.dart`](../lib/core/utils/salary_cycle_helper.dart) | Core utility managing calendar-month, Oct Interim OT transition, and legacy 25th–24th salary cycle resolution and metrics. |
| [`lib/core/utils/leave_calculator.dart`](../lib/core/utils/leave_calculator.dart) | Calculation engine for daily leave records, Sunday weekly offs, Sunday duties, and attendance percentages. |
| [`lib/core/utils/timesheet_calculator.dart`](../lib/core/utils/timesheet_calculator.dart) | Timesheet aggregation incorporating salary cycles, break/travel tolerance, Sunday 100% OT rules, and 24-hour auto check-outs. |
| [`lib/core/utils/employee_directory_helper.dart`](../lib/core/utils/employee_directory_helper.dart) | Helper for strict identity matching, relieved staff exclusion, badge normalization, and avatar bindings. |
| [`lib/core/widgets/employee_avatar.dart`](../lib/core/widgets/employee_avatar.dart) | Reusable UI component rendering official portrait photos with fallback initials. |
| [`test/salary_cycle_test.dart`](../test/salary_cycle_test.dart) | Unit test suite verifying calendar-month, Oct transition, and legacy 25th–24th boundary transitions. |
| [`test/leave_calculator_test.dart`](../test/leave_calculator_test.dart) | Unit test suite validating leave categorization, Sunday off days, and duty detection. |
| [`test/auto_checkout_24h_test.dart`](../test/auto_checkout_24h_test.dart) | Unit tests verifying the 24-hour unclosed shift auto-completion rule. |
| [`test/employee_records_reassignment_test.dart`](../test/employee_records_reassignment_test.dart) | Unit tests verifying strict employee log isolation and relieved employee exclusion. |
