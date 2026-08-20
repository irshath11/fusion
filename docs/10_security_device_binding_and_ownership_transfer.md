# 10. Hardware Device Binding & Organization Ownership Transfer Feature

## Overview
The **Hardware Device Binding & Organization Ownership Transfer** feature provides enterprise security controls, device hardware fingerprinting, hardware binding enforcement, and atomic organization ownership transfer capabilities.

---

## 1. Key Functionalities

### A. Hardware Device Binding & Fingerprinting (`DeviceBindingService`)
1. **Multi-Platform Hardware Identification**:
   - Leverages `device_info_plus` package to extract platform-native hardware identifiers:
     - **Android**: `androidInfo.id`, manufacturer, model, OS release version.
     - **iOS**: `iosInfo.identifierForVendor`, device model, iOS version.
     - **Windows**: `windowsInfo.deviceId`, computer name, Windows OS build.
     - **Web**: `webInfo.userAgent`, browser name, platform.

2. **Supabase Hardware Device Registration**:
   - Automatically registers hardware fingerprint into the Supabase `devices` table upon user authentication via `SupabaseService.bindDevice()`.
   - Records hardware ID (`device_hardware_id`), device model, OS version, active status, and `last_active` timestamp.
   - Prevents unauthorized device spoofing and enforces enterprise device access compliance.

---

### B. Atomic Organization Ownership Transfer Engine
1. **Super Admin Re-Authentication**:
   - Initiating ownership transfer requires the active Super Admin to re-enter their current password for identity verification via `Firebase_Auth` re-authentication credentials (`EmailAuthProvider.credential`).

2. **Atomic Database RPC Procedure (`transfer_organization_ownership`)**:
   - Invokes PostgreSQL stored procedure `transfer_organization_ownership(p_org_id, p_current_super_admin_id, p_target_admin_id)`.
   - Executes within a single atomic database transaction:
     1. Verifies that `p_current_super_admin_id` holds active `SUPER_ADMIN` role.
     2. Verifies that `p_target_admin_id` holds active `ADMIN` role.
     3. Promotes Target Administrator to `SUPER_ADMIN` (`role = 'SUPER_ADMIN'`).
     4. Demotes Current Super Admin to Administrator (`role = 'ADMIN'`).
     5. Records audit log event `OWNERSHIP_TRANSFERRED` in `activity_logs` with previous and new super admin metadata.

3. **Immediate Local Session Update**:
   - Updates local Hive `currentUserBox` profile to reflect the demoted `ADMIN` role for the current session.
   - Displays immediate success feedback and updates dashboard access controls.

---

## 2. Technical Implementation Architecture & Data Schema

### Stored Procedure (`transfer_organization_ownership`)
```sql
CREATE OR REPLACE FUNCTION public.transfer_organization_ownership(
    p_org_id UUID,
    p_current_super_admin_id UUID,
    p_target_admin_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify current super admin role
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_current_super_admin_id AND role = 'SUPER_ADMIN') THEN
        RAISE EXCEPTION 'Only an active SUPER_ADMIN can initiate an ownership transfer.';
    END IF;

    -- Update Target Admin -> SUPER_ADMIN
    UPDATE public.users SET role = 'SUPER_ADMIN', updated_at = CURRENT_TIMESTAMP WHERE id = p_target_admin_id;

    -- Demote Previous Super Admin -> ADMIN
    UPDATE public.users SET role = 'ADMIN', updated_at = CURRENT_TIMESTAMP WHERE id = p_current_super_admin_id;

    -- Log Audit Trail
    INSERT INTO public.activity_logs (organization_id, actor_user_id, target_user_id, action, details)
    VALUES (p_org_id, p_current_super_admin_id, p_target_admin_id, 'OWNERSHIP_TRANSFERRED', jsonb_build_object('timestamp', CURRENT_TIMESTAMP));

    RETURN TRUE;
END;
$$;
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/security/device_binding_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/security/device_binding_service.dart) | Device fingerprinting service extracting hardware IDs across Android, iOS, Windows, and Web. |
| [`lib/features/admin/presentation/ownership_transfer_cubit.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/ownership_transfer_cubit.dart) | Cubit managing Super Admin password re-authentication and atomic RPC execution. |
| [`lib/features/admin/presentation/ownership_transfer_dialog.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/admin/presentation/ownership_transfer_dialog.dart) | Modal dialog for selecting target administrator and entering re-authentication credentials with show/hide password toggles. |
| [`backend/supabase_schema.sql`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/backend/supabase_schema.sql) | SQL schema defining `devices` table and `transfer_organization_ownership` PL/pgSQL function. |
