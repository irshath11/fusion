# 13. Salary, Payroll & WPS Export Module

## Overview
The **Salary, Payroll & WPS Export Module** (`lib/features/salary/`) provides end-to-end automated monthly payroll computation, day-wise salary ledgers, manual office attendance entry, overtime rate governance, October transition Interim Overtime accounting, and official **UAE Wage Protection System (WPS)** Excel & PDF export generation across **Fusion Electro-Mechanical Maintenance LLC** and **Fusion Neo Building Contracting LLC**.

---

## 1. Key Capabilities

### 1. Division-Aware Workforce Payroll & WPS Registry
- Supports dual company divisions from [`WpsMasterRegistry`](../lib/core/constants/wps_registry.dart):
  - **Fusion Electro-Mechanical Maintenance LLC** (`department = 'Fusion'`, MOL No: `803095`)
  - **Fusion Neo Building Contracting LLC** (`department = 'Neo'`, MOL No: `2846014`)
- Stores official **Work Permit Numbers**, **Personal Numbers**, **Bank Names** (e.g., `NBAD`, `ADCB`), **Bank Account Numbers / IBANs**, and default basic salaries.
- Pre-seeded master salary configurations in [`DefaultSalaryData`](../lib/features/salary/data/default_salary_data.dart) and [`backend/create_employee_salaries_table.sql`](../backend/create_employee_salaries_table.sql) (including active technician Alnaser Samsudeen, code `1058`).
- **Owner & Relieved Staff Exclusion (`SalaryCalculator.isExcludedOwner`)**: Automatically excludes non-payroll company partners/directors (e.g., Nasurudeen, Sirajudeen) and relieved personnel (e.g., Asik Saheel via `EmployeeDirectoryHelper.isRelievedEmployee`) from payroll runs, WPS exports, and database seeding.

### 2. Salary Structure & Overtime Calculation Rules (`EmployeeSalaryConfig` & `SalaryCalculator`)
Each employee's configuration (`employee_salaries` table & local Hive `salaries_json`) tracks:
- **Fixed / Basic Salary (`fixed_salary`)**: Base monthly salary component.
- **Variable Salary / Allowance (`variable_salary`)**: Monthly variable/allowance component.
- **Daily Proration Rates**:
  - $\text{Daily Fixed Rate} = \frac{\text{Basic Salary}}{\text{Days in Month}}$
  - $\text{Daily Variable Rate} = \frac{\text{Variable Salary}}{\text{Days in Month}}$
- **Strict Basic-Only Hourly OT Rate**:
  - By default, overtime hourly rate is computed strictly from **Basic Salary ONLY** (variable allowance is excluded):
    $$\text{Hourly OT Rate} = \frac{\text{Basic Salary} / \text{Days in Month}}{\text{Standard Daily Hours (8.0)}}$$
  - **OT Included in Variable (`ot_included_in_variable`)**: When enabled (e.g., supervisory or fixed-allowance staff), hourly OT rate is set to `0.0` AED/hr and no separate hourly OT is credited.
  - **Custom OT Hourly Rate (`custom_ot_hourly_rate`)**: Optional per-employee hourly rate override.
  - **Custom Monthly OT Amount (`custom_monthly_ot_amount`)**: Optional fixed monthly OT amount (AED) overriding hourly OT calculation, distributed proportionally across OT-worked days in the day-wise ledger (`backend/add_custom_monthly_ot_amount_column.sql`).

### 3. Day-Wise Salary Ledger & Paid Sunday Rules (`DailySalaryRecord`)
Every calendar day within the active cycle is categorized into one of six `DailySalaryStatus` states:
| Status | Label | Payable | Description |
| :--- | :--- | :---: | :--- |
| `present` | **Present** | ✅ | Scheduled working day (Mon–Sat) with attendance logged; earns Daily Fixed + Daily Variable + OT Credit. |
| `sundayDuty` | **Sunday Duty** | ✅ | Sunday with attendance logged; 100% of worked hours convert to Overtime (`regularHours = 0.0`) + earns Daily Fixed & Variable. |
| `paidSundayOff` | **Paid Sunday Off** | ✅ | Unworked Sunday credited as payable when **worked on the following Monday** (`pay_sunday_if_monday_worked`) OR when **worked both before and after** the Sunday in the cycle (In-Between Weekly Off). |
| `absent` | **Absent / Leave** | ❌ | Working day (Mon–Sat) with no attendance; 0.0 credit. |
| `unpaidSundayOff` | **Unpaid Sunday** | ❌ | Unworked Sunday not meeting Paid Sunday Off criteria; 0.0 credit. |
| `futureDay` | **Upcoming** | ❌ | Unreached calendar date after `referenceDate`. |

