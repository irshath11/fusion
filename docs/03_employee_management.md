# 03. Employee Management & Role Assignment Feature

## Overview
The **Employee Management** feature empowers Super Admins and Administrators to provision, update, assign roles (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`), activate, deactivate, and remove workforce accounts. It features secondary app authentication creation to keep Admin sessions active while provisioning new credentials, assignable office stations, custom office overrides, and automatic database synchronization across Hive and Supabase.

---

## 1. Key Functionalities

1. **User & Employee Provisioning**:
   - Captures Full Name, Employee Code (e.g., `EMP-1002`), Email Address, Mobile Number, Designation, and Department.
   - Assigns temporary password (e.g. `aa123456`).
   - Assigns role (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`).
   - Assigns specific Office Station or enables Default Office Station.

2. **Secondary Firebase App Instance Credential Registration**:
   - To prevent the active Super Admin/Admin session from being signed out when calling `createUserWithEmailAndPassword`, the cubit initializes an isolated `SecondaryAuthApp` Firebase instance (`FirebaseAuth.instanceFor(app: secondaryApp)`).
   - Registers employee credentials in Firebase Auth and updates `displayName`.
   - Catches `FirebaseAuthException` codes (e.g., `weak-password`, `email-already-in-use`) and surfaces explicit error feedback to the Admin.

3. **Multi-Table Relational Schema Sync**:
   - Creates a user record in Supabase `users` with specified role and `requires_password_change = true`.
   - Creates an employee detail record in Supabase `employees` linked by `user_id`.
   - Saves record locally in Hive `employeesBox` and `usersBox` for instant local UI rendering.

4. **Employee Lifecycle & Custom Office Assignment**:
   - **Edit Employee**: Updates Designation, Department, Phone, & Assigned Office.
   - **Custom Office Override**: Supports `useDefaultOffice: false` to bind specific field personnel to custom client branch stations or depots.
   - **Active/Inactive Toggle**: Toggles `isActive`. Inactive employees are blocked from logging into the mobile application.
   - **Password Reset**: Admin can trigger password resets for staff members.
   - **Audit Activity Logging**: Records `EMPLOYEE_CREATED`, `EMPLOYEE_UPDATED`, `EMPLOYEE_DISABLED`, `EMPLOYEE_ACTIVATED`, and `EMPLOYEE_DELETED` in `activity_logs`.

5. **Official Portrait Photo Directory & Avatars**:
   - Every employee badge is mapped to high-resolution official portrait photos stored in `assets/images/employees/` (mirrored in `web/assets/images/employees/` for web admin).
   - Supported badges include `1004`, `1008`, `1012`, `1021`, `1024`, `1031`, `1036`, `1038`, `1047`, `1048`, `1049`, `1054`, `1056`, `1057`, `1058`, `1059`, `1060`, and North branch codes `N-1003` through `N-1013`.
   - The [`EmployeeAvatar`](../lib/core/widgets/employee_avatar.dart) widget automatically resolves image assets by employee code, with seamless fallback to stylized monogram initials.

6. **Identity Reconciliation Helper (`EmployeeDirectoryHelper`)**:
   - Normalizes employee names, badge numbers, and department codes.
   - Reconciles historical attendance and timesheet entries across variant formats (`1004` vs `N-1004`, case-insensitive names, stripped whitespace).

7. **Employee Statutory Cards & Passes Linkage**:
   - Each employee profile is directly linked to their active statutory documents (Emirates ID, Visa, Passport, Insurance, MOPA, CISPA, Custom passes) in the `employee_cards` table.
   - Administrators can monitor card compliance statuses directly from the employee management screen and drill down to the Cards Manager.

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
| [`lib/features/admin/presentation/user_management_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/user_management_cubit.dart) | Cubit managing multi-role user creation via isolated Firebase secondary auth, Supabase RPC/insertions, and Hive box updates. |
| [`lib/features/admin/presentation/employee_management_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/employee_management_screen.dart) | Comprehensive UI list view, search bar, active/inactive badges, employee avatar rendering, and bottom-sheet form for adding/editing employees. |
| [`lib/features/admin/presentation/user_form_dialog.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/user_form_dialog.dart) | User creation and editing modal form with role selection dropdown (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`) and password visibility toggles. |
| [`lib/core/widgets/employee_avatar.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/widgets/employee_avatar.dart) | Widget rendering official employee portrait photos with graceful monogram fallback. |
| [`lib/core/utils/employee_directory_helper.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/utils/employee_directory_helper.dart) | Identity matching and badge normalization utility. |
| [`lib/core/constants/employee_photo_data.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/constants/employee_photo_data.dart) | Registry mapping badge codes to local asset image paths. |

