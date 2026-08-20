# 02. Organization Setup & Onboarding Feature

## Overview
The **Organization Setup & Onboarding** feature allows a new enterprise customer or Super Admin to initialize company configuration, establish the primary office station, define initial geofencing bounds, and provision the root Super Admin credentials (`role = 'SUPER_ADMIN'`) on first launch.

---

## 1. Key Functionalities

1. **First-Time App Setup Detection**:
   - The app checks `LocalDatabaseService` for an existing `OrganizationEntity`.
   - If no organization is found, the app automatically routes the user to the `OrganizationSetupScreen`.

2. **Organization Configuration**:
   - Captures Organization Name (e.g., `Apex Logistics Solutions`).
   - Captures Super Admin Name, Email, & Password.
   - Captures Default Office Station Name & Address.
   - Captures Office Latitude & Longitude coordinates.
   - Sets Default Geofence Radius in meters (default: `200.0` meters).

3. **GPS Auto-Detection During Setup**:
   - Provides a "Use Current GPS Location" feature during onboarding to automatically populate high-accuracy latitude and longitude from hardware GPS sensors.

4. **Multi-Table Database Initialization**:
   - Initializes local Hive boxes (`organizationBox`, `currentUserBox`, `officesBox`, `usersBox`).
   - Creates the root organization record in Supabase `organizations`.
   - Creates the default office station in Supabase `offices`.
   - Creates the root Super Admin user profile (`role = 'SUPER_ADMIN'`) in Supabase `users`.
   - Logs audit trail action `ORG_SETUP` in `activity_logs`.

---

## 2. Technical Implementation & Data Structures

### Data Model (`OrganizationEntity`)
```dart
class OrganizationEntity {
  final String id;
  final String name;
  final String superAdminName;
  final String superAdminEmail;
  final String defaultOfficeName;
  final double defaultLatitude;
  final double defaultLongitude;
  final double defaultGeofenceRadiusMeters;
  final DateTime createdAt;

  OrganizationEntity({
    required this.id,
    required this.name,
    required this.superAdminName,
    required this.superAdminEmail,
    required this.defaultOfficeName,
    required this.defaultLatitude,
    required this.defaultLongitude,
    required this.defaultGeofenceRadiusMeters,
    required this.createdAt,
  });
}
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/setup/domain/organization_setup.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/setup/domain/organization_setup.dart) | Organization domain model and serialization rules. |
| [`lib/features/setup/presentation/setup_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/setup/presentation/setup_cubit.dart) | Cubit managing onboarding validation, GPS location retrieval, and cloud provisioning. |
| [`lib/features/setup/presentation/organization_setup_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/setup/presentation/organization_setup_screen.dart) | Interactive onboarding UI with step-by-step form inputs, password visibility toggles, and location auto-detect. |
