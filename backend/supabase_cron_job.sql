-- ==============================================================================
-- FUSION 360: AUTOMATED 3-DAY CARD EXPIRY COMPLIANCE ROBOT (SUPABASE CRON & PG_NET)
-- ==============================================================================
-- Target Recipients:
--   Email:    sr.irshath@gmail.com, nasuru@fusionmaint.com
--   WhatsApp: +971586939371
--
-- Schedule: Daily at 08:00 AM Gulf Standard Time (GST = UTC+4 -> 04:00 UTC)
-- Services:
--   - Resend API (Free Tier: 3,000 emails/mo via fusionmaint.org)
--   - CallMeBot WhatsApp API (Free Tier for personal alerts)
-- ==============================================================================

-- 1. Enable required PostgreSQL Extensions for Supabase
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 2. Compliance Notification Settings Table
CREATE TABLE IF NOT EXISTS public.compliance_notification_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    resend_api_key TEXT,
    callmebot_api_key TEXT,
    target_email TEXT NOT NULL DEFAULT 'sr.irshath@gmail.com, nasuru@fusionmaint.com',
    target_phone TEXT NOT NULL DEFAULT '971586939371',
    is_automated_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_run_at TIMESTAMP WITH TIME ZONE,
    last_run_status TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- RLS Policy for Settings
ALTER TABLE public.compliance_notification_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS compliance_notification_settings_all ON public.compliance_notification_settings;
CREATE POLICY compliance_notification_settings_all ON public.compliance_notification_settings FOR ALL USING (true);

-- Insert Default Configuration if not present
INSERT INTO public.compliance_notification_settings (
    target_email,
    target_phone,
    is_automated_enabled
) 
SELECT 'sr.irshath@gmail.com, nasuru@fusionmaint.com', '971586939371', true
WHERE NOT EXISTS (SELECT 1 FROM public.compliance_notification_settings LIMIT 1);

-- 3. URL Encode Helper for CallMeBot WhatsApp Query Parameters (RFC 3986)
CREATE OR REPLACE FUNCTION public.url_encode(data text) 
RETURNS text 
LANGUAGE plpgsql 
IMMUTABLE STRICT 
AS $$
DECLARE
    res text := '';
    i int;
    b bytea;
    byte_val int;
BEGIN
    IF data IS NULL THEN
        RETURN '';
    END IF;
    b := convert_to(data, 'UTF8');
    FOR i IN 0..octet_length(b) - 1 LOOP
        byte_val := get_byte(b, i);
        IF (byte_val >= 48 AND byte_val <= 57) OR -- 0-9
           (byte_val >= 65 AND byte_val <= 90) OR -- A-Z
           (byte_val >= 97 AND byte_val <= 122) OR -- a-z
           byte_val IN (45, 95, 46, 126) THEN     -- - _ . ~
            res := res || chr(byte_val);
        ELSE
            res := res || '%' || lpad(upper(to_hex(byte_val)), 2, '0');
        END IF;
    END LOOP;
    RETURN res;
END;
$$;

-- 4. Stored Procedure to Check Expiries and Trigger Headless Alerts
CREATE OR REPLACE FUNCTION public.check_and_send_card_expiry_alerts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    settings_rec RECORD;
    card_rec RECORD;
    urgent_count INT := 0;
    wa_msg TEXT := '';
    email_html TEXT := '';
    table_rows TEXT := '';
    card_ids UUID[] := ARRAY[]::UUID[];
    days_left INT;
    status_label TEXT;
    status_bg TEXT;
    resend_response_id BIGINT;
    callmebot_response_id BIGINT;
    clean_phone TEXT;
    email_array JSONB;
