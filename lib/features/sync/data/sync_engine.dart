import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/location_service.dart';
import '../../attendance/domain/attendance_record.dart';

class SyncEngineResult {
  final int syncedCount;
  final int failedCount;
  final bool isNoInternet;
  final String message;

  SyncEngineResult({
    required this.syncedCount,
    required this.failedCount,
    this.isNoInternet = false,
    required this.message,
  });
}

class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;
  SyncEngine._internal();

  final LocalDatabaseService _db = LocalDatabaseService();
  final SupabaseService _supabase = SupabaseService();

  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final StreamController<SyncEngineResult> _syncResultController =
      StreamController<SyncEngineResult>.broadcast();
  Stream<SyncEngineResult> get syncResultStream => _syncResultController.stream;

  StreamSubscription? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _isAutoSyncStarted = false;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Starts the continuous background auto-sync process:
  /// 1. Listens for network connectivity changes (offline -> online).
  /// 2. Sets a recurring timer (every 2 minutes) to auto-flush pending queues.
  void startAutoSync() {
    if (_isAutoSyncStarted) return;
    _isAutoSyncStarted = true;

    // 1. Connectivity listener
    try {
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((results) {
        final bool hasConnection =
            results.any((r) => r != ConnectivityResult.none);

        if (hasConnection) {
          triggerAutoSync();
        }
      });
    } catch (e) {
      debugPrint('SyncEngine connectivity listener error: $e');
    }

    // 2. Periodic background flush timer (every 2 minutes)
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_db.getAllPendingSyncRecords().isNotEmpty) {
        triggerAutoSync();
      }
    });

    // 3. Initial check on startup
    triggerAutoSync();
  }

  void stopAutoSync() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _isAutoSyncStarted = false;
  }

  /// Triggers auto-sync asynchronously with safety guards and debounce
  void triggerAutoSync() {
    if (_isSyncing) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isSyncing) {
        performSync();
      }
    });
  }

  /// Check active internet connectivity with multi-endpoint fallback
  Future<bool> hasInternetConnection() async {
    try {
      final res1 = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (res1.isNotEmpty && res1[0].rawAddress.isNotEmpty) return true;
    } catch (_) {}

    try {
      final res2 = await InternetAddress.lookup('supabase.co')
          .timeout(const Duration(seconds: 3));
      if (res2.isNotEmpty && res2[0].rawAddress.isNotEmpty) return true;
    } catch (_) {}

    try {
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {}

    return false;
  }

  /// Trigger sync manually or via background network monitor
  Future<SyncEngineResult> performSync() async {
    if (_isSyncing) {
      return SyncEngineResult(
        syncedCount: 0,
        failedCount: 0,
        message: 'Sync already in progress.',
      );
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;

    try {
      final hasNet = await hasInternetConnection();
      if (!hasNet) {
        final res = SyncEngineResult(
          syncedCount: 0,
          failedCount: 0,
          isNoInternet: true,
          message:
              'No internet connection. Please connect to Wi-Fi or mobile data.',
        );
        _syncResultController.add(res);
        return res;
      }

      // Consolidate Anandh & Rafi records to canonical identities before uploading
      await _db.sanitizeDuplicateEmployees();

      List<AttendanceRecord> pendingRecords = _db.getAllPendingSyncRecords();

      if (pendingRecords.isEmpty) {
        final res = SyncEngineResult(
          syncedCount: 0,
          failedCount: 0,
          isNoInternet: false,
          message: 'No pending offline attendance records to sync.',
        );
        _syncResultController.add(res);
        return res;
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> syncedIds = [];

      for (var record in pendingRecords) {
        try {
          AttendanceRecord recordToSync = record;

          // Deferred Reverse Geocoding:
          // Convert raw GPS coordinates to exact live street address now that internet is available
          if (record.latitude != 0.0 && record.longitude != 0.0) {
            try {
              final exactAddress =
                  await LocationService.getAddressFromCoordinates(
                record.latitude,
                record.longitude,
              ).timeout(const Duration(seconds: 4));

              if (exactAddress.isNotEmpty &&
                  !exactAddress.contains('Live Field Location') &&
                  !exactAddress.contains('Timeout') &&
                  !exactAddress.contains('Error')) {
                recordToSync = record.copyWith(address: exactAddress);
                _db.updateAttendanceRecord(recordToSync);
              }
            } catch (_) {}
          }

          String? publicPhotoUrl;

          if (recordToSync.photoBase64.isNotEmpty &&
              !recordToSync.photoBase64.startsWith('http')) {
            publicPhotoUrl = await _supabase.uploadAttendancePhotoData(
              photoDataOrPath: recordToSync.photoBase64,
              recordId: recordToSync.id,
            );
          }

          bool success = await _supabase.insertAttendanceEntry(
            record: recordToSync,
            photoPublicUrl: publicPhotoUrl,
          );

          if (success) {
            if (publicPhotoUrl != null && publicPhotoUrl.isNotEmpty) {
              recordToSync =
                  recordToSync.copyWith(photoBase64: publicPhotoUrl);
              _db.updateAttendanceRecord(recordToSync);
            }
            syncedIds.add(recordToSync.id);
            syncedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
        }
      }

      if (syncedIds.isNotEmpty) {
        _db.markRecordsSynced(syncedIds);
      }

      final message = failedCount > 0
          ? 'Synced $syncedCount entries ($failedCount failed).'
          : 'Successfully synchronized $syncedCount attendance entries to cloud.';

      final res = SyncEngineResult(
        syncedCount: syncedCount,
        failedCount: failedCount,
        isNoInternet: false,
        message: message,
      );
      _syncResultController.add(res);
      return res;
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }
  }
}
