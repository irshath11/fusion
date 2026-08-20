# Complete Technical Code Documentation (Developer Documentation)

**Application Title**: Fusion Enterprise Offline-First Attendance, Field Workforce Tracking & Timesheet Management System  
**Target Audience**: Senior Software Engineers, Solution Architects, Backend Developers, and DevOps Maintenance Teams  
**Document Version**: 2.0.0  
**Repository Location**: `attendance_app/`  

---

## 1. Application Overview

### Business Purpose
The **Fusion Field Workforce Tracking & Timesheet Management Platform** is an enterprise-grade mobile and web application engineered to solve critical operational challenges in field service, logistics, construction, and remote workforce management. It provides automated, tamper-proof attendance verification, geofenced location validation, daily shift duration calculation, overtime accounting, and real-time administrative oversight.

### Problems Solved by the System
1. **Attendance Fraud & Proxy Check-Ins**: Eliminates buddy punching through mandatory live hardware selfie capture with front camera verification and gallery upload restrictions.
2. **Geofence Compliance**: Prevents remote or off-site check-ins by enforcing real-time hardware GPS location validation against static offices and dynamic client work sites using the Haversine spherical distance formula.
3. **Connectivity Dependency**: Eliminates data loss and workflow interruption in remote locations with zero cellular coverage via a local-first Hive storage architecture and background sync engine.
4. **Manual Timesheet Processing Overhead**: Automates daily work hour aggregation, regular vs. overtime hour splitting (capped at 8.0 hours standard daily shift), and site visit duration tracking.
5. **Administrative Blindspots**: Provides real-time interactive OpenStreetMap live employee tracking and executive analytics KPI cards for operational visibility.

### Complete Application Workflow
```
[User Launch / First-Time Setup] 
        │
        ├─► If First Launch ──► Organization Setup Wizard (`OrganizationSetupScreen`)
        │                        └─► Provisions Org, Default Office, & Root Super Admin (`SUPER_ADMIN`)
        │
        └─► Login Screen (`LoginScreen`)
                 │
                 ├─► Primary: Firebase Auth (`signInWithEmailAndPassword`)
                 └─► Fallback: Local Hive DB & Demo Credentials (`app_settings` & `employeesBox`)
                          [Role-Based Router (`main.dart`)]
                  │
                  ├─► Role = 'SUPER_ADMIN' / 'ADMIN' ──► Admin Web/Mobile Suite (`AdminDashboardScreen`)
                  │                                        ├─► Executive KPI Ticker Ribbon & Attendance Feeds
                  │                                        ├─► Employee & User Management (3-Tier RBAC)
                  │                                        ├─► Office & Work Site Registry
                  │                                        ├─► Live GPS Tracking Map (`LiveTrackingMapScreen`)
                  │                                        ├─► 3-Tab Reports & Analytics (`ReportsAnalyticsScreen`)
                  │                                        │    ├─► Directory 3-Level Drilldown & Selfie Verification
                  │                                        │    ├─► Cumulative Attendance Summary & Overtime Aggregation
                  │                                        │    └─► Site / Client Man-Hours Analytics & Client Grouping
                  │                                        ├─► Cloud Attendance Log Sync & Auto-Merge Engine
                  │                                        └─► Organization Ownership Transfer Dialog
                  │
                  └─► Role = 'EMPLOYEE' ───────────────► Employee Duty Portal (`EmployeeDashboardScreen`)
                                                          ├─► 4-Step Attendance Stepper & Duty Pause Engine:
                                                          │    1. Office Check-In (`OFFICE_CHECK_IN`)
                                                          │    2. Site Check-In (`SITE_CHECK_IN` + `SiteNameDialog`)
                                                          │    3. Duty Pause / Break (`BreakTypeDialog`)
                                                          │    4. Site Check-Out (`SITE_CHECK_OUT`)
                                                          │    5. Office Check-Out (`OFFICE_CHECK_OUT`)
                                                          │    6. Shift Completed (`COMPLETED`)
                                                          ├─► Live Camera Capture & 480px JPEG Compression Engine
                                                          ├─► Haversine Distance Geofence Validation
                                                          ├─► Personal Daily Work Timesheet & PDF Export
                                                          └─► Background Offline Sync Queue Indicator (`OfflineBanner`)
```

