# 07. Admin Dashboard, Live Tracking & Analytics Feature

## Overview
The **Admin Dashboard, Live GPS Tracking & Analytics** feature provides executive visibility into overall organizational attendance metrics, daily workforce progression, real-time interactive GPS mapping, multi-filter activity feeds, and a standalone enterprise web admin application (`web_admin`).

---

## 1. Key Functionalities

1. **Executive Key Performance Indicators (KPI Cards)**:
   - **Active Employees**: Total active personnel in system.
   - **Present Today**: Unique employees who executed at least 1 workflow step today.
   - **On Duty**: Personnel actively performing field inspection duties.
   - **Shift Complete**: Personnel who completed all 4 daily workflow steps (`Office Check-Out`).
   - **Pending Sync**: Queue of records stored locally waiting for network transmission.

2. **Live Interactive GPS Tracking Map (`LiveTrackingMapScreen`)**:
   - Built with OpenStreetMap & `flutter_map`.
   - Renders green office station markers with semi-transparent geofence radius circles.
   - Displays real-time employee check-in location markers with custom avatars, employee name callouts, timestamp, and workflow step labels.
   - Fits bounding box to display all office stations and field locations simultaneously.

3. **Multi-Filter Attendance Activity Feed**:
   - Filter by Date, Office Station, Employee Name/Code, and Workflow Status.
   - Displays selfie photos, exact GPS coordinates, geofence status (`VALID` / `VIOLATION`), and sync indicators.

4. **Statutory Cards & Passes Compliance Module**:
   - Executive Cards overview cards: **Total Cards**, **Expired**, **Critical (≤3d)**, **Expiring (≤30d)**, and **Valid**.
   - Gemini AI Vision OCR scanning button for instant document processing from image/camera files.
   - 1-Click WhatsApp reminder links (`https://wa.me/...`) and email broadcasting to compliance recipients.
   - Quick navigation into the full **Cards Management Screen** (`CardsManagementScreen`).

5. **Reports, Strict Log Isolation & Salary Cycle Analytics**:
   - **8-Tab Navigation Shell (`AdminDashboardScreen`)**: `Overview`, `Employees`, `Cards & Passes`, `Offices`, `Work Sites`, `Live Map`, `Reports`, and `Salary & Payroll` (`SalaryPayrollScreen`).
   - **Salary Cycle Filter in Main Reports**: `ReportsAnalyticsScreen` features a Salary Cycle selector positioned directly above the search bar on the main Employee Attendance Directory, Cumulative Summary, and Leave Record tabs, spanning calendar months (Nov 2026+), `26–31 Oct 2026` Interim OT, and legacy 25th–24th cycles.
   - **Strict Employee Log Isolation**: Enforces strict identity matching (`EmployeeDirectoryHelper.matchesEmployeeIdentity`) across `getTodayAttendanceRecords` and reports, with legacy bulk-reassign and misattributed-logs banners removed to guarantee zero cross-employee log contamination.
   - **Admin Attendance Editing (`AdminEditAttendanceDialog`)**: Allows admins to edit daily check-in/out times, manual OT hours, and remarks (`isEdited`, `editedBy`).
   - **Site / Client Man-Hours Tab**: Aggregates field hours by specific work site or standardized client group (`REELAM`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS`).
   - **Direct Database Query Optimization**: Date ranges are filtered server-side in Supabase PostgreSQL queries (`lightColumns` select without eager base64 photo blobs; lazy photo loading on date detail view).

6. **Standalone Enterprise Admin Web Portal (`web_admin/`)**:
   - Lightweight, ultra-fast web application built using HTML5, CSS3, vanilla JavaScript, Supabase JS SDK, and Leaflet.js maps.
   - **Key Web Features**:
     - Session persistence & administrative login overlay (`SUPER_ADMIN` and `ADMIN` access control).
     - Dashboard metric cards (Active Employees, Present Today, On Duty, Completed Shifts).
     - Live Leaflet map rendering office stations, geofence radius circles, and real-time employee check-in pins.
     - Employee Management drawer form with official avatar rendering, office assignment, and **per-employee Geofence Enable/Disable toggle** (`activeEmployeeGeofenceTab`, `toggleEmployeeGeofence`).
     - Office & Work Site table management with branch deletion safeguard.
     - **Reports with Calendar-Month & Interim OT Cycle Selector** (`getSalaryCycles()`).
     - **Cards Compliance Manager**: Full web implementation with live cards grid, status badges, Gemini OCR scan modal, direct WhatsApp notification buttons, and Excel (.xlsx) compliance export.
     - Interactive Organization Ownership Transfer modal dialog (`transferModal`).

7. **Multi-Theme UI & Service Worker Cache Busting**:
   - Flutter Admin & Employee suites support **5 curated theme presets** (`ThemeSelectorModal` / `ThemeCubit`) across Light & Dark modes.
   - `web/index.html` automatically unregisters stale service workers on web updates alongside GitHub Actions deployment (`.github/workflows/deploy.yml` to `fusionmaint.org`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/admin_dashboard_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_dashboard_screen.dart) | Executive dashboard with 8 navigation tabs, metric cards, quick actions, cards summary, cache reset, and attendance feeds. |
| [`lib/features/salary/presentation/salary_payroll_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/salary/presentation/salary_payroll_screen.dart) | Division-aware Salary & Payroll screen with collapsible KPIs, status/department filters, and WPS exports. |
| [`lib/features/admin/presentation/cards_management_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/cards_management_screen.dart) | Dedicated UI for managing statutory employee cards, Gemini OCR scanning, and compliance alerts. |
| [`lib/features/admin/presentation/reports_analytics_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/reports_analytics_screen.dart) | Comprehensive analytics portal with Salary Cycle selector, Directory, Cumulative Summary, Leave Records, and Site/Client Man-Hours tabs. |
| [`lib/features/admin/presentation/admin_edit_attendance_dialog.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_edit_attendance_dialog.dart) | Modal dialog enabling admins to edit daily check-in/out times, manual OT hours, and remarks. |
| [`lib/features/admin/presentation/live_tracking_map_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/live_tracking_map_screen.dart) | Interactive OpenStreetMap rendering geofence radii and real-time employee check-in markers. |
| [`lib/features/admin/presentation/admin_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_cubit.dart) | Cubit fetching records, aggregating stats, and processing filter criteria. |
| [`web_admin/index.html`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/index.html) | HTML5 SPA container for Standalone Web Admin Portal with Cards Manager section. |
| [`web_admin/styles.css`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/styles.css) | Enterprise Design System styling, dark/light theme tokens, layout grid. |
| [`web_admin/app.js`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/app.js) | JavaScript controller, Supabase JS SDK integration, Leaflet.js map logic, Cards manager, and session storage. |

