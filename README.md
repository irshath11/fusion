# Offline-First Employee Attendance, Field Workforce Tracking & Timesheet Management Application

Enterprise-grade, offline-first mobile and web application built using **Flutter**, **Flutter Web**, **Supabase (PostgreSQL, RLS, Storage)**, **Firebase Authentication**, **Hive Local Storage**, and **Clean Architecture**.

---

## 🌟 Key Application Features & Specifications

### 1. Dual-Role Architecture & Dedicated Admin Web Application
- **Super Admin & Admin Web & Mobile Suite**: Standalone Web Admin Portal (`web_admin`) and Flutter Web/Mobile Admin Dashboard (8 navigation tabs: Overview, Employees, Cards & Passes, Offices, Work Sites, Live Map, Reports, and **Salary & Payroll**) with 3-tier RBAC (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`), multi-theme selector (5 curated palettes with Light & Dark modes), and real-time GPS tracking.
- **Employee Mobile Portal**: Enforced 4-step daily attendance workflow stepper (plus Break Start/End and Emergency Duty Check-In/Out), live selfie photo capture, geofence verification, personal work timesheet summary, and pending offline sync monitor.

### 2. First-Time Setup Wizard
- When opened for the very first time, prompts for **Organization Name**, **Address**, **Super Admin Credentials**, and automatically provisions the organization, default office, and root Super Admin account (`role = 'SUPER_ADMIN'`).
- Sets persistent setup flags so future app launches automatically route directly to the **Login Screen**.

### 3. Dual-Layer Authentication & Password Security
- **Primary Firebase Auth + Local Hive Database Fallback**: Authenticates via Firebase Authentication; seamlessly falls back to local database profiles (`app_settings` Hive box) and demo admin credentials if Firebase is unreachable or throws credential exceptions (`invalid-credential`, `user-not-found`).
- **Universal Password Visibility Toggles**: All password input fields across the application (Login, Setup Wizard, Employee Password Update, User Creation Form, Ownership Transfer) feature interactive show/hide eye icon toggle buttons (`Icons.visibility_outlined` / `Icons.visibility_off_outlined`).

### 4. Strict 4-Step Sequential Attendance Workflow Engine
`1. Office Check-In` ➔ `2. Site Check-In` ➔ `3. Site Check-Out (Leaving Site)` ➔ `4. Office Check-Out (Reach Office)` ➔ `Shift Completed`
- State locks prevent skipping steps or altering step execution order.
- `SiteNameDialog` dropdown prompts selection from pre-configured work sites (`RELAAM (AMC)`, `RELAAM (WO)`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS (AMC)`, `OTHERS (WO)`) or custom location inputs.

### 5. Employee Work Timesheet Engine
- **Automatic Hour Calculation**: Calculates total daily work duration between `1. Office Check-In` and `4. Office Check-Out` (with Admin attendance editing & manual OT override support via `AdminEditAttendanceDialog`).
- **Regular, Break, Travel Tolerance & Overtime Hours**: Caps regular working hours at **8.0 hours per day** (Mon–Sat). For shifts exceeding 8.0 gross hours, deducts **1 hour food break** (or logged break if greater) and applies **1 hour travel tolerance** — Overtime accrues after 10 gross hours. Emergency Duty logs (`emergencyCheckIn` / `emergencyCheckOut`) are credited at **100% Overtime**.
- **Site Visit Breakdown**: Captures detailed site visit durations (`SiteVisitSummary`) and client man-hour summaries (`calculateSiteManHours`) for each field location visited during the shift.
- **Timesheet PDF Export**: Generates and downloads individual and master timesheet reports in PDF format directly from the app.

### 6. Work Site & Construction Project Registry
- Dedicated registry for client project sites (`WorkSiteManagementScreen`, `work_sites` database table) with custom client names, physical addresses, GPS coordinates, and geofence radii.

### 7. Hardware Device Binding & Fingerprinting
- Hardware device identification using `device_info_plus` across Android (`androidInfo.id`), iOS (`identifierForVendor`), Windows (`deviceId`), and Web (`userAgent`).
- Binds unique hardware device IDs to user accounts in Supabase (`devices` table) for session security and hardware authentication.

### 8. Organization Ownership Transfer Engine
- Atomic organization ownership transfer (`OwnershipTransferCubit`, `transfer_organization_ownership` SQL stored procedure).
- Promotes a target Administrator to Super Admin while demoting the current Super Admin to Administrator in a single database transaction, backed by mandatory password re-authentication and audit logging (`OWNERSHIP_TRANSFERRED`).

