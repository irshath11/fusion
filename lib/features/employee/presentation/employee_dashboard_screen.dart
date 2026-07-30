import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../attendance/presentation/attendance_cubit.dart';
import '../../attendance/presentation/camera_capture_modal.dart';
import '../../sync/data/sync_engine.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/login_screen.dart';
import 'package:intl/intl.dart';
import '../../attendance/domain/attendance_record.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshSyncCount();
  }

  void _refreshSyncCount() {
    final user = _db.currentUser;
    setState(() {
      _pendingSyncCount =
          _db.getPendingSyncRecords(user?.id ?? user?.firebaseUid).length;
    });
  }

  Future<void> _manualSync() async {
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
              Icon(Icons.wifi_off_rounded, color: AppColors.warning),
              SizedBox(width: 10),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'Unable to synchronize attendance records. Please connect to a Wi-Fi or mobile data network and try again.',
            style: TextStyle(fontSize: 14),
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
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _manualSync();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
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
  }

  void _openCameraModal(WorkflowStep step) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CameraCaptureModal(
        stepName: step.displayName,
        onPhotoCaptured: (cameraResult) {
          context.read<AttendanceCubit>().executeAttendanceStep(
                step: step,
                cameraResult: cameraResult,
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Change Password'),
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
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current / Temporary Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please enter current password'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_rounded),
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
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.check_circle_outline_rounded),
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
                  backgroundColor: AppColors.primary,
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

  @override
  Widget build(BuildContext context) {
    final user = _db.currentUser;
    final currentStep =
        _db.getWorkflowStepForEmployee(user?.id ?? user?.firebaseUid);
    final allRecords = _db.getAttendanceRecords();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final userTodayRecords = allRecords.where((r) {
      final isUserMatch = (user != null &&
          (r.employeeId == user.id ||
              r.employeeId == user.firebaseUid ||
              r.employeeName == user.fullName));
      final rDate = DateTime(
          r.eventTimestamp.year, r.eventTimestamp.month, r.eventTimestamp.day);
      return isUserMatch && rDate.isAtSameMomentAs(today);
    }).toList();

    String workingTime = '00h 00m';
    final checkInMatches = userTodayRecords
        .where((r) => r.workflowStep == WorkflowStep.officeCheckIn);
    if (checkInMatches.isNotEmpty) {
      final checkInTime = checkInMatches.first.eventTimestamp;
      final checkOutMatches = userTodayRecords
          .where((r) => r.workflowStep == WorkflowStep.officeCheckOut);
      final endTime = checkOutMatches.isNotEmpty
          ? checkOutMatches.first.eventTimestamp
          : now;
      final diff = endTime.difference(checkInTime);
      final hrs = diff.inHours.toString().padLeft(2, '0');
      final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
      workingTime = '${hrs}h ${mins}m';
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
            const Text(
              'Field Workforce Duty Portal',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_reset_rounded),
            tooltip: 'Change Password',
            onPressed: _showChangePasswordDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Offline Queue',
            onPressed: _manualSync,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
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
                    }
                  },
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Assignment Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                          Icons.location_on_rounded,
                                          color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Assigned Office Station',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors
                                                    .textSecondaryLight),
                                          ),
                                          Text(
                                            assignedOffice,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(
                                      label:
                                          currentStep == WorkflowStep.completed
                                              ? 'Shift Complete'
                                              : 'On Duty',
                                      color:
                                          currentStep == WorkflowStep.completed
                                              ? Colors.grey
                                              : AppColors.success,
                                    )
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildInfoMetric(
                                      'Duty Step',
                                      currentStep == WorkflowStep.completed
                                          ? '4/4'
                                          : '${currentStep.index + 1}/4',
                                    ),
                                    _buildInfoMetric(
                                        'Working Time', workingTime),
                                    _buildInfoMetric(
                                        'Pending Sync', '$_pendingSyncCount'),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Banner / Button for Current Step
                        Text(
                          'Required Workflow Step',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        if (currentStep != WorkflowStep.completed) ...[
                          Card(
                            color: AppColors.primary.withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.touch_app_rounded,
                                          color: AppColors.primary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          currentStep.displayName,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Live camera frame & GPS location will be captured & validated against assigned geofence radius.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondaryLight),
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    text: 'Execute ${currentStep.displayName}',
                                    isLoading: state is AttendanceProcessing,
                                    icon: Icons.camera_alt_rounded,
                                    onPressed: () =>
                                        _openCameraModal(currentStep),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 28),
                                SizedBox(width: 12),
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

                        const SizedBox(height: 24),
                        // 6-Step Workflow Stepper Log
                        Text(
                          'Today\'s Attendance Timeline',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: WorkflowStep.values.length -
                              1, // Exclude completed tag
                          itemBuilder: (context, index) {
                            final step = WorkflowStep.values[index];
                            final record = userTodayRecords.firstWhere(
                              (r) => r.workflowStep == step,
                              orElse: () => AttendanceRecord(
                                id: '',
                                employeeId: '',
                                employeeName: '',
                                workflowStep: step,
                                eventTimestamp: DateTime.now(),
                                latitude: 0,
                                longitude: 0,
                                gpsAccuracy: 0,
                                address: '',
                                deviceId: '',
                                photoBase64: '',
                                isGeofenceValid: false,
                              ),
                            );

                            bool isDone = record.id.isNotEmpty;
                            bool isCurrent = step == currentStep;
                            final formattedTime = isDone
                                ? DateFormat('hh:mm a')
                                    .format(record.eventTimestamp.toLocal())
                                : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.primary.withOpacity(0.08)
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppColors.primary
                                      : isDone
                                          ? AppColors.success
                                          : AppColors.cardBorderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isDone
                                        ? AppColors.success
                                        : isCurrent
                                            ? AppColors.primary
                                            : Colors.grey.shade300,
                                    child: Icon(
                                      isDone ? Icons.check : Icons.circle,
                                      size: 14,
                                      color: Colors.white,
                                    ),
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
                                                step.displayName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isCurrent
                                                      ? AppColors.primary
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            if (isDone) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  formattedTime,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.greenAccent,
                                                  ),
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isDone
                                              ? (record.address.isNotEmpty
                                                  ? record.address
                                                  : 'Captured')
                                              : 'Pending capture',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondaryLight),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isDone) ...[
                                    const SizedBox(width: 8),
                                    StatusBadge(
                                      label:
                                          record.syncStatus.name.toUpperCase(),
                                      color:
                                          record.syncStatus == SyncStatus.synced
                                              ? AppColors.success
                                              : AppColors.warning,
                                    ),
                                  ]
                                ],
                              ),
                            );
                          },
                        )
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

  Widget _buildInfoMetric(String title, String value) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondaryLight)),
        ),
      ],
    );
  }
}
