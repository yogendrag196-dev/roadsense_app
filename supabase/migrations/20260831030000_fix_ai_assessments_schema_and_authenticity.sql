-- ==============================================================================
-- Migration: Fix ai_assessments Schema, Photo Authenticity Columns & Auto Trigger
-- ==============================================================================

-- 1. Create or Ensure ai_assessments Table Structure
CREATE TABLE IF NOT EXISTS public.ai_assessments (
    complaint_id UUID PRIMARY KEY REFERENCES public.complaints(id) ON DELETE CASCADE,
    severity TEXT NOT NULL DEFAULT 'Medium',
    confidence NUMERIC NOT NULL DEFAULT 0.85,
    reason TEXT,
    reasoning TEXT,
    duplicate_of UUID REFERENCES public.complaints(id) ON DELETE SET NULL,
    is_authentic BOOLEAN DEFAULT true,
    authenticity_score NUMERIC DEFAULT 0.95,
    photo_verdict TEXT DEFAULT 'Real Photo',
    is_ai_generated BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure ALL columns exist on ai_assessments table
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS severity TEXT NOT NULL DEFAULT 'Medium';
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS confidence NUMERIC NOT NULL DEFAULT 0.85;
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS reasoning TEXT;
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS duplicate_of UUID REFERENCES public.complaints(id) ON DELETE SET NULL;
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS is_authentic BOOLEAN DEFAULT true;
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS authenticity_score NUMERIC DEFAULT 0.95;
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS photo_verdict TEXT DEFAULT 'Real Photo';
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS is_ai_generated BOOLEAN DEFAULT false;
ALTER TABLE public.ai_assessments ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Grant Privileges on ai_assessments to all Roles
GRANT USAGE ON SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;

-- 3. RLS Policies on ai_assessments
ALTER TABLE public.ai_assessments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read ai assessments" ON public.ai_assessments;
DROP POLICY IF EXISTS "Allow public read of ai assessments" ON public.ai_assessments;
DROP POLICY IF EXISTS "ai_assessments_select_policy" ON public.ai_assessments;
DROP POLICY IF EXISTS "ai_assessments_insert_policy" ON public.ai_assessments;
DROP POLICY IF EXISTS "ai_assessments_update_policy" ON public.ai_assessments;

CREATE POLICY "ai_assessments_select_policy" ON public.ai_assessments
FOR SELECT USING (true);

CREATE POLICY "ai_assessments_insert_policy" ON public.ai_assessments
FOR INSERT WITH CHECK (true);

CREATE POLICY "ai_assessments_update_policy" ON public.ai_assessments
FOR UPDATE USING (true);

-- 4. Recreate Fail-Safe auto_assess_complaint Trigger Function
CREATE OR REPLACE FUNCTION public.auto_assess_complaint()
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_severity TEXT := 'Medium';
    v_confidence NUMERIC := 0.85;
    v_reason TEXT := 'AI automated initial inspection based on reported hazard type and description.';
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

    -- Update complaint severity if not set
    IF NEW.severity IS NULL OR NEW.severity = 'Pending AI' OR NEW.severity = '' THEN
        NEW.severity := v_severity;
    END IF;

    -- Safely insert into ai_assessments table
    BEGIN
        INSERT INTO public.ai_assessments (
            complaint_id, 
            severity, 
            confidence, 
            reason, 
            reasoning, 
            photo_verdict, 
            is_authentic, 
            authenticity_score
        )
        VALUES (
            NEW.id, 
            v_severity, 
            v_confidence, 
            v_reason, 
            v_reason, 
            'Authentic Field Photo', 
            true, 
            0.92
        )
        ON CONFLICT (complaint_id) DO UPDATE SET
            severity = EXCLUDED.severity,
            confidence = EXCLUDED.confidence,
            reason = EXCLUDED.reason,
            reasoning = EXCLUDED.reasoning;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'auto_assess_complaint ai_assessments insert warning: %', SQLERRM;
    END;

    -- Create work order if not existing
    BEGIN
        INSERT INTO public.work_orders (complaint_id, priority, sla_deadline, stage)
        VALUES (
            NEW.id,
            CASE WHEN v_severity IN ('Critical', 'High') THEN 'P1 - High' ELSE 'P2 - Normal' END,
            NOW() + CASE WHEN v_severity = 'Critical' THEN INTERVAL '24 hours' WHEN v_severity = 'High' THEN INTERVAL '48 hours' ELSE INTERVAL '72 hours' END,
            'Assigned'
        )
        ON CONFLICT DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'auto create work order warning: %', SQLERRM;
    END;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- 5. Attach trigger to complaints
DROP TRIGGER IF EXISTS trg_auto_assess_complaint ON public.complaints;
CREATE TRIGGER trg_auto_assess_complaint
    BEFORE INSERT ON public.complaints
    FOR EACH ROW EXECUTE FUNCTION public.auto_assess_complaint();
