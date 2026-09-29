-- ==============================================================================
-- Clean Fix for RLS Policies, Infinite Recursion Prevention, and Auth Trigger
-- ==============================================================================

-- 1. Grant necessary privileges to Supabase roles
GRANT USAGE ON SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, supabase_auth_admin, anon, authenticated, service_role;

-- 2. Create non-recursive is_staff() helper function (SECURITY DEFINER + search_path)
CREATE OR REPLACE FUNCTION public.is_staff(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = user_id AND role IN ('admin', 'staff', 'engineer', 'authority', 'supervisor')
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_staff(uuid) TO postgres, supabase_auth_admin, anon, authenticated, service_role;

-- 3. Drop ALL old / duplicate / conflicting policies on profiles
DROP POLICY IF EXISTS "Anyone can read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow public read of profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow users to insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow users to update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Staff can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Staff can read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Citizens can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Citizens can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Staff can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;

-- 4. Enable RLS on profiles and apply properly-scoped, non-recursive policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Citizens read their own row, staff/engineers read all rows
CREATE POLICY "profiles_select_policy" ON public.profiles
FOR SELECT USING (
  auth.uid() = id OR public.is_staff(auth.uid())
);

-- Users can insert their own profile (and auth triggers running without auth.uid() can insert)
CREATE POLICY "profiles_insert_policy" ON public.profiles
FOR INSERT WITH CHECK (
  auth.uid() = id OR auth.uid() IS NULL
);

-- Citizens update their own row, staff can update any row
CREATE POLICY "profiles_update_policy" ON public.profiles
FOR UPDATE USING (
  auth.uid() = id OR public.is_staff(auth.uid())
) WITH CHECK (
  auth.uid() = id OR public.is_staff(auth.uid())
);

-- 5. Drop ALL old / duplicate / conflicting policies on complaints
DROP POLICY IF EXISTS "Anyone can read complaints" ON public.complaints;
DROP POLICY IF EXISTS "Anyone can insert complaints" ON public.complaints;
DROP POLICY IF EXISTS "Anyone can update complaints" ON public.complaints;
DROP POLICY IF EXISTS "Staff can read all complaints" ON public.complaints;
DROP POLICY IF EXISTS "Citizens can read own complaints" ON public.complaints;
DROP POLICY IF EXISTS "complaints_select_policy" ON public.complaints;
DROP POLICY IF EXISTS "complaints_insert_policy" ON public.complaints;
DROP POLICY IF EXISTS "complaints_update_policy" ON public.complaints;

ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- Citizens can view complaints (public civic hazard data)
CREATE POLICY "complaints_select_policy" ON public.complaints
FOR SELECT USING (true);

-- Authenticated users can insert complaints
CREATE POLICY "complaints_insert_policy" ON public.complaints
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Owner or staff can update complaints
CREATE POLICY "complaints_update_policy" ON public.complaints
FOR UPDATE USING (
  auth.uid() = citizen_id OR auth.uid() = user_id OR public.is_staff(auth.uid())
);

-- 6. Recreate Fail-Safe handle_new_user() Trigger Function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_default_ward UUID;
    v_name TEXT;
    v_role TEXT;
BEGIN
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

    v_name := COALESCE(
        NEW.raw_user_meta_data->>'name',
        NEW.raw_user_meta_data->>'full_name',
        split_part(COALESCE(NEW.email, ''), '@', 1),
        'Citizen'
    );
    IF v_name = '' THEN
        v_name := 'Citizen';
    END IF;

    v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'citizen');

    BEGIN
        INSERT INTO public.profiles (id, name, email, role, ward_id)
        VALUES (
            NEW.id,
            v_name,
            NEW.email,
            v_role,
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
        RAISE WARNING 'handle_new_user warning: %', SQLERRM;
    END;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- 7. Drop and Recreate Trigger on auth.users (strictly AFTER INSERT, NOT UPDATE)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user_trigger ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 8. Backfill profile for existing users if missing
INSERT INTO public.profiles (id, name, email, role)
SELECT 
    u.id,
    COALESCE(u.raw_user_meta_data->>'name', u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1), 'Citizen'),
    u.email,
    COALESCE(u.raw_user_meta_data->>'role', 'citizen')
FROM auth.users u
ON CONFLICT (id) DO NOTHING;