BEGIN
    -- Fetch active compliance settings
    SELECT * INTO settings_rec FROM public.compliance_notification_settings 
    WHERE is_automated_enabled = TRUE 
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Automated alerts are disabled or unconfigured');
    END IF;

    -- Clean phone number (strip + and spaces)
    clean_phone := regexp_replace(settings_rec.target_phone, '[^0-9]', '', 'g');

    -- Build recipient array from comma-separated target_email string
    SELECT jsonb_agg(trim(email))
    INTO email_array
    FROM unnest(string_to_array(settings_rec.target_email, ',')) AS email
    WHERE trim(email) <> '';

    IF email_array IS NULL THEN
        email_array := jsonb_build_array('sr.irshath@gmail.com', 'nasuru@fusionmaint.com');
    END IF;

    -- Build WhatsApp & Email Bodies
    wa_msg := '🚨 *URGENT COMPLIANCE NOTICE: CARD EXPIRATION (<= 3 DAYS)*' || chr(10);
    wa_msg := wa_msg || '----------------------------------------' || chr(10);
    wa_msg := wa_msg || 'Attention: Compliance and Operations Control' || chr(10);

    FOR card_rec IN
        SELECT 
            c.id,
            c.card_name,
            c.card_number,
            c.expiry_date,
            COALESCE(u.full_name, 'Employee') AS employee_name,
            e.employee_code,
            e.department
        FROM public.employee_cards c
        LEFT JOIN public.employees e ON (e.id = c.employee_id OR e.user_id = c.employee_id)
        LEFT JOIN public.users u ON (u.id = c.employee_id OR u.id = e.user_id)
        WHERE (c.is_deleted IS FALSE OR c.is_deleted IS NULL)
          AND (c.expiry_date::date - CURRENT_DATE) <= 3
          AND (c.last_notified_at IS NULL OR c.last_notified_at::date < CURRENT_DATE)
        ORDER BY c.expiry_date ASC
    LOOP
        urgent_count := urgent_count + 1;
        card_ids := array_append(card_ids, card_rec.id);
        days_left := (card_rec.expiry_date::date - CURRENT_DATE);

        IF days_left < 0 THEN
            status_label := 'EXPIRED (' || abs(days_left) || 'd ago)';
            status_bg := '#ef4444';
        ELSIF days_left = 0 THEN
            status_label := 'EXPIRES TODAY!';
            status_bg := '#ef4444';
        ELSE
            status_label := 'Expires in ' || days_left || ' day(s)';
            status_bg := '#f97316';
        END IF;

        -- Append to WhatsApp Message
        wa_msg := wa_msg || chr(10) || '*' || urgent_count || '. ' || upper(card_rec.card_name) || '*' || chr(10);
        wa_msg := wa_msg || '  👤 Employee: ' || card_rec.employee_name || ' (' || coalesce(card_rec.employee_code, 'EMP') || ')' || chr(10);
        wa_msg := wa_msg || '  🔢 Card No: ' || card_rec.card_number || chr(10);
        wa_msg := wa_msg || '  📅 Expiry: ' || to_char(card_rec.expiry_date, 'DD Mon YYYY') || chr(10);
        wa_msg := wa_msg || '  ⏳ Status: ' || status_label || chr(10);

        -- Append to HTML Email Rows
        table_rows := table_rows || 
            '<tr style="border-bottom: 1px solid #e2e8f0;">' ||
            '<td style="padding: 10px 12px; font-weight: bold; color: #0f172a;">' || card_rec.card_name || '</td>' ||
            '<td style="padding: 10px 12px; font-family: monospace; color: #1e293b;">' || card_rec.card_number || '</td>' ||
            '<td style="padding: 10px 12px; color: #334155;">' || card_rec.employee_name || ' (' || coalesce(card_rec.employee_code, 'EMP') || ')</td>' ||
            '<td style="padding: 10px 12px; font-weight: 600; color: #0f172a;">' || to_char(card_rec.expiry_date, 'DD Mon YYYY') || '</td>' ||
            '<td style="padding: 10px 12px;"><span style="background: ' || status_bg || '; color: white; padding: 2px 7px; border-radius: 4px; font-size: 11px; font-weight: bold;">' || status_label || '</span></td>' ||
            '</tr>';
    END LOOP;

    -- If no cards expiring, exit cleanly
    IF urgent_count = 0 THEN
        UPDATE public.compliance_notification_settings
        SET last_run_at = CURRENT_TIMESTAMP,
            last_run_status = 'Success: No cards expiring in <= 3 days'
        WHERE id = settings_rec.id;
        
        RETURN jsonb_build_object('success', true, 'count', 0, 'message', 'No cards expiring in <= 3 days');
    END IF;

    -- Complete WhatsApp text
    wa_msg := wa_msg || chr(10) || '⚠️ *Action Required:* Please coordinate renewal immediately.' || chr(10);
    wa_msg := wa_msg || '----------------------------------------' || chr(10);
    wa_msg := wa_msg || '_Fusion 360 Document Control System_';

    -- Complete HTML Email
    email_html := '<!DOCTYPE html><html><body style="font-family: sans-serif; background: #f8fafc; padding: 20px;">' ||
        '<div style="max-width: 650px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0;">' ||
        '<div style="background: #0f172a; padding: 20px; color: #ffffff; border-bottom: 3px solid #ef4444;">' ||
        '<div style="font-size: 11px; color: #38bdf8; font-weight: bold; text-transform: uppercase;">Fusion 360 &bull; Automated Document Control</div>' ||
        '<h2 style="margin: 6px 0; color: #ffffff;">Critical Expiry Notice: ' || urgent_count || ' Document(s) Expiring &le; 3 Days</h2>' ||
        '</div>' ||
        '<div style="padding: 20px;">' ||
        '<table style="width: 100%; border-collapse: collapse; font-size: 13px;">' ||
        '<thead><tr style="background: #f1f5f9; text-align: left;"><th style="padding: 8px;">Document</th><th style="padding: 8px;">Number</th><th style="padding: 8px;">Employee</th><th style="padding: 8px;">Expiry</th><th style="padding: 8px;">Urgency</th></tr></thead>' ||
        '<tbody>' || table_rows || '</tbody></table>' ||
        '<p style="margin-top: 20px; font-size: 12px; color: #64748b;">Target Recipients: ' || settings_rec.target_email || '</p>' ||
        '</div></div></body></html>';

    -- 4. Dispatch Email via Resend if API Key configured
    IF settings_rec.resend_api_key IS NOT NULL AND length(settings_rec.resend_api_key) > 5 THEN
        SELECT net.http_post(
            url := 'https://api.resend.com/emails',
            body := jsonb_build_object(
                'from', 'Fusion Compliance <compliance@fusionmaint.org>',
                'to', email_array,
                'subject', '[URGENT] Compliance Alert: ' || urgent_count || ' Document(s) Expiring Within 3 Days',
                'html', email_html
            ),
            headers := jsonb_build_object(
                'Authorization', 'Bearer ' || settings_rec.resend_api_key,
                'Content-Type', 'application/json'
            )
        ) INTO resend_response_id;
    END IF;

    -- 5. Dispatch WhatsApp via CallMeBot if API Key configured (properly URL-encoded)
    IF settings_rec.callmebot_api_key IS NOT NULL AND length(settings_rec.callmebot_api_key) > 2 THEN
        SELECT net.http_get(
            url := 'https://api.callmebot.com/whatsapp.php?phone=' || clean_phone ||
                   '&text=' || public.url_encode(wa_msg) ||
                   '&apikey=' || settings_rec.callmebot_api_key
        ) INTO callmebot_response_id;
    END IF;

    -- 6. Stamp last_notified_at so cards aren't alerted repeatedly on same day
    UPDATE public.employee_cards
    SET last_notified_at = CURRENT_TIMESTAMP
    WHERE id = ANY(card_ids);

    -- 7. Log Activity in Audit Trail
    BEGIN
        IF EXISTS (SELECT 1 FROM public.organizations LIMIT 1) THEN
            INSERT INTO public.activity_logs (
                organization_id,
                action,
                details
            ) VALUES (
                (SELECT id FROM public.organizations LIMIT 1),
                'AUTOMATED_EXPIRY_ALERT_SENT',
                jsonb_build_object(
                    'urgent_count', urgent_count,
                    'email', settings_rec.target_email,
                    'phone', clean_phone,
                    'dispatched_by', 'Supabase pg_cron Automated Engine'
                )
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Continue gracefully even if audit log fails
    END;

    UPDATE public.compliance_notification_settings
    SET last_run_at = CURRENT_TIMESTAMP,
        last_run_status = 'Dispatched alerts for ' || urgent_count || ' cards'
    WHERE id = settings_rec.id;

    RETURN jsonb_build_object(
        'success', true,
        'count', urgent_count,
        'email_sent', (settings_rec.resend_api_key IS NOT NULL),
        'whatsapp_sent', (settings_rec.callmebot_api_key IS NOT NULL)
    );
END;
$$;

-- 4. Schedule the cron job to run daily at 08:00 AM Gulf Standard Time (GST = UTC+4 -> 04:00 UTC)
-- Unschedule previous job if exists to avoid duplicates
DO $$
BEGIN
    PERFORM cron.unschedule('card-expiry-daily-alert');
EXCEPTION WHEN OTHERS THEN
    -- Ignore if job doesn't exist
END;
$$;

SELECT cron.schedule(
    'card-expiry-daily-alert',
    '0 4 * * *',
    $$SELECT public.check_and_send_card_expiry_alerts();$$
);
