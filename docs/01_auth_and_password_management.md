# 01. Authentication & Password Management Feature

## Overview
The **Authentication & Password Management** feature governs identity verification, dual-layer authentication (Firebase Authentication primary + Local Hive Database fallback), role-based access control (Super Admin vs. Employee), initial account setup with temporary passwords, forced initial password changes for privacy, self-service password updates, universal password visibility toggles, and session management.

---

## 1. Key Functionalities

1. **Role-Based Authentication**:
   - **Super Admin**: Manages organization settings, office stations, employee accounts, live GPS tracking, and company reports.
   - **Employee**: Accesses daily workflow dashboard, captures selfie/location verification, tracks attendance history, and manages credentials.

2. **Dual-Layer Authentication Engine (`AuthCubit`)**:
   - **Primary (Firebase Auth)**: Authenticates user credentials via `FirebaseAuth.instance.signInWithEmailAndPassword`. On success, syncs profile from Supabase or assigns fallback role profile.
   - **Fallback (Local & Demo Database)**: If Firebase Authentication returns an exception (e.g., `invalid-credential`, `user-not-found`, `wrong-password`, or offline mode), `AuthCubit` evaluates the credentials against:
     1. **Super Admin Profile**: Stored in Hive `app_settings` box (`_db.organization.superAdminPassword`), as well as demo super admin accounts (`sr.irshath@gmail.com`, `admin@apexlogistics.com`).
     2. **Local Employee Directory**: Stored in local Hive database (`_db.getEmployees()`) matching by email or employee code.
   - An `AuthError` is presented to the user only when both Firebase Authentication and local database fallback checks fail.

3. **Universal Password Visibility Toggles**:
   - All password input fields across the application are equipped with an interactive eye icon toggle button (`Icons.visibility_outlined` / `Icons.visibility_off_outlined`).
   - Powered by `CustomTextField` (converted to a `StatefulWidget`) and implemented across:
     - **Login Screen** (`login_screen.dart`)
     - **First-Time Setup Wizard** (`setup_wizard_screen.dart`)
     - **Force Password Change Screen** (`force_password_change_screen.dart`)
     - **User Creation Form Dialog** (`user_form_dialog.dart`)
     - **Ownership Transfer Dialog** (`ownership_transfer_dialog.dart`)
     - **Employee Dashboard Change Password Dialog** (`employee_dashboard_screen.dart`)

4. **Temporary Password Onboarding**:
   - When an Admin creates a new employee account, a temporary password (e.g., `TempPass123!`) is assigned.
   - The user profile is created in Firebase Authentication, and a record is inserted into Supabase with `requires_password_change = true`.

5. **Forced First-Time Password Change**:
   - Upon entering valid credentials with a temporary password, the system detects `requiresPasswordChange == true`.
   - The employee is automatically routed to `ForcePasswordChangeScreen` before gaining access to any dashboard or workforce features.
   - The employee enters a new secure private password with live visibility toggle support. The password is updated in Firebase Authentication and `requires_password_change` is set to `false` in Supabase.

6. **Self-Service Password Management**:
   - Employees can update their private password at any time via the **Change Password** icon (`lock_reset`) located in the AppBar of the Employee Dashboard, featuring show/hide password visibility toggles on all 3 input fields (Current, New, and Confirm Password).

---

## 2. Technical Implementation & Data Structures

### Data Models (`UserEntity` & `UserRole`)
```dart
enum UserRole { superAdmin, employee }

class UserEntity {
  final String id;
  final String firebaseUid;
  final String email;
  final String fullName;
  final UserRole role;
  final String organizationId;
  final bool requiresPasswordChange;
  final bool isActive;

  UserEntity({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.organizationId,
    this.requiresPasswordChange = false,
    this.isActive = true,
  });
}
```

---

## 3. Login & Password Change State Machine (`AuthCubit`)

```
                 ┌───────────────────────────┐
                 │       Initial State       │
                 └─────────────┬─────────────┘
                               │
                      loginWithEmailAndPassword()
                               │
                               ▼
                 ┌───────────────────────────┐
                 │        AuthLoading        │
                 └─────────────┬─────────────┘
                               │
                               ▼
                Try Firebase Authentication
                               │
            ┌──────────────────┴──────────────────┐
            │                                     │
   (Firebase Success)                   (Firebase Auth Error / Exception)
            │                                     │
   Fetch Supabase Profile                 Check Local Hive Database & Demo Fallbacks
            │                                     │
            ├─────────────────────────────────────┤
            │                                     │
   (Valid Credentials)                   (Invalid Credentials)
            │                                     │
            ▼                                     ▼
requiresPasswordChange == true?         ┌───────────────────┐
  ├── YES ──► Emit `RequiresPassword...`│     AuthError     │
  └── NO  ──► Emit `Authenticated`      └───────────────────┘
```

---

## 4. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/auth/domain/user_entity.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/domain/user_entity.dart) | User model, roles, and JSON serialization. |
| [`lib/features/auth/presentation/auth_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/presentation/auth_cubit.dart) | BLoC controller managing dual-layer login, fallback authentication, session restoration, and password changes. |
| [`lib/core/widgets/custom_text_field.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/widgets/custom_text_field.dart) | Stateful text input widget with built-in password show/hide visibility toggle buttons. |
| [`lib/features/auth/presentation/login_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/presentation/login_screen.dart) | Clean, responsive login user interface with email/password validation & password visibility toggles. |
| [`lib/features/auth/presentation/force_password_change_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/presentation/force_password_change_screen.dart) | Mandatory password setup screen shown on first login with temporary password. |
