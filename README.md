# Offline-First Employee Attendance & Field Workforce Tracking Application

Enterprise-grade, offline-first mobile application built using **Flutter**, **Supabase (PostgreSQL, RLS, Storage)**, **Firebase Authentication**, **Hive Local Storage**, and **Clean Architecture**.

---

## 🌟 Key Application Features & Specifications

### 1. Dual-Role Architecture
- **Super Admin Module**: Total operational oversight, employee management, office management, work site management, live map tracking, and analytics reporting.
- **Employee Module**: Enforced 6-step attendance workflow stepper, live photo capture, geofence verification, and pending offline sync monitor.

### 2. First-Time Setup Wizard
- When opened for the very first time, prompts for **Organization Name**, **Address**, **Super Admin Credentials**, and automatically provisions the organization, default office, and Super Admin account.
- Sets persistent setup flags so future app launches automatically route directly to the **Login Screen**.

### 3. Strict 6-Step Sequential Attendance Workflow Engine
`Office Check-In` ➔ `Travel to Site` ➔ `Site Check-In` ➔ `Perform Work` ➔ `Site Check-Out` ➔ `Return to Office` ➔ `Office Check-Out`
- State locks prevent skipping steps or altering step execution order.

### 4. Real-time Camera Capture & Compression
- Direct integration with camera stream.
- **Gallery uploads & file pickers are strictly disabled**.
- Images are automatically compressed to ~18KB JPEG payloads before storage/sync.

### 5. Haversine Geofence Validation
- Validates real-time GPS location against assigned office or site coordinates.
- Displays immediate warning modal: `"You are outside the permitted attendance area."` if user is outside allowed radius (default 200m).

### 6. Employee Office Override Support
- Allows assigning custom client offices or construction sites to specific employees (`useDefaultOffice: false`).
- Attendance geofence rules validate against the employee's specific assigned office location.

### 7. Offline-First Operation & Background Sync Engine
- Local Hive key-value boxes store attendance logs, photos, and sync queues without internet.
- Sync engine automatically flushes queue upon connectivity restoration while preserving original `event_timestamp`.

### 8. Analytics & Multi-Format Report Export
- Generates downloadable compliance reports in **PDF**, **Excel**, and **CSV** formats.

---

## 📁 Project Architecture & Folder Structure

```
attendance_app/
├── backend/
│   └── supabase_schema.sql         # Supabase PostgreSQL schema, UUID FKs, RLS Policies
├── lib/
│   ├── main.dart                   # Role-Based Router Entry Point
│   ├── app_config.dart             # Global environment configurations
│   ├── core/                       # Shared utilities, constants, & themes
│   │   ├── constants/              # Colors, Themes, Enums (UserRole, WorkflowStep)
│   │   ├── services/               # LocationService, CameraService, ExportServices
│   │   ├── utils/                  # GeofenceCalculator (Haversine formula)
│   │   └── widgets/                # AppButton, CustomTextField, StatusBadge, OfflineBanner
│   ├── database/                   # Hive Local Database Persistence
│   └── features/                   # Clean Architecture Features
│       ├── setup/                  # First-Time Wizard Screen & Cubit
│       ├── auth/                   # Login Screen, Firebase/Supabase Auth & Cubit
│       ├── attendance/             # Attendance Workflow Stepper, Camera Modal, Cubit
│       ├── employee/               # Employee Duty Portal & Timeline
│       ├── admin/                  # Super Admin Dashboard, Employee/Office/Site CRUD, Reports
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
3. **Run Application**:
   ```bash
   flutter run
   ```
4. **Deploy Database**:
   - Copy `backend/supabase_schema.sql` into your Supabase SQL Editor and execute.
