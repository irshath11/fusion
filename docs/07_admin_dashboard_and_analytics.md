# 07. Admin Dashboard, Live Tracking & Analytics Feature

## Overview
The **Admin Dashboard, Live GPS Tracking & Analytics** feature provides executive visibility into overall organizational attendance metrics, daily workforce progression, real-time interactive GPS mapping, multi-filter activity feeds, and a standalone enterprise web admin application (`web_admin`).

---

## 1. Key Functionalities

1. **Executive Key Performance Indicators (KPI Cards)**:
   - **Active Employees**: Total active personnel in system.
   - **Present Today**: Unique employees who executed at least 1 workflow step today.
   - **On Duty**: Personnel actively performing field inspection duties.
   - **Shift Complete**: Personnel who completed all 4 daily workflow steps (`Office Check-Out`).
   - **Pending Sync**: Queue of records stored locally waiting for network transmission.

2. **Live Interactive GPS Tracking Map (`LiveTrackingMapScreen`)**:
   - Built with OpenStreetMap & `flutter_map`.
   - Renders green office station markers with semi-transparent geofence radius circles.
   - Displays real-time employee check-in location markers with custom avatars, employee name callouts, timestamp, and workflow step labels.
   - Fits bounding box to display all office stations and field locations simultaneously.

3. **Multi-Filter Attendance Activity Feed**:
   - Filter by Date, Office Station, Employee Name/Code, and Workflow Status.
   - Displays selfie photos, exact GPS coordinates, geofence status (`VALID` / `VIOLATION`), and sync indicators.

4. **Statutory Cards & Passes Compliance Module**:
   - Executive Cards overview cards: **Total Cards**, **Expired**, **Critical (≤3d)**, **Expiring (≤30d)**, and **Valid**.
   - Gemini AI Vision OCR scanning button for instant document processing from image/camera files.
   - 1-Click WhatsApp reminder links (`https://wa.me/...`) and email broadcasting to compliance recipients.
   - Quick navigation into the full **Cards Management Screen** (`CardsManagementScreen`).

5. **Reports & Analytics with 25th–24th Salary Cycle & Leave Records**:
   - Dynamic Salary Cycle selector allowing quick toggling across months (running 25th to 24th).
   - Dedicated **Leave Records** tab breaking down employee presence, unapproved leaves/absences, Sunday weekly off days, and Sunday duties.
   - Direct database query optimization: date ranges are filtered server-side in Supabase PostgreSQL queries instead of fetching entire history client-side.

6. **Standalone Enterprise Admin Web Portal (`web_admin/`)**:
   - Lightweight, ultra-fast web application built using HTML5, CSS3, vanilla JavaScript, Supabase JS SDK, and Leaflet.js maps.
   - **Key Web Features**:
     - Session persistence & administrative login overlay (`SUPER_ADMIN` and `ADMIN` access control).
     - Dashboard metric cards (Active Employees, Present Today, On Duty, Completed Shifts).
     - Live Leaflet map rendering office stations, geofence radius circles, and real-time employee check-in pins.
     - Employee Management drawer form with official avatar rendering and office assignment.
     - Office & Work Site table management with branch deletion safeguard.
     - **Cards Compliance Manager**: Full web implementation with live cards grid, status badges, Gemini OCR scan modal, direct WhatsApp notification buttons, and Excel (.xlsx) compliance export.
     - Interactive Organization Ownership Transfer modal dialog (`transferModal`).

---

## 2. Technical Implementation & Source Files

### Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/presentation/admin_dashboard_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_dashboard_screen.dart) | Executive dashboard with metric cards, navigation tabs, quick actions, cards summary, and attendance feeds. |
| [`lib/features/admin/presentation/cards_management_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/cards_management_screen.dart) | Dedicated UI for managing statutory employee cards, Gemini OCR scanning, and compliance alerts. |
| [`lib/features/admin/presentation/reports_analytics_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/reports_analytics_screen.dart) | Comprehensive analytics portal with Salary Cycle (25th–24th) filters, Attendance logs, and Leave Records ledger. |
| [`lib/features/admin/presentation/live_tracking_map_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/live_tracking_map_screen.dart) | Interactive OpenStreetMap rendering geofence radii and real-time employee check-in markers. |
| [`lib/features/admin/presentation/admin_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/admin_cubit.dart) | Cubit fetching records, aggregating stats, and processing filter criteria. |
| [`web_admin/index.html`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/index.html) | HTML5 SPA container for Standalone Web Admin Portal with Cards Manager section. |
| [`web_admin/styles.css`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/styles.css) | Enterprise Design System styling, dark/light theme tokens, layout grid. |
| [`web_admin/app.js`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/web_admin/app.js) | JavaScript controller, Supabase JS SDK integration, Leaflet.js map logic, Cards manager, and session storage. |

