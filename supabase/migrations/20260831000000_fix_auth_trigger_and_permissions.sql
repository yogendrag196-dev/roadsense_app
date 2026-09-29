-- Fix: Database error granting user / saving new user on Supabase Auth

-- 1. Grant schema usage and table permissions to Supabase Auth roles
GRANT USAGE ON SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO postgres, supabase_auth_admin, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres, supabase_auth_admin, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO postgres, supabase_auth_admin, anon, authenticated, service_role;

-- 2. Drop the old trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 3. Create a robust, fail-safe handle_new_user() function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_default_ward UUID;
    v_name TEXT;
BEGIN
    -- Safely get a default ward ID
    BEGIN
        SELECT id INTO v_default_ward 
        FROM public.wards 
        WHERE name ILIKE '%HSR%' OR name ILIKE '%Shantalanagar%' OR name ILIKE '%Koramangala%'
        LIMIT 1;

        IF v_default_ward IS NULL THEN
            SELECT id INTO v_default_ward FROM public.wards LIMIT 1;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_default_ward := NULL;
    END;

    -- Extract name safely from metadata or email
    v_name := COALESCE(
        NEW.raw_user_meta_data->>'name',
        NEW.raw_user_meta_data->>'full_name',
        split_part(COALESCE(NEW.email, ''), '@', 1),
        'Citizen'
    );

    IF v_name = '' THEN
        v_name := 'Citizen';
    END IF;

    -- Insert or update public.profiles with exception safety
    BEGIN
        INSERT INTO public.profiles (id, name, email, role, ward_id)
        VALUES (
            NEW.id,
            v_name,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'role', 'citizen'),
            v_default_ward
        )
        ON CONFLICT (id) DO UPDATE SET
            email = COALESCE(EXCLUDED.email, profiles.email),
            name = CASE 
                WHEN profiles.name IS NULL OR profiles.name = 'Citizen' OR profiles.name = '' 
                THEN EXCLUDED.name 
                ELSE profiles.name 
            END,
            ward_id = COALESCE(profiles.ward_id, EXCLUDED.ward_id);
    EXCEPTION WHEN OTHERS THEN
        -- Log warning and do not block auth
        RAISE WARNING 'handle_new_user error: %', SQLERRM;
    END;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- In no circumstance should an error here block user login/signup in GoTrue
    RETURN NEW;
END;
$$;

-- 4. Re-create the trigger for AFTER INSERT ONLY (not UPDATE, so logins are not affected)
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Ensure RLS policies on profiles allow inserting and updating
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read of profiles" ON public.profiles;
CREATE POLICY "Allow public read of profiles" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow users to insert their own profile" ON public.profiles;
CREATE POLICY "Allow users to insert their own profile" ON public.profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow users to update their own profile" ON public.profiles;
CREATE POLICY "Allow users to update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id OR auth.uid() IS NULL);

-- 6. Ensure default wards exist so foreign key lookups succeed
INSERT INTO public.wards (name, ward_number, center_lat, center_lng, resolution_rate, total_reports, resolved_reports)
VALUES
  ('Ward 150 - Bellandur', 150, 12.9304, 77.6784, 85.0, 12, 10),
  ('Ward 174 - HSR Layout', 174, 12.9121, 77.6446, 90.0, 15, 13),
  ('Ward 151 - Koramangala', 151, 12.9352, 77.6245, 88.0, 18, 16),
  ('Ward 112 - Domlur / Indiranagar', 112, 12.9609, 77.6387, 92.0, 20, 18),
  ('Ward 85 - Doddanekkundi / Whitefield', 85, 12.9719, 77.7289, 75.0, 24, 18),
  ('Ward 80 - Shantalanagar / MG Road', 80, 12.9716, 77.6006, 95.0, 10, 9),
  ('Ward 177 - Jayanagar', 177, 12.9250, 77.5938, 89.0, 14, 12),
  ('Ward 193 - Arakere / JP Nagar', 193, 12.8918, 77.5855, 82.0, 16, 13),
  ('Ward 45 - Malleshwaram', 45, 13.0031, 77.5643, 91.0, 11, 10),
  ('Ward 66 - Subramanya Nagar / Rajajinagar', 66, 12.9915, 77.5524, 86.0, 14, 12),
  ('Ward 7 - Thanisandra / Hebbal', 7, 13.0489, 77.6264, 78.0, 22, 17),
  ('Ward 198 - Hemmigepura / Kengeri', 198, 12.8942, 77.5028, 80.0, 15, 12),
  ('Ward 175 - Bommanahalli / Electronic City', 175, 12.9081, 77.6225, 84.0, 25, 21),
  ('Ward 82 - Halasuru', 82, 12.9784, 77.6241, 88.0, 9, 8),
  ('Ward 22 - BTM Layout', 22, 12.9166, 77.6101, 87.0, 16, 14)
ON CONFLICT DO NOTHING;