### User Roles & Permissions Matrix
| Feature / Functionality | Super Admin (`SUPER_ADMIN`) | Administrator (`ADMIN`) | Employee (`EMPLOYEE`) |
| :--- | :---: | :---: | :---: |
| **Organization Setup & Onboarding** | ✅ Full Access | ❌ Restricted | ❌ Restricted |
| **Organization Ownership Transfer** | ✅ Full Access | ❌ Restricted | ❌ Restricted |
| **Create / Edit / Disable Admins & Users** | ✅ Full Access | ❌ Restricted | ❌ Restricted |
| **Create / Edit / Disable Employees** | ✅ Full Access | ✅ Full Access | ❌ Restricted |
| **Office Station & Work Site Management** | ✅ Full Access | ✅ Full Access | ❌ Restricted |
| **Executive Dashboard & Live Tracking Map** | ✅ Full Access | ✅ Full Access | ❌ Restricted |
| **Company Reports & Export (PDF, Excel, CSV)** | ✅ Full Access | ✅ Full Access | ❌ Restricted |
| **Execute 4-Step Attendance Stepper** | ❌ Restricted | ❌ Restricted | ✅ Full Access |
| **Personal Timesheet Summary & PDF Export** | ❌ Restricted | ❌ Restricted | ✅ Full Access |
| **Self-Service Password Update** | ✅ Full Access | ✅ Full Access | ✅ Full Access |

