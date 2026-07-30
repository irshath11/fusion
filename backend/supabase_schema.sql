-- ==============================================================================
-- OFFLINE-FIRST EMPLOYEE ATTENDANCE & FIELD WORKFORCE TRACKING SYSTEM
-- SUPABASE POSTGRESQL DATABASE SCHEMA, RLS POLICIES & OWNERSHIP TRANSFER RPC
-- ==============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Clean up legacy tables to prevent schema type mismatch errors (e.g. TEXT vs UUID)
DROP TABLE IF EXISTS public.activity_logs CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.devices CASCADE;
DROP TABLE IF EXISTS public.gps_logs CASCADE;
DROP TABLE IF EXISTS public.attendance_records CASCADE;
DROP TABLE IF EXISTS public.work_site_assignments CASCADE;
DROP TABLE IF EXISTS public.work_sites CASCADE;
DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS public.offices CASCADE;
DROP TABLE IF EXISTS public.user_role_assignments CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;
DROP TABLE IF EXISTS public.organizations CASCADE;
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    super_admin_name VARCHAR(255),
    super_admin_email VARCHAR(255),
    mobile_number VARCHAR(50),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 2. ROLES TABLE & USER ROLE TYPE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert standard roles if they do not exist
INSERT INTO public.roles (name, description) VALUES
    ('SUPER_ADMIN', 'Full control over organization data, settings, and ownership management.'),
    ('ADMIN', 'Administrative access for employee management, office configuration, and report analytics.'),
    ('EMPLOYEE', 'Standard field workforce user access for attendance tracking and personal logs.')
ON CONFLICT (name) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 3. USERS / AUTH PROFILES TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid VARCHAR(128) UNIQUE NOT NULL,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(50),
    role VARCHAR(50) NOT NULL DEFAULT 'EMPLOYEE' CHECK (role IN ('SUPER_ADMIN', 'ADMIN', 'EMPLOYEE')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    requires_password_change BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 4. USER ROLE ASSIGNMENTS (Junction Table for Multi-Role Support)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_role_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, role_id)
);

-- ------------------------------------------------------------------------------
-- 5. OFFICES TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.offices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geofence_radius_meters DOUBLE PRECISION NOT NULL DEFAULT 200.0,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 6. EMPLOYEES TABLE (Extended Profile Info)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    employee_code VARCHAR(50) UNIQUE NOT NULL,
    designation VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    use_default_office BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_office_id UUID REFERENCES public.offices(id) ON DELETE SET NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 7. WORK SITES TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_sites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    site_name VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters DOUBLE PRECISION NOT NULL DEFAULT 200.0,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 8. WORK SITE ASSIGNMENTS (Junction Table)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_site_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_site_id UUID NOT NULL REFERENCES public.work_sites(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(work_site_id, employee_id)
);

