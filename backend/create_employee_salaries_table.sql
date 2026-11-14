-- ==============================================================================
-- FUSION & NEO WORKFORCE SALARY MANAGEMENT & PAYROLL SCHEMA
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.employee_salaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    employee_code VARCHAR(50) NOT NULL UNIQUE,
    employee_id VARCHAR(100),
    employee_name VARCHAR(255) NOT NULL,
    department VARCHAR(100) NOT NULL DEFAULT 'General',
    fixed_salary DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    variable_salary DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    daily_divisor DOUBLE PRECISION NOT NULL DEFAULT 30.0,
    standard_daily_hours DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    custom_ot_hourly_rate DOUBLE PRECISION,
    custom_monthly_ot_amount DOUBLE PRECISION,
    ot_included_in_variable BOOLEAN NOT NULL DEFAULT FALSE,
    pay_sunday_if_monday_worked BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- RLS Policies
ALTER TABLE public.employee_salaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to read employee salaries"
    ON public.employee_salaries FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow admins and super admins to insert/update employee salaries"
    ON public.employee_salaries FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.firebase_uid = auth.uid()::text
            AND users.role IN ('ADMIN', 'SUPER_ADMIN')
        )
    );

-- Seed initial master salaries for Fusion and Neo Divisions
INSERT INTO public.employee_salaries (employee_code, employee_name, department, fixed_salary, variable_salary, ot_included_in_variable)
VALUES
    -- Fusion Division
    ('1004', 'Mohammed Iburahim Baseer Ahamed', 'Fusion', 2000.0, 4000.0, true),
    ('1008', 'Ibramsha Sathar Sathar', 'Fusion', 1500.0, 1500.0, true),
    ('1012', 'Raja Mohammed Mohammed Ali', 'Fusion', 1500.0, 1100.0, false),
    ('1021', 'Mohamed Azarudheen Anvar Ali', 'Fusion', 1000.0, 800.0, false),
    ('1024', 'Ramesh Gopal Gopal', 'Fusion', 1500.0, 500.0, false),
    ('1031', 'Mohamed Rifaye Abdul Jabar Abdul Jabar', 'Fusion', 1000.0, 500.0, true),
    ('1036', 'Mahatheer Mohamed Jamal Mohamed Jamal Mohamed', 'Fusion', 1500.0, 1500.0, false),
    ('1038', 'Mohamed Ali Shaik Mohamed Mohamed Ali', 'Fusion', 1500.0, 700.0, false),
    ('1047', 'Ramakrishnan Kulangaravalappil Kuttan', 'Fusion', 1200.0, 300.0, false),
    ('1048', 'Muhammad Irfan Faqeer Hussain', 'Fusion', 1200.0, 400.0, false),
    ('1049', 'Sanjay Kumar Shrawan Kumar', 'Fusion', 1200.0, 600.0, false),
    ('1054', 'Nowfal Rizwan Naina Mohamed Naina Mohamed', 'Fusion', 1000.0, 400.0, false),
    ('1056', 'Rafi Ullah Khan Aman Ullah Khan', 'Fusion', 1200.0, 600.0, false),
    ('1057', 'Anandh Veeramani Veeramani', 'Fusion', 1500.0, 1500.0, true),
    ('1059', 'Saleem Allapitchai Allapitchai', 'Fusion', 1200.0, 200.0, false),
    ('1060', 'Silambarasan Rajamanikkam Rajamanikkam', 'Fusion', 1000.0, 400.0, false),

    -- Neo Division
    ('N-1003', 'Muhammed Riyas Hussain Hussain Kasim', 'Neo', 1200.0, 800.0, true),
    ('N-1004', 'Shabi Bismillah Bismillah', 'Neo', 1200.0, 1100.0, false),
    ('N-1005', 'Adham Bismilla Bismilla', 'Neo', 1200.0, 600.0, false),
    ('N-1006', 'Irshath Ahamed Shaik Allavudin Shaik Allavudin', 'Neo', 1500.0, 2500.0, true),
    ('N-1007', 'Saji Kumar Thankamani Thankamani', 'Neo', 1200.0, 600.0, false),
    ('N-1008', 'Kajamohideen Samsudeen Samsudeen', 'Neo', 1200.0, 800.0, false),
    ('N-1009', 'Abdul Kabarkhan Abdul Gafoor Abdul Gafoor', 'Neo', 1500.0, 1700.0, true),
    ('N-1010', 'Krishnan Mahavishnu Mahavishnu', 'Neo', 1000.0, 700.0, false),
    ('N-1011', 'Kuthoos Abthul Kani Abthul Kani', 'Neo', 1000.0, 600.0, false),
    ('N-1012', 'Javeedu Rahuman Hameed Sulthan Hameed Sulthan', 'Neo', 1000.0, 300.0, false),
    ('N-1013', 'Abhishek Sharma Aniruddh Sharma', 'Neo', 1200.0, 800.0, false),
    ('N-1014', 'Meeran', 'Neo', 1500.0, 3500.0, true)
ON CONFLICT (employee_code) DO UPDATE
SET
    fixed_salary = EXCLUDED.fixed_salary,
    variable_salary = EXCLUDED.variable_salary,
    custom_monthly_ot_amount = EXCLUDED.custom_monthly_ot_amount,
    ot_included_in_variable = EXCLUDED.ot_included_in_variable,
    pay_sunday_if_monday_worked = EXCLUDED.pay_sunday_if_monday_worked,
    updated_at = CURRENT_TIMESTAMP;

-- Ensure company owners and non-payroll personnel (Nasurudeen, Sirajudeen, Asik Saheel) are excluded from the salary table
DELETE FROM public.employee_salaries
WHERE employee_code = '1058'
   OR LOWER(employee_name) LIKE '%nasur%'
   OR LOWER(employee_name) LIKE '%alnaser%'
   OR LOWER(employee_name) LIKE '%siraj%'
   OR LOWER(employee_name) LIKE '%asik%'
   OR LOWER(employee_name) LIKE '%saheel%'
   OR LOWER(employee_name) LIKE '%ashik%';

