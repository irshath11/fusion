import 'dart:async';
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../attendance/domain/attendance_record.dart';

class SyncEngineResult {
  final int syncedCount;
  final int failedCount;
  final String message;

  SyncEngineResult({
    required this.syncedCount,
    required this.failedCount,
    required this.message,
  });
}

class SyncEngine {
  final LocalDatabaseService _db = LocalDatabaseService();
  final SupabaseService _supabase = SupabaseService();

  /// Trigger sync manually or via background network monitor
  Future<SyncEngineResult> performSync() async {
    List<AttendanceRecord> pendingRecords = _db.getPendingSyncRecords();

    if (pendingRecords.isEmpty) {
      return SyncEngineResult(
        syncedCount: 0,
        failedCount: 0,
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

      if (success || !_supabase.isInitialized) {
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
      message: 'Successfully synchronized $syncedCount attendance entries & photos to Supabase.',
    );
  }
}
