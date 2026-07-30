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

  /// Check active internet connectivity via DNS lookup
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
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
      String? publicPhotoUrl;

      if (record.photoBase64.isNotEmpty) {
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
    }

    if (syncedIds.isNotEmpty) {
      _db.markRecordsSynced(syncedIds);
    }

    return SyncEngineResult(
      syncedCount: syncedCount,
      failedCount: failedCount,
      isNoInternet: false,
      message: 'Successfully synchronized $syncedCount attendance entries & photos to Supabase.',
    );
  }
}
