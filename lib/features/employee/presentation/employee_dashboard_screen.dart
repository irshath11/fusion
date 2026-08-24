import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../attendance/presentation/attendance_cubit.dart';
import '../../attendance/presentation/camera_capture_modal.dart';
import '../../attendance/presentation/site_name_dialog.dart';
import '../../attendance/presentation/break_type_dialog.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../sync/data/sync_engine.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';
import '../../timesheet/presentation/employee_timesheet_screen.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/theme/theme_selector_modal.dart';
import 'package:intl/intl.dart';

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
        _db.autoResolveExpiredCheckIns();
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
            title: Row(
              children: [
                Icon(Icons.wifi_off_rounded,
                    color: AppColors.warning, size: 24),
                const SizedBox(width: 10),
                const Expanded(
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
                  backgroundColor: AppTheme.currentColors.primaryFor(Theme.of(ctx).brightness),
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

    // Fast 10ms pre-check location status before showing camera or dialogs
    final status = await LocationService.quickStatusCheck();
    if (!status.isOk) {
      if (!mounted) return;
      context.read<AttendanceCubit>().emitLocationError(
            status.message,
            isPermissionDenied: status.isPermissionDenied,
          );
      return;
    }

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
    } else if (step == WorkflowStep.breakStart) {
      final breakReason = await BreakTypeDialog.show(context);
      if (breakReason == null || breakReason.isEmpty) return;
      if (!mounted) return;
      context.read<AttendanceCubit>().executeAttendanceStep(
            step: step,
            siteName: breakReason,
          );
    } else if (step == WorkflowStep.breakEnd) {
      final activeBreak = _db.getActiveBreakToday(empId);
      final bName = activeBreak?.siteName ?? 'Break';
      context.read<AttendanceCubit>().executeAttendanceStep(
            step: step,
            siteName: '$bName Ended',
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

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? errorMessage;
    bool obscureCurrentPass = true;
    bool obscureNewPass = true;
    bool obscureConfirmPass = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.lock_reset_rounded,
                    color: AppTheme.currentColors.primaryFor(Theme.of(context).brightness)),
                const SizedBox(width: 10),
                const Text('Change Password'),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: currentPassController,
                      obscureText: obscureCurrentPass,
                      decoration: InputDecoration(
                        labelText: 'Current / Temporary Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrentPass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrentPass = !obscureCurrentPass;
                            });
                          },
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please enter current password'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscureNewPass,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNewPass = !obscureNewPass;
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Please enter new password';
                        if (val.length < 6)
                          return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscureConfirmPass,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon:
                            const Icon(Icons.check_circle_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirmPass = !obscureConfirmPass;
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val != newPassController.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.currentColors.primaryFor(Theme.of(ctx).brightness),
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        final success =
                            await context.read<AuthCubit>().changePassword(
                                  currentPassword:
                                      currentPassController.text.trim(),
                                  newPassword: newPassController.text.trim(),
                                );

                        if (!mounted) return;
                        if (success) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage =
                                'Failed to update password. Please check your current password.';
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetCacheDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset Local Cache'),
          ],
        ),
        content: const Text(
          'This will purge all locally cached attendance records from this device.\n\n'
          'Use this if you deleted logs directly in Supabase or want to clear old offline data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _db.clearLocalAttendanceRecords();
              _refreshSyncCount();
              if (mounted) setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local attendance records cleared successfully.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Reset Cache'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _db.currentUser;
    final currentStep =
        _db.getWorkflowStepForEmployee(user?.id ?? user?.firebaseUid);
    final now = DateTime.now();

    final empId = user?.id ?? user?.firebaseUid;
    final userTodayRecords = _db.getTodayAttendanceRecords(empId);

    String workingTime = '00h 00m';
    final bool isOnBreak =
        _db.isEmployeeOnBreakToday(user?.id ?? user?.firebaseUid);
    final activeBreak =
        _db.getActiveBreakToday(user?.id ?? user?.firebaseUid);
    final Duration totalBreakToday =
        _db.getTodayBreakDuration(user?.id ?? user?.firebaseUid);

    if (userTodayRecords.isNotEmpty) {
      final checkInMatches = userTodayRecords
          .where((r) => r.workflowStep == WorkflowStep.officeCheckIn);
      if (checkInMatches.isNotEmpty) {
        final checkInTime = checkInMatches.first.eventTimestamp;
        final lastRecord = userTodayRecords.last;

        DateTime endTime;
        bool isAutoCompleted = false;

        if (lastRecord.workflowStep == WorkflowStep.officeCheckOut) {
          endTime = lastRecord.eventTimestamp;
          isAutoCompleted = lastRecord.address.contains('Auto Check-Out');
        } else if (now.difference(checkInTime) >= const Duration(hours: 24)) {
          endTime = checkInTime.add(const Duration(hours: 8));
          isAutoCompleted = true;
        } else if (lastRecord.workflowStep == WorkflowStep.siteCheckOut) {
          endTime = lastRecord.eventTimestamp;
        } else {
          // officeCheckIn, siteCheckIn, or break: Duty is currently active!
          endTime = now;
        }

        if (isAutoCompleted) {
          workingTime = '08h 00m (Auto)';
        } else {
          final grossDiff = endTime.isAfter(checkInTime)
              ? endTime.difference(checkInTime)
              : Duration.zero;
          final netDiff = grossDiff > totalBreakToday
              ? (grossDiff - totalBreakToday)
              : Duration.zero;
          final hrs = netDiff.inHours.toString().padLeft(2, '0');
          final mins = (netDiff.inMinutes % 60).toString().padLeft(2, '0');
          workingTime = '${hrs}h ${mins}m';
        }
      }
    }

    final offices = _db.getOffices();
    final assignedOffice =
        offices.isNotEmpty ? offices.first.name : 'Main Office';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.fullName ?? 'Field Employee'),
            Text(
              'Field Workforce Duty Portal',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: _isSyncing ? 'Syncing...' : 'Sync Offline Queue',
            onPressed: _isSyncing ? null : _manualSync,
          ),
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'My Timesheet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeTimesheetScreen(
                    employeeId: user?.id ?? user?.firebaseUid,
                    employeeName: user?.fullName,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'theme') {
                ThemeSelectorModal.show(context);
              } else if (value == 'reset_cache') {
                _showResetCacheDialog();
              } else if (value == 'password') {
                _showChangePasswordDialog();
              } else if (value == 'logout') {
                context.read<AuthCubit>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.palette_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Theme & Appearance'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset_cache',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Reset Local Cache'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Change Password'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            OfflineBanner(
              pendingCount: _pendingSyncCount,
              isSyncing: _isSyncing,
              onSyncPressed: _manualSync,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: BlocConsumer<AttendanceCubit, AttendanceState>(
                  listener: (context, state) {
                    if (state is AttendanceStepSuccess) {
                      _refreshSyncCount();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${state.record.workflowStep.displayName} Captured Successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (state is GeofenceViolationError) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.gpp_bad_rounded,
                                  color: AppColors.error),
                              SizedBox(width: 10),
                              Text('Geofence Violation'),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.message,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                  'Distance to target: ${state.distanceMeters.toStringAsFixed(1)} meters'),
                              Text(
                                  'Permitted Geofence Radius: ${state.allowedRadiusMeters.toStringAsFixed(1)} meters'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            )
                          ],
                        ),
                      );
                    } else if (state is LocationServicesDisabledError) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.location_off_rounded,
                                  color: AppColors.error, size: 28),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Location Required',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.message,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Attendance log cannot be saved without valid GPS location. Please turn on Location (GPS) services on your device and try logging again.',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          actions: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.location_on_rounded,
                                  size: 18),
                              label: Text(state.isPermissionDenied
                                  ? 'Open App Settings'
                                  : 'Turn On Location'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (state.isPermissionDenied) {
                                  Geolocator.openAppSettings();
                                } else {
                                  Geolocator.openLocationSettings();
                                }
                              },
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    } else if (state is AttendanceFailure) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.errorMessage),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final palette = AppTheme.currentColors;
                    final activePrimary = palette
                        .primaryFor(isDark ? Brightness.dark : Brightness.light);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Assignment Card
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? palette.surfaceDark
                                : palette.surfaceLight,
                            borderRadius:
                                BorderRadius.circular(palette.cardRadius),
                            border: Border.all(
                              color: isDark
                                  ? palette.cardBorderDark
                                  : palette.cardBorderLight,
                              width: isDark ? 1.2 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: palette.accentGlow,
                                blurRadius: isDark ? 8 : 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: activePrimary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(
                                            palette.cardRadius * 0.7),
                                      ),
                                      child: Icon(Icons.location_on_rounded,
                                          color: activePrimary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Assigned Office Station',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? palette.textSecondaryDark
                                                    : palette
                                                        .textSecondaryLight),
                                          ),
                                          Text(
                                            assignedOffice,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isDark
                                                    ? palette.textPrimaryDark
                                                    : palette
                                                        .textPrimaryLight),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(
                                      label:
                                          currentStep == WorkflowStep.completed
                                              ? 'Shift Complete'
                                              : (isOnBreak
                                                  ? '☕ On Break'
                                                  : 'On Duty'),
                                      color:
                                          currentStep == WorkflowStep.completed
                                              ? Colors.grey
                                              : (isOnBreak
                                                  ? Colors.amber.shade800
                                                  : palette.success),
                                    )
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildInfoMetric(
                                      context,
                                      'Duty Status',
                                      currentStep == WorkflowStep.completed
                                          ? 'Completed'
                                          : (isOnBreak
                                              ? '☕ On Break'
                                              : 'Active Duty'),
                                      color: activePrimary,
                                    ),
                                    _buildInfoMetric(
                                      context,
                                      'Net Working',
                                      workingTime,
                                      color: palette.success,
                                    ),
                                    _buildInfoMetric(
                                      context,
                                      'Pending Sync',
                                      '$_pendingSyncCount',
                                      color: _pendingSyncCount > 0
                                          ? palette.warning
                                          : (isDark
                                              ? palette.textPrimaryDark
                                              : palette.textPrimaryLight),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Banner / Button for Current Step
                        Text(
                          'Required Workflow Action',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: KeyedSubtree(
                            key: ValueKey('workflow_step_${currentStep}_${isOnBreak}'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (currentStep == WorkflowStep.breakEnd || isOnBreak) ...[
                                  Card(
                                    color: isDark ? const Color(0xFF2C2416) : Colors.amber.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isDark ? Colors.amber.shade700 : Colors.amber.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade700.withValues(alpha: 0.18),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(Icons.coffee_rounded,
                                                    color: Colors.amber.shade800, size: 24),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Currently On Break',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                                      ),
                                                    ),
                                                    Text(
                                                      activeBreak != null
                                                          ? '${activeBreak.siteName ?? "Break"} • Started ${DateFormat("hh:mm a").format(activeBreak.eventTimestamp)}'
                                                          : 'Break In Progress',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Break time is automatically excluded from your work hour calculation. Tap below to resume duty.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          AppButton(
                                            text: state is AttendanceProcessing
                                                ? 'Acquiring GPS & Resuming...'
                                                : 'End Break & Resume Work',
                                            isLoading: state is AttendanceProcessing,
                                            icon: Icons.play_arrow_rounded,
                                            onPressed: () =>
                                                _handleAttendanceStep(WorkflowStep.breakEnd),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (currentStep ==
                                    WorkflowStep.officeCheckIn) ...[
                                  Card(
                                    color: isDark
                                        ? palette.surfaceDark
                                        : activePrimary.withValues(alpha: 0.06),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.business_rounded,
                                                  color: activePrimary),
                                              const SizedBox(width: 10),
                                              const Expanded(
                                                child: Text(
                                                  'Start Work Day - Office Check-In',
                                                  style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Check in to start your workday. Live selfie photo & GPS location required.',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors
                                                    .textSecondaryLight),
                                          ),
                                          const SizedBox(height: 16),
                                          AppButton(
                                            text: state is AttendanceProcessing
                                                ? 'Acquiring GPS & Logging...'
                                                : 'Execute Office Check-In',
                                            isLoading:
                                                state is AttendanceProcessing,
                                            icon: Icons.camera_alt_rounded,
                                            onPressed: () =>
                                                _handleAttendanceStep(
                                                    WorkflowStep.officeCheckIn),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (currentStep ==
                                    WorkflowStep.siteCheckOut) ...[
                                  Card(
                                    color: isDark
                                        ? AppColors.surfaceDark
                                        : Colors.orange.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                          color: isDark
                                              ? AppColors.warning
                                              : Colors.orange.shade300),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                  Icons.location_on_rounded,
                                                  color: Colors.orange),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Currently at: ${_db.getActiveSiteNameToday(user?.id ?? user?.firebaseUid) ?? "Work Site"}',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? AppColors
                                                            .textPrimaryDark
                                                        : Colors
                                                            .orange.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Complete current site work session to log site check-out time.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                      .textSecondaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 6,
                                                child: AppButton(
                                                  text: state is AttendanceProcessing
                                                      ? 'Logging...'
                                                      : 'Check-Out Site',
                                                  isLoading:
                                                      state is AttendanceProcessing,
                                                  icon: Icons.logout_rounded,
                                                  onPressed: () =>
                                                      _handleAttendanceStep(
                                                          WorkflowStep.siteCheckOut),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 5,
                                                child: OutlinedButton.icon(
                                                  onPressed: state is AttendanceProcessing
                                                      ? null
                                                      : () => _handleAttendanceStep(
                                                          WorkflowStep.breakStart),
                                                  icon: const Icon(Icons.coffee_rounded, size: 18),
                                                  label: const FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      'Take Break',
                                                      style: TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.amber.shade800,
                                                    side: BorderSide(color: Colors.amber.shade600),
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (currentStep ==
                                    WorkflowStep.siteCheckIn) ...[
                                  Card(
                                    color: isDark
                                        ? palette.surfaceDark
                                        : activePrimary.withValues(alpha: 0.06),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Work Day in Progress',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Check in to your next job site, take a break, or perform Final Office Check-Out.',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors
                                                    .textSecondaryLight),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 6,
                                                child: AppButton(
                                                  text: state
                                                          is AttendanceProcessing
                                                      ? 'Logging...'
                                                      : 'Check-In to Site',
                                                  isLoading: state
                                                      is AttendanceProcessing,
                                                  icon: Icons
                                                      .add_location_alt_rounded,
                                                  onPressed: () =>
                                                      _handleAttendanceStep(
                                                          WorkflowStep
                                                              .siteCheckIn),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 5,
                                                child: OutlinedButton.icon(
                                                  onPressed: state
                                                          is AttendanceProcessing
                                                      ? null
                                                      : () =>
                                                          _handleAttendanceStep(
                                                              WorkflowStep
                                                                  .officeCheckOut),
                                                  icon: state
                                                          is AttendanceProcessing
                                                      ? SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors
                                                                .red.shade700,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons
                                                              .no_meeting_room_rounded,
                                                          size: 18),
                                                  label: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      state is AttendanceProcessing
                                                          ? 'Processing...'
                                                          : 'Final Day End',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.red.shade700,
                                                    side: BorderSide(
                                                        color: Colors
                                                            .red.shade400),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 14),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: state is AttendanceProcessing
                                                ? null
                                                : () => _handleAttendanceStep(
                                                    WorkflowStep.breakStart),
                                            icon: const Icon(Icons.coffee_rounded, size: 18),
                                            label: const Text(
                                              'Take a Break',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.amber.shade800,
                                              side: BorderSide(color: Colors.amber.shade600),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              minimumSize: const Size(double.infinity, 44),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            color: AppColors.success, size: 28),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Daily attendance workflow fully completed. Thank you!',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        // Dynamic Workday Stepper Timeline Log
                        Text(
                          'Today\'s Attendance Timeline',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        if (userTodayRecords.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                    'No attendance activity logged for today yet.',
                                    style: TextStyle(
                                        color: AppColors.textSecondaryLight,
                                        fontSize: 13)),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: userTodayRecords.length,
                            itemBuilder: (context, index) {
                              final record = userTodayRecords[index];
                              final formattedTime = DateFormat('hh:mm a')
                                  .format(record.eventTimestamp);
                              final hasSite = (record.workflowStep ==
                                          WorkflowStep.siteCheckIn ||
                                      record.workflowStep ==
                                          WorkflowStep.siteCheckOut) &&
                                  record.siteName != null &&
                                  record.siteName!.trim().isNotEmpty;
                              
                              final isBreakStart = record.workflowStep == WorkflowStep.breakStart;
                              final isBreakEnd = record.workflowStep == WorkflowStep.breakEnd;
                              final isBreak = isBreakStart || isBreakEnd;

                              final Color stepColor = isBreak
                                  ? Colors.amber.shade700
                                  : AppColors.success;
                              final IconData stepIcon = isBreakStart
                                  ? Icons.coffee_rounded
                                  : (isBreakEnd
                                      ? Icons.play_arrow_rounded
                                      : Icons.check);

                              String stepTitle;
                              if (isBreakStart) {
                                final sName = record.siteName?.trim();
                                if (sName != null && sName.isNotEmpty && sName != 'Break') {
                                  stepTitle = '☕ Break Started ($sName)';
                                } else {
                                  stepTitle = '☕ Break Started';
                                }
                              } else if (isBreakEnd) {
                                stepTitle = '🟢 Break Ended (Resumed Work)';
                              } else if (hasSite) {
                                stepTitle = '${record.workflowStep.displayName} (${record.siteName!.trim()})';
                              } else {
                                stepTitle = record.workflowStep.displayName;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: stepColor.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: stepColor,
                                      child: Icon(stepIcon,
                                          size: 14, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  stepTitle,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isBreak
                                                          ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                                                          : null),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isBreak
                                                      ? Colors.amber.shade700.withValues(alpha: 0.15)
                                                      : activePrimary.withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  formattedTime,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isBreak
                                                        ? Colors.amber.shade800
                                                        : Colors.greenAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            (record.address.isNotEmpty &&
                                                    !record.address.contains(
                                                        'Live Field Location (GPS Active)') &&
                                                    !record.address.contains(
                                                        'Live Field Operations (GPS Active)'))
                                                ? record.address
                                                : '${LocationService.resolvePlaceName(record.latitude, record.longitude)} (GPS: ${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                      .textSecondaryLight,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoMetric(BuildContext context, String title, String value,
      {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color ??
                  (isDark ? palette.textPrimaryDark : palette.textPrimaryLight),
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? palette.textSecondaryDark
                  : palette.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
