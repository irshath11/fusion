# Enterprise Attendance, Field Workforce Tracking & Timesheets — System Documentation

Welcome to the comprehensive feature and architecture documentation for the **Enterprise Attendance, Field Workforce Tracking & Timesheet Application**.

---

## Documentation Index

| Module # | Document Title | Primary Coverage & Knowledge Area |
| :---: | :--- | :--- |
| **00** | [System Architecture & Engineering Blueprint](00_system_architecture.md) | High-level technology stack, Clean Architecture layers, data flow diagrams, 16 Supabase tables, RLS policies, & Standalone Web Admin architecture. |
| **01** | [Authentication & Password Management Feature](01_auth_and_password_management.md) | Dual-layer authentication engine (Firebase Auth + local Hive database fallback), 3-tier RBAC (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`), direct dashboard login, self-service password management, universal show/hide password visibility toggles, & ownership transfer overview. |
| **02** | [Organization Setup & Onboarding Feature](02_organization_setup.md) | Enterprise onboarding, root organization initialization, default geofence configuration, initial Super Admin credential assignment (`SUPER_ADMIN`), and GPS auto-detection during setup. |
| **03** | [Employee Management & Role Assignment Feature](03_employee_management.md) | User & employee provisioning, secondary Firebase auth instance creation (`SecondaryAuthApp`), 3-tier role assignment, custom office overrides (`useDefaultOffice: false`), per-employee geofence bypass toggles (`bypassGeofence`), relieved employee exclusion, and audit activity logging. |
| **04** | [Office Station & Geofence Management Feature](04_office_geofence_management.md) | Static office station setup, client work site registry, hardware GPS location auto-fetch, Haversine spherical distance validation algorithms, branch deletion fallback, and per-employee geofence enable/disable controls. |
| **05** | [Attendance Workflow & Camera Verification Feature](05_attendance_workflow_and_camera.md) | Strict 4-step daily duty cycle (`1. Office Check-In` ➔ `2. Site Check-In` ➔ `3. Site Check-Out` ➔ `4. Office Check-Out` ➔ `Shift Completed`), break & emergency duty steps, `SiteNameDialog` dropdown selection (`RELAAM`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS`), live camera selfie capture, 480px JPEG image compression engine (99% payload reduction), and timeline time badges. |
| **06** | [Offline Storage & Background Sync Engine Feature](06_offline_storage_and_sync_engine.md) | Hive local `app_settings` persistence engine, offline pending banner indicators, background sync engine (15-min periodic flush & connectivity listener), non-blocking bulk cloud sync, and local cache reset. |
| **07** | [Admin Dashboard, Live Tracking & Analytics Feature](07_admin_dashboard_and_analytics.md) | Executive KPI cards, 8-tab desktop/mobile admin suite (including Salary & Payroll), real-time OpenStreetMap live employee tracking map, geofence radius visual rings, attendance feeds, strict log isolation, and Standalone Enterprise Web Admin Portal (`web_admin/`). |
| **08** | [Reports & Multi-Format Data Export Feature](08_reports_and_data_export.md) | Multi-criteria filter engine with Salary Cycle selector, CSV data generation, Excel (.xlsx) spreadsheets (Attendance, Cards Compliance, Division WPS, Master Payroll, Interim OT), and multi-page PDF document rendering & printing services. |
| **09** | [Employee Timesheet & Work Site Management Feature](09_timesheet_and_work_site_management.md) | Daily work shift hour calculation (`TimesheetCalculator`), 8.0h regular cap, 1h Food Break + 1h Travel Tolerance overtime rules, Emergency Duty 100% OT, Admin attendance editing, individual site visit duration breakdown (`SiteVisitSummary`), timesheet PDF export, and work site registry (`work_sites`). |
| **10** | [Hardware Device Binding & Organization Ownership Transfer Feature](10_security_device_binding_and_ownership_transfer.md) | Multi-platform hardware device fingerprinting (`DeviceBindingService`), Supabase device registration (`devices`), and atomic organization ownership transfer procedure (`transfer_organization_ownership`). |
| **11** | [Cards Management, Gemini AI OCR & Automated Compliance Robot](11_cards_management_and_ai_compliance.md) | Employee statutory cards tracking (Emirates ID, Visa, Passport, Insurance, MOPA, CISPA), Google Gemini Multimodal AI Vision OCR extraction, multi-tier expiry alerting (Expired, ≤3d Critical, ≤30d Expiring), and automated multi-channel notification robot via Supabase `pg_cron`, `pg_net`, Resend Email API, and CallMeBot WhatsApp API. |
| **12** | [Enterprise Leave Records, Weekly Off Rules & Configurable Salary Cycles](12_leave_management_and_payroll_cycles.md) | Calendar-month salary cycle engine (Nov 2026+ calendar month, `26–31 Oct 2026` Interim OT transition, legacy 25th–24th cycles via `SalaryCycleHelper`), daily leave records ledger (`LeaveCalculator`), 5-state day categorization, Sunday mandatory weekly off rules, Sunday duty 100% overtime conversion, and 24-hour unclosed shift auto-checkout safety guard. |
| **13** | [Salary, Payroll & WPS Export Module](13_salary_payroll_and_wps_module.md) | Division-aware UAE WPS payroll engine (`SalaryCalculator`, `WpsMasterRegistry`), Basic-only OT rate formula, Paid Sunday Off rules, November Interim OT rollover, manual office attendance calendar (`PutOfficeAttendanceDialog`), and WPS Excel / Payslip PDF exports. |
| **Special** | [Cards Management & Expiry Notification Module Manual](CARD_AND_EXPIRY_NOTIFICATION_MODULE.md) | Dedicated standalone manual covering card lifecycles, Gemini AI Vision extraction, 3-day critical alerting, Resend Email API, CallMeBot WhatsApp automation, Supabase `pg_cron` setup, and operational runbook. |


---

## Quick Reference Commands

- **Run Static Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Install Dependencies**: `flutter pub get`
- **Run Flutter Web App**: `flutter run -d chrome`
- **Run Standalone Web Admin Portal**: `cd web_admin && npx serve -s . -l 3000`
