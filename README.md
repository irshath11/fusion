# Offline-First Employee Attendance & Field Workforce Tracking Application

Enterprise-grade, offline-first mobile and web application built using **Flutter**, **Flutter Web**, **Supabase (PostgreSQL, RLS, Storage)**, **Firebase Authentication**, **Hive Local Storage**, and **Clean Architecture**.

---

## 🌟 Key Application Features & Specifications

### 1. Dual-Role Architecture & Dedicated Admin Web Application
- **Super Admin Web & Mobile Suite**: Standalone Web Admin Portal (`web_admin`) and Flutter Web/Mobile Admin Dashboard for total operational oversight, employee directory management, office geofence configuration, work site registry, real-time GPS map tracking, and analytics reporting.
- **Employee Mobile Portal**: Enforced 6-step attendance workflow stepper, live photo capture, geofence verification, and pending offline sync monitor.

### 2. First-Time Setup Wizard
- When opened for the very first time, prompts for **Organization Name**, **Address**, **Super Admin Credentials**, and automatically provisions the organization, default office, and Super Admin account.
- Sets persistent setup flags so future app launches automatically route directly to the **Login Screen**.

### 3. Dual-Layer Authentication & Password Security
- **Primary Firebase Auth + Local Hive Database Fallback**: Authenticates via Firebase Authentication; seamlessly falls back to local database profiles (`app_settings` Hive box) and demo admin credentials if Firebase is unreachable or throws credential exceptions (`invalid-credential`, `user-not-found`).
- **Universal Password Visibility Toggles**: All password input fields across the application (Login, Setup Wizard, Employee Password Update, User Creation, Ownership Transfer) feature interactive show/hide eye icon toggle buttons (`Icons.visibility_outlined` / `Icons.visibility_off_outlined`).

### 4. Strict 6-Step Sequential Attendance Workflow Engine
`Office Check-In` ➔ `Travel to Site` ➔ `Site Check-In` ➔ `Perform Work` ➔ `Site Check-Out` ➔ `Return to Office` ➔ `Office Check-Out`
- State locks prevent skipping steps or altering step execution order.

### 5. Real-time Camera Capture & Compression
- Direct integration with camera stream.
- **Gallery uploads & file pickers are strictly disabled**.
- Images are automatically compressed to ~18KB JPEG payloads before storage/sync.

### 6. Haversine Geofence Validation
- Validates real-time GPS location against assigned office or site coordinates.
- Displays immediate warning modal: `"You are outside the permitted attendance area."` if user is outside allowed radius (default 200m).

### 7. Employee Office Override Support
- Allows assigning custom client offices or construction sites to specific employees (`useDefaultOffice: false`).
- Attendance geofence rules validate against the employee's specific assigned office location.

### 8. Offline-First Operation & Background Sync Engine
- Local Hive key-value boxes store attendance logs, photos, and sync queues without internet.
- Sync engine automatically flushes queue upon connectivity restoration while preserving original `event_timestamp`.

### 9. Analytics & Multi-Format Report Export
- Generates downloadable compliance reports in **PDF**, **Excel**, and **CSV** formats.

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
│   └── supabase_schema.sql         # Supabase PostgreSQL schema, UUID FKs, RLS Policies
├── web_admin/                      # Standalone Enterprise Web Admin Portal
│   ├── index.html                  # HTML5 SPA Container
│   ├── styles.css                  # Enterprise Design System & CSS Variables
│   ├── app.js                      # JavaScript Controller & Supabase/Leaflet Integration
│   └── package.json                # Local web server script
├── lib/
│   ├── main.dart                   # Role-Based Router Entry Point (Web & Mobile)
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
│       ├── admin/                  # Super Admin Dashboard & Responsive Desktop Web View
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
