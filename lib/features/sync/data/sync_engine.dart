import 'dart:async';
import 'dart:io';
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
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

  /// Check active internet connectivity with fast 600ms timeout
  Future<bool> hasInternetConnection() async {
    try {
      final res1 = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 600));
      if (res1.isNotEmpty && res1[0].rawAddress.isNotEmpty) return true;
    } catch (_) {}

    try {
      final res2 = await InternetAddress.lookup('supabase.co')
          .timeout(const Duration(milliseconds: 600));
      if (res2.isNotEmpty && res2[0].rawAddress.isNotEmpty) return true;
    } catch (_) {}

    return false;
  }

  /// Trigger sync manually or via background network monitor
  Future<SyncEngineResult> performSync() async {
    List<AttendanceRecord> pendingRecords = _db.getAllPendingSyncRecords();

    if (pendingRecords.isEmpty) {
      return SyncEngineResult(
        syncedCount: 0,
        failedCount: 0,
        isNoInternet: false,
        message: 'No pending offline attendance records to sync.',
      );
    }

    final hasNet = await hasInternetConnection();
    if (!hasNet) {
      return SyncEngineResult(
        syncedCount: 0,
        failedCount: 0,
        isNoInternet: true,
        message: 'No internet connection. Please connect to Wi-Fi or mobile data.',
      );
    }

    int syncedCount = 0;
    int failedCount = 0;
    List<String> syncedIds = [];
    bool encounteredNetworkError = false;

    for (var record in pendingRecords) {
      try {
        String? publicPhotoUrl;

        if (record.photoBase64.isNotEmpty && !record.photoBase64.startsWith('http')) {
          publicPhotoUrl = await _supabase.uploadAttendancePhotoData(
            photoDataOrPath: record.photoBase64,
            recordId: record.id,
          );
        }

        bool success = await _supabase.insertAttendanceEntry(
          record: record,
          photoPublicUrl: publicPhotoUrl,
        );

        if (success) {
          syncedIds.add(record.id);
          syncedCount++;
        } else {
          failedCount++;
        }
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('handshakeexception') ||
            errStr.contains('timeout') ||
            errStr.contains('clientexception')) {
          encounteredNetworkError = true;
          break;
        }
        failedCount++;
      }
    }

    if (syncedIds.isNotEmpty) {
      _db.markRecordsSynced(syncedIds);
    }

    if (encounteredNetworkError && syncedCount == 0) {
      return SyncEngineResult(
        syncedCount: 0,
        failedCount: failedCount,
        isNoInternet: true,
        message: 'No internet connection. Please connect to Wi-Fi or mobile data.',
      );
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