### 4. November 2026 Interim Overtime Rollover (`26–31 Oct 2026`)
- When the organization transitioned from the legacy 25th-to-24th cycle (`25 Sep – 25 Oct 2026`) to full calendar-month cycles starting **1 November 2026**, the 6-day gap (**26 Oct – 31 Oct 2026**) was isolated as the **October Transition Interim OT Period** (`SalaryCycle.octoberTransition()`, ID `2026-10-transition`).
- For the **November 2026** cycle, `SalaryCalculator` automatically computes Interim Overtime earned during `26–31 Oct 2026` (`interimOtHours`, `interimOtSalary`) and credits it into the employee's **Earned Variable Salary** (`earnedVariableSalary = baseVariableSalary + interimOtSalary`), reflected across the UI (`EmployeeSalaryDetailSheet`, `SalaryPayrollScreen`) and Master/WPS Excel exports.
- Dedicated **Interim OT Breakdown Modal** (`InterimOtBreakdownDialog`) displays day-by-day OT hours (`26–31 Oct`), division filtering (`ALL`, `NEO`, `ELECTRO`), search, and 1-click **Interim OT Excel** & **Interim OT PDF** downloads.

### 5. Calendar-Based Manual Office Attendance (`PutOfficeAttendanceDialog`)
- Enables admins to record attendance for office-based or non-mobile staff directly via an interactive cycle calendar picker (`deviceId: 'OFFICE_CALENDAR_ENTRY'`, `remarks: 'Office Attendance (Calendar)'`).
- Supports entering total monthly overtime hours alongside selected working dates.
- Performs **instant local Hive persistence** for immediate UI recalculation paired with **non-blocking bulk cloud sync** (`SupabaseService`).

### 6. Modernized Payroll UI & Responsive Viewport (`SalaryPayrollScreen`)
- Integrated as the **8th tab (`Salary & Payroll`)** in [`AdminDashboardScreen`](../lib/features/admin/presentation/admin_dashboard_screen.dart).
- Features:
  - Cycle switcher with previous/next navigation across calendar months, `26–31 Oct 2026` Interim OT cycle, and historical legacy cycles.
  - Collapsible executive KPI analytics banner (`_showKpiBanner`) maximizing the employee list viewport.
  - Status tabs: **All Staff**, **Clocked**, **0 Days Logged**, and **Manual Attendance** (`isCalendarAttendance`).
  - Division filter (`ALL`, `Fusion`, `Neo`) and live employee name/code/department search.
  - High-contrast light & dark theme styling (`EmployeeSalaryDetailSheet`, `PutOfficeAttendanceDialog`, `InterimOtBreakdownDialog`).

### 7. Multi-Format Payroll Exports
- **Fusion Neo WPS Excel** (`Neo_employees-WPS_MM-YYYY.xlsx`): Division-formatted Wage Protection System spreadsheet via `ExcelCsvExportService.exportFusionNeoWpsExcel()`.
- **Fusion Electro WPS Excel** (`Fusion-electro-employees-WPS_MM-YYYY.xlsx`): Division-formatted WPS spreadsheet via `ExcelCsvExportService.exportFusionElectroWpsExcel()`.
- **Master Estimated Payroll Details Excel** (`Total_Estimated_Payroll_Details_MM-YYYY.xlsx`): Executive summary + separate Fusion & Neo sheets including prorated fixed, variable, interim OT, and OT totals.
- **Workforce Salary Payroll PDF** (`Workforce_Salary_Payroll_<cycle>.pdf`) & **Individual Employee Payslip PDF** (`Payslip_<code>_<cycle>.pdf`) with complete day-wise calculation ledger via `PdfExportService`.
- **Interim OT Excel & PDF** (`26–31 Oct 2026`) via `ExcelCsvExportService.exportInterimOtExcel()` & `PdfExportService.exportInterimOtPdf()`.

---

## 2. Database Schema (`public.employee_salaries`)

Defined in [`backend/create_employee_salaries_table.sql`](../backend/create_employee_salaries_table.sql) and [`backend/add_custom_monthly_ot_amount_column.sql`](../backend/add_custom_monthly_ot_amount_column.sql):

