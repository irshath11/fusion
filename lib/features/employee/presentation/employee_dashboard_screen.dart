import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/timesheet_calculator.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/animated_widgets.dart';
import '../../attendance/presentation/attendance_cubit.dart';
import '../../attendance/presentation/camera_capture_modal.dart';
import '../../attendance/presentation/site_name_dialog.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../auth/domain/user_entity.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../sync/data/sync_engine.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';
import '../../timesheet/presentation/employee_timesheet_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final SyncEngine _syncEngine = SyncEngine();

  int _selectedTabIndex = 0;
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
    _workingTimeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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

    setState(() => _isSyncing = true);

    try {
      final result = await _syncEngine.performSync();
      _refreshSyncCount();

      if (!mounted) return;

      if (result.isNoInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No internet connection. Records remain securely saved locally.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message,
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor:
              result.syncedCount > 0 ? AppColors.success : AppColors.info,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _handleAttendanceStep(WorkflowStep step,
      {String? activeSiteName}) async {
    final user = _db.currentUser;
    final empId = user?.id ?? user?.firebaseUid;

    // Pre-check location services status
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
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Change Password',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                    TextFormField(
                      controller: currentPassController,
                      obscureText: obscureCurrentPass,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrentPass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setDialogState(
                              () => obscureCurrentPass = !obscureCurrentPass),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscureNewPass,
                      decoration: InputDecoration(
                        labelText: 'New Password (min 6 chars)',
                        suffixIcon: IconButton(
                          icon: Icon(obscureNewPass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setDialogState(
                              () => obscureNewPass = !obscureNewPass),
                        ),
                      ),
                      validator: (v) =>
                          v != null && v.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscureConfirmPass,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirmPass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setDialogState(
                              () => obscureConfirmPass = !obscureConfirmPass),
                        ),
                      ),
                      validator: (v) => v != newPassController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSecondaryLight)),
              ),
              AppButton(
                text: 'Update Password',
                isLoading: isLoading,
                width: 150,
                height: 42,
                borderRadius: 10,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() {
                    isLoading = true;
                    errorMessage = null;
                  });

                  final success =
                      await context.read<AuthCubit>().changePassword(
                            currentPassword: currentPassController.text.trim(),
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
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _db.currentUser;
    final empId = user?.id ?? user?.firebaseUid;

    final currentStep = _db.getWorkflowStepForEmployee(empId);
    final userTodayRecords = _db.getTodayAttendanceRecords(empId);

    final now = DateTime.now();

    // Working time calculation
    String workingTime = '00h 00m';
    double progressPercent = 0.0;
    bool isAutoCompleted = false;

    if (userTodayRecords.isNotEmpty) {
      final checkInMatches = userTodayRecords
          .where((r) => r.workflowStep == WorkflowStep.officeCheckIn);
      if (checkInMatches.isNotEmpty) {
        final checkInTime = checkInMatches.first.eventTimestamp;
        final lastRecord = userTodayRecords.last;

        DateTime endTime;

        if (lastRecord.workflowStep == WorkflowStep.officeCheckOut) {
          endTime = lastRecord.eventTimestamp;
          isAutoCompleted = lastRecord.address.contains('Auto Check-Out');
        } else if (now.difference(checkInTime) >= const Duration(hours: 24)) {
          endTime = checkInTime.add(const Duration(hours: 8));
          isAutoCompleted = true;
        } else if (lastRecord.workflowStep == WorkflowStep.siteCheckOut) {
          endTime = lastRecord.eventTimestamp;
        } else {
          // duty is currently active
          endTime = now;
        }

        if (isAutoCompleted) {
          workingTime = '08h 00m (Auto)';
          progressPercent = 1.0;
        } else {
          final diff = endTime.isAfter(checkInTime)
              ? endTime.difference(checkInTime)
              : Duration.zero;
          final hrs = diff.inHours.toString().padLeft(2, '0');
          final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
          workingTime = '${hrs}h ${mins}m';
          progressPercent = (diff.inMinutes / (8 * 60)).clamp(0.0, 1.0);
        }
      }
    }

    final offices = _db.getOffices();
    final assignedOffice = offices.isNotEmpty ? offices.first.name : 'Main HQ';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.fullName ?? 'Field Employee',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _db.organization?.name ?? 'Enterprise Workforce',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          // Cloud Sync Action
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Icons.cloud_sync_rounded,
                    color: _pendingSyncCount > 0
                        ? AppColors.warning
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
            tooltip: _isSyncing ? 'Syncing...' : 'Sync Cloud Queue',
            onPressed: _isSyncing ? null : _manualSync,
          ),
          // Security / Password
          IconButton(
            icon: const Icon(Icons.lock_reset_rounded),
            tooltip: 'Change Password',
            onPressed: _showChangePasswordDialog,
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () {
              context.read<AuthCubit>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                (route) => false,
              );
            },
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
              child: BlocConsumer<AttendanceCubit, AttendanceState>(
                listener: (context, state) {
                  if (state is AttendanceStepSuccess) {
                    _refreshSyncCount();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${state.record.workflowStep.displayName} Verified & Logged!',
                                style:
                                    GoogleFonts.plusJakartaSans(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } else if (state is GeofenceViolationError) {
                    _showGeofenceDialog(state);
                  } else if (state is LocationServicesDisabledError) {
                    _showLocationErrorDialog(state);
                  } else if (state is AttendanceFailure) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.errorMessage,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  return IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildDutyDeskPage(
                        isDark: isDark,
                        currentStep: currentStep,
                        workingTime: workingTime,
                        progressPercent: progressPercent,
                        assignedOffice: assignedOffice,
                        userTodayRecords: userTodayRecords,
                        isProcessing: state is AttendanceProcessing,
                      ),
                      _buildFieldSitesPage(
                        isDark: isDark,
                        empId: empId,
                        userTodayRecords: userTodayRecords,
                      ),
                      _buildTimesheetsPage(
                        isDark: isDark,
                        empId: empId,
                        userFullName: user?.fullName,
                      ),
                      _buildProfileSecurityPage(
                        isDark: isDark,
                        user: user,
                        assignedOffice: assignedOffice,
                      ),
                    ],
                  );
                },
              ),
            ),
            // Multi-Page Sliding Bottom Navigation Bar
            SegmentedPillNavBar(
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) =>
                  setState(() => _selectedTabIndex = index),
              items: const [
                SegmentedTabItem(
                  label: 'Duty Desk',
                  icon: Icons.fingerprint_rounded,
                ),
                SegmentedTabItem(
                  label: 'Field Sites',
                  icon: Icons.location_on_outlined,
                  activeIcon: Icons.location_on_rounded,
                ),
                SegmentedTabItem(
                  label: 'Timesheets',
                  icon: Icons.date_range_outlined,
                  activeIcon: Icons.date_range_rounded,
                ),
                SegmentedTabItem(
                  label: 'Digital ID',
                  icon: Icons.badge_outlined,
                  activeIcon: Icons.badge_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAGE 1: DUTY DESK
  // ==========================================
  Widget _buildDutyDeskPage({
    required bool isDark,
    required WorkflowStep currentStep,
    required String workingTime,
    required double progressPercent,
    required String assignedOffice,
    required List<AttendanceRecord> userTodayRecords,
    required bool isProcessing,
  }) {
    final now = DateTime.now();
    final timeFormat = DateFormat('hh:mm:ss a');
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy');

    final bool isDutyActive = currentStep == WorkflowStep.siteCheckIn ||
        currentStep == WorkflowStep.siteCheckOut;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Clock & Presence Status Card
          GlassSurfaceCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 22,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(now),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          timeFormat.format(now),
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(
                      label: currentStep == WorkflowStep.completed
                          ? 'Shift Done'
                          : (isDutyActive ? 'On Active Duty' : 'Checked Out'),
                      color: currentStep == WorkflowStep.completed
                          ? AppColors.info
                          : (isDutyActive
                              ? AppColors.success
                              : AppColors.textTertiaryDark),
                      isLive: isDutyActive,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 14),

                // Duty Duration Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Duty Hours Today:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      workingTime,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Interactive Workflow Step Visualizer
          _buildWorkflowTimeline(isDark, currentStep),
          const SizedBox(height: 20),

          // Large Ergonomic Action CTA Button
          if (isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _buildMainActionCTA(currentStep),

          const SizedBox(height: 18),

          // Assigned Office Telemetry Card
          GlassSurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.domain_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Base Office',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        assignedOffice,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const StatusBadge(
                  label: 'GPS Geofenced',
                  color: AppColors.primary,
                  fontSize: 10.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowTimeline(bool isDark, WorkflowStep currentStep) {
    final steps = [
      WorkflowStep.officeCheckIn,
      WorkflowStep.siteCheckIn,
      WorkflowStep.siteCheckOut,
      WorkflowStep.officeCheckOut,
    ];

    return GlassSurfaceCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duty Step Sequence',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final isCurrent = currentStep == step;
              final isPassed = _isStepPassed(currentStep, step);

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPassed
                                  ? AppColors.success
                                  : (isCurrent
                                      ? AppColors.primary
                                      : (isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFE2E8F0))),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: isPassed
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : Text(
                                      '${i + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isCurrent
                                            ? Colors.white
                                            : (isDark
                                                ? AppColors.textTertiaryDark
                                                : AppColors.textSecondaryLight),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.displayName.replaceAll(' ', '\n'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent
                                  ? (isDark
                                      ? AppColors.primaryLight
                                      : AppColors.primary)
                                  : (isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textSecondaryLight),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 14,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 24),
                        color: isPassed
                            ? AppColors.success
                            : (isDark
                                ? AppColors.cardBorderDark
                                : AppColors.cardBorderLight),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  bool _isStepPassed(WorkflowStep current, WorkflowStep target) {
    if (current == WorkflowStep.completed) return true;
    final order = [
      WorkflowStep.officeCheckIn,
      WorkflowStep.siteCheckIn,
      WorkflowStep.siteCheckOut,
      WorkflowStep.officeCheckOut,
    ];
    return order.indexOf(target) < order.indexOf(current);
  }

  Widget _buildMainActionCTA(WorkflowStep currentStep) {
    if (currentStep == WorkflowStep.completed) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 22),
            const SizedBox(width: 10),
            Text(
              "Today's Shift Completed",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    String ctaText = 'Punch In (Office Check-In)';
    IconData ctaIcon = Icons.camera_alt_rounded;
    AppButtonVariant variant = AppButtonVariant.primary;

    if (currentStep == WorkflowStep.siteCheckIn) {
      ctaText = 'Site Check-In';
      ctaIcon = Icons.location_city_rounded;
      variant = AppButtonVariant.primary;
    } else if (currentStep == WorkflowStep.siteCheckOut) {
      ctaText = 'Site Check-Out';
      ctaIcon = Icons.exit_to_app_rounded;
      variant = AppButtonVariant.secondary;
    } else if (currentStep == WorkflowStep.officeCheckOut) {
      ctaText = 'Final Office Check-Out';
      ctaIcon = Icons.logout_rounded;
      variant = AppButtonVariant.danger;
    }

    return Column(
      children: [
        AppButton(
          text: ctaText,
          icon: ctaIcon,
          variant: variant,
          height: 56,
          borderRadius: 16,
          onPressed: () => _handleAttendanceStep(currentStep),
        ),
        if (currentStep == WorkflowStep.siteCheckIn) ...[
          const SizedBox(height: 10),
          AppButton(
            text: 'Skip to Final Office Check-Out',
            variant: AppButtonVariant.outline,
            height: 46,
            borderRadius: 12,
            icon: Icons.logout_rounded,
            onPressed: () => _handleAttendanceStep(WorkflowStep.officeCheckOut),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // PAGE 2: FIELD SITES TRACKER
  // ==========================================
  Widget _buildFieldSitesPage({
    required bool isDark,
    required String? empId,
    required List<AttendanceRecord> userTodayRecords,
  }) {
    final activeSite = _db.getActiveSiteNameToday(empId);
    final isCheckedInSite = activeSite != null;

    final siteRecords = userTodayRecords
        .where((r) =>
            r.workflowStep == WorkflowStep.siteCheckIn ||
            r.workflowStep == WorkflowStep.siteCheckOut)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active Site Status Card
          GlassSurfaceCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Work Site',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    StatusBadge(
                      label: isCheckedInSite ? 'Active On-Site' : 'Not On-Site',
                      color: isCheckedInSite
                          ? AppColors.success
                          : AppColors.textTertiaryDark,
                      isLive: isCheckedInSite,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  activeSite ?? 'No Active Site Visit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (isCheckedInSite) ...[
                  const SizedBox(height: 14),
                  AppButton(
                    text: 'Complete Site Visit (Check-Out)',
                    variant: AppButtonVariant.secondary,
                    height: 44,
                    borderRadius: 12,
                    icon: Icons.check_rounded,
                    onPressed: () => _handleAttendanceStep(
                      WorkflowStep.siteCheckOut,
                      activeSiteName: activeSite,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Today's Site Visits Log
          Text(
            "Today's Site Logs",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 10),
          if (siteRecords.isEmpty)
            GlassSurfaceCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.location_city_outlined,
                        size: 36,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textSecondaryLight),
                    const SizedBox(height: 8),
                    Text(
                      'No site visits recorded today.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...siteRecords.map((r) {
              final timeStr = DateFormat('hh:mm a').format(r.eventTimestamp);
              final isCheckIn = r.workflowStep == WorkflowStep.siteCheckIn;

              return GlassSurfaceCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                borderRadius: 14,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isCheckIn
                                ? AppColors.primary
                                : AppColors.secondary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                        size: 18,
                        color:
                            isCheckIn ? AppColors.primary : AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TimesheetCalculator.resolveSiteName(r),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            r.workflowStep.displayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      timeStr,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // PAGE 3: TIMESHEETS EMBEDDED
  // ==========================================
  Widget _buildTimesheetsPage({
    required bool isDark,
    required String? empId,
    required String? userFullName,
  }) {
    return EmployeeTimesheetScreen(
      employeeId: empId,
      employeeName: userFullName,
    );
  }

  // ==========================================
  // PAGE 4: DIGITAL ID & PROFILE
  // ==========================================
  Widget _buildProfileSecurityPage({
    required bool isDark,
    required UserEntity? user,
    required String assignedOffice,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Digital Corporate ID Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.darkCardGradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.35),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EMPLOYEE DIGITAL PASS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Icon(Icons.nfc_rounded,
                        color: AppColors.primaryLight, size: 20),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  user?.fullName ?? 'Field Employee',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  user?.email ?? 'employee@company.com',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIdField('ROLE', user?.role?.displayName ?? 'Employee'),
                    _buildIdField('OFFICE', assignedOffice),
                    _buildIdField('STATUS', 'ACTIVE'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Security Settings Card
          GlassSurfaceCard(
            padding: const EdgeInsets.all(18),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security & Authentication',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _showChangePasswordDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.password_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Portal Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Update your master login passcode',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.phonelink_lock_rounded,
                            color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hardware Device Binding',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bound & Verified to this handset',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(
                        label: 'Bound',
                        color: AppColors.success,
                        fontSize: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showGeofenceDialog(GeofenceViolationError state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text(
              'Geofence Boundary',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
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
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Distance to Office: ${state.distanceMeters.toStringAsFixed(1)} m',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
            ),
            Text(
              'Allowed Geofence Radius: ${state.allowedRadiusMeters.toStringAsFixed(1)} m',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog(LocationServicesDisabledError state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded,
                color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text(
              'Location Required',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          state.message,
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
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
}