### High-Level System Architecture
```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   PRESENTATION LAYER                                   │
│  [Flutter Mobile / Web UI]   [Bloc / Cubits]   [Standalone Web Admin (HTML5/CSS/JS)]   │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                     DOMAIN LAYER                                       │
│  [Entities: User, Employee, Office, WorkSite, AttendanceRecord, DailyTimesheetEntry]  │
│  [Enums: UserRole, WorkflowStep, ActivityLogAction, SyncStatus]                       │
│  [Calculators: GeofenceCalculator (Haversine), TimesheetCalculator]                    │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                      DATA LAYER                                        │
│  [Local Persistence: LocalDatabaseService (Hive Engine - 8 Isolated Boxes)]            │
│  [Cloud Integration: SupabaseService (PostgreSQL, Storage, RLS, Stored Procedures)]     │
│  [Sync Engine: SyncEngine (Background Queue, Connectivity Listener)]                   │
│  [Hardware Services: LocationService, CameraService, DeviceBindingService]             │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack

### Flutter / Dart Implementation
- **SDK Version**: Dart 3.x, Flutter 3.x
- **Target Platforms**: Android (API 21+), iOS (12.0+), Web (Chrome/Edge/Safari), Windows Desktop.
- **Key Flutter Dependencies**:
  - `flutter_bloc` (`^8.1.3`): State management layer.
  - `hive` & `hive_flutter` (`^2.2.3`): Offline local database storage engine.
  - `firebase_core` & `firebase_auth` (`^3.1.0`, `^5.1.0`): Primary authentication gateway.
  - `supabase_flutter` (`^2.5.2`): Cloud PostgreSQL, storage bucket, real-time database, and RPC execution.
  - `geolocator` (`^12.0.0`) & `permission_handler`: Hardware GPS location & permissions.
  - `camera` (`^0.11.0`): Direct hardware selfie camera capture.
  - `image` (`^4.2.0`): Pure Dart image downscaling and quality compression.
  - `flutter_map` (`^7.0.2`) & `latlong2`: OpenStreetMap rendering for live tracking.
  - `device_info_plus` (`^10.1.0`): Hardware fingerprinting across platforms.
  - `pdf`, `printing`, `excel`, `csv`: Reporting, timesheet PDF rendering, and spreadsheet generation.

### State Management Approach (BLoC / Cubit)
The architecture strictly employs `flutter_bloc` using `Cubit` controllers to enforce unidirectional data flow:
- **`AuthCubit`** ([`auth_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/presentation/auth_cubit.dart)): Manages login states, dual-layer fallback checks, and session restoration.
- **`AttendanceCubit`** ([`attendance_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/attendance/presentation/attendance_cubit.dart)): Controls the 4-step workflow stepper, geofence verification, photo capture, and local record persistence.
- **`AdminCubit`** ([`admin_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_cubit.dart)): Handles executive stats aggregation, office/site CRUD, and live tracking map updates.
- **`UserManagementCubit`** ([`user_management_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/user_management_cubit.dart)): Manages 3-tier user accounts, secondary Firebase auth instances, and status toggles.
- **`OwnershipTransferCubit`** ([`ownership_transfer_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/ownership_transfer_cubit.dart)): Executes Super Admin re-authentication and atomic RPC ownership transfer.
- **`TimesheetCubit`** ([`timesheet_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/timesheet/presentation/timesheet_cubit.dart)): Controls daily shift aggregation, regular/overtime hours calculation, and PDF downloading.

---

## 3. Complete Architecture Explanation

### Directory Structure & Responsibilities
```
lib/
├── main.dart                       # App entry point & role-based router
├── app_config.dart                 # Global environment configurations & Supabase credentials
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         # Color palette & branding tokens
│   │   ├── app_enums.dart          # UserRole, WorkflowStep, ActivityLogAction, SyncStatus
│   │   └── app_theme.dart          # ThemeData configuration (Light/Dark themes)
│   ├── services/
│   │   ├── camera_service.dart     # Image downscaling (480px) & 65% JPEG compression engine
│   │   ├── location_service.dart   # Hardware GPS location fetching & Haversine distance calculations
│   │   ├── supabase_service.dart   # Supabase cloud database CRUD, RLS queries, & RPC execution
│   │   ├── pdf_export_service.dart # Multi-page PDF generation for attendance & timesheets
│   │   └── excel_csv_export_service.dart # Excel (.xlsx) & CSV export generation
│   ├── utils/
│   │   ├── geofence_calculator.dart # Spherical trigonometry math (Haversine formula)
│   │   └── timesheet_calculator.dart# Daily shift aggregation, regular/overtime hours splitting
│   └── widgets/
│       ├── app_button.dart         # Standardized elevated button with loading indicators
│       ├── custom_text_field.dart  # Form text input widget with built-in password visibility toggles
│       ├── status_badge.dart       # Color-coded badge for SyncStatus and workflow steps
│       └── offline_banner.dart     # Persistent offline warning bar & manual sync trigger
├── database/
│   └── local_database_service.dart # Hive local database service managing 8 isolated storage boxes
└── features/
    ├── setup/                      # First-time onboarding wizard & organization setup
    ├── auth/                       # Login screen, AuthCubit, password management
    ├── attendance/                 # 4-step stepper, camera capture modal, site selection dialog
    ├── employee/                   # Employee duty dashboard, daily timeline, selfie displays
    ├── admin/                      # Executive dashboard, employee management, office/site management, ownership transfer
    ├── timesheet/                  # Employee timesheet screen, shift filter tabs, timesheet PDF export
    ├── security/                   # Hardware device fingerprinting service (`DeviceBindingService`)
    └── sync/                       # Offline sync engine with connectivity listener (`SyncEngine`)
```

---

## 4. Feature-Level Implementation Documentation

### Feature 1: 4-Step Attendance Workflow & Selfie Verification

#### Business Rules
1. Workflow steps must be executed strictly in order: `1. Office Check-In` ➔ `2. Site Check-In` ➔ `3. Site Check-Out` ➔ `4. Office Check-Out`.
2. Attendance capture requires a mandatory live selfie taken via the front hardware camera; gallery uploads are disabled.
3. Every step validates current hardware GPS location against assigned office station or site geofence bounds ($d \le \text{radius}$).

#### Code Execution Flow Diagram
```
User Taps "Capture Step" Button
        │
        ▼
Launch `CameraCaptureModal` (`camera_capture_modal.dart`)
        │
        ▼
Capture Frame ──► `CameraService.compressImage()` (480px @ 65% JPEG)
        │
        ▼
`AttendanceCubit.processWorkflowStep()`
        │
        ├─► Call `LocationService.getCurrentPosition()`
        ├─► Call `LocationService.calculateDistance()` (Haversine Formula)
        │
        ├─► If Distance > Radius ──► Surface `GeofenceViolationError` Modal
        │
        └─► If Distance <= Radius:
                 │
                 ▼
        Create `AttendanceRecord` with `SyncStatus.pending`
                 │
                 ▼
        Persist in Hive `attendanceRecordsBox` & `pendingSyncBox`
                 │
                 ▼
        Update UI Timeline Immediately
                 │
                 ▼
        Trigger `SyncEngine.syncPendingRecords()` (If Online)
                 │
                 ▼
        Upload to Supabase `attendance_records` table & `attendance_photos` storage bucket
                 │
                 ▼
        Update Hive Record to `SyncStatus.synced` & Clear Queue
```

---

## 5. Authentication & Authorization

### Authentication Architecture
- **Primary Auth**: Authenticates against Firebase Authentication (`FirebaseAuth.instance.signInWithEmailAndPassword`).
- **Fallback Auth**: If Firebase returns credentials errors or offline exceptions, checks local Hive `app_settings` box (Super Admin password) and local `employeesBox`.
- **Secondary Firebase Auth Instance (`SecondaryAuthApp`)**: To provision new staff accounts without terminating the current Admin session, `UserManagementCubit` initializes `FirebaseAuth.instanceFor(app: secondaryApp)`.

### Role-Based Access Control (RBAC)
```dart
enum UserRole { superAdmin, admin, employee }
```
- **`SUPER_ADMIN`**: Full database control, organization settings, site/office management, and atomic ownership transfer.
- **`ADMIN`**: Employee management, office configuration, live tracking map, and reporting.
- **`EMPLOYEE`**: 4-step workflow stepper, selfie capture, personal timesheet viewing, and credential updates.

---

## 6. Offline-First Architecture

### Hive Local Storage Design
The application initializes 8 isolated Hive key-value boxes in `LocalDatabaseService`:
1. `organizationBox`: Local copy of root organization profile.
2. `currentUserBox`: Active authenticated user entity.
3. `employeesBox`: Local directory of all organization employees.
4. `usersBox`: System user profiles and assigned roles.
5. `officesBox`: Geofenced office stations.
6. `workSitesBox`: Client project locations and geofence radii.
7. `attendanceRecordsBox`: Complete historical attendance logs.
8. `pendingSyncBox`: Queue of un-synced offline records awaiting cloud transmission.

### Synchronization Scenarios

#### Scenario 1: Online Operation
1. Record written to Hive `attendanceRecordsBox` with `SyncStatus.pending`.
2. `SyncEngine` detects active network connectivity.
3. Record uploaded to Supabase `attendance_records` table and Base64 photo uploaded to `attendance_photos` storage bucket.
4. Record status updated to `SyncStatus.synced` in Hive; pending queue cleared.

#### Scenario 2: Completely Offline Operation
1. Record written to Hive `attendanceRecordsBox` and queued in `pendingSyncBox`.
2. UI timeline immediately renders new step with `PENDING` badge.
3. `OfflineBanner` widget displays active un-synced record count (e.g. `2 Pending Offline Records`).

#### Scenario 3: Connectivity Restoration
1. `connectivity_plus` fires network state change event (`ConnectivityResult.mobile` or `wifi`).
2. `SyncEngine.syncPendingRecords()` automatically executes.
3. Flushes queue sequentially while preserving original hardware `event_timestamp`.
4. Converts UI badges from `PENDING` to `SYNCED`.

---

## 7. Workforce Attendance Module

### 4-Step Stepper Specifications
1. **Step 1: `1. Office Check-In` (`OFFICE_CHECK_IN`)**: Employee checks in at designated home office station.
2. **Step 2: `2. Site Check-In` (`SITE_CHECK_IN`)**: Employee arrives at client work site; prompts `SiteNameDialog` for selecting project location (`RELAAM`, `CARRIER`, `MOPA`, `MPM`, `ELV`, `OTHERS`).
3. **Step 3: `3. Site Check-Out (Leaving Site)` (`SITE_CHECK_OUT`)**: Employee finishes site inspection and checks out from work site.
4. **Step 4: `4. Office Check-Out (Reach Office)` (`OFFICE_CHECK_OUT`)**: Employee returns to office station and completes shift.
5. **Final State: `Shift Completed` (`COMPLETED`)**: Enforces state lock until next working day.

---

## 8. GPS & Geofencing Module

### Haversine Distance Calculation Algorithm
Evaluates the spherical distance $d$ between device GPS coordinates $(\phi_1, \lambda_1)$ and office/site target coordinates $(\phi_2, \lambda_2)$:

$$\Delta \phi = \phi_2 - \phi_1, \quad \Delta \lambda = \lambda_2 - \lambda_1$$

$$a = \sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1) \cdot \cos(\phi_2) \cdot \sin^2\left(\frac{\Delta \lambda}{2}\right)$$

$$c = 2 \cdot \arctan2\left(\sqrt{a}, \sqrt{1-a}\right)$$

$$d = R \cdot c \quad (\text{where } R = 6,371,000 \text{ meters})$$

If $d \le \text{geofence\_radius}$, check-in is **APPROVED**. Otherwise, check-in is **REJECTED** with exact distance violation in meters.

---

## 9. Timesheet Engine

### Timesheet Calculation Logic (`TimesheetCalculator`)
- **Daily Shift Duration**: Calculated between `1. Office Check-In` timestamp and `4. Office Check-Out` timestamp.
- **Regular Hours Cap**: Standard regular working hours are capped at **8.0 hours per day**.
- **Overtime Calculation**: If total shift duration $> 8.0$ hours, $\text{Regular Hours} = 8.0$ and $\text{Overtime Hours} = \text{Total Hours} - 8.0$.
- **Site Visit Summary (`SiteVisitSummary`)**: Tracks time elapsed between `2. Site Check-In` and `3. Site Check-Out` for each site visit during the shift.

---

## 10. Database Documentation (Supabase PostgreSQL)

### Database Schema Overview
The database consists of **13 relational tables** with Row-Level Security (RLS) enabled across all entities:

```
[organizations] ───< [users] ───< [user_role_assignments] >─── [roles]
       │               │
       ├─► [offices]   └─► [employees] ───< [attendance_records]
       │                       │                     │
       └─► [work_sites] ───────┼─────────────────────┘
                               ├─► [devices]
                               ├─► [gps_logs]
                               └─► [activity_logs]
```

### Stored Procedure: Atomic Organization Ownership Transfer
```sql
CREATE OR REPLACE FUNCTION public.transfer_organization_ownership(
    p_org_id UUID,
    p_current_super_admin_id UUID,
    p_target_admin_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify active Super Admin role
    IF NOT EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = p_current_super_admin_id AND role = 'SUPER_ADMIN' AND organization_id = p_org_id
    ) THEN
        RAISE EXCEPTION 'Only an active SUPER_ADMIN can initiate an ownership transfer.';
    END IF;

    -- Promote Target Admin to SUPER_ADMIN
    UPDATE public.users SET role = 'SUPER_ADMIN', updated_at = CURRENT_TIMESTAMP WHERE id = p_target_admin_id;

    -- Demote Previous Super Admin to ADMIN
    UPDATE public.users SET role = 'ADMIN', updated_at = CURRENT_TIMESTAMP WHERE id = p_current_super_admin_id;

    -- Log Audit Event
    INSERT INTO public.activity_logs (organization_id, actor_user_id, target_user_id, action, details)
    VALUES (p_org_id, p_current_super_admin_id, p_target_admin_id, 'OWNERSHIP_TRANSFERRED', jsonb_build_object('timestamp', CURRENT_TIMESTAMP));

    RETURN TRUE;
END;
$$;
```

---

## 11. Security Documentation

1. **Hardware Device Fingerprinting (`DeviceBindingService`)**: Extracts platform hardware ID (`androidInfo.id`, `iosInfo.identifierForVendor`, `windowsInfo.deviceId`) and registers hardware binding in Supabase `devices` table.
2. **Gallery File Picker Disabled**: Camera modal forces direct camera stream capture to block static image uploads or spoofing.
3. **Database RLS Policies**: All database queries enforce tenant separation via `organization_id`.
4. **Password Security**: Interactive show/hide password visibility toggles (`CustomTextField`) enforce visual privacy across setup, login, user creation, and ownership transfer screens.

---

## 12. Performance Optimization

1. **Image Downscaling Engine**: Downscales 5MB raw camera photos to 480px @ 65% JPEG quality (**~25KB–45KB payload, 99% reduction**), eliminating network congestion during sync.
2. **Hive Local Key-Value Storage**: Outperforms SQLite with sub-millisecond read/write latencies for local UI rendering.
3. **Selective Map Marker Rendering**: `flutter_map` and Leaflet.js map markers render using spatial bounding boxes to maintain 60 FPS UI performance.

---

## 13. Deployment Documentation

### Setup & Local Execution Commands
```bash
# 1. Install Flutter Dependencies
flutter pub get

# 2. Run Flutter Web / Desktop Application
flutter run -d chrome

# 3. Serve Standalone Web Admin Portal
cd web_admin
npx serve -s . -l 3000
```

### Database Deployment
1. Open Supabase Console -> SQL Editor.
2. Copy contents of `backend/supabase_schema.sql` and click **Run**.
