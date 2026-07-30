# 06. Offline Storage & Background Sync Engine Feature

## Overview
The **Offline Storage & Background Sync Engine** provides local persistence, offline operation capability, and background cloud synchronization. All workforce operations—including employee profiles, office definitions, and daily attendance records—are written locally to Hive key-value boxes first. A background synchronization engine listens for network connectivity changes and flushes pending records to Supabase with automatic retry logic.

---

## 1. Key Functionalities

1. **Hive Local Storage Engine (`LocalDatabaseService`)**:
   - Manages isolated Hive boxes:
     - `organizationBox`: Organization setup profile.
     - `currentUserBox`: Active logged-in user profile.
     - `employeesBox`: Employee directory.
     - `officesBox`: Geofence office stations.
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
   - Updates local record `syncStatus` from `SyncStatus.pending` to `SyncStatus.synced`.
   - Clears uploaded items from the pending sync queue upon verified cloud confirmation.

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
