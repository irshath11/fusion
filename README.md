# Offline-First Employee Attendance, Field Workforce Tracking & Timesheet Management Application

Enterprise-grade, offline-first mobile and web application built using **Flutter**, **Flutter Web**, **Supabase (PostgreSQL, RLS, Storage)**, **Firebase Authentication**, **Hive Local Storage**, and **Clean Architecture**.

---

## 🌟 Key Application Features & Specifications

### 1. Dual-Role Architecture & Dedicated Admin Web Application
- **Super Admin & Admin Web & Mobile Suite**: Standalone Web Admin Portal (`web_admin`) and Flutter Web/Mobile Admin Dashboard for total operational oversight, employee directory management, 3-tier RBAC (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`), office geofence configuration, work site registry, real-time GPS map tracking, timesheet auditing, and analytics reporting.
- **Employee Mobile Portal**: Enforced 4-step daily attendance workflow stepper, live selfie photo capture, geofence verification, personal work timesheet summary, and pending offline sync monitor.

### 2. First-Time Setup Wizard
- When opened for the very first time, prompts for **Organization Name**, **Address**, **Super Admin Credentials**, and automatically provisions the organization, default office, and root Super Admin account (`role = 'SUPER_ADMIN'`).
- Sets persistent setup flags so future app launches automatically route directly to the **Login Screen**.

### 3. Dual-Layer Authentication & Password Security
- **Primary Firebase Auth + Local Hive Database Fallback**: Authenticates via Firebase Authentication; seamlessly falls back to local database profiles (`app_settings` Hive box) and demo admin credentials if Firebase is unreachable or throws credential exceptions (`invalid-credential`, `user-not-found`).
- **Universal Password Visibility Toggles**: All password input fields across the application (Login, Setup Wizard, Employee Password Update, User Creation Form, Ownership Transfer) feature interactive show/hide eye icon toggle buttons (`Icons.visibility_outlined` / `Icons.visibility_off_outlined`).

### 4. Strict 4-Step Sequential Attendance Workflow & Duty Pause Engine
`1. Office Check-In` ➔ `2. Site Check-In` ➔ `3. Site Check-Out (Leaving Site)` ➔ `4. Office Check-Out (Reach Office)` ➔ `Shift Completed`
- State locks prevent skipping steps or altering step execution order.
- `SiteNameDialog` dropdown prompts selection from pre-configured work sites (`RELAAM (AMC)`, `RELAAM (WO)`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS (AMC)`, `OTHERS (WO)`) or custom location inputs.
- **Duty Pause & Break Tracking (`BreakTypeDialog`)**: Allows field personnel to pause duty for rest/errands with optional notes, excluding break duration from net billable duty hours without breaking the 4-step shift workflow.

### 5. Employee Work Timesheet Engine
- **Automatic Hour Calculation**: Calculates total daily work duration between `1. Office Check-In` and `4. Office Check-Out`, factoring out logged duty breaks.
- **Regular vs. Overtime Hours**: Automatically caps regular working hours at **8.0 hours per day** and allocates any excess duration as **Overtime Hours**.
- **Site Visit Breakdown**: Captures detailed site visit durations (`SiteVisitSummary`) for each field location visited during the shift.
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

### 10. Haversine Geofence Validation
- Validates real-time GPS location against assigned office or site coordinates using the Haversine spherical distance formula.
- Displays immediate warning modal: `"You are outside the permitted attendance area."` if user is outside allowed radius (default 200m).

### 11. Employee Office Override Support
- Allows assigning custom client offices or branch stations to specific employees (`useDefaultOffice: false`).
- Attendance geofence rules validate against the employee's specific assigned office location.

### 12. Offline-First Operation & Background Sync Engine
- Local Hive key-value boxes store attendance logs, photos, and sync queues without internet.
- Sync engine automatically flushes queue upon connectivity restoration while preserving original `event_timestamp`.

### 13. 3-Tab Advanced Reports & Analytics Suite
- **Directory 3-Level Drilldown View**:
  - *Level 1*: All Employee list with real-time search, Executive KPI Ticker Ribbon (Total Staff, Active Duty, Attendance %, Geofence Audit %), and Cloud Log Sync.
  - *Level 2*: Selected employee date-wise duty log timeline & check-in/out timestamps.
  - *Level 3*: Date detailed view with high-res camera selfie photo verification, exact GPS coordinates, geofence compliance badges, and site visit breakdown.
- **Cumulative Summary Tab**: Cross-employee aggregate attendance statistics, present/absent counts, total regular hours, overtime hours, cumulative site visits, and export shortcuts.
- **Site / Client Man-Hours Analytics Tab**: Site-wise and Client-wise man-hour aggregation engine, date range filters (`All Time`, `This Month`, `This Week`, `Today`), grouping toggle (`Group by Client` vs. `Specific Site`), and expandable site cards with detailed worker lists.

