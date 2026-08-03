import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../database/local_database_service.dart';
import '../domain/employee_entity.dart';
import '../domain/work_shift_entity.dart';
import '../domain/employee_shift_assignment_entity.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LocalDatabaseService _db = LocalDatabaseService();

  List<EmployeeEntity> _employees = [];
  List<WorkShiftEntity> _shifts = [];
  List<EmployeeShiftAssignmentEntity> _assignments = [];

  // Roster assignment form state
  EmployeeEntity? _selectedEmployee;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String _shiftName = 'Custom Shift';
  int _gracePeriodMinutes = 15;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _employees = _db.getEmployees();
      _shifts = _db.getShifts();
      _assignments = _db.getShiftAssignments();

      if (_employees.isNotEmpty) {
        if (_selectedEmployee != null &&
            _employees.contains(_selectedEmployee)) {
          _selectedEmployee =
              _employees.firstWhere((e) => e.id == _selectedEmployee!.id);
        } else {
          _selectedEmployee = _employees.first;
        }
      } else {
        _selectedEmployee = null;
      }
    });
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _format12HourTime(TimeOfDay tod) {
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyTemplate(WorkShiftEntity template) {
    setState(() {
      _shiftName = template.name;
      _startTime = _parseTimeOfDay(template.startTime);
      _endTime = _parseTimeOfDay(template.endTime);
      _gracePeriodMinutes = template.gracePeriodMinutes;
    });
  }

  void _saveAssignment() {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final dateStr = _formatDate(_selectedDate);
    final startTimeStr = _formatTimeOfDay(_startTime);
    final endTimeStr = _formatTimeOfDay(_endTime);

    final assignment = EmployeeShiftAssignmentEntity(
      id: '${_selectedEmployee!.id}-$dateStr',
      employeeId: _selectedEmployee!.id,
      dateStr: dateStr,
      shiftName: _shiftName.trim().isEmpty ? 'Custom Shift' : _shiftName.trim(),
      startTime: startTimeStr,
      endTime: endTimeStr,
      gracePeriodMinutes: _gracePeriodMinutes,
    );

    _db.saveShiftAssignment(assignment);
    _loadData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shift saved for ${_selectedEmployee!.name} on $dateStr (${assignment.shiftName} ${_format12HourTime(_startTime)} - ${_format12HourTime(_endTime)})',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddShiftTemplateDialog([WorkShiftEntity? existingShift]) {
    final nameController =
        TextEditingController(text: existingShift?.name ?? '');
    TimeOfDay start = existingShift != null
        ? _parseTimeOfDay(existingShift.startTime)
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = existingShift != null
        ? _parseTimeOfDay(existingShift.endTime)
        : const TimeOfDay(hour: 18, minute: 0);
    int grace = existingShift?.gracePeriodMinutes ?? 15;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existingShift == null
                ? 'Create Shift Template'
                : 'Edit Shift Template',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Shift Name',
                    hintText: 'e.g. Early Morning, Night Shift',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text('Start: ${_format12HourTime(start)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: start,
                          );
                          if (picked != null) {
                            setDialogState(() => start = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_filled_rounded),
                        label: Text('End: ${_format12HourTime(end)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: end,
                          );
                          if (picked != null) {
                            setDialogState(() => end = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Grace Period: '),
                    Expanded(
                      child: Slider(
                        value: grace.toDouble(),
                        min: 0,
                        max: 60,
                        divisions: 12,
                        label: '$grace mins',
                        onChanged: (val) {
                          setDialogState(() => grace = val.toInt());
                        },
                      ),
                    ),
                    Text('$grace min'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final shift = WorkShiftEntity(
                  id: existingShift?.id ??
                      'shift-${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  startTime: _formatTimeOfDay(start),
                  endTime: _formatTimeOfDay(end),
                  gracePeriodMinutes: grace,
                );

                _db.saveShift(shift);
                Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Save Shift'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift & Roster Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.event_note_rounded), text: 'Daily Roster'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Shift Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRosterTab(theme),
          _buildTemplatesTab(theme),
        ],
      ),
    );
  }

  Widget _buildRosterTab(ThemeData theme) {
    final dateStr = _formatDate(_selectedDate);
    final dateAssignments =
        _assignments.where((a) => a.dateStr == dateStr).toList();

    final validEmployee = (_employees.isNotEmpty &&
            _selectedEmployee != null &&
            _employees.contains(_selectedEmployee))
        ? _selectedEmployee
        : (_employees.isNotEmpty ? _employees.first : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee & Date Selector Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_pin_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Assign Custom Daily Shift',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Employee Dropdown
                  const Text('Select Employee',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (_employees.isNotEmpty)
                    DropdownButtonFormField<EmployeeEntity>(
                      value: validEmployee,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      isExpanded: true,
                      items: _employees.map((emp) {
                        return DropdownMenuItem<EmployeeEntity>(
                          value: emp,
                          child: Text(
                            '${emp.name} (${emp.employeeCode})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedEmployee = val);
                      },
                    )
                  else
                    const Text('No employees registered yet.'),

                  const SizedBox(height: 16),

                  // Date Picker & Quick Buttons
                  const Text('Target Date',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.calendar_month_rounded,
                              size: 20),
                          label: Text(
                            _formatDate(_selectedDate),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        label: const Text('Today'),
                        onPressed: () =>
                            setState(() => _selectedDate = DateTime.now()),
                      ),
                      const SizedBox(width: 4),
                      ActionChip(
                        label: const Text('Tomorrow'),
                        onPressed: () => setState(() => _selectedDate =
                            DateTime.now().add(const Duration(days: 1))),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick Shift Templates Chips
                  if (_shifts.isNotEmpty) ...[
                    const Text('Quick Preset Templates (Optional)',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _shifts.map((shift) {
                        final isSelected = _shiftName == shift.name;
                        return ChoiceChip(
                          label:
                              Text('${shift.name} (${shift.displayTimeRange})'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) _applyTemplate(shift);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Custom Start & End Time Pickers
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded,
                                  color: AppColors.success, size: 20),
                              label: Text(
                                _format12HourTime(_startTime),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _startTime,
                                );
                                if (picked != null) {
                                  setState(() => _startTime = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.stop_rounded,
                                  color: AppColors.error, size: 20),
                              label: Text(
                                _format12HourTime(_endTime),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _endTime,
                                );
                                if (picked != null) {
                                  setState(() => _endTime = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Save Shift Assignment Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Shift Assignment',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: _saveAssignment,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Daily Roster Table / Cards for selected date ("Newly Added Shift Section")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Scheduled Roster for $dateStr',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${dateAssignments.length} Assigned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (dateAssignments.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No custom shifts assigned for this date.\nEmployees will default to General Shift (09:00 - 18:00).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dateAssignments.length,
              itemBuilder: (ctx, index) {
                final item = dateAssignments[index];
                final emp = _employees.firstWhere(
                  (e) => e.id == item.employeeId,
                  orElse: () => EmployeeEntity(
                    id: item.employeeId,
                    employeeCode: 'N/A',
                    name: 'Employee (${item.employeeId})',
                    mobileNumber: '',
                    email: '',
                    designation: '',
                    department: '',
                  ),
                );

                final workShift = item.toWorkShift();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: workShift.isNightShift
                              ? const Color(0xFF1E293B)
                              : theme.colorScheme.primaryContainer,
                          child: Icon(
                            workShift.isNightShift
                                ? Icons.nights_stay_rounded
                                : Icons.wb_sunny_rounded,
                            color: workShift.isNightShift
                                ? Colors.amber
                                : theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      emp.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      emp.employeeCode,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Shift: ${item.shiftName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    '(${workShift.displayTimeRange})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.gracePeriodMinutes > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Grace: ${item.gracePeriodMinutes} mins',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent),
                          tooltip: 'Remove Shift Assignment',
                          onPressed: () {
                            _db.deleteShiftAssignment(item.id);
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Shift removed for ${emp.name}'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pre-configured Shift Templates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Template'),
                onPressed: () => _showAddShiftTemplateDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shifts.length,
            itemBuilder: (ctx, index) {
              final shift = _shifts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: shift.isNightShift
                        ? const Color(0xFF0F172A)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      shift.isNightShift
                          ? Icons.bedtime_rounded
                          : Icons.schedule_rounded,
                      color: shift.isNightShift
                          ? Colors.amber
                          : theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    shift.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    'Time Range: ${shift.displayTimeRange}\nGrace Period: ${shift.gracePeriodMinutes} mins',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded),
                        onPressed: () => _showAddShiftTemplateDialog(shift),
                      ),
                      if (shift.id != 'shift-general')
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red),
                          onPressed: () {
                            _db.deleteShift(shift.id);
                            _loadData();
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
