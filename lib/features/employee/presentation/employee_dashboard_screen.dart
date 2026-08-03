import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../attendance/presentation/attendance_cubit.dart';
import '../../attendance/presentation/camera_capture_modal.dart';
import '../../attendance/presentation/site_name_dialog.dart';
import '../../../core/services/supabase_service.dart';
import '../../sync/data/sync_engine.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';

import 'views/app_shell_view.dart';
import 'views/home_dashboard_view.dart';
import 'views/employee_profile_view.dart';
import '../../timesheet/presentation/views/activity_timeline_view.dart';
import '../../attendance/presentation/views/attendance_hub_view.dart';
import '../../admin/presentation/views/sites_hub_view.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final SyncEngine _syncEngine = SyncEngine();

  int _pendingSyncCount = 0;
  bool _isSyncing = false;
  Timer? _workingTimeTimer;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _refreshSyncCount();
    _startWorkingTimeTimer();
    _startAutoSyncListener();
    _syncCloudData();
  }

  Future<void> _syncCloudData() async {
    try {
      await SupabaseService().syncCloudDataToLocal();
      await _syncEngine.performSync();
      if (mounted) {
        _refreshSyncCount();
        setState(() {});
      }
    } catch (_) {}
  }

  void _startWorkingTimeTimer() {
    _workingTimeTimer?.cancel();
    _workingTimeTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _startAutoSyncListener() {
    _autoSyncTimer?.cancel();
    // Check every 5 seconds if internet connectivity has been restored for pending offline records
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isSyncing) return;

      final pendingCount = _db.getPendingSyncRecords().length;
      if (pendingCount > 0) {
        final hasNet = await _syncEngine.hasInternetConnection();
        if (hasNet && mounted && !_isSyncing) {
          await _autoSyncOnInternetRestored();
        }
      }
    });
  }

  Future<void> _autoSyncOnInternetRestored() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final result = await _syncEngine.performSync();
      _refreshSyncCount();

      if (!mounted) return;

      if (result.syncedCount > 0) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.cloud_done_rounded,
                    color: AppColors.success, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Records Synced Successfully!',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.syncedCount} offline attendance record(s) were automatically synced to the cloud.',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Internet connection was restored and your data is now securely backed up in the cloud.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Awesome!'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void dispose() {
    _workingTimeTimer?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  void _refreshSyncCount() {
    final user = _db.currentUser;
    setState(() {
      _pendingSyncCount =
          _db.getPendingSyncRecords(user?.id ?? user?.firebaseUid).length;
    });
  }

  Future<void> _manualSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncEngine.performSync();
      _refreshSyncCount();

      if (!mounted) return;

      if (result.isNoInternet) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.wifi_off_rounded,
                    color: AppColors.warning, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pending Sync (Offline Mode)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pendingSyncCount > 0
                        ? '$_pendingSyncCount record(s) pending sync to cloud database.'
                        : 'No internet connection detected.',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All attendance entries are saved safely on your phone. Once you connect to Wi-Fi or mobile data, your records will be uploaded automatically.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _manualSync();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Sync'),
              ),
            ],
          ),
        );
        return;
      }

      if (result.syncedCount > 0) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.cloud_done_rounded,
                    color: AppColors.success, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Records Synced Successfully!',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.syncedCount} attendance record(s) uploaded successfully to the cloud database.',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your attendance data is now securely stored in the cloud and visible across all manager and admin devices.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Great!'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All Records Synced',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Text(
                'All your attendance records are already up to date and saved in the cloud database.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _handleAttendanceStep(WorkflowStep step,
      {String? activeSiteName}) async {
    final user = _db.currentUser;
    final empId = user?.id ?? user?.firebaseUid;

    if (step == WorkflowStep.officeCheckIn) {
      _openCameraModal(step);
    } else if (step == WorkflowStep.siteCheckIn) {
      final siteName = await SiteNameDialog.show(context);
      if (siteName == null || siteName.isEmpty) return;

      final isFirstSite = _db.isFirstSiteCheckInToday(empId);
      if (isFirstSite) {
        _openCameraModal(step, siteName: siteName);
      } else {
        context.read<AttendanceCubit>().executeAttendanceStep(
              step: step,
              siteName: siteName,
            );
      }
    } else if (step == WorkflowStep.siteCheckOut) {
      final sName =
          activeSiteName ?? _db.getActiveSiteNameToday(empId) ?? 'Site';
      context.read<AttendanceCubit>().executeAttendanceStep(
            step: step,
            siteName: sName,
          );
    } else if (step == WorkflowStep.officeCheckOut) {
      _openCameraModal(step);
    }
  }

  void _openCameraModal(WorkflowStep step, {String? siteName}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CameraCaptureModal(
        stepName: step == WorkflowStep.siteCheckIn && siteName != null
            ? 'First Site Check-In ($siteName)'
            : step.displayName,
        onPhotoCaptured: (cameraResult) {
          context.read<AttendanceCubit>().executeAttendanceStep(
                step: step,
                cameraResult: cameraResult,
                siteName: siteName,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _db.currentUser;
    final currentStep =
        _db.getWorkflowStepForEmployee(user?.id ?? user?.firebaseUid);
    final empId = user?.id ?? user?.firebaseUid;
    final isCheckedIn = currentStep == WorkflowStep.officeCheckOut ||
        currentStep == WorkflowStep.siteCheckOut;
    final activeSiteName = _db.getActiveSiteNameToday(empId);

    return BlocListener<AttendanceCubit, AttendanceState>(
      listener: (context, state) {
        if (state is AttendanceStepSuccess) {
          _refreshSyncCount();

          final isSynced = state.record.syncStatus == SyncStatus.synced ||
              state.syncResult.syncedCount > 0;

          if (isSynced) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.cloud_done_rounded,
                        color: AppColors.success, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recorded & Synced Successfully!',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your ${state.record.workflowStep.displayName} was recorded and uploaded to the cloud database in real-time.',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your attendance is now securely stored in the cloud and visible across all manager and admin devices.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Awesome!'),
                  ),
                ],
              ),
            );
          } else {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        color: AppColors.warning, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Attendance Recorded (Offline)',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your ${state.record.workflowStep.displayName} is saved safely on your phone.',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'It will automatically upload to the cloud database once an internet connection is restored.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else if (state is AttendanceFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (state is GeofenceViolationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${state.message} (Distance: ${state.distanceMeters.toStringAsFixed(0)}m)'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      },
      child: BlocBuilder<AttendanceCubit, AttendanceState>(
        builder: (context, state) {
          final isLoading = state is AttendanceProcessing;

          return AppShellView(
            homeView: HomeDashboardView(
              userName: user?.fullName ?? 'Employee',
              userRole: user?.role.displayName ?? 'Staff',
              isCheckedIn: isCheckedIn,
              isLoading: isLoading,
              activeSiteName: activeSiteName,
              pendingSyncCount: _pendingSyncCount,
              onPunchPressed: () => _handleAttendanceStep(currentStep,
                  activeSiteName: activeSiteName),
              onSiteCheckInPressed: isCheckedIn
                  ? () => _handleAttendanceStep(WorkflowStep.siteCheckIn)
                  : null,
              isFirstSiteCheckIn: _db.isFirstSiteCheckInToday(empId),
              onSyncPressed: _manualSync,
            ),
            activityView: const ActivityTimelineView(),
            attendanceView: const AttendanceHubView(),
            sitesView: const SitesHubView(),
            profileView: EmployeeProfileView(
              userName: user?.fullName ?? 'Employee',
              userRole: user?.role.displayName ?? 'Staff',
              onLogoutPressed: () {
                context.read<AuthCubit>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
