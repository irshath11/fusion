# 13. Service Report Generator & Digital E-Signatures Feature

## Overview
The **Service Report Generator & Digital E-Signatures** feature provides field service engineers and technicians with a complete mobile-first solution for creating, signing, and exporting professional client service sheets (`EmployeeReportGeneratorScreen`, `EmployeeReportsListScreen`). It captures detailed property and call information, service categories, equipment defects, repair steps, spare parts usage, customer satisfaction ratings, and legally binding digital signatures from both the customer and the technician.

---

## 1. Key Functionalities

### A. Multi-Section Service Report Form
1. **Header & Call Details**:
   - Unique auto-incrementing Reference Number (e.g., `FES-SR-2026-0001`).
   - Job Number, Property Details, Contact Name & Phone Number, Physical Location.
   - Time Tracking: Appointment Time, Attended Time, Call Booking Time.
   - Call Type Selection: `Complaint`, `Breakdown`, or `Preventive`.

2. **Services Required & Priority Level**:
   - Multi-selection chips across 15 engineering disciplines:
     - `A/C`, `CCTV`, `Fire Fighting`, `Carpentry`, `BMS`, `Electrical`, `SMATV`, `Generator`, `Civil`, `Access Control`, `Plumbing`, `Intercom`, `Cleaning Service`, `Painting`, `Soft Services`.
   - Priority toggle: `Normal` or `Urgent`.

3. **Defects Found & Details of Work Done**:
   - Multi-line description of equipment faults before servicing.
   - Multi-line breakdown of servicing and remediation steps performed.
   - Direct integration with AI Voice Report Assistant (`AiVoiceReportBottomSheet`) for hands-free voice dictation and automated population.

4. **Materials & Spare Parts Table**:
   - Dynamic item list where technicians add physical parts replaced (e.g. `Contactor 32A`, `Air Filter 24x24`).
   - Unit quantities and descriptions.

5. **Customer Satisfaction & Site Housekeeping**:
   - Customer Performance Rating: `Excellent`, `Good`, `Fair`, `Poor`.
   - Site Housekeeping & Cleanliness Confirmation: `Completed` or `Pending`.
   - Technician, Engineer, Supervisor, and Customer name sign-offs.

---

### B. Digital E-Signature Pad (`ESignaturePad`)
- Interactive digital canvas allowing on-screen finger or stylus signing.
- Captures high-fidelity vector stroke data and converts it into raw PNG image bytes (`Uint8List`).
- Supports **Technician Signature** and **Customer Signature**.
- Features clear canvas, stroke width adjustments, and signature preview modal.

---

### C. Professional PDF Export & Printing (`ServiceReportPdfService`)
- Builds an ISO-standard, company-branded service report document:
  - Corporate header with organization logo, contact details, and reference badge.
  - Formatted property, appointment, and call type metadata tables.
  - Checklist of selected services and priority indicator.
  - Side-by-side technical descriptions for *Defects Found* and *Work Performed*.
  - Tabular breakdown of materials and spare parts used.
  - Performance rating stars and housekeeping badge.
  - Dual embedded digital signatures with timestamped sign-off lines.
- Directly integrated with native device printing, PDF sharing, and document saving (`Printing.sharePdf()`, `Printing.layoutPdf()`).

---

### D. Offline Persistence & Cloud Synchronization
- **Local Database Storage (`LocalDatabaseService`)**: Saves reports locally in Hive (`serviceReportsBox`), allowing technicians to create, edit, and view past reports with zero internet connection.
- **Supabase Cloud Synchronization**: Synchronizes reports to the remote Supabase `service_reports` table when connectivity is available.
- **History & Search Screen (`EmployeeReportsListScreen`)**: Provides technicians with a searchable list of all generated reports with quick PDF reprint and view actions.

---

## 2. Technical Architecture & Database Schema

### Supabase Table: `service_reports`
```sql
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
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/features/employee/presentation/employee_report_generator_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/employee/presentation/employee_report_generator_screen.dart) | Interactive multi-section form for creating and editing field service reports with AI dictation. |
| [`lib/features/employee/presentation/employee_reports_list_screen.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/features/employee/presentation/employee_reports_list_screen.dart) | History directory listing past service reports with search, filtering, and reprint capabilities. |
| [`lib/core/services/service_report_pdf_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/service_report_pdf_service.dart) | Engine rendering multi-section enterprise service report PDF documents with embedded e-signatures. |
| [`lib/core/widgets/e_signature_pad.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/widgets/e_signature_pad.dart) | Digital canvas widget capturing touch-drawn customer and technician signatures. |
| [`supabase_service_reports_schema.sql`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/supabase_service_reports_schema.sql) | PostgreSQL schema and RLS policies for remote `service_reports` table. |