### 14. Cloud Attendance Log Sync & Local Auto-Merge Engine
- On-demand and automatic synchronization of remote attendance logs from Supabase (`fetchAttendanceRecordsFromSupabase()`).
- Auto-merges remote records into local Hive storage while eliminating duplicates, featuring live progress indicator controls (`_isLoadingCloud`).

### 15. Analytics & Multi-Format Report Export
- Generates downloadable compliance reports in **PDF**, **Excel (.xlsx)**, and **CSV** formats with customizable filters.

### 16. Multi-Preset Dynamic Theme Engine & Adaptive UI Shell
- **5 Curated Color Palettes (`AppThemePalette`)**: `Slate Indigo`, `Emerald Mint`, `Midnight Amber`, `Royal Amethyst`, and `Ocean Cobalt`.
- **Interactive Theme Selector Modal (`ThemeSelectorModal`)**: Allows users and administrators to switch color presets dynamically with real-time UI previews.
- **Adaptive Application Shell (`AppShell`)**: Automatically renders a floating glass bottom navigation dock on mobile screens (< 750px) and a collapsible modern navigation rail on tablet/desktop displays (>= 750px).
- **Glassmorphic Design System**: Uses backdrop glass blur cards (`AppGlassCard`) and smooth micro-animations (`AppBounceable`, `StaggeredAnimatedItem`).

### 17. Google Play Store Release & Publishing Infrastructure
- **Production Android App Bundle (`.aab`)**: Signed compilation pipeline configured via `upload-keystore.jks`, `key.properties`, and `build.gradle.kts`.
- **Play Console Compliance Declarations**: Configured Data Safety (Location, Name, Email collection), IARC Content Rating (PEGI 3 / Everyone 3+), App Access credentials, and Public Account Deletion Link.
- **Store Listing Visual Assets**: Includes customized 512x512 PNG App Icon (`app_icon_512.jpg`) and 1024x500 Figma-style Feature Graphic banner (`feature_graphic.jpg`).

---

## 💻 Running the Admin Web Application

### Option A: Running as a Flutter Web App
You can run the Flutter Web application directly using Flutter:
```bash
# Run in Chrome browser
flutter run -d chrome
```

### Option B: Running the Standalone Web Admin Site (`web_admin`)
A dedicated, ultra-fast web admin portal constructed with HTML5/CSS3/JS, Supabase SDK, and Leaflet Maps is located in `web_admin/`:
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
├── backend/
│   └── supabase_schema.sql         # Supabase PostgreSQL schema, UUID FKs, RLS Policies, Ownership Transfer RPC
├── web_admin/                      # Standalone Enterprise Web Admin Portal
│   ├── index.html                  # HTML5 SPA Container & Leaflet Map Container
│   ├── styles.css                  # Enterprise Design System & CSS Variables
│   ├── app.js                      # JavaScript Controller, Supabase JS SDK & Leaflet Integration
│   └── package.json                # Local web server script
├── docs/                           # Comprehensive System & Feature Documentation (Modules 00–11)
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
│   ├── 11_google_play_store_deployment_and_publishing.md
│   └── README.md                   # Documentation Index
├── lib/
│   ├── main.dart                   # Role-Based Router Entry Point (Web & Mobile)
│   ├── app_config.dart             # Global environment configurations
│   ├── core/                       # Shared utilities, constants, & themes
│   │   ├── constants/              # Colors, Themes, Enums (UserRole, WorkflowStep, ActivityLogAction)
│   │   ├── theme/                  # AppThemePreset, AppThemePalette, ThemeCubit, ThemeSelectorModal
│   │   ├── services/               # LocationService, CameraService, SupabaseService, ExportServices
│   │   ├── utils/                  # GeofenceCalculator, TimesheetCalculator
│   │   └── widgets/                # AppButton, CustomTextField, StatusBadge, OfflineBanner, AppShell
│   ├── database/                   # Hive Local Database Persistence
│   └── features/                   # Clean Architecture Features
│       ├── setup/                  # First-Time Wizard Screen & Cubit
│       ├── auth/                   # Login Screen, Firebase/Supabase Auth & Cubit
│       ├── attendance/             # Attendance Workflow Stepper, Camera Modal, SiteNameDialog, Cubit
│       ├── employee/               # Employee Duty Portal & Timeline
│       ├── admin/                  # Dashboard, Employee & Office Management, Work Sites, Ownership Transfer
│       ├── timesheet/              # Employee Timesheet Portal, Daily Entry Calculation, PDF Export
│       ├── security/               # Hardware Device Binding Service
│       └── sync/                   # Offline Sync Engine
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
4. **Deploy Database**:
   - Copy `backend/supabase_schema.sql` into your Supabase SQL Editor and execute.
