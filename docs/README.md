# Enterprise Attendance, Field Workforce Tracking & Timesheets — System Documentation

Welcome to the comprehensive feature and architecture documentation for the **Enterprise Attendance, Field Workforce Tracking & Timesheet Application**.

---

## Documentation Index

| Module # | Document Title | Primary Coverage & Knowledge Area |
| :---: | :--- | :--- |
| **00** | [System Architecture & Engineering Blueprint](00_system_architecture.md) | High-level technology stack, Clean Architecture layers, data flow diagrams, 13 Supabase tables, RLS policies, & Standalone Web Admin architecture. |
| **01** | [Authentication & Password Management Feature](01_auth_and_password_management.md) | Dual-layer authentication engine (Firebase Auth + local Hive database fallback), 3-tier RBAC (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`), direct dashboard login, self-service password management, universal show/hide password visibility toggles, & ownership transfer overview. |
| **02** | [Organization Setup & Onboarding Feature](02_organization_setup.md) | Enterprise onboarding, root organization initialization, default geofence configuration, initial Super Admin credential assignment (`SUPER_ADMIN`), and GPS auto-detection during setup. |
| **03** | [Employee Management & Role Assignment Feature](03_employee_management.md) | User & employee provisioning, secondary Firebase auth instance creation (`SecondaryAuthApp`), 3-tier role assignment, custom office overrides (`useDefaultOffice: false`), and audit activity logging. |
| **04** | [Office Station & Geofence Management Feature](04_office_geofence_management.md) | Static office station setup, client work site registry, hardware GPS location auto-fetch, and Haversine spherical distance validation algorithms. |
| **05** | [Attendance Workflow & Camera Verification Feature](05_attendance_workflow_and_camera.md) | Strict 4-step daily duty cycle (`1. Office Check-In` ➔ `2. Site Check-In` ➔ `3. Site Check-Out` ➔ `4. Office Check-Out` ➔ `Shift Completed`), `SiteNameDialog` dropdown selection (`RELAAM`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS`), `BreakTypeDialog` duty pause engine, live camera selfie capture, 480px JPEG image compression engine (99% payload reduction), and timeline time badges. |
| **06** | [Offline Storage & Background Sync Engine Feature](06_offline_storage_and_sync_engine.md) | Hive local key-value box architecture (8 isolated boxes), offline pending banner indicators, background sync engine, and connectivity listeners. |
| **07** | [Admin Dashboard, Live Tracking & Analytics Feature](07_admin_dashboard_and_analytics.md) | Executive KPI cards & Ticker Ribbon (Total Staff, Active Duty, Attendance %, Geofence Audit %), real-time OpenStreetMap live employee tracking map, geofence radius visual rings, attendance feeds, and Standalone Enterprise Web Admin Portal (`web_admin/`). |
| **08** | [Reports & Multi-Format Data Export Feature](08_reports_and_data_export.md) | 3-Tab Analytics Suite (Directory 3-Level Drilldown, Cumulative Attendance Summary, Site/Client Man-Hours Analytics with Date Filters & Client Grouping), Cloud Log Sync (`_loadCloudAttendanceRecords`), CSV data generation, Excel (.xlsx) spreadsheet creation, and multi-page PDF document rendering & printing services. |
| **09** | [Employee Timesheet & Work Site Management Feature](09_timesheet_and_work_site_management.md) | Daily work shift hour calculation (`TimesheetCalculator`), regular hours (capped at 8.0h), overtime hours tracking (>8.0h), individual site visit duration breakdown (`SiteVisitSummary`), timesheet PDF export, and work site registry (`work_sites`). |
| **10** | [Hardware Device Binding & Organization Ownership Transfer Feature](10_security_device_binding_and_ownership_transfer.md) | Multi-platform hardware device fingerprinting (`DeviceBindingService`), Supabase device registration (`devices`), and atomic organization ownership transfer procedure (`transfer_organization_ownership`). |
| **11** | [Google Play Store Deployment & Publishing Infrastructure](11_google_play_store_deployment_and_publishing.md) | Keystore signing setup (`upload-keystore.jks`, `key.properties`), Android App Bundle (`.aab`) compilation, Play Console Data Safety & IARC compliance declarations, store listing assets (512x512 icon, 1024x500 banner), & testing track release workflows. |

---

## Quick Reference Commands

- **Run Static Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Install Dependencies**: `flutter pub get`
- **Run Flutter Web App**: `flutter run -d chrome`
- **Run Standalone Web Admin Portal**: `cd web_admin && npx serve -s . -l 3000`
