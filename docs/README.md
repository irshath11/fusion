# Enterprise Attendance, Field Workforce Tracking & Timesheets — System Documentation

Welcome to the comprehensive feature and architecture documentation for the **Enterprise Attendance, Field Workforce Tracking, Timesheets & Service Reports Application**.

---

## Documentation Index

| Module # | Document Title | Primary Coverage & Knowledge Area |
| :---: | :--- | :--- |
| **00** | [System Architecture & Engineering Blueprint](00_system_architecture.md) | High-level technology stack, Clean Architecture layers, data flow diagrams, Supabase tables, RLS policies, AI Engine, & Standalone Web Admin architecture. |
| **01** | [Authentication & Password Management Feature](01_auth_and_password_management.md) | Dual-layer authentication engine (Firebase Auth + local Hive database fallback), 3-tier RBAC (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`), direct dashboard login, self-service password management, universal show/hide password visibility toggles, & ownership transfer overview. |
| **02** | [Organization Setup & Onboarding Feature](02_organization_setup.md) | Enterprise onboarding, root organization initialization, default geofence configuration, initial Super Admin credential assignment (`SUPER_ADMIN`), and GPS auto-detection during setup. |
| **03** | [Employee Management & Role Assignment Feature](03_employee_management.md) | User & employee provisioning, secondary Firebase auth instance creation (`SecondaryAuthApp`), 3-tier role assignment, custom office overrides (`useDefaultOffice: false`), attendance records reassignment, and audit activity logging. |
| **04** | [Office Station & Geofence Management Feature](04_office_geofence_management.md) | Static office station setup, client work site registry, hardware GPS location auto-fetch, and Haversine spherical distance validation algorithms. |
| **05** | [Attendance Workflow & Camera Verification Feature](05_attendance_workflow_and_camera.md) | Sequential daily duty cycle (`Office Check-In` ➔ multi-site `Site Check-In` / `Site Check-Out` ➔ `Office Check-Out` ➔ `Shift Completed`), dynamic step numbering (`1.`, `2.`, `3.`, `4.`, ...), `SiteNameDialog` selection, duty pause & break tracking, Emergency Duty workflow, live camera selfie capture, 480px JPEG compression (99% payload reduction), and timeline time badges. |
| **06** | [Offline Storage & Background Sync Engine Feature](06_offline_storage_and_sync_engine.md) | Hive local key-value box architecture (isolated boxes for organization, records, service reports), offline pending banner indicators, background sync engine, and connectivity listeners. |
| **07** | [Admin Dashboard, Live Tracking & Analytics Feature](07_admin_dashboard_and_analytics.md) | Executive KPI cards & Ticker Ribbon (Total Staff, Active Duty, Attendance %, Geofence Audit %), Active Salary Cycle overview, AI Voice Report Assistant trigger, real-time OpenStreetMap live employee tracking map, geofence radius visual rings, emergency duty monitoring, and Standalone Enterprise Web Admin Portal (`web_admin/`). |
| **08** | [Reports & Multi-Format Data Export Feature](08_reports_and_data_export.md) | 3-Tab Analytics Suite (Directory 3-Level Drilldown, Cumulative Attendance Summary, Site/Client Man-Hours Analytics), Salary Cycle filter (25th to 24th), Cloud Log Sync, Admin Add/Edit Emergency Logs, CSV data generation, Excel (.xlsx) spreadsheets, and multi-page PDF document rendering. |
| **09** | [Employee Timesheet & Work Site Management Feature](09_timesheet_and_work_site_management.md) | Daily work shift hour calculation (`TimesheetCalculator`), regular hours (capped at 8.0h), overtime hours tracking (>8.0h), emergency duty hour tracking, salary cycle filtering, individual site visit duration breakdown (`SiteVisitSummary`), timesheet PDF export, and work site registry (`work_sites`). |
| **10** | [Hardware Device Binding & Organization Ownership Transfer Feature](10_security_device_binding_and_ownership_transfer.md) | Multi-platform hardware device fingerprinting (`DeviceBindingService`), Supabase device registration (`devices`), and atomic organization ownership transfer procedure (`transfer_organization_ownership`). |
| **11** | [Google Play Store Deployment & Publishing Infrastructure](11_google_play_store_deployment_and_publishing.md) | Keystore signing setup (`upload-keystore.jks`, `key.properties`), Android App Bundle (`.aab`) compilation, Play Console Data Safety & IARC compliance declarations, store listing assets (512x512 icon, 1024x500 banner), & testing track release workflows. |
| **12** | [AI Voice Reporting & Google Gemini AI Integration](12_ai_voice_reporting_and_gemini_insights.md) | Google Gemini AI integration (`gemini-3.6-flash`), speech-to-text phonetic error cleaning, automated engineering defect/work/materials extraction, offline heuristic parser, and interactive AI Voice Report assistant modal (`AiVoiceReportBottomSheet`). |
| **13** | [Service Report Generator & Digital E-Signatures](13_service_report_generator_and_e_signatures.md) | Mobile field service report generator (`EmployeeReportGeneratorScreen`, `EmployeeReportsListScreen`), 15 engineering disciplines, spare parts tracking, digital touch E-Signature pad (`ESignaturePad`), ISO-style PDF report generation (`ServiceReportPdfService`), and Supabase sync (`service_reports`). |
| **14** | [Emergency Duty & Salary Cycle Engine](14_emergency_duty_and_salary_cycle_engine.md) | On-call emergency duty workflow (`emergencyCheckIn`, `emergencyCheckOut`), admin emergency log add/edit dialogs, 25th-to-24th corporate payroll salary cycle engine (`SalaryCycleHelper`), and cycle-aware reporting. |

---

## Quick Reference Commands

- **Run Static Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Install Dependencies**: `flutter pub get`
- **Run Flutter Web App**: `flutter run -d chrome`
- **Run Standalone Web Admin Portal**: `cd web_admin && npx serve -s . -l 3000`
