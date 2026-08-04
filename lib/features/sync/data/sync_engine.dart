import 'dart:async';
import 'dart:io';
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
  final LocalDatabaseService _db = LocalDatabaseService();
  final SupabaseService _supabase = SupabaseService();

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
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {}

    return false;
  }

  /// Trigger sync manually or via background network monitor
  Future<SyncEngineResult> performSync() async {
    final hasNet = await hasInternetConnection();
    if (!hasNet) {
      return SyncEngineResult(
        syncedCount: 0,
        failedCount: 0,
        isNoInternet: true,
        message: 'No internet connection. Please connect to Wi-Fi or mobile data.',
      );
    }

    List<AttendanceRecord> pendingRecords = _db.getAllPendingSyncRecords();

    if (pendingRecords.isEmpty) {
      return SyncEngineResult(
        syncedCount: 0,
        failedCount: 0,
        isNoInternet: false,
        message: 'No pending offline attendance records to sync.',
      );
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
            final exactAddress = await LocationService.getAddressFromCoordinates(
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

        if (recordToSync.photoBase64.isNotEmpty) {
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

    return SyncEngineResult(
      syncedCount: syncedCount,
      failedCount: failedCount,
      isNoInternet: false,
      message: message,
    );
  }
}
