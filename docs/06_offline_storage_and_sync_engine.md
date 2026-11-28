# 06. Offline Storage & Background Sync Engine Feature

## Overview
The **Offline Storage & Background Sync Engine** provides local persistence, offline operation capability, and background cloud synchronization. All workforce operations—including employee profiles, office definitions, work site registries, and daily attendance records—are written locally to Hive key-value boxes first. A background synchronization engine listens for network connectivity changes and flushes pending records to Supabase with automatic retry logic while preserving exact hardware event timestamps.

---

## 1. Key Functionalities

1. **Hive Local Storage Engine (`LocalDatabaseService`)**:
   - Opens the Hive `app_settings` box (`Hive.openBox('app_settings')`) and maintains in-memory caches backed by JSON-serialized persistence keys:
     - `is_setup_completed` & `organization_json`: Organization setup profile.
     - `current_user_json`: Active logged-in user profile.
     - `employees_json`: Employee directory (with relieved personnel automatically purged on init).
     - `users_json`: User accounts and role definitions.
     - `offices_json`: Geofence office stations.
     - `worksites_json`: Client project locations.
     - `attendance_records_json`: Historical, daily, and pending (`SyncStatus.pending`) attendance records.
     - `salaries_json`: Employee salary configurations (`DefaultSalaryData` seeded if empty).
     - `geofence_bypass_overrides`: Per-employee geofence bypass overrides map.
   - **Auto-Resolution on Init**: Automatically resolves expired unclosed check-ins older than 24 hours (`autoResolveExpiredCheckIns()`) and deduplicates canonical employee identities (`sanitizeDuplicateEmployees()`).

2. **Offline Banner & Indicator Widget**:
   - Displays real-time pending sync status banner (`OfflineBanner`) when un-synced records exist.
   - Shows exact count of pending records (e.g., `2 Pending Offline Records`).
   - Provides a "Sync Now" manual trigger button.

3. **Background Sync Engine (`SyncEngine`)**:
   - Listens to device network connectivity changes via `connectivity_plus`.
   - Sets a **15-minute periodic background flush timer** (`Duration(minutes: 15)`) when pending records exist (preserving Supabase free-tier log ingestion).
   - On network restoration (Cellular / Wi-Fi) or manual trigger, executes `performSync()`:
     - Performs deferred reverse geocoding when coordinates lack a street address.
     - Uploads compressed photo payloads to `attendance_photos` storage bucket.
     - Inserts attendance entries to Supabase `attendance_records` while preserving original hardware `event_timestamp`.
     - Updates local record `syncStatus` from `SyncStatus.pending` to `SyncStatus.synced`.
   - **Non-Blocking Bulk Cloud Sync**: Manual calendar attendance entries (`PutOfficeAttendanceDialog`) save instantly to local Hive storage and sync in non-blocking batches to Supabase (`SupabaseService`).
   - **Admin Local Cache Reset**: Administrators can clear locally cached attendance records via `Clear Cache` in `AdminDashboardScreen` (`clearAttendanceCache()`).

---

## 2. Technical Implementation Architecture

```
                               ┌────────────────────────────────┐
                               │  Employee Captures Attendance  │
                               └───────────────┬────────────────┘
                                               │
                                               ▼
                               ┌────────────────────────────────┐
                               │ Save to Hive Local Box         │
                               │ (SyncStatus.pending)           │
                               └───────────────┬────────────────┘
                                               │
                                               ▼
                               ┌────────────────────────────────┐
                               │  Check Connectivity Listener   │
                               └───────────────┬────────────────┘
                                               │
                      ┌────────────────────────┴────────────────────────┐
                      │ Offline                                         │ Online
                      ▼                                                 ▼
        ┌───────────────────────────┐                     ┌───────────────────────────┐
        │ Queue in pendingSyncBox   │                     │ Upload to Supabase DB     │
        │ Banner displays count     │                     │ (base64 photo + GPS)      │
        └───────────────────────────┘                     └─────────────┬─────────────┘
                                                                        │
                                                                        ▼
                                                          ┌───────────────────────────┐
                                                          │ Mark SyncStatus.synced    │
                                                          │ Clear from pendingSyncBox │
                                                          └───────────────────────────┘
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/database/local_database_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/database/local_database_service.dart) | Core Hive database initialization, box accessors, and CRUD helper methods. |
| [`lib/features/sync/data/sync_engine.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/sync/data/sync_engine.dart) | Connectivity monitoring, background queue processor, and Supabase synchronization logic. |
| [`lib/core/widgets/offline_banner.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/widgets/offline_banner.dart) | UI banner displaying pending offline counts and manual sync triggers. |