| Column | Type | Default / Constraint | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | Unique salary config identifier |
| `organization_id` | `UUID` | `REFERENCES organizations(id)` | Tenant organization FK |
| `employee_code` | `VARCHAR(50)` | `NOT NULL UNIQUE` | Official employee code (`1004`, `N-1003`, etc.) |
| `employee_id` | `VARCHAR(100)` | Nullable | Linked employee UUID |
| `employee_name` | `VARCHAR(255)` | `NOT NULL` | Full employee name |
| `department` | `VARCHAR(100)` | `'General'` | Division (`Fusion` or `Neo`) |
| `fixed_salary` | `DOUBLE PRECISION` | `0.0` | Monthly Basic / Fixed Salary (AED) |
| `variable_salary` | `DOUBLE PRECISION` | `0.0` | Monthly Variable / Allowance (AED) |
| `daily_divisor` | `DOUBLE PRECISION` | `30.0` | Standard divisor for daily base rate |
| `standard_daily_hours` | `DOUBLE PRECISION` | `8.0` | Standard shift hours per day |
| `custom_ot_hourly_rate` | `DOUBLE PRECISION` | Nullable | Optional custom hourly OT override |
| `custom_monthly_ot_amount` | `DOUBLE PRECISION` | Nullable | Optional fixed monthly OT amount (AED) |
| `ot_included_in_variable` | `BOOLEAN` | `FALSE` | If `TRUE`, OT rate is `0.0` (fixed OT in variable) |
| `pay_sunday_if_monday_worked` | `BOOLEAN` | `TRUE` | Credits Sunday if Monday is worked |

Row-Level Security (RLS) restricts `INSERT`/`UPDATE`/`DELETE` on `employee_salaries` to `ADMIN` and `SUPER_ADMIN` roles.

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/salary/presentation/salary_payroll_screen.dart`](../lib/features/salary/presentation/salary_payroll_screen.dart) | Main Salary & Payroll dashboard with collapsible KPIs, division/status filters, cycle navigation, and export triggers. |
| [`lib/features/salary/utils/salary_calculator.dart`](../lib/features/salary/utils/salary_calculator.dart) | Core day-wise payroll calculation engine, Paid Sunday Off rules, Nov Interim OT rollover, and owner/relieved exclusions. |
| [`lib/features/salary/domain/employee_salary_config.dart`](../lib/features/salary/domain/employee_salary_config.dart) | Per-employee salary structure model (`fixedSalary`, `variableSalary`, `customMonthlyOtAmount`, `otIncludedInVariable`). |
| [`lib/features/salary/domain/employee_salary_summary.dart`](../lib/features/salary/domain/employee_salary_summary.dart) | Individual (`EmployeeSalarySummary`) and workforce (`WorkforceSalarySummary`) aggregated payroll totals. |
| [`lib/features/salary/domain/daily_salary_record.dart`](../lib/features/salary/domain/daily_salary_record.dart) | Day-wise salary record model and `DailySalaryStatus` enum. |
| [`lib/features/salary/presentation/edit_salary_dialog.dart`](../lib/features/salary/presentation/edit_salary_dialog.dart) | Modal form for configuring fixed/variable salary, custom OT hourly rate, fixed monthly OT amount, and Sunday rules. |
| [`lib/features/salary/presentation/employee_salary_detail_sheet.dart`](../lib/features/salary/presentation/employee_salary_detail_sheet.dart) | Bottom sheet showing day-wise ledger, OT toggles, manual attendance trigger, and payslip PDF export. |
| [`lib/features/salary/presentation/put_office_attendance_dialog.dart`](../lib/features/salary/presentation/put_office_attendance_dialog.dart) | Calendar picker dialog for saving manual office attendance and OT hours with instant local + non-blocking cloud sync. |
| [`lib/features/salary/presentation/interim_ot_breakdown_dialog.dart`](../lib/features/salary/presentation/interim_ot_breakdown_dialog.dart) | Dedicated `26–31 Oct 2026` Interim OT breakdown modal with Excel & PDF export actions. |
| [`lib/features/salary/data/default_salary_data.dart`](../lib/features/salary/data/default_salary_data.dart) | Pre-seeded salary configurations for Fusion and Neo staff. |
| [`lib/core/constants/wps_registry.dart`](../lib/core/constants/wps_registry.dart) | Official `WpsMasterRegistry` mapping employees to MOL numbers, Work Permit IDs, Personal IDs, and Bank Accounts. |
| [`test/salary_calculator_test.dart`](../test/salary_calculator_test.dart) | Unit tests covering basic-only OT rates, Paid Sunday Off rules, Nov Interim OT rollover, prorated WPS math, and isolation. |
