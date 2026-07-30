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
import '../../attendance/domain/attendance_record.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
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
    setState(() {
      _pendingSyncCount = _db.getPendingSyncRecords().length;
    });
  }

  Future<void> _manualSync() async {
    final result = await _syncEngine.performSync();
    _refreshSyncCount();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.syncedCount > 0 ? AppColors.success : AppColors.info,
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final user = _db.currentUser;
    final currentStep = _db.currentWorkflowStep;
    final records = _db.getAttendanceRecords();
    final offices = _db.getOffices();
    final assignedOffice = offices.isNotEmpty ? offices.first.name : 'Main Office';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.fullName ?? 'Field Employee'),
            const Text(
              'Field Workforce Duty Portal',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
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
                          content: Text('${state.record.workflowStep.displayName} Captured Successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (state is GeofenceViolationError) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(
                            children: [
                              Icon(Icons.gpp_bad_rounded, color: AppColors.error),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                              const SizedBox(height: 12),
                              Text('Distance to target: ${state.distanceMeters.toStringAsFixed(1)} meters'),
                              Text('Permitted Geofence Radius: ${state.allowedRadiusMeters.toStringAsFixed(1)} meters'),
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
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Assigned Office Station',
                                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                          ),
                                          Text(
                                            assignedOffice,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(
                                      label: currentStep == WorkflowStep.completed ? 'Shift Complete' : 'On Duty',
                                      color: currentStep == WorkflowStep.completed ? Colors.grey : AppColors.success,
                                    )
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildInfoMetric('Duty Step', '${currentStep.index + 1}/7'),
                                    _buildInfoMetric('Working Time', '06h 45m'),
                                    _buildInfoMetric('Pending Sync', '$_pendingSyncCount'),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                                      const Icon(Icons.touch_app_rounded, color: AppColors.primary),
                                      const SizedBox(width: 10),
                                      Text(
                                        currentStep.displayName,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Live camera frame & GPS location will be captured & validated against assigned geofence radius.',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    text: 'Execute ${currentStep.displayName}',
                                    isLoading: state is AttendanceProcessing,
                                    icon: Icons.camera_alt_rounded,
                                    onPressed: () => _openCameraModal(currentStep),
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
                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Daily attendance workflow fully completed. Thank you!',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: WorkflowStep.values.length - 1, // Exclude completed tag
                          itemBuilder: (context, index) {
                            final step = WorkflowStep.values[index];
                            final record = records.firstWhere(
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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrent ? AppColors.primary.withOpacity(0.08) : Theme.of(context).cardColor,
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.displayName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent ? AppColors.primary : null,
                                          ),
                                        ),
                                        Text(
                                          isDone ? record.address : 'Pending capture',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isDone)
                                    StatusBadge(
                                      label: record.syncStatus.name.toUpperCase(),
                                      color: record.syncStatus == SyncStatus.synced ? AppColors.success : AppColors.warning,
                                    )
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
      ],
    );
  }
}
