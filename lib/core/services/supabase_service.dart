import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../../features/setup/domain/organization_setup.dart';
import '../../features/auth/domain/user_entity.dart';
import '../../features/admin/domain/office_entity.dart';
import '../../features/admin/domain/employee_entity.dart';
import '../../database/local_database_service.dart';
import '../constants/app_enums.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final Uuid _uuid = const Uuid();

  static const String supabaseUrl = 'https://agkuybibzrjqcxtlnlrm.supabase.co';

  // Public anon key for project agkuybibzrjqcxtlnlrm
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFna3V5YmlienJqcWN4dGxubHJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5Njc1OTgsImV4cCI6MjA5ODU0MzU5OH0.lmhZ8TIklkj7I9oSRawuitWvnsZ6jMaL-95raMVLNTA';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Helper to validate standard 36-character UUID string format
  bool _isValidUuid(String? str) {
    if (str == null || str.isEmpty) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str);
  }

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    return Supabase.instance.client;
  }

  /// Initialize Supabase Client
  Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('Supabase initialized successfully.');
    } catch (e) {
      debugPrint('Supabase initialization warning: $e');
    }
  }

  /// Check if any Organization exists in Supabase
  Future<bool> checkOrganizationExists() async {
    if (!_isInitialized || client == null) return false;

    try {
      final response = await client!
          .from('organizations')
          .select('id')
          .eq('is_deleted', false)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('PGRST205') || errStr.contains('schema cache')) {
        debugPrint(
            'Supabase setup note: Table "public.organizations" does not exist in schema cache yet. '
            'Please run backend/supabase_schema.sql in your Supabase SQL Editor.');
      } else {
        debugPrint('Supabase checkOrganizationExists note: $e');
      }
      return false;
    }
  }

  /// Save Organization, Super Admin User, and Default Office in Supabase
  Future<bool> saveOrganizationSetup({
    required OrganizationSetup setup,
    required String firebaseUid,
  }) async {
    if (!_isInitialized || client == null) {
      debugPrint('Supabase not initialized; skipping organization cloud save');
      return false;
    }

    try {
      // 1. Create Organization
      final orgPayload = {
        'id': setup.id,
        'name': setup.name,
        'address': setup.address,
        'super_admin_name': setup.superAdminName,
        'super_admin_email': setup.superAdminEmail,
        'mobile_number': setup.mobileNumber,
        'is_deleted': false,
        'created_at': setup.createdAt.toIso8601String(),
        'updated_at': setup.createdAt.toIso8601String(),
      };
      await client!.from('organizations').upsert(orgPayload);

      // 2. Create Super Admin User Record
      final userPayload = {
        'firebase_uid': firebaseUid,
        'organization_id': setup.id,
        'email': setup.superAdminEmail,
        'full_name': setup.superAdminName,
        'phone_number': setup.mobileNumber,
        'role': 'SUPER_ADMIN',
        'is_active': true,
        'requires_password_change': false,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final userResponse =
          await client!.from('users').upsert(userPayload).select().single();
      final userId = userResponse['id'];

      // 3. Create Default Office ("Main Office")
      final officePayload = {
        'organization_id': setup.id,
        'name': 'Main Office',
        'address': setup.address,
        'latitude': 24.365500, // Default HQ coordinates (Dubai Business Bay)
        'longitude': 54.500531,
        'geofence_radius_meters': 200.0,
        'is_default': true,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client!.from('offices').upsert(officePayload);

      // 4. Log Activity
      await logActivity(
        orgId: setup.id,
        actorUserId: _isValidUuid(userId) ? userId : null,
        action: ActivityLogAction.orgSetup.dbValue,
        details: {'org_name': setup.name, 'admin_email': setup.superAdminEmail},
      );

      debugPrint(
          'Organization setup and Super Admin successfully saved in Supabase.');
      return true;
    } catch (e) {
      debugPrint('Supabase saveOrganizationSetup error: $e');
      return false;
    }
  }

  /// Save or Update Office in Supabase
  Future<void> saveOfficeToSupabase(OfficeEntity office) async {
    if (!_isInitialized || client == null) return;
    try {
      final localOrg = LocalDatabaseService().organization;
      final orgId = localOrg?.id ?? '00000000-0000-0000-0000-000000000001';
      final validOrgId = await ensureOrganizationExistsInCloud(orgId) ?? orgId;

      final officePayload = {
        if (_isValidUuid(office.id)) 'id': office.id,
        'organization_id': validOrgId,
        'name': office.name,
        'address': office.address,
        'latitude': office.latitude,
        'longitude': office.longitude,
        'geofence_radius_meters': office.geofenceRadiusMeters,
        'is_default': office.isDefault,
        'is_deleted': false,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client!.from('offices').upsert(officePayload);
    } catch (e) {
      debugPrint('Supabase saveOfficeToSupabase error: $e');
    }
  }

  /// Fetch Offices from Supabase
  Future<List<OfficeEntity>> fetchOfficesFromSupabase() async {
    if (!_isInitialized || client == null) return [];
    try {
      final List<dynamic> response = await client!
          .from('offices')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: true);
      return response.map((json) => OfficeEntity.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Supabase fetchOfficesFromSupabase error: $e');
      return [];
    }
  }

  /// Fetch User Profile by Firebase UID / ID / Email
  Future<UserEntity?> fetchUserByFirebaseUid(String identifier) async {
    if (!_isInitialized || client == null) return null;

    final cleanId = identifier.trim();
    if (cleanId.isEmpty) return null;

    // 1. Try querying by firebase_uid string
    try {
      final response = await client!
          .from('users')
          .select()
          .eq('firebase_uid', cleanId)
          .eq('is_deleted', false)
          .maybeSingle();

      if (response != null) {
        final map = Map<String, dynamic>.from(response);
        final userId = map['id']?.toString() ?? '';
        Map<String, dynamic>? empRow;
        try {
          if (userId.isNotEmpty && _isValidUuid(userId)) {
            empRow = await client!
                .from('employees')
                .select()
                .eq('user_id', userId)
                .eq('is_deleted', false)
                .maybeSingle();
          }
          if (empRow == null && cleanId.isNotEmpty) {
            empRow = await client!
                .from('employees')
                .select()
                .eq('user_id', cleanId)
                .eq('is_deleted', false)
                .maybeSingle();
          }
        } catch (_) {}

        if (empRow != null) {
          if (empRow['employee_code'] != null &&
              empRow['employee_code'].toString().trim().isNotEmpty &&
              empRow['employee_code'].toString().trim() != 'EMP-000') {
            map['employee_code'] = empRow['employee_code'].toString().trim();
          }
          if (empRow['designation'] != null &&
              empRow['designation'].toString().trim().isNotEmpty) {
            map['designation'] = empRow['designation'].toString().trim();
          }
          if (empRow['department'] != null &&
              empRow['department'].toString().trim().isNotEmpty) {
            map['department'] = empRow['department'].toString().trim();
          }
        }
        return UserEntity.fromJson(map);
      }
    } catch (e) {
      debugPrint('Supabase fetchUserByFirebaseUid (firebase_uid) note: $e');
    }

    // 2. Try querying by email
    if (cleanId.contains('@')) {
      try {
        final response = await client!
            .from('users')
            .select()
            .eq('email', cleanId.toLowerCase())
            .eq('is_deleted', false)
            .maybeSingle();

        if (response != null) {
          final map = Map<String, dynamic>.from(response);
          final userId = map['id']?.toString() ?? '';
          Map<String, dynamic>? empRow;
          try {
            if (userId.isNotEmpty && _isValidUuid(userId)) {
              empRow = await client!
                  .from('employees')
                  .select()
                  .eq('user_id', userId)
                  .eq('is_deleted', false)
                  .maybeSingle();
            }
          } catch (_) {}

          if (empRow != null) {
            if (empRow['employee_code'] != null &&
                empRow['employee_code'].toString().trim().isNotEmpty &&
                empRow['employee_code'].toString().trim() != 'EMP-000') {
              map['employee_code'] = empRow['employee_code'].toString().trim();
            }
            if (empRow['designation'] != null &&
                empRow['designation'].toString().trim().isNotEmpty) {
              map['designation'] = empRow['designation'].toString().trim();
            }
            if (empRow['department'] != null &&
                empRow['department'].toString().trim().isNotEmpty) {
              map['department'] = empRow['department'].toString().trim();
            }
          }
          return UserEntity.fromJson(map);
        }
      } catch (e) {
        debugPrint('Supabase fetchUserByFirebaseUid (email) note: $e');
      }
    }

    // 3. Try querying by id if cleanId is a valid UUID
    if (_isValidUuid(cleanId)) {
      try {
        final response = await client!
            .from('users')
            .select()
            .eq('id', cleanId)
            .eq('is_deleted', false)
            .maybeSingle();

        if (response != null) {
          final map = Map<String, dynamic>.from(response);
          Map<String, dynamic>? empRow;
          try {
            empRow = await client!
                .from('employees')
                .select()
                .eq('user_id', cleanId)
                .eq('is_deleted', false)
                .maybeSingle();
          } catch (_) {}

          if (empRow != null) {
            if (empRow['employee_code'] != null &&
                empRow['employee_code'].toString().trim().isNotEmpty &&
                empRow['employee_code'].toString().trim() != 'EMP-000') {
              map['employee_code'] = empRow['employee_code'].toString().trim();
            }
            if (empRow['designation'] != null &&
                empRow['designation'].toString().trim().isNotEmpty) {
              map['designation'] = empRow['designation'].toString().trim();
            }
            if (empRow['department'] != null &&
                empRow['department'].toString().trim().isNotEmpty) {
              map['department'] = empRow['department'].toString().trim();
            }
          }
          return UserEntity.fromJson(map);
        }
      } catch (e) {
        debugPrint('Supabase fetchUserByFirebaseUid (id) note: $e');
      }
    }

    return null;
  }

  /// Update user password change requirement flag
  Future<bool> updateUserPasswordChangeStatus(
      String userId, bool requiresPasswordChange,
      [String? firebaseUid]) async {
    if (!_isInitialized || client == null) return false;

    try {
      if (_isValidUuid(userId)) {
        await client!.from('users').update({
          'requires_password_change': requiresPasswordChange,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }

      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        await client!.from('users').update({
          'requires_password_change': requiresPasswordChange,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('firebase_uid', firebaseUid);
      }
      return true;
    } catch (e) {
      debugPrint('Supabase updateUserPasswordChangeStatus error: $e');
      return false;
    }
  }

  /// Fetch Organization Users
  Future<List<UserEntity>> fetchOrganizationUsers(String orgId) async {
    if (!_isInitialized || client == null) return [];

    try {
      final targetOrgId = await ensureOrganizationExistsInCloud(orgId) ?? orgId;

      List<dynamic> usersResp = [];
      try {
        usersResp = await client!
            .from('users')
            .select()
            .eq('organization_id', targetOrgId)
            .eq('is_deleted', false)
            .order('created_at', ascending: false);
      } catch (_) {}

      // Fallback: If orgId filter returned empty list, fetch all non-deleted users
      if (usersResp.isEmpty) {
        try {
          usersResp = await client!
              .from('users')
              .select()
              .eq('is_deleted', false)
              .order('created_at', ascending: false);
        } catch (_) {}
      }

      // Fetch employees table to merge employee_code, designation, department
      List<dynamic> empResp = [];
      try {
        empResp = await client!
            .from('employees')
            .select()
            .eq('is_deleted', false);
      } catch (_) {}

      final List<UserEntity> result = [];
      for (final u in usersResp) {
        if (u is! Map) continue;
        final map = Map<String, dynamic>.from(u);
        final userId = map['id']?.toString() ?? '';
        final firebaseUid = map['firebase_uid']?.toString() ?? '';
        final email = map['email']?.toString() ?? '';

        Map<String, dynamic>? empRow;
        for (final e in empResp) {
          if (e is! Map) continue;
          final empUserId = e['user_id']?.toString();
          final empId = e['id']?.toString();
          final empEmail = e['email']?.toString();

          if ((empUserId != null &&
                  (empUserId == userId ||
                      (firebaseUid.isNotEmpty && empUserId == firebaseUid))) ||
              (empId != null && empId == userId) ||
              (empEmail != null &&
                  email.isNotEmpty &&
                  empEmail.trim().toLowerCase() ==
                      email.trim().toLowerCase())) {
            empRow = Map<String, dynamic>.from(e);
            break;
          }
        }

        if (empRow != null) {
          if (empRow['employee_code'] != null &&
              empRow['employee_code'].toString().trim().isNotEmpty &&
              empRow['employee_code'].toString().trim() != 'EMP-000') {
            map['employee_code'] = empRow['employee_code'].toString().trim();
          }
          if (empRow['designation'] != null &&
              empRow['designation'].toString().trim().isNotEmpty) {
            map['designation'] = empRow['designation'].toString().trim();
          }
          if (empRow['department'] != null &&
              empRow['department'].toString().trim().isNotEmpty) {
            map['department'] = empRow['department'].toString().trim();
          }
        }

        result.add(UserEntity.fromJson(map));
      }

      return result;
    } catch (e) {
      debugPrint('Supabase fetchOrganizationUsers error: $e');
      return [];
    }
  }

  /// Fetch Employees from Supabase (queries public.employees table and merges user details)
  Future<List<EmployeeEntity>> fetchEmployeesFromSupabase([String? orgId]) async {
    if (!_isInitialized || client == null) return [];

    try {
      final targetOrgId = (orgId != null && orgId.isNotEmpty)
          ? await ensureOrganizationExistsInCloud(orgId) ?? orgId
          : null;

      final List<dynamic> usersResp;
      if (targetOrgId != null && targetOrgId.isNotEmpty) {
        final filtered = await client!
            .from('users')
            .select()
            .eq('organization_id', targetOrgId)
            .eq('is_deleted', false);
        usersResp = filtered.isNotEmpty
            ? filtered
            : await client!.from('users').select().eq('is_deleted', false);
      } else {
        usersResp =
            await client!.from('users').select().eq('is_deleted', false);
      }

      final List<dynamic> empResp;
      if (targetOrgId != null && targetOrgId.isNotEmpty) {
        final filtered = await client!
            .from('employees')
            .select()
            .eq('organization_id', targetOrgId)
            .eq('is_deleted', false);
        empResp = filtered.isNotEmpty
            ? filtered
            : await client!.from('employees').select().eq('is_deleted', false);
      } else {
        empResp =
            await client!.from('employees').select().eq('is_deleted', false);
      }

      final offices = await fetchOfficesFromSupabase();

      final List<EmployeeEntity> result = [];
      final Set<String> processedEmpRowIds = {};

      for (final u in usersResp) {
        if (u is! Map) continue;
        final userId = u['id']?.toString() ?? '';
        final firebaseUid = u['firebase_uid']?.toString() ?? '';
        final email = u['email']?.toString() ?? '';
        final name = u['full_name']?.toString() ?? '';
        final phone = u['phone_number']?.toString() ?? '';
        final isActive = u['is_active'] ?? true;

        Map<String, dynamic>? empRow;
        for (final e in empResp) {
          if (e is! Map) continue;
          final empUserId = e['user_id']?.toString();
          final empId = e['id']?.toString();
          final empEmail = e['email']?.toString();

          if ((empUserId != null &&
                  (empUserId == userId ||
                      (firebaseUid.isNotEmpty && empUserId == firebaseUid))) ||
              (empId != null && empId == userId) ||
              (empEmail != null &&
                  email.isNotEmpty &&
                  empEmail.trim().toLowerCase() ==
                      email.trim().toLowerCase())) {
            empRow = Map<String, dynamic>.from(e);
            if (empId != null && empId.isNotEmpty) {
              processedEmpRowIds.add(empId);
            }
            break;
          }
        }

        final rawUserCode = u['employee_code']?.toString().trim();
        final userCode = (rawUserCode != null &&
                rawUserCode.isNotEmpty &&
                rawUserCode != 'EMP-000')
            ? rawUserCode
            : null;

        final rawEmpCode = empRow?['employee_code']?.toString().trim();
        final empRowCode = (rawEmpCode != null &&
                rawEmpCode.isNotEmpty &&
                rawEmpCode != 'EMP-000')
            ? rawEmpCode
            : null;

        final empCode = empRowCode ??
            userCode ??
            'EMP-${userId.length >= 4 ? userId.substring(0, 4).toUpperCase() : "000"}';
        final designation = empRow?['designation']?.toString() ?? 'Staff';
        final department = empRow?['department']?.toString() ?? 'Operations';
        final useDefaultOffice = empRow?['use_default_office'] ?? true;
        final assignedOfficeId = empRow?['assigned_office_id']?.toString();

        String? assignedOfficeName;
        if (assignedOfficeId != null && assignedOfficeId.isNotEmpty) {
          final matchedOffice = offices.where((o) => o.id == assignedOfficeId);
          if (matchedOffice.isNotEmpty) {
            assignedOfficeName = matchedOffice.first.name;
          }
        }

        result.add(EmployeeEntity(
          id: userId.isNotEmpty
              ? userId
              : (firebaseUid.isNotEmpty ? firebaseUid : name),
          employeeCode: empCode,
          name: name,
          mobileNumber: phone,
          email: email,
          designation: designation,
          department: department,
          useDefaultOffice: useDefaultOffice,
          assignedOfficeId: assignedOfficeId,
          assignedOfficeName: assignedOfficeName,
          isActive: isActive,
        ));
      }

      // Include any standalone active employee rows from employees table not yet matched
      for (final e in empResp) {
        if (e is! Map) continue;
        final empId = e['id']?.toString() ?? '';
        if (empId.isNotEmpty && processedEmpRowIds.contains(empId)) continue;
        final empCode = e['employee_code']?.toString() ?? '';
        final empName =
            e['name']?.toString() ?? e['full_name']?.toString() ?? 'Employee';
        final empEmail = e['email']?.toString() ?? '';
        final empPhone = e['mobile_number']?.toString() ??
            e['phone_number']?.toString() ??
            '';
        final designation = e['designation']?.toString() ?? 'Staff';
        final department = e['department']?.toString() ?? 'Operations';
        final useDefaultOffice = e['use_default_office'] ?? true;
        final assignedOfficeId = e['assigned_office_id']?.toString();

        String? assignedOfficeName;
        if (assignedOfficeId != null && assignedOfficeId.isNotEmpty) {
          final matchedOffice = offices.where((o) => o.id == assignedOfficeId);
          if (matchedOffice.isNotEmpty) {
            assignedOfficeName = matchedOffice.first.name;
          }
        }

        final alreadyAdded = result.any((r) =>
            (empEmail.isNotEmpty &&
                r.email.toLowerCase() == empEmail.toLowerCase()) ||
            (empCode.isNotEmpty &&
                r.employeeCode.toLowerCase() == empCode.toLowerCase()));

        if (!alreadyAdded) {
          result.add(EmployeeEntity(
            id: e['user_id']?.toString() ??
                (empId.isNotEmpty ? empId : empCode),
            employeeCode: empCode.isNotEmpty ? empCode : 'EMP-000',
            name: empName,
            mobileNumber: empPhone,
            email: empEmail,
            designation: designation,
            department: department,
            useDefaultOffice: useDefaultOffice,
            assignedOfficeId: assignedOfficeId,
            assignedOfficeName: assignedOfficeName,
            isActive: e['is_active'] ?? true,
          ));
        }
      }

      return result;
    } catch (e) {
      debugPrint('Supabase fetchEmployeesFromSupabase error: $e');
      return [];
    }
  }

  /// Fetch complete Employee Details (from users + employees + offices tables) by User ID or Email
  Future<EmployeeEntity?> fetchEmployeeDetails(String userIdOrEmail) async {
    if (!_isInitialized || client == null) return null;
    final clean = userIdOrEmail.trim();
    if (clean.isEmpty) return null;

    try {
      Map<String, dynamic>? userRow;
      if (_isValidUuid(clean)) {
        userRow = await client!
            .from('users')
            .select()
            .eq('id', clean)
            .eq('is_deleted', false)
            .maybeSingle();
      }
      if (userRow == null && clean.contains('@')) {
        userRow = await client!
            .from('users')
            .select()
            .eq('email', clean.toLowerCase())
            .eq('is_deleted', false)
            .maybeSingle();
      }
      if (userRow == null) {
        userRow = await client!
            .from('users')
            .select()
            .eq('firebase_uid', clean)
            .eq('is_deleted', false)
            .maybeSingle();
      }

      final actualUserId = userRow?['id']?.toString() ?? (_isValidUuid(clean) ? clean : '');
      final firebaseUid = userRow?['firebase_uid']?.toString() ?? clean;
      final fullName = userRow?['full_name']?.toString() ?? '';
      final email = userRow?['email']?.toString() ?? (clean.contains('@') ? clean : '');
      final phone = userRow?['phone_number']?.toString() ?? '';
      final isActive = userRow?['is_active'] ?? true;

      Map<String, dynamic>? empRow;
      if (actualUserId.isNotEmpty) {
        empRow = await client!
            .from('employees')
            .select()
            .eq('user_id', actualUserId)
            .eq('is_deleted', false)
            .maybeSingle();
      }
      if (empRow == null && firebaseUid.isNotEmpty) {
        empRow = await client!
            .from('employees')
            .select()
            .eq('user_id', firebaseUid)
            .eq('is_deleted', false)
            .maybeSingle();
      }
      if (empRow == null && clean.isNotEmpty) {
        empRow = await client!
            .from('employees')
            .select()
            .eq('employee_code', clean)
            .eq('is_deleted', false)
            .maybeSingle();
      }

      if (userRow == null && empRow == null) return null;

      final rawUserCode = userRow?['employee_code']?.toString().trim();
      final userCode = (rawUserCode != null &&
              rawUserCode.isNotEmpty &&
              rawUserCode != 'EMP-000')
          ? rawUserCode
          : null;

      final rawEmpCode = empRow?['employee_code']?.toString().trim();
      final empRowCode = (rawEmpCode != null &&
              rawEmpCode.isNotEmpty &&
              rawEmpCode != 'EMP-000')
          ? rawEmpCode
          : null;

      final empCode = empRowCode ??
          userCode ??
          (actualUserId.length >= 4
              ? 'EMP-${actualUserId.substring(0, 4).toUpperCase()}'
              : 'EMP-000');
      final designation = empRow?['designation']?.toString() ?? '';
      final department = empRow?['department']?.toString() ?? '';
      final useDefaultOffice = empRow?['use_default_office'] ?? true;
      final assignedOfficeId = empRow?['assigned_office_id']?.toString();

      String? assignedOfficeName;
      if (assignedOfficeId != null && assignedOfficeId.isNotEmpty) {
        final officeRow = await client!
            .from('offices')
            .select('name')
            .eq('id', assignedOfficeId)
            .maybeSingle();
        assignedOfficeName = officeRow?['name']?.toString();
      }

      return EmployeeEntity(
        id: actualUserId.isNotEmpty ? actualUserId : (firebaseUid.isNotEmpty ? firebaseUid : clean),
        employeeCode: empCode,
        name: fullName.isNotEmpty ? fullName : (empRow?['name']?.toString() ?? ''),
        mobileNumber: phone.isNotEmpty ? phone : (empRow?['mobile_number']?.toString() ?? ''),
        email: email.isNotEmpty ? email : (empRow?['email']?.toString() ?? ''),
        designation: designation,
        department: department,
        useDefaultOffice: useDefaultOffice,
        assignedOfficeId: assignedOfficeId,
        assignedOfficeName: assignedOfficeName,
        isActive: isActive,
      );
    } catch (e) {
      debugPrint('Supabase fetchEmployeeDetails error: $e');
      return null;
    }
  }

  /// Helper to guarantee that an organization record exists in cloud before adding users
  Future<String?> ensureOrganizationExistsInCloud(String? orgId) async {
    if (!_isInitialized || client == null) return null;

    try {
      // 1. Check if orgId exists in organizations table
      if (orgId != null && _isValidUuid(orgId)) {
        final existing = await client!
            .from('organizations')
            .select('id')
            .eq('id', orgId)
            .maybeSingle();

        if (existing != null) return orgId;
      }

      // 2. Check if any organization exists in cloud
      final anyOrg = await client!
          .from('organizations')
          .select('id')
          .eq('is_deleted', false)
          .limit(1)
          .maybeSingle();

      if (anyOrg != null && anyOrg['id'] != null) {
        return anyOrg['id'].toString();
      }

      // 3. Auto-provision organization record to fulfill foreign key constraint
      final localOrg = LocalDatabaseService().organization;
      final targetOrgId = (localOrg != null && _isValidUuid(localOrg.id))
          ? localOrg.id
          : '00000000-0000-0000-0000-000000000001';

      final orgPayload = {
        'id': targetOrgId,
        'name': localOrg?.name ?? 'Enterprise Operations',
        'address': localOrg?.address ?? 'HQ Operations Center',
        'super_admin_name': localOrg?.superAdminName ?? 'Chief Administrator',
        'super_admin_email':
            localOrg?.superAdminEmail ?? 'admin@enterprise.com',
        'mobile_number': localOrg?.mobileNumber ?? '+971501234567',
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client!.from('organizations').upsert(orgPayload);
      return targetOrgId;
    } catch (e) {
      debugPrint('ensureOrganizationExistsInCloud note: $e');
      return orgId != null && _isValidUuid(orgId)
          ? orgId
          : '00000000-0000-0000-0000-000000000001';
    }
  }

  /// Create User in Supabase (Users table + Employees table if applicable)
  Future<UserEntity?> createUserInSupabase({
    required String firebaseUid,
    required String orgId,
    required String email,
    required String fullName,
    String? phoneNumber,
    required UserRole role,
    required bool requiresPasswordChange,
    String? employeeCode,
    String? designation,
    String? department,
    bool useDefaultOffice = true,
    String? assignedOfficeId,
    String? assignedOfficeName,
    String? actorUserId,
  }) async {
    if (!_isInitialized || client == null) return null;

    final targetOrgId = await ensureOrganizationExistsInCloud(orgId) ?? orgId;

    try {
      final userPayload = {
        'firebase_uid': firebaseUid,
        'organization_id': targetOrgId,
        'email': email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'role': role.nameString,
        'is_active': true,
        'requires_password_change': requiresPasswordChange,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final userResponse =
          await client!.from('users').insert(userPayload).select().single();
      final user = UserEntity.fromJson(userResponse);

      // Insert Employee table entry if provided or role is employee/admin
      if (employeeCode != null && employeeCode.isNotEmpty) {
        final empPayload = {
          'user_id': user.id,
          'organization_id': targetOrgId,
          'employee_code': employeeCode,
          'designation': designation ?? 'Team Member',
          'department': department ?? 'Operations',
          'use_default_office': useDefaultOffice,
          if (assignedOfficeId != null && _isValidUuid(assignedOfficeId))
            'assigned_office_id': assignedOfficeId,
          'is_deleted': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        await client!.from('employees').upsert(empPayload);
      }

      await logActivity(
        orgId: orgId,
        actorUserId: _isValidUuid(actorUserId) ? actorUserId : null,
        targetUserId: _isValidUuid(user.id) ? user.id : null,
        action: ActivityLogAction.employeeCreated.dbValue,
        details: {'email': email, 'role': role.nameString, 'name': fullName},
      );

      return user;
    } catch (e) {
      debugPrint('Supabase createUserInSupabase error: $e');
      return null;
    }
  }

  /// Update User profile in Supabase
  Future<bool> updateUserInSupabase({
    required String userId,
    required String orgId,
    required String fullName,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? employeeCode,
    String? designation,
    String? department,
    bool? useDefaultOffice,
    String? assignedOfficeId,
    String? actorUserId,
  }) async {
    if (!_isInitialized || client == null || !_isValidUuid(userId))
      return false;

    try {
      final updates = <String, dynamic>{
        'full_name': fullName,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (email != null && email.trim().isNotEmpty) updates['email'] = email.trim();
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (role != null) updates['role'] = role.nameString;

      await client!.from('users').update(updates).eq('id', userId);

      final empUpdates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (employeeCode != null && employeeCode.isNotEmpty) {
        empUpdates['employee_code'] = employeeCode;
      }
      if (designation != null) empUpdates['designation'] = designation;
      if (department != null) empUpdates['department'] = department;
      if (useDefaultOffice != null)
        empUpdates['use_default_office'] = useDefaultOffice;
      if (assignedOfficeId != null) {
        empUpdates['assigned_office_id'] =
            _isValidUuid(assignedOfficeId) ? assignedOfficeId : null;
      }

      await client!.from('employees').update(empUpdates).eq('user_id', userId);

      if (_isValidUuid(orgId)) {
        await logActivity(
          orgId: orgId,
          actorUserId: _isValidUuid(actorUserId) ? actorUserId : null,
          targetUserId: userId,
          action: ActivityLogAction.employeeUpdated.dbValue,
          details: {'updated_name': fullName, 'role': role?.nameString},
        );
      }

      return true;
    } catch (e) {
      debugPrint('Supabase updateUserInSupabase error: $e');
      return false;
    }
  }

  /// Sync all cloud offices and employees down to LocalDatabaseService
  Future<void> syncCloudDataToLocal() async {
    if (!_isInitialized || client == null) return;
    try {
      final cloudOffices = await fetchOfficesFromSupabase();
      if (cloudOffices.isNotEmpty) {
        LocalDatabaseService().setOffices(cloudOffices);
      }

      final cloudEmployees = await fetchEmployeesFromSupabase();
      LocalDatabaseService().setEmployees(cloudEmployees);
    } catch (e) {
      debugPrint('Supabase syncCloudDataToLocal note: $e');
    }
  }

  /// Activate or Disable User
  Future<bool> setUserActiveStatus({
    required String userId,
    required String orgId,
    required bool isActive,
    String? actorUserId,
  }) async {
    if (!_isInitialized || client == null || !_isValidUuid(userId))
      return false;

    try {
      await client!.from('users').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (_isValidUuid(orgId)) {
        await logActivity(
          orgId: orgId,
          actorUserId: _isValidUuid(actorUserId) ? actorUserId : null,
          targetUserId: userId,
          action: isActive
              ? ActivityLogAction.employeeActivated.dbValue
              : ActivityLogAction.employeeDisabled.dbValue,
          details: {'is_active': isActive},
        );
      }

      return true;
    } catch (e) {
      debugPrint('Supabase setUserActiveStatus error: $e');
      return false;
    }
  }

  /// Soft Delete User
  Future<bool> softDeleteUser({
    required String userId,
    String? email,
    required String orgId,
    String? actorUserId,
  }) async {
    if (!_isInitialized || client == null) return false;

    try {
      final now = DateTime.now().toIso8601String();
      String? actualUuid;

      if (_isValidUuid(userId)) {
        actualUuid = userId;
      } else {
        try {
          final userRow = await client!
              .from('users')
              .select('id')
              .eq('firebase_uid', userId)
              .maybeSingle();
          if (userRow != null && userRow['id'] != null) {
            actualUuid = userRow['id'].toString();
          }
        } catch (_) {}
      }

      if (actualUuid == null && email != null && email.trim().isNotEmpty) {
        try {
          final userRow = await client!
              .from('users')
              .select('id')
              .eq('email', email.trim().toLowerCase())
              .maybeSingle();
          if (userRow != null && userRow['id'] != null) {
            actualUuid = userRow['id'].toString();
          }
        } catch (_) {}
      }

      if (actualUuid == null && userId.contains('@')) {
        try {
          final userRow = await client!
              .from('users')
              .select('id')
              .eq('email', userId.trim().toLowerCase())
              .maybeSingle();
          if (userRow != null && userRow['id'] != null) {
            actualUuid = userRow['id'].toString();
          }
        } catch (_) {}
      }

      final targetEmail = (email ?? '').trim().toLowerCase();

      // 1. Update Users Table (is_deleted: true, is_active: false)
      if (actualUuid != null && _isValidUuid(actualUuid)) {
        try {
          await client!
              .from('users')
              .update({'is_deleted': true, 'is_active': false})
              .eq('id', actualUuid);
        } catch (e) {
          debugPrint('softDeleteUser users by id error: $e');
        }
      }
      if (userId.isNotEmpty) {
        try {
          await client!
              .from('users')
              .update({'is_deleted': true, 'is_active': false})
              .eq('firebase_uid', userId);
        } catch (e) {
          debugPrint('softDeleteUser users by firebase_uid error: $e');
        }
        if (userId.contains('@')) {
          try {
            await client!
                .from('users')
                .update({'is_deleted': true, 'is_active': false})
                .eq('email', userId.trim().toLowerCase());
          } catch (_) {}
        }
      }
      if (targetEmail.isNotEmpty) {
        try {
          await client!
              .from('users')
              .update({'is_deleted': true, 'is_active': false})
              .eq('email', targetEmail);
        } catch (e) {
          debugPrint('softDeleteUser users by email error: $e');
        }
      }

      // 2. Update Employees Table (is_deleted: true, is_active: false)
      if (actualUuid != null && _isValidUuid(actualUuid)) {
        try {
          await client!
              .from('employees')
              .update({'is_deleted': true, 'is_active': false})
              .eq('user_id', actualUuid);
        } catch (e) {
          debugPrint('softDeleteUser employees by user_id error: $e');
        }
        try {
          await client!
              .from('employees')
              .update({'is_deleted': true, 'is_active': false})
              .eq('id', actualUuid);
        } catch (e) {
          debugPrint('softDeleteUser employees by id error: $e');
        }
      }
      if (userId.isNotEmpty) {
        try {
          await client!
              .from('employees')
              .update({'is_deleted': true, 'is_active': false})
              .eq('user_id', userId);
        } catch (_) {}
        try {
          await client!
              .from('employees')
              .update({'is_deleted': true, 'is_active': false})
              .eq('id', userId);
        } catch (_) {}
        try {
          await client!
              .from('employees')
              .update({'is_deleted': true, 'is_active': false})
              .eq('employee_code', userId);
        } catch (_) {}
        if (userId.contains('@')) {
          try {
            await client!
                .from('employees')
                .update({'is_deleted': true, 'is_active': false})
                .eq('email', userId.trim().toLowerCase());
          } catch (_) {}
        }
      }
      if (targetEmail.isNotEmpty) {
        try {
          await client!
              .from('employees')
              .update({'is_deleted': true, 'is_active': false})
              .eq('email', targetEmail);
        } catch (_) {}
      }

      if (_isValidUuid(orgId)) {
        await logActivity(
          orgId: orgId,
          actorUserId: _isValidUuid(actorUserId) ? actorUserId : null,
          targetUserId: actualUuid,
          action: ActivityLogAction.employeeDeleted.dbValue,
          details: {'soft_deleted_at': now, 'target_id': userId, 'email': email},
        );
      }

      return true;
    } catch (e) {
      debugPrint('Supabase softDeleteUser error: $e');
      return false;
    }
  }

  /// Execute Organization Ownership Transfer RPC
  Future<bool> transferOrganizationOwnership({
    required String orgId,
    required String currentSuperAdminId,
    required String targetAdminId,
  }) async {
    if (!_isInitialized || client == null || !_isValidUuid(orgId)) return false;

    try {
      final response =
          await client!.rpc('transfer_organization_ownership', params: {
        'p_org_id': orgId,
        'p_current_super_admin_id': currentSuperAdminId,
        'p_target_admin_id': targetAdminId,
      });

      return response == true;
    } catch (e) {
      debugPrint('Supabase transferOrganizationOwnership RPC error: $e');
      return false;
    }
  }

  /// Bind Device to User
  Future<bool> bindDevice({
    required String userId,
    required String deviceHardwareId,
    String? deviceModel,
    String? osVersion,
  }) async {
    if (!_isInitialized || client == null) return false;

    try {
      String? targetUuid = _isValidUuid(userId) ? userId : null;

      // If userId is a Firebase UID, resolve or auto-provision Supabase UUID
      if (targetUuid == null) {
        targetUuid = await ensureEmployeeExistsInCloud(userId, '');
      }

      if (targetUuid == null || !_isValidUuid(targetUuid)) {
        debugPrint(
            'Supabase bindDevice note: No valid user UUID found for $userId. Skipping cloud device binding.');
        return false;
      }

      final payload = {
        'user_id': targetUuid,
        'device_hardware_id': deviceHardwareId,
        'device_model': deviceModel ?? 'Unknown Device',
        'os_version': osVersion ?? 'Unknown OS',
        'is_active': true,
        'last_active': DateTime.now().toIso8601String(),
      };

      await client!
          .from('devices')
          .upsert(payload, onConflict: 'device_hardware_id');
      return true;
    } catch (e) {
      debugPrint('Supabase bindDevice error: $e');
      return false;
    }
  }

  /// Log Administrative Activity Audit Entry
  Future<void> logActivity({
    required String orgId,
    String? actorUserId,
    String? targetUserId,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    if (!_isInitialized || client == null || !_isValidUuid(orgId)) return;

    try {
      final payload = {
        'organization_id': orgId,
        'actor_user_id': _isValidUuid(actorUserId) ? actorUserId : null,
        'target_user_id': _isValidUuid(targetUserId) ? targetUserId : null,
        'action': action,
        'details': details ?? {},
        'created_at': DateTime.now().toIso8601String(),
      };

      await client!.from('activity_logs').insert(payload);
    } catch (e) {
      debugPrint('Supabase logActivity note: $e');
    }
  }

  /// Upload captured selfie / verification photo to Supabase Storage bucket 'attendance_photos'
  Future<String?> uploadAttendancePhotoData({
    required String photoDataOrPath,
    required String recordId,
  }) async {
    if (!_isInitialized || client == null) return null;

    try {
      final fileName =
          'attendance_${recordId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'photos/$fileName';

      Uint8List bytes;
      if (!kIsWeb && File(photoDataOrPath).existsSync()) {
        bytes = await File(photoDataOrPath).readAsBytes();
      } else {
        String cleanData = photoDataOrPath;
        if (cleanData.contains(',')) {
          cleanData = cleanData.split(',').last;
        }
        bytes = base64Decode(cleanData.trim());
      }

      await client!.storage.from('attendance_photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', cacheControl: '3600', upsert: true),
          );

      final publicUrl =
          client!.storage.from('attendance_photos').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Supabase Storage upload note: $e');
      return null;
    }
  }

  /// Helper to guarantee that a valid employee record exists in public.employees in Supabase
  Future<String?> ensureEmployeeExistsInCloud(
      String employeeIdOrUid, String employeeName) async {
    if (!_isInitialized || client == null) return null;

    try {
      // 1. Check if employeeIdOrUid is a valid UUID in public.employees(id)
      if (_isValidUuid(employeeIdOrUid)) {
        final existingEmp = await client!
            .from('employees')
            .select('id')
            .eq('id', employeeIdOrUid)
            .maybeSingle();

        if (existingEmp != null && existingEmp['id'] != null) {
          return existingEmp['id'].toString();
        }

        // Check if employeeIdOrUid is a valid user_id in public.employees(user_id)
        final empByUser = await client!
            .from('employees')
            .select('id')
            .eq('user_id', employeeIdOrUid)
            .maybeSingle();

        if (empByUser != null && empByUser['id'] != null) {
          return empByUser['id'].toString();
        }
      }

      // 2. Resolve user_id from public.users by firebase_uid or id
      String? userUuid;
      if (_isValidUuid(employeeIdOrUid)) {
        userUuid = employeeIdOrUid;
      } else {
        final userByFirebase = await client!
            .from('users')
            .select('id')
            .eq('firebase_uid', employeeIdOrUid)
            .maybeSingle();

        if (userByFirebase != null && userByFirebase['id'] != null) {
          userUuid = userByFirebase['id'].toString();
        }
      }

      // 3. If user found, check if employee row exists for this user_id
      if (userUuid != null) {
        final empByUser = await client!
            .from('employees')
            .select('id')
            .eq('user_id', userUuid)
            .maybeSingle();

        if (empByUser != null && empByUser['id'] != null) {
          return empByUser['id'].toString();
        }
      }

      // 4. Auto-provision user + employee in cloud if missing
      final localOrg = LocalDatabaseService().organization;
      final orgId = localOrg?.id ?? '00000000-0000-0000-0000-000000000001';
      final validOrgId = await ensureOrganizationExistsInCloud(orgId) ?? orgId;
      final currentUser = LocalDatabaseService().currentUser;

      final targetFirebaseUid = _isValidUuid(employeeIdOrUid)
          ? 'user_${_uuid.v4()}'
          : employeeIdOrUid;

      final createdUser = await createUserInSupabase(
        firebaseUid: targetFirebaseUid,
        orgId: validOrgId,
        email: currentUser?.email ?? 'user@enterprise.com',
        fullName: employeeName.isNotEmpty
            ? employeeName
            : (currentUser?.fullName ?? 'Field Employee'),
        phoneNumber: currentUser?.phoneNumber,
        role: currentUser?.role ?? UserRole.employee,
        requiresPasswordChange: false,
        employeeCode:
            'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        designation: 'Field Engineer',
        department: 'Operations',
      );

      if (createdUser != null) {
        final createdEmp = await client!
            .from('employees')
            .select('id')
            .eq('user_id', createdUser.id)
            .maybeSingle();

        if (createdEmp != null && createdEmp['id'] != null) {
          return createdEmp['id'].toString();
        }
        return createdUser.id;
      }
    } catch (e) {
      debugPrint('ensureEmployeeExistsInCloud note: $e');
    }

    // 5. Fallback: Any active employee in employees table
    try {
      final anyEmp = await client!
          .from('employees')
          .select('id')
          .eq('is_deleted', false)
          .limit(1)
          .maybeSingle();

      if (anyEmp != null && anyEmp['id'] != null) {
        return anyEmp['id'].toString();
      }
    } catch (_) {}

    return null;
  }

  /// Insert attendance record entry into Supabase
  Future<bool> insertAttendanceEntry({
    required AttendanceRecord record,
    String? photoPublicUrl,
  }) async {
    if (!_isInitialized || client == null) return false;

    try {
      final localOrg = LocalDatabaseService().organization;
      final orgId = localOrg?.id ?? '00000000-0000-0000-0000-000000000001';
      final validOrgId = await ensureOrganizationExistsInCloud(orgId) ?? orgId;
      final validEmployeeId = await ensureEmployeeExistsInCloud(
          record.employeeId, record.employeeName);

      if (validEmployeeId == null) {
        debugPrint(
            'Supabase insertAttendanceEntry note: No valid employee record found in cloud for ${record.employeeId}');
        return false;
      }

      final payload = <String, dynamic>{
        if (_isValidUuid(record.id)) 'id': record.id,
        'organization_id': validOrgId,
        'employee_id': validEmployeeId,
        'employee_name': record.employeeName,
        'workflow_step': record.workflowStep.name,
        'event_timestamp': record.eventTimestamp.toIso8601String(),
        'latitude': record.latitude,
        'longitude': record.longitude,
        'is_geofence_valid': record.isGeofenceValid,
        'photo_url': photoPublicUrl ??
            (record.photoBase64.isNotEmpty ? record.photoBase64 : null),
        'address': record.address,
        if (record.officeId != null && record.officeId!.isNotEmpty && _isValidUuid(record.officeId))
          'office_id': record.officeId,
        if (record.workSiteId != null && record.workSiteId!.isNotEmpty && _isValidUuid(record.workSiteId))
          'work_site_id': record.workSiteId,
        if (record.siteName != null && record.siteName!.isNotEmpty)
          'site_name': record.siteName,
        'device_id': record.deviceId.isEmpty ? 'DEV-CLIENT' : record.deviceId,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await client!.from('attendance_records').upsert(payload);
        return true;
      } catch (e) {
        final errStr = e.toString();
        // Fallback: If site_name column is missing in user's Supabase table schema (PGRST204), retry without site_name
        if (errStr.contains('site_name') || errStr.contains('PGRST204')) {
          payload.remove('site_name');
          try {
            await client!.from('attendance_records').upsert(payload);
            return true;
          } catch (retryErr) {
            debugPrint('Supabase DB insert retry error: $retryErr');
            return false;
          }
        }
        debugPrint('Supabase DB insert note: $e');
        return false;
      }
    } catch (outerErr) {
      debugPrint('Supabase insertAttendanceEntry outer error: $outerErr');
      return false;
    }
  }

  /// Fetch all attendance records from Supabase cloud database
  Future<List<AttendanceRecord>> fetchAttendanceRecordsFromSupabase() async {
    if (!_isInitialized || client == null) return [];
    try {
      final List<dynamic> response = await client!
          .from('attendance_records')
          .select()
          .order('event_timestamp', ascending: false);

      final List<AttendanceRecord> records = [];
      for (final json in response) {
        try {
          final map = Map<String, dynamic>.from(json);
          final rec = AttendanceRecord.fromJson(map);
          records.add(rec.copyWith(syncStatus: SyncStatus.synced));
        } catch (e) {
          debugPrint('Supabase parse attendance record error: $e');
        }
      }
      return records;
    } catch (e) {
      debugPrint('Supabase fetchAttendanceRecordsFromSupabase note: $e');
      return [];
    }
  }
}
