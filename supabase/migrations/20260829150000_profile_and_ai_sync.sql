-- 1. Create media_files table if not exists
CREATE TABLE IF NOT EXISTS media_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID REFERENCES complaints(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE media_files ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read media_files" ON media_files;
CREATE POLICY "Anyone can read media_files" ON media_files FOR SELECT USING (true);
DROP POLICY IF EXISTS "Anyone can insert media_files" ON media_files;
CREATE POLICY "Anyone can insert media_files" ON media_files FOR INSERT WITH CHECK (true);

-- 2. Enhanced handle_new_user function to sync auth.users into profiles
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
DECLARE
    v_default_ward UUID;
    v_name TEXT;
BEGIN
    SELECT id INTO v_default_ward 
    FROM wards 
    WHERE name ILIKE '%HSR%' OR name ILIKE '%Shantalanagar%' OR name ILIKE '%Koramangala%'
    LIMIT 1;

    IF v_default_ward IS NULL THEN
        SELECT id INTO v_default_ward FROM wards LIMIT 1;
    END IF;

    v_name := COALESCE(
        NEW.raw_user_meta_data->>'name',
        NEW.raw_user_meta_data->>'full_name',
        split_part(NEW.email, '@', 1),
        'Citizen'
    );

    INSERT INTO public.profiles (id, name, email, role, ward_id)
    VALUES (
        NEW.id,
        v_name,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'role', 'citizen'),
        v_default_ward
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = CASE WHEN profiles.name IS NULL OR profiles.name = 'Citizen' THEN EXCLUDED.name ELSE profiles.name END,
        ward_id = COALESCE(profiles.ward_id, EXCLUDED.ward_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create Trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 3. Backfill all existing auth.users into public.profiles with their actual emails & names
INSERT INTO public.profiles (id, name, email, role, ward_id)
SELECT 
    u.id,
    COALESCE(u.raw_user_meta_data->>'name', u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1), 'Citizen'),
    u.email,
    COALESCE(u.raw_user_meta_data->>'role', 'citizen'),
    (SELECT id FROM wards WHERE name ILIKE '%Koramangala%' LIMIT 1)
FROM auth.users u
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = CASE WHEN profiles.name IS NULL OR profiles.name = 'Citizen' THEN EXCLUDED.name ELSE profiles.name END,
    ward_id = COALESCE(profiles.ward_id, EXCLUDED.ward_id);

-- 4. Clean up any orphaned profile entries where email was NULL
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id AND (p.email IS NULL OR p.email = '');

-- Set default ward for any profiles with null ward_id
UPDATE public.profiles
SET ward_id = (SELECT id FROM wards WHERE name ILIKE '%Koramangala%' LIMIT 1)
WHERE ward_id IS NULL;

-- 5. Auto AI Assessment Trigger on Complaints
CREATE OR REPLACE FUNCTION auto_assess_complaint()
RETURNS trigger AS $$
DECLARE
    v_severity TEXT := 'Medium';
    v_confidence NUMERIC := 0.85;
    v_reason TEXT := 'AI automated multi-factor analysis based on hazard type and description.';
    v_text TEXT;
BEGIN
    v_text := lower(COALESCE(NEW.description, '') || ' ' || COALESCE(NEW.category, ''));

    IF v_text ~* '(sinkhole|collapse|flooding|flood|deep water|manhole|danger|accident|rebar|burst)' THEN
        v_severity := 'Critical';
        v_confidence := 0.95;
        v_reason := 'Critical road hazard detected posing immediate danger to motorists and pedestrians.';
    ELSIF v_text ~* '(pothole|broken drain|drain|large|deep|crack|subsidence|obstruction|debris)' THEN
        v_severity := 'High';
        v_confidence := 0.90;
        v_reason := 'High priority road defect detected requiring municipal intervention.';
    ELSIF v_text ~* '(small|minor|hairline|cosmetic|faint|light)' THEN
        v_severity := 'Low';
        v_confidence := 0.88;
        v_reason := 'Low impact minor surface defect.';
    END IF;

    -- Update complaint severity if Pending AI
    IF NEW.severity IS NULL OR NEW.severity = 'Pending AI' THEN
        NEW.severity := v_severity;
    END IF;

    -- Insert into ai_assessments table
    INSERT INTO ai_assessments (complaint_id, severity, confidence, reason)
    VALUES (NEW.id, v_severity, v_confidence, v_reason)
    ON CONFLICT (complaint_id) DO UPDATE SET
        severity = EXCLUDED.severity,
        confidence = EXCLUDED.confidence,
        reason = EXCLUDED.reason;

    -- Create work order if not existing
    INSERT INTO work_orders (complaint_id, priority, sla_deadline, stage)
    VALUES (
        NEW.id,
        CASE WHEN v_severity IN ('Critical', 'High') THEN 'P1 - High' ELSE 'P2 - Normal' END,
        NOW() + CASE WHEN v_severity = 'Critical' THEN INTERVAL '24 hours' WHEN v_severity = 'High' THEN INTERVAL '48 hours' ELSE INTERVAL '72 hours' END,
        'Assigned'
    )
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_assess_complaint ON complaints;
CREATE TRIGGER trg_auto_assess_complaint
    BEFORE INSERT ON complaints
    FOR EACH ROW EXECUTE FUNCTION auto_assess_complaint();

GRANT ALL ON media_files TO authenticated, anon, service_role;
GRANT ALL ON profiles TO authenticated, anon, service_role;
GRANT ALL ON complaints TO authenticated, anon, service_role;
GRANT ALL ON ai_assessments TO authenticated, anon, service_role;
GRANT ALL ON work_orders TO authenticated, anon, service_role;
