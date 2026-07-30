# Enterprise Attendance & Field Workforce Tracking — System Documentation

Welcome to the comprehensive feature and architecture documentation for the **Enterprise Attendance & Field Workforce Tracking Application**.

---

## Documentation Index

| Module # | Document Title | Primary Coverage & Knowledge Area |
| :---: | :--- | :--- |
| **00** | [System Architecture & Engineering Blueprint](00_system_architecture.md) | High-level technology stack, Clean Architecture layers, data flow diagrams, security & project structure. |
| **01** | [Authentication & Password Management Feature](01_auth_and_password_management.md) | Dual-layer authentication engine (Firebase Auth + local Hive database fallback), Super Admin vs Employee roles, direct dashboard login, self-service password management, and universal show/hide password visibility toggles. |
| **02** | [Organization Setup & Onboarding Feature](02_organization_setup.md) | Enterprise onboarding, root organization initialization, default geofence configuration, and GPS auto-detection during setup. |
| **03** | [Employee Management & Role Assignment Feature](03_employee_management.md) | Provisioning employees, secondary Firebase auth instance creation, employee codes, designation/department management, and office station assignment. |
| **04** | [Office Station & Geofence Management Feature](04_office_geofence_management.md) | Geofence office station setup, hardware GPS location auto-fetch, and Haversine spherical distance validation algorithms. |
| **05** | [Attendance Workflow & Camera Verification Feature](05_attendance_workflow_and_camera.md) | 4-Step daily duty cycle (`Check-In` -> `Start Duty` -> `Complete Duty` -> `Check-Out`), live camera capture, 480px JPEG image compression engine (99% payload reduction), and timeline time badges. |
| **06** | [Offline Storage & Background Sync Engine Feature](06_offline_storage_and_sync_engine.md) | Hive local key-value box architecture, offline pending banner indicators, background sync engine, and connectivity listeners. |
| **07** | [Admin Dashboard, Live Tracking & Analytics Feature](07_admin_dashboard_and_analytics.md) | Executive KPI cards, real-time OpenStreetMap live employee tracking map, geofence radius visual rings, and attendance feeds. |
| **08** | [Reports & Multi-Format Data Export Feature](08_reports_and_data_export.md) | Multi-criteria filter engine, CSV data generation, Excel (.xlsx) spreadsheet creation, and PDF document rendering & printing. |

---

## Quick Reference Commands

- **Run Static Analysis**: `flutter analyze`
- **Run Unit Tests**: `flutter test`
- **Install Dependencies**: `flutter pub get`
- **Run App Locally**: `flutter run`
