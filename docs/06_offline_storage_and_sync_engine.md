# 06. Offline Storage & Background Sync Engine Feature

## Overview
The **Offline Storage & Background Sync Engine** provides local persistence, offline operation capability, and background cloud synchronization. All workforce operations—including employee profiles, office definitions, work site registries, and daily attendance records—are written locally to Hive key-value boxes first. A background synchronization engine listens for network connectivity changes and flushes pending records to Supabase with automatic retry logic while preserving exact hardware event timestamps.

---

## 1. Key Functionalities

1. **Hive Local Storage Engine (`LocalDatabaseService`)**:
   - Manages isolated Hive boxes:
     - `organizationBox`: Organization setup profile.
     - `currentUserBox`: Active logged-in user profile.
     - `employeesBox`: Employee directory.
     - `usersBox`: User accounts and role definitions.
     - `officesBox`: Geofence office stations.
     - `workSitesBox`: Client project locations.
     - `attendanceRecordsBox`: Historical and daily attendance records.
     - `pendingSyncBox`: Queue of un-synced attendance records.

2. **Offline Banner & Indicator Widget**:
   - Displays real-time pending sync status banner (`OfflineBanner`) when un-synced records exist.
   - Shows exact count of pending records (e.g., `2 Pending Offline Records`).
   - Provides a "Sync Now" manual trigger button.

3. **Background Sync Engine (`SyncEngine`)**:
   - Listens to device network connectivity changes via `connectivity_plus`.
   - On network restoration (Cellular / Wi-Fi), automatically triggers `syncPendingRecords()`.
   - Flushes pending records from `pendingSyncBox` to Supabase `attendance_records` table.
   - Preserves original hardware event timestamps (`event_timestamp`).
   - Updates local record `syncStatus` from `SyncStatus.pending` to `SyncStatus.synced`.
   - Clears uploaded items from the pending sync queue upon verified cloud confirmation.

4. **Offline Service Reports Storage & Sequential Prefix Sequencing**:
   - **Local Queue (`pending_service_reports_json`)**: Manages offline client service sheets directly in Hive storage, allowing full report generation, editing, and previewing without internet.
   - **Sequential Prefix Tracking (`currentEmployeePrefix`, `sr_seq_$prefix`)**: Generates prefix codes (e.g. `E01`, `E02`) and tracks sequential reference numbers starting at `2001` (`SR-E01-2001`, `SR-E01-2002`).
   - **In-Memory Caching (`_cachedServiceReports`)**: In-memory caching layer guarantees instantaneous list rendering and zero UI latency during scroll.
   - **Cloud Reconciliation (`mergeCloudServiceReports`)**: Intelligently reconciles local pending reports with remote Supabase records upon reconnection without overwriting offline edits.

5. **Offline Work Site Photo Submissions Management**:
   - **Local Storage (`work_photo_submissions_json`)**: Persists technician field work photo batches locally with metadata (work title, location, employee, remarks, base64/URL photos).
   - **In-Memory Cache (`_cachedWorkPhotoSubmissions`)**: Provides sub-millisecond retrieval performance for UI galleries.
   - **Batch Sync Tracking**: Monitors pending uploads via `getPendingWorkPhotoSubmissions()` and marks items synced via `markWorkPhotoSubmissionSynced()`.

6. **Non-Blocking Background Startup Initialization**:
   - On application launch, if organization setup has previously succeeded locally, the cloud organization status check is dispatched asynchronously via `unawaited(checkSetupStatusFromSupabase())`.
   - Prevents network timeouts from blocking the UI thread or delaying the splash/login screen render.

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
| [`lib/database/local_database_service.dart`](../lib/database/local_database_service.dart) | Core Hive database initialization, non-blocking setup check, offline service reports, work photos, and CRUD helper methods. |
| [`lib/features/sync/data/sync_engine.dart`](../lib/features/sync/data/sync_engine.dart) | Connectivity monitoring, background queue processor, and Supabase synchronization logic. |
| [`lib/core/widgets/offline_banner.dart`](../lib/core/widgets/offline_banner.dart) | UI banner displaying pending offline counts and manual sync triggers. |
