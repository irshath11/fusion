# 03. Employee Management & Role Assignment Feature

## Overview
The **Employee Management** feature empowers Super Admins to provision, update, assign, activate, and deactivate field employees and organizational staff. It features secondary app authentication creation to keep Admin sessions active while provisioning new credentials, assignable office stations, and automatic database synchronization across Hive and Supabase.

---

## 1. Key Functionalities

1. **Employee Provisioning**:
   - Captures Full Name, Employee Code (e.g., `EMP-1002`), Email Address, Mobile Number, Designation, and Department.
   - Assigns temporary password (e.g. `aa123456`).
   - Assigns specific Office Station or assigns default office.

2. **Secondary Firebase App Instance Credential Registration**:
   - To prevent the active Super Admin session from being signed out when calling `createUserWithEmailAndPassword`, the cubit initializes a isolated `SecondaryAuthApp` Firebase instance (`FirebaseAuth.instanceFor(app: secondaryApp)`).
   - Registers employee credentials in Firebase Auth and updates `displayName`.
   - Catches `FirebaseAuthException` codes (e.g., `weak-password`, `email-already-in-use`) and surfaces explicit error feedback to the Admin.

3. **Multi-Table Relational Schema Sync**:
   - Creates a user record in the Supabase `users` table with `role = 'employee'` and `requires_password_change = true`.
   - Creates an employee detail record in the Supabase `employees` table linked by `user_id`.
   - Saves record locally in Hive `employeesBox` for instant local UI rendering.

4. **Employee Lifecycle & Office Assignment**:
   - **Edit Employee**: Updates Designation, Department, Phone, & Assigned Office.
   - **Active/Inactive Toggle**: Toggles `isActive`. Inactive employees are blocked from logging into the mobile application.

---

## 2. Technical Implementation & Data Structures

### Data Model (`EmployeeEntity`)
```dart
class EmployeeEntity {
  final String id;
  final String employeeCode;
  final String name;
  final String mobileNumber;
  final String email;
  final String designation;
  final String department;
  final bool useDefaultOffice;
  final String? assignedOfficeId;
  final String? assignedOfficeName;
  final bool isActive;

  EmployeeEntity({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.mobileNumber,
    required this.email,
    required this.designation,
    required this.department,
    this.useDefaultOffice = true,
    this.assignedOfficeId,
    this.assignedOfficeName,
    this.isActive = true,
  });
}
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/admin/domain/employee_entity.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/domain/employee_entity.dart) | Domain entity for staff members. |
| [`lib/features/admin/presentation/user_management_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/user_management_cubit.dart) | Cubit managing employee creation via isolated Firebase secondary auth, Supabase RPC/insertions, and Hive box updates. |
| [`lib/features/admin/presentation/employee_management_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/employee_management_screen.dart) | Comprehensive UI list view, search bar, active/inactive badges, and bottom-sheet form for adding/editing employees. |
