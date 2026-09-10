# 07. Admin Dashboard, Live Tracking & Analytics Feature

## Overview
The **Admin Dashboard, Live GPS Tracking & Analytics** feature provides executive visibility into overall organizational attendance metrics, daily workforce progression, real-time interactive GPS mapping, multi-filter activity feeds, and a standalone enterprise web admin application (`web_admin`).

---

## 1. Key Functionalities

1. **Executive Key Performance Indicators (KPI Cards & Ticker Ribbon)**:
   - **Active Employees**: Total active personnel configured in system.
   - **Present Today**: Unique employees who executed at least 1 workflow step today.
   - **On Duty**: Personnel actively performing field inspection duties.
   - **Shift Complete**: Personnel who completed all daily workflow steps (`Office Check-Out`).
   - **Pending Sync**: Queue of records stored locally waiting for network transmission.
   - **Active Salary Cycle Header Card (`SalaryCycleHelper`)**: Displays current corporate pay period (e.g. `25 Aug 2026 – 24 Sep 2026 (Sep 2026)`) with cycle-to-date attendance rates and responsive overflow wrapping.
   - **Executive KPI Ticker Ribbon (`AppGlassCard`)**: High-impact glassmorphic KPI summary bar displaying:
     - **Total Staff**: Dynamic aggregate staff count.
     - **Active Duty**: Active field personnel count (`officeCheckIn`).
     - **Attendance Rate (%)**: Real-time calculated attendance compliance percentage.
     - **Geofence Audit (%)**: Percentage of check-ins meeting strict geofence radius criteria (e.g. 98.4%).

2. **AI Voice Report Assistant & Generative Insights Trigger**:
   - One-tap quick action launching the **AI Voice Report Assistant** (`AiVoiceReportBottomSheet`), allowing administrators and supervisors to run speech-to-text post-processing and automated field report extraction.

3. **Emergency Duty Monitoring & Audit Controls**:
   - Real-time detection and feed indicators for `emergencyCheckIn` and `emergencyCheckOut` duty events.
   - Administrative action dialog allowing direct creation or adjustment of emergency logs for on-call engineers.

4. **Live Interactive GPS Tracking Map (`LiveTrackingMapScreen`)**:
   - Built with OpenStreetMap & `flutter_map`.
   - Renders green office station markers with semi-transparent geofence radius circles.
   - Displays real-time employee check-in location markers with custom avatars, employee name callouts, timestamp, and workflow step labels.
   - Fits bounding box to display all office stations and field locations simultaneously.

5. **Multi-Filter Attendance Activity Feed**:
   - Filter by Date, Office Station, Employee Name/Code, and Workflow Status.
   - Displays selfie photos, exact GPS coordinates, geofence status (`VALID` / `VIOLATION`), and sync indicators.

6. **Standalone Enterprise Admin Web Portal (`web_admin/`)**:
   - Lightweight, ultra-fast web application built using HTML5, CSS3, vanilla JavaScript, Supabase JS SDK, and Leaflet.js maps.
   - **Key Web Features**:
     - Session persistence & administrative login overlay (`SUPER_ADMIN` and `ADMIN` access control).
     - Dashboard metric cards (Active Employees, Present Today, On Duty, Completed Shifts).
     - Live Leaflet map rendering office stations, geofence radius circles, and real-time employee check-in pins.
     - Employee Management drawer form for adding and updating staff profiles.
     - Emergency Duty logs and active status badges.
     - Office & Work Site table management.
     - Interactive Organization Ownership Transfer modal dialog (`transferModal`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/admin_dashboard_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_dashboard_screen.dart) | Executive dashboard with metric cards, navigation tabs, quick actions, and attendance feeds. |
| [`lib/features/admin/presentation/live_tracking_map_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/live_tracking_map_screen.dart) | Interactive OpenStreetMap rendering geofence radii and real-time employee check-in markers. |
| [`lib/features/admin/presentation/admin_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_cubit.dart) | Cubit fetching records, aggregating stats, and processing filter criteria. |
| [`web_admin/index.html`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/index.html) | HTML5 SPA container for Standalone Web Admin Portal. |
| [`web_admin/styles.css`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/styles.css) | Enterprise Design System styling, dark/light theme tokens, layout grid. |
| [`web_admin/app.js`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/app.js) | JavaScript controller, Supabase JS SDK integration, Leaflet.js map logic, and session storage. |
