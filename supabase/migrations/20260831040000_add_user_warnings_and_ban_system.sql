-- ==============================================================================
-- Migration: Add User Warnings and Ban System for Fake / AI Image Abuse
-- ==============================================================================

-- 1. Add warning_count, is_banned, ban_reason, last_warning_at to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS warning_count INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ban_reason TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_warning_at TIMESTAMPTZ;

-- 2. Create RPC Function to Safely Record Warning & Ban after 4 strikes
CREATE OR REPLACE FUNCTION public.record_user_warning(p_user_id UUID, p_reason TEXT)
RETURNS JSON 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_new_count INTEGER;
    v_is_banned BOOLEAN;
BEGIN
    UPDATE public.profiles
    SET 
        warning_count = COALESCE(warning_count, 0) + 1,
        last_warning_at = NOW(),
        ban_reason = p_reason,
        is_banned = CASE WHEN COALESCE(warning_count, 0) + 1 >= 4 THEN true ELSE false END
    WHERE id = p_user_id
    RETURNING warning_count, is_banned INTO v_new_count, v_is_banned;

    IF v_new_count IS NULL THEN
        v_new_count := 1;
        v_is_banned := false;
    END IF;

    RETURN json_build_object(
        'warning_count', v_new_count,
        'is_banned', v_is_banned
    );
END;
$$;

-- 3. Grant Permissions
GRANT EXECUTE ON FUNCTION public.record_user_warning(UUID, TEXT) TO postgres, supabase_auth_admin, anon, authenticated, service_role;