### 9. Real-time Camera Capture & Compression
- Direct integration with front selfie camera stream (`camera` package).
- **Gallery uploads & file pickers are strictly disabled**.
- Images are automatically downscaled to **480px** and compressed to **65% JPEG quality** (~25KB–45KB payload, **99% payload reduction**) before storage/sync.

### 10. Haversine Geofence Validation & Per-Employee Bypass Controls
- Validates real-time GPS location against assigned office or site coordinates using the Haversine spherical distance formula during `1. Office Check-In`.
- Displays immediate warning modal: `"You are outside the permitted attendance area."` if user is outside allowed radius (default 200m).
- **Per-Employee Geofence Enable / Disable Toggle (`bypassGeofence`)**: Admins can enable or disable geofence enforcement per employee in Flutter (`EmployeeManagementScreen`, `UserFormDialog`) and Web Admin (`web_admin`), synced via Supabase (`bypass_geofence` columns) and Hive local overrides (`geofence_bypass_overrides`).

### 11. Employee Office Override Support
- Allows assigning custom client offices or branch stations to specific employees (`useDefaultOffice: false`).
- Attendance geofence rules validate against the employee's specific assigned office location.

### 12. Offline-First Operation & Background Sync Engine
- Local Hive key-value boxes store attendance logs, photos, and sync queues without internet.
- Sync engine automatically flushes queue upon connectivity restoration while preserving original `event_timestamp`.

### 13. Analytics & Multi-Format Report Export
- Generates downloadable compliance reports in **PDF**, **Excel (.xlsx)**, and **CSV** formats with customizable filters and a **Salary Cycle selector** directly on the main attendance reports screen (`ReportsAnalyticsScreen`).
- **WPS & Payroll Exports**: Generates division-specific UAE WPS Excel files (`Neo_employees-WPS_MM-YYYY.xlsx`, `Fusion-electro-employees-WPS_MM-YYYY.xlsx`), Master Estimated Payroll Details Excel, Interim OT Excel/PDF (`26–31 Oct 2026`), Workforce Payroll PDF, and individual employee Payslip PDFs.

### 14. Statutory Cards Management & Gemini Multimodal AI Vision OCR
- **Compliance Document Tracking**: Centrally tracks employee statutory cards and field access passes (`EMIRATES_ID`, `VISA`, `PASSPORT`, `INSURANCE`, `MOPA_PASS`, `CISPA_PASS`, and `CUSTOM_PASS`).
- **Google Gemini Multimodal AI Vision**: Automatically scans uploaded card photos or PDF scans (`CardOcrService`) and extracts document type, card number, employee name, issue date, and expiry date.
- **Dynamic Expiry Lifecycle**: Real-time status badges for **Expired** (<0d), **Critical** (≤3d), **Expiring Soon** (≤30d), and **Valid** (>30d).

### 15. Automated Multi-Channel Notification Robot
- **Supabase Database Cron (`pg_cron` & `pg_net`)**: Dispatches automated daily compliance checks every morning at **08:00 AM Gulf Standard Time (GST)** via `backend/supabase_cron_job.sql`.
- **Automated Email & WhatsApp Alerts**: Broadcasts urgent renewal alerts via **Resend API** to operations executives (`sr.irshath@gmail.com, nasuru@fusionmaint.com`) and automated WhatsApp alerts via **CallMeBot API** to `+971586939371`.
- **Client-Side Quick Triggers**: 1-click WhatsApp (`https://wa.me/...`) and pre-composed email drafting directly from the Flutter app and Web Admin Portal.
- **Dedicated Documentation**: See [Cards Management & Expiry Notification Module Manual](docs/CARD_AND_EXPIRY_NOTIFICATION_MODULE.md) for full operational, architectural, and setup runbooks.

### 16. Configurable Salary Cycle Engine & Leave Records Ledger
- **Calendar-Month & Transition Salary Cycles (`SalaryCycleHelper`)**:
  - **Nov 2026 Onwards**: Full calendar-month cycles (`1st` to last day of month, e.g. `01 Nov – 30 Nov 2026`).
  - **26–31 Oct 2026 Transition Window**: Dedicated 6-day **Interim OT Cycle** (`2026-10-transition`) tracking transition overtime, automatically rolled into November 2026's variable payroll component.
  - **Prior to 26 Oct 2026**: Legacy 25th-to-24th payroll cycles (`25 Aug – 24 Sep`, `25 Sep – 25 Oct 2026`).
- **Daily Leave Records Ledger**: Categorizes every calendar day into 5 definitive states: `Present`, `Leave / Absent`, `Sunday (Weekly Off)`, `Sunday Duty (Worked)`, and `Upcoming` (`LeaveCalculator`).

