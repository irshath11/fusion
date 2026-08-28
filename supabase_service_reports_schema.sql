-- ==========================================================
-- FUSION ELECTRO MECHANICAL - SERVICE REPORTS SCHEMA
-- Run this script in your Supabase SQL Editor
-- ==========================================================

-- 1. Create service_reports table
CREATE TABLE IF NOT EXISTS public.service_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ref_number TEXT UNIQUE NOT NULL,
  job_no TEXT,
  property_details TEXT,
  contact_name TEXT,
  contact_number TEXT,
  location TEXT,
  call_type TEXT,
  priority TEXT,
  performance_rating TEXT,
  housekeeping_completed TEXT,
  technician_name TEXT,
  engineer_name TEXT,
  supervisor_name TEXT,
  customer_name TEXT,
  report_data JSONB NOT NULL,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create index for fast reference number ordering
CREATE INDEX IF NOT EXISTS idx_service_reports_ref_number ON public.service_reports (ref_number DESC);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.service_reports ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies (Allow authenticated and anon employees to insert & read service reports)
CREATE POLICY "Allow public read access to service_reports"
  ON public.service_reports FOR SELECT
  USING (true);

CREATE POLICY "Allow public insert access to service_reports"
  ON public.service_reports FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow public update access to service_reports"
  ON public.service_reports FOR UPDATE
  USING (true);
