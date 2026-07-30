# 07. Admin Dashboard, Live Tracking & Analytics Feature

## Overview
The **Admin Dashboard, Live GPS Tracking & Analytics** feature provides executive visibility into overall organizational attendance metrics, daily workforce progression, real-time interactive GPS mapping, and multi-filter activity feeds.

---

## 1. Key Functionalities

1. **Executive Key Performance Indicators (KPI Cards)**:
   - **Active Employees**: Total active personnel in system.
   - **Present Today**: Unique employees who executed at least 1 workflow step today.
   - **On Duty**: Personnel actively performing field inspection duties.
   - **Shift Complete**: Personnel who completed all 4 daily workflow steps.
   - **Pending Sync**: Queue of records stored locally waiting for network transmission.

2. **Live Interactive GPS Tracking Map (`LiveTrackingMapScreen`)**:
   - Built with OpenStreetMap & `flutter_map`.
   - Renders green office station markers with semi-transparent geofence radius circles.
   - Displays real-time employee check-in location markers with custom avatars, employee name callouts, timestamp, and workflow step labels.
   - Fits bounding box to display all office stations and field locations simultaneously.

3. **Multi-Filter Attendance Activity Feed**:
   - Filter by Date, Office Station, Employee Name/Code, and Workflow Status.
   - Displays selfie photos, exact GPS coordinates, geofence status (`VALID` / `VIOLATION`), and sync indicators.

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/admin_dashboard_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_dashboard_screen.dart) | Executive dashboard with metric cards, navigation tabs, quick actions, and attendance feeds. |
| [`lib/features/admin/presentation/live_tracking_map_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/live_tracking_map_screen.dart) | Interactive OpenStreetMap rendering geofence radii and real-time employee check-in markers. |
| [`lib/features/admin/presentation/admin_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_cubit.dart) | Cubit fetching records, aggregating stats, and processing filter criteria. |