### 17. 24-Hour Auto-Checkout Safety Guard & Sunday 100% OT Rule
- **24-Hour Auto-Checkout**: Any unclosed shift exceeding 24 hours without an official check-out is automatically capped at **8.0 standard regular hours** and **0.0 overtime hours** (`isAutoCompleted: true`), protecting timesheet calculations from runaway shift lengths.
- **Sunday 100% Overtime Rule**: Sunday is designated as the mandatory weekly off day; **100% of all hours worked on Sunday are automatically converted to Overtime Hours**.

### 18. Employee Photo Directory, Strict Log Isolation & Relieved Staff Exclusion
- **Badge Image Mapping**: Maps official employee codes (`1004`, `1008`, `1058`, `N-1003`–`N-1014`, etc.) to high-resolution portrait photos stored in `assets/images/employees/` and `web/assets/images/employees/`.
- **Avatar Component**: Reusable `EmployeeAvatar` rendering official photos with graceful monogram initials fallback.
- **Strict Identity Isolation (`EmployeeDirectoryHelper.matchesEmployeeIdentity`)**: Strictly isolates individual employee attendance logs, preventing cross-employee contamination across timesheets, payroll, and daily reports, and excludes relieved personnel (`isRelievedEmployee`) across all modules.

### 19. Office Station Deletion with Safeguard Protection
- Admins can delete branch office stations with automatic employee fallback: any personnel assigned to a deleted branch automatically revert to the default Main Office without breaking geofence validation.

### 20. Division-Aware Salary, Payroll & UAE WPS Module
- **Automated Payroll Engine (`SalaryPayrollScreen`, `SalaryCalculator`)**: Computes day-wise fixed, variable, and overtime earnings across **Fusion Electro-Mechanical Maintenance LLC (MOL: `803095`)** and **Fusion Neo Building Contracting LLC (MOL: `2846014`)** using `WpsMasterRegistry` and `employee_salaries`.
- **Basic-Only OT & Paid Sunday Rules**: Derives hourly OT rate strictly from Basic Salary (`(Basic / Days in Month) / 8`), supports fixed-in-variable OT (`otIncludedInVariable`), custom hourly/monthly OT overrides, and Paid Sunday Off credit when working the following Monday or both before and after the Sunday.
- **Manual Office Attendance Calendar (`PutOfficeAttendanceDialog`)**: Interactive calendar dialog for marking office staff attendance (`OFFICE_CALENDAR_ENTRY`) and cycle OT hours with instant local persistence and non-blocking cloud sync.
- **Dedicated Documentation**: See [Salary, Payroll & WPS Export Module](docs/13_salary_payroll_and_wps_module.md).

### 21. Multi-Theme UI System (`AppThemePreset` & `ThemeCubit`)
- Supports **5 curated theme palettes** (`Slate Indigo`, `Emerald Mint`, `Midnight Amber`, `Royal Amethyst`, `Ocean Cobalt`) with full Light & Dark mode contrast support (`ThemeSelectorModal`).

---

## 💻 Running the Admin Web Application

### Option A: Running as a Flutter Web App
You can run the Flutter Web application directly using Flutter:
```bash
# Run in Chrome browser
flutter run -d chrome
```

### Option B: Running the Standalone Web Admin Site (`web_admin`)
A dedicated, ultra-fast web admin portal constructed with HTML5/CSS3/JS, Supabase SDK, Leaflet Maps, and Cards Manager is located in `web_admin/`:
```bash
cd web_admin
npm start
```
Or serve via any web server / Python server:
```bash
npx serve -s . -l 3000
```
Open `http://localhost:3000` in your browser.

---

## 📁 Project Architecture & Folder Structure