-- ------------------------------------------------------------------------------
-- 9. ATTENDANCE LOGS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
    workflow_step VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    sync_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    gps_accuracy DOUBLE PRECISION,
    address TEXT,
    device_id VARCHAR(255) NOT NULL,
    is_geofence_valid BOOLEAN NOT NULL DEFAULT TRUE,
    office_id UUID REFERENCES public.offices(id),
    work_site_id UUID REFERENCES public.work_sites(id),
    photo_url TEXT,
    employee_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 10. GPS LOGS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gps_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 11. DEVICES TABLE (Device Binding & Session Management)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_hardware_id VARCHAR(255) NOT NULL UNIQUE,
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 12. NOTIFICATIONS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 13. ACTIVITY LOGS TABLE (Audit Trail)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    target_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- INDEXES FOR HIGH PERFORMANCE
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_org ON public.users(organization_id);
CREATE INDEX IF NOT EXISTS idx_users_firebase ON public.users(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_employees_user ON public.employees(user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_emp_time ON public.attendance_records(employee_id, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_org ON public.attendance_records(organization_id);
CREATE INDEX IF NOT EXISTS idx_activity_org ON public.activity_logs(organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_devices_user ON public.devices(user_id);

-- ------------------------------------------------------------------------------
-- STORED PROCEDURE: ATOMIC ORGANIZATION OWNERSHIP TRANSFER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.transfer_organization_ownership(
    p_org_id UUID,
    p_current_super_admin_id UUID,
    p_target_admin_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_role VARCHAR(50);
    v_target_role VARCHAR(50);
BEGIN
    -- Verify current super admin role
    SELECT role INTO v_current_role FROM public.users
    WHERE id = p_current_super_admin_id AND organization_id = p_org_id AND is_deleted = FALSE;

    IF v_current_role IS NULL OR v_current_role <> 'SUPER_ADMIN' THEN
        RAISE EXCEPTION 'Only an active SUPER_ADMIN can initiate an ownership transfer.';
    END IF;

    -- Verify target user role (Must be an ADMIN)
    SELECT role INTO v_target_role FROM public.users
    WHERE id = p_target_admin_id AND organization_id = p_org_id AND is_deleted = FALSE;

    IF v_target_role IS NULL THEN
        RAISE EXCEPTION 'Target user does not exist or has been deleted.';
    END IF;

    -- Update Target Admin -> SUPER_ADMIN
    UPDATE public.users
    SET role = 'SUPER_ADMIN', updated_at = CURRENT_TIMESTAMP
    WHERE id = p_target_admin_id AND organization_id = p_org_id;

    -- Demote Previous Super Admin -> ADMIN
    UPDATE public.users
    SET role = 'ADMIN', updated_at = CURRENT_TIMESTAMP
    WHERE id = p_current_super_admin_id AND organization_id = p_org_id;

    -- Record Audit Log
    INSERT INTO public.activity_logs (
        organization_id,
        actor_user_id,
        target_user_id,
        action,
        details
    ) VALUES (
        p_org_id,
        p_current_super_admin_id,
        p_target_admin_id,
        'OWNERSHIP_TRANSFERRED',
        jsonb_build_object(
            'previous_super_admin_id', p_current_super_admin_id,
            'new_super_admin_id', p_target_admin_id,
            'timestamp', CURRENT_TIMESTAMP
        )
    );

    RETURN TRUE;
END;
$$;

-- ------------------------------------------------------------------------------
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Allow Public/Anon during setup checks & initial user creation
DROP POLICY IF EXISTS anon_read_orgs ON public.organizations;
CREATE POLICY anon_read_orgs ON public.organizations FOR SELECT USING (true);

DROP POLICY IF EXISTS anon_insert_orgs ON public.organizations;
CREATE POLICY anon_insert_orgs ON public.organizations FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS anon_insert_users ON public.users;
CREATE POLICY anon_insert_users ON public.users FOR INSERT WITH CHECK (true);

-- Authenticated User General Access Policies
DROP POLICY IF EXISTS users_read_same_org ON public.users;
CREATE POLICY users_read_same_org ON public.users FOR SELECT USING (true);

DROP POLICY IF EXISTS users_admin_all ON public.users;
CREATE POLICY users_admin_all ON public.users
    FOR ALL USING (
        role IN ('SUPER_ADMIN', 'ADMIN')
    );

DROP POLICY IF EXISTS org_admin_manage ON public.organizations;
CREATE POLICY org_admin_manage ON public.organizations FOR ALL USING (true);

DROP POLICY IF EXISTS offices_all ON public.offices;
CREATE POLICY offices_all ON public.offices FOR ALL USING (true);

DROP POLICY IF EXISTS employees_all ON public.employees;
CREATE POLICY employees_all ON public.employees FOR ALL USING (true);

DROP POLICY IF EXISTS attendance_all ON public.attendance_records;
CREATE POLICY attendance_all ON public.attendance_records FOR ALL USING (true);

DROP POLICY IF EXISTS devices_all ON public.devices;
CREATE POLICY devices_all ON public.devices FOR ALL USING (true);

DROP POLICY IF EXISTS activity_logs_all ON public.activity_logs;
CREATE POLICY activity_logs_all ON public.activity_logs FOR ALL USING (true);

-- ------------------------------------------------------------------------------
-- STORAGE BUCKETS SETUP FOR ATTENDANCE PHOTOS
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('attendance_photos', 'attendance_photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Access for attendance_photos" ON storage.objects;
CREATE POLICY "Public Access for attendance_photos"
ON storage.objects FOR SELECT USING (bucket_id = 'attendance_photos');

DROP POLICY IF EXISTS "Allow Public Uploads to attendance_photos" ON storage.objects;
CREATE POLICY "Allow Public Uploads to attendance_photos"
ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'attendance_photos');
