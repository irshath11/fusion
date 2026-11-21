-- ==============================================================================
-- ADD BYPASS_GEOFENCE COLUMNS TO USERS & EMPLOYEES IN SUPABASE
-- Run this script in the Supabase SQL Editor to enable direct column support
-- ==============================================================================

-- 1. Add bypass_geofence column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS bypass_geofence BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Add bypass_geofence column to employees table
ALTER TABLE public.employees 
ADD COLUMN IF NOT EXISTS bypass_geofence BOOLEAN NOT NULL DEFAULT FALSE;

-- 3. Update comments and grant permissions for standard authenticated / service roles
COMMENT ON COLUMN public.users.bypass_geofence IS 'Whether this user can bypass geofence checks (check in from anywhere)';
COMMENT ON COLUMN public.employees.bypass_geofence IS 'Whether this employee can bypass geofence checks (check in from anywhere)';