```
attendance_app/
├── .github/workflows/
│   └── deploy.yml                  # GitHub Actions CI/CD deploying Flutter Web to fusionmaint.org
├── backend/
│   ├── supabase_schema.sql         # Core PostgreSQL schema, RLS policies, Ownership Transfer RPC
│   ├── create_employee_salaries_table.sql # Salary & payroll schema + division master seeds
│   ├── add_custom_monthly_ot_amount_column.sql # Fixed monthly OT override migration
│   ├── add_bypass_geofence_columns.sql # Per-employee geofence bypass migration
│   └── supabase_cron_job.sql       # Automated 8:00 AM GST card expiry compliance robot (pg_cron & pg_net)
├── web_admin/                      # Standalone Enterprise Web Admin Portal
│   ├── index.html                  # HTML5 SPA Container, Leaflet Map, & Cards Manager
│   ├── styles.css                  # Enterprise Design System & CSS Variables
│   ├── app.js                      # JavaScript Controller, Supabase JS SDK, Gemini OCR, Leaflet Map
│   └── package.json                # Local web server script
├── docs/                           # Comprehensive System Documentation (Modules 00–13)
│   ├── 00_system_architecture.md
│   ├── 01_auth_and_password_management.md
│   ├── 02_organization_setup.md
│   ├── 03_employee_management.md
│   ├── 04_office_geofence_management.md
│   ├── 05_attendance_workflow_and_camera.md
│   ├── 06_offline_storage_and_sync_engine.md
│   ├── 07_admin_dashboard_and_analytics.md
│   ├── 08_reports_and_data_export.md
│   ├── 09_timesheet_and_work_site_management.md
│   ├── 10_security_device_binding_and_ownership_transfer.md
│   ├── 11_cards_management_and_ai_compliance.md
│   ├── 12_leave_management_and_payroll_cycles.md
│   ├── 13_salary_payroll_and_wps_module.md
│   ├── architecture_runtime_diagram.html
│   ├── CARD_AND_EXPIRY_NOTIFICATION_MODULE.md
│   ├── TECHNICAL_DEVELOPER_DOCUMENTATION.md
│   ├── CODING_IMPLEMENTATION_GUIDE.md
│   ├── ENTERPRISE_CASE_STUDY.md
│   └── README.md                   # Documentation Index
├── assets/
│   └── images/employees/           # Official portrait employee badge photos
├── web/
│   └── index.html                  # Flutter Web entry with stale service worker cache-busting
├── lib/
│   ├── main.dart                   # Role-Based Router Entry Point (Web & Mobile)
│   ├── app_config.dart             # Global environment configurations & Supabase keys
│   ├── core/                       # Shared utilities, constants, & themes
│   │   ├── constants/              # Colors, Themes, Enums, EmployeePhotoData, WpsMasterRegistry
│   │   ├── services/               # LocationService, CameraService, SupabaseService, CardOcrService,
│   │   │                           # CardExpiryNotificationService, PdfExportService, ExcelCsvExportService
│   │   ├── theme/                  # AppThemePreset, ThemeCubit, ThemeSelectorModal (5 themes)
│   │   ├── utils/                  # GeofenceCalculator, TimesheetCalculator, SalaryCycleHelper,
│   │   │                           # LeaveCalculator, EmployeeDirectoryHelper, PhotoAttachmentHelper
│   │   └── widgets/                # AppButton, CustomTextField, StatusBadge, OfflineBanner, EmployeeAvatar
│   ├── database/                   # Hive Local Database Persistence Engine
│   └── features/                   # Clean Architecture Features
│       ├── setup/                  # First-Time Wizard Screen & Cubit
│       ├── auth/                   # Login Screen, Firebase/Supabase Auth & Cubit
│       ├── attendance/             # Attendance Workflow Stepper, Camera Modal, BreakTypeDialog, SiteNameDialog, Cubit
│       ├── employee/               # Employee Duty Portal & Timeline
│       ├── admin/                  # Dashboard (8 tabs), Employee & Office Management, Cards Management Screen,
│       │                           # Work Sites, Reports, AdminEditAttendanceDialog, Ownership Transfer
│       ├── salary/                 # Salary & Payroll Module, WPS Exports, Interim OT Dialog, Calendar Attendance
│       ├── timesheet/              # Employee Timesheet Portal, Salary Cycle Filter, Daily Calculation, PDF Export
│       ├── security/               # Hardware Device Binding Service
│       └── sync/                   # Offline Sync Engine (15-min periodic flush & connectivity listener)
├── test/                           # Unit tests (salary, cycle, geofence toggle, break/OT, isolation, leave)
├── pubspec.yaml
└── README.md
```

---

## 🚀 Getting Started

1. **Clone or navigate to the workspace**:
   ```bash
   cd C:\Users\srirs\.gemini\antigravity-ide\scratch\attendance_app
   ```
2. **Install Flutter Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run Mobile / Desktop Web App**:
   ```bash
   flutter run -d chrome
   ```
4. **Deploy Database, Migrations & Scheduled Compliance Robot**:
   - Execute `backend/supabase_schema.sql` in the Supabase SQL Editor for core tables and RLS policies.
   - Execute `backend/add_bypass_geofence_columns.sql`, `backend/create_employee_salaries_table.sql`, and `backend/add_custom_monthly_ot_amount_column.sql` to enable per-employee geofence bypass and the Salary & Payroll module.
   - Execute `backend/supabase_cron_job.sql` to schedule the automated daily 8:00 AM GST compliance robot.
5. **Automated Web Deployment (GitHub Pages)**:
   - Pushes to `main`, `master`, or `admin_web` trigger `.github/workflows/deploy.yml`, building the Flutter Web bundle (`--base-href "/"`) and deploying to `fusionmaint.org`.

