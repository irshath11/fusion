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

  @override
  void initState() {
    super.initState();
    _refreshSyncCount();
    _startWorkingTimeTimer();
    _syncCloudData();
  }

  Future<void> _syncCloudData() async {
    try {
      await SupabaseService().syncCloudDataToLocal();
      if (mounted) setState(() {});
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

  @override
  void dispose() {
    _workingTimeTimer?.cancel();
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
                    color: AppColors.warning, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No Internet Connection',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Text(
                'Unable to synchronize attendance records. Please connect to a Wi-Fi or mobile data network and try again.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actionsOverflowDirection: VerticalDirection.down,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.syncedCount > 0 ? AppColors.success : AppColors.info,
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Successfully recorded ${state.record.workflowStep.displayName}'),
              backgroundColor: AppColors.success,
            ),
          );
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
