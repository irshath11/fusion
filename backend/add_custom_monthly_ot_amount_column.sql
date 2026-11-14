-- ==============================================================================
-- Migration: Add custom_monthly_ot_amount to employee_salaries table
-- Allows setting a manual fixed total OT amount directly for the month (AED)
-- ==============================================================================

ALTER TABLE public.employee_salaries
ADD COLUMN IF NOT EXISTS custom_monthly_ot_amount DOUBLE PRECISION;

