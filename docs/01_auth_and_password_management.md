# 01. Authentication & Password Management Feature

## Overview
The **Authentication & Password Management** feature governs identity verification, role-based access control (Super Admin vs. Employee), initial account setup with temporary passwords, forced initial password changes for privacy, self-service password updates, and session management.

---

## 1. Key Functionalities

1. **Role-Based Authentication**:
   - **Super Admin**: Manages organization settings, office stations, employee accounts, live GPS tracking, and company reports.
   - **Employee**: Accesses daily 4-step workflow dashboard, captures selfie/location verification, tracks attendance history, and manages credentials.

2. **Temporary Password Onboarding**:
   - When an Admin creates a new employee account, a temporary password (e.g., `aa123456` or `TempPass123!`) is assigned.
   - The user profile is created in Firebase Authentication, and a record is inserted into Supabase with `requires_password_change = true`.

3. **Forced First-Time Password Change**:
   - Upon entering valid credentials with temporary password, the system detects `requiresPasswordChange == true`.
   - The employee is automatically routed to `ForcePasswordChangeScreen` before gaining access to any dashboard or workforce features.
   - The employee enters a new secure private password. The password is updated in Firebase Authentication and `requires_password_change` is updated to `false` in Supabase.

4. **Self-Service Password Management**:
   - Employees can update their private password at any time via the **Change Password** icon (`lock_reset`) located in the AppBar of the Employee Dashboard.

5. **Strict Authentication Security**:
   - Bypasses fallback demo accounts. All logins authenticate strictly against Firebase Authentication.
   - Catches `FirebaseAuthException` codes (`wrong-password`, `invalid-credential`, `user-not-found`, `user-disabled`) and presents clear, user-friendly error feedback.

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
         ┌─────────────────────┴─────────────────────┐
         │ (Firebase Auth Success)                   │ (Auth Failure)
         ▼                                           ▼
Fetch Supabase Profile                     ┌───────────────────┐
         │                                 │     AuthError     │
  requiresPasswordChange == true?          └───────────────────┘
    ├── YES ──► Emit `RequiresPasswordChangeState` ──► Navigates to `ForcePasswordChangeScreen`
    └── NO  ──► Emit `Authenticated`               ──► Navigates to Dashboard
```

---

## 4. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/auth/domain/user_entity.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/domain/user_entity.dart) | User model, roles, and JSON serialization. |
| [`lib/features/auth/presentation/auth_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/presentation/auth_cubit.dart) | BLoC controller managing login, sign-out, session restoration, and password change logic. |
| [`lib/features/auth/presentation/login_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/presentation/login_screen.dart) | Clean, responsive login user interface with email/password validation & password visibility toggles. |
| [`lib/features/auth/presentation/force_password_change_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/auth/presentation/force_password_change_screen.dart) | Mandatory password setup screen shown on first login with temporary password. |
