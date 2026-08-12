import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../database/local_database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/employee_entity.dart';
import '../domain/office_entity.dart';
import '../domain/work_site_entity.dart';
import '../../../core/services/location_service.dart';

abstract class AdminState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminDataLoaded extends AdminState {
  final List<EmployeeEntity> employees;
  final List<OfficeEntity> offices;
  final List<WorkSiteEntity> workSites;
  final String? statusMessage;

  AdminDataLoaded({
    required this.employees,
    required this.offices,
    required this.workSites,
    this.statusMessage,
  });

  @override
  List<Object?> get props => [employees, offices, workSites, statusMessage];
}

class AdminCubit extends Cubit<AdminState> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final SupabaseService _supabase = SupabaseService();
  final Uuid _uuid = const Uuid();

  AdminCubit() : super(AdminDataLoaded(
    employees: [],
    offices: [],
    workSites: [],
  )) {
    loadDashboardData();
  }

  Future<void> loadDashboardData([String? message]) async {
    final localOffices = _db.getOffices();
    List<OfficeEntity> cloudOffices = [];
    try {
      cloudOffices = await _supabase.fetchOfficesFromSupabase();
    } catch (_) {}

    final officeMap = <String, OfficeEntity>{};
    for (final off in localOffices) {
      officeMap[off.id] = off;
    }
    for (final off in cloudOffices) {
      officeMap[off.id] = off;
    }

    final combinedOffices = officeMap.values.toList();

    final orgId = _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
    try {
      final cloudUsers = await _supabase.fetchOrganizationUsers(orgId);
      for (final u in cloudUsers) {
        final emp = EmployeeEntity(
          id: u.id,
          employeeCode: 'EMP-${u.id.length >= 4 ? u.id.substring(0, 4).toUpperCase() : u.id.toUpperCase()}',
          name: u.fullName,
          mobileNumber: u.phoneNumber ?? '',
          email: u.email,
          designation: 'Staff',
          department: 'Operations',
          isActive: u.isActive,
        );
        _db.saveEmployee(emp);
      }
    } catch (_) {}

    emit(AdminDataLoaded(
      employees: _db.getEmployees(),
      offices: combinedOffices.isNotEmpty ? combinedOffices : localOffices,
      workSites: _db.getWorkSites(),
      statusMessage: message,
    ));
  }

  // Save / Update Employee
  Future<void> saveEmployee({
    required String? id,
    required String code,
    required String name,
    required String email,
    required String mobile,
    required String designation,
    required String department,
    required bool useDefaultOffice,
    String? assignedOfficeId,
  }) async {
    final emp = EmployeeEntity(
      id: id ?? _uuid.v4(),
      employeeCode: code.trim(),
      name: name.trim(),
      mobileNumber: mobile.trim(),
      email: email.trim(),
      designation: designation.trim(),
      department: department.trim(),
      useDefaultOffice: useDefaultOffice,
      assignedOfficeId: assignedOfficeId,
      isActive: true,
    );

    _db.saveEmployee(emp);

    final orgId = _db.organization?.id ?? '00000000-0000-0000-0000-000000000001';
    if (id != null && id.isNotEmpty) {
      try {
        await _supabase.updateUserInSupabase(
          userId: id,
          orgId: orgId,
          fullName: name.trim(),
          phoneNumber: mobile.trim(),
          designation: designation.trim(),
          department: department.trim(),
          useDefaultOffice: useDefaultOffice,
          assignedOfficeId: assignedOfficeId,
        );
      } catch (_) {}
    }

    await loadDashboardData('Employee profile saved successfully.');
  }

  void deleteEmployee(String id) {
    _db.deleteEmployee(id);
    loadDashboardData('Employee deleted.');
  }

  // Save / Update Office with Live GPS Capture
  Future<void> saveOffice({
    required String? id,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    bool isDefault = false,
  }) async {
    final office = OfficeEntity(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
      geofenceRadiusMeters: radiusMeters,
      isDefault: isDefault,
    );

    _db.saveOffice(office);
    await _supabase.saveOfficeToSupabase(office);
    await loadDashboardData('Office details updated successfully.');
  }

  /// Live GPS Capture ("Use Current Location" button)
  Future<LocationDataResult> captureCurrentLocationForOffice() async {
    return await LocationService.getCurrentLocation();
  }

  void deleteOffice(String id) {
    _db.deleteOffice(id);
    loadDashboardData('Office removed.');
  }

  // Save / Update Work Site
  void saveWorkSite({
    required String? id,
    required String siteName,
    required String clientName,
    required String address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    final site = WorkSiteEntity(
      id: id ?? _uuid.v4(),
      siteName: siteName.trim(),
      clientName: clientName.trim(),
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      assignedEmployeeIds: [],
    );

    _db.saveWorkSite(site);
    loadDashboardData('Work site saved.');
  }

  void deleteWorkSite(String id) {
    _db.deleteWorkSite(id);
    loadDashboardData('Work site removed.');
  }
}
