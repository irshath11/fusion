# 04. Office Station & Geofence Management Feature

## Overview
The **Office Station & Geofence Management** feature enables administrators to configure physical office locations, work sites, construction hubs, and field branches with precise GPS coordinates (Latitude & Longitude) and custom geofence radii (in meters). All employee check-ins and field activities are validated against these boundaries in real-time.

---

## 1. Key Functionalities

1. **Office Station & Work Site Configuration**:
   - Defines Station / Work Site Name (e.g., `Headquarters - Dubai` or `Dubai Harbor Construction Site`).
   - Defines Client Name & Physical Address.
   - Sets Latitude & Longitude coordinates.
   - Sets Geofence Radius in meters (e.g., `100.0m`, `200.0m`, `300.0m`, `500.0m`).

2. **Hardware GPS Auto-Fetch**:
   - Integrated with `Geolocator` (`LocationService.getCurrentPosition()`).
   - Provides a "Use Current GPS Location" button in the form modal to automatically fetch current coordinates from the device hardware GPS sensor and populate the latitude and longitude text fields.

3. **Geofence Distance Calculation Algorithm (Haversine Formula)**:
   - Evaluates the precise spherical distance between employee hardware GPS coordinates `(lat1, lon1)` and office/site target coordinates `(lat2, lon2)` using the Haversine formula:

$$\Delta \sigma = 2 \arcsin \left( \sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1) \cos(\phi_2) \sin^2\left(\frac{\Delta \lambda}{2}\right)} \right)$$

$$d = R \cdot \Delta \sigma$$

   - If distance $d \le \text{radius}$, check-in is **APPROVED**.
   - If distance $d > \text{radius}$, check-in is **REJECTED** with a `GeofenceViolationError` dialog displaying exact excess distance in meters.

4. **Multi-Location Hierarchy**:
   - **Static Offices (`offices` table)**: Permanent company headquarters, depots, and regional hubs.
   - **Work Sites (`work_sites` table)**: Client-specific project locations, construction sites, or maintenance depots with custom radius bounds.

5. **Office Station Deletion & Assignment Fallback**:
   - **Delete Action**: Administrators can delete branch offices directly from the offices list (`OfficeManagementScreen`) or from the office editing modal.
   - **Protected Main Office Safeguard**: The default Main Office (`isDefault == true`) is protected against deletion, preventing accidental removal of the central organization geofence.
   - **Automatic Employee Fallback**: Deleting a branch office automatically reverts all assigned employees to the default Main Office (`useDefaultOffice: true`, `assignedOfficeId: null`), preventing orphaned profiles or broken geofence checks.
   - **Soft-Delete Cloud Synchronization**: Performs atomic soft deletion in Supabase (`is_deleted: true`) and clears references in `employees` table, preserving historical attendance audit logs.

6. **Per-Employee Geofence Enable / Disable Toggle (`bypassGeofence`)**:
   - **Selective Bypass**: Admins can disable geofence validation for specific travelling or remote personnel (`bypassGeofence: true`), allowing them to execute `1. Office Check-In` from anywhere while keeping geofence validation strictly enforced for office/site-bound staff.
   - **Resolution Precedence**: `AttendanceCubit` evaluates `localOverride ?? (emp.bypassGeofence || user.bypassGeofence)` before running Haversine distance checks.
   - **Multi-Surface Management**: Accessible via quick toggle pills and `Geofence Enabled` / `Disabled` filter tabs in `EmployeeManagementScreen`, the switch inside `UserFormDialog`, and the `web_admin/app.js` employee table.
   - **Database Migration & Tests**: Backed by `backend/add_bypass_geofence_columns.sql` (`users.bypass_geofence`, `employees.bypass_geofence`) and verified by `test/geofence_toggle_test.dart`.

---

## 2. Technical Implementation & Data Structures

### Data Model (`OfficeEntity`)
```dart
class OfficeEntity {
  final String id;
  final String organizationId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;
  final bool isDefault;
  final bool isActive;

  OfficeEntity({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.geofenceRadiusMeters = 200.0,
    this.isDefault = false,
    this.isActive = true,
  });
}
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/domain/office_entity.dart`](../lib/features/admin/domain/office_entity.dart) | Office station domain model. |
| [`lib/features/admin/presentation/admin_cubit.dart`](../lib/features/admin/presentation/admin_cubit.dart) | Cubit managing office station and work site CRUD operations in local Hive storage & Supabase cloud tables. |
| [`lib/features/admin/presentation/office_management_screen.dart`](../lib/features/admin/presentation/office_management_screen.dart) | Admin UI for creating, editing, and deleting office stations with GPS location picker and geofence radius adjustment. |
| [`lib/features/admin/presentation/work_site_management_screen.dart`](../lib/features/admin/presentation/work_site_management_screen.dart) | Admin UI for creating/editing client work sites and project locations. |
| [`lib/core/services/location_service.dart`](../lib/core/services/location_service.dart) | Service handling GPS permission checks, position retrieval, and Haversine distance calculations. |
| [`backend/add_bypass_geofence_columns.sql`](../backend/add_bypass_geofence_columns.sql) | SQL migration adding `bypass_geofence` columns to `users` and `employees` tables. |
| [`test/geofence_toggle_test.dart`](../test/geofence_toggle_test.dart) | Unit tests verifying Haversine geofence boundary checks and per-employee bypass overrides. |

