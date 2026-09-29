-- Enable PostGIS extension in extensions schema
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- 1. Wards Table
CREATE TABLE IF NOT EXISTS wards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    ward_number INTEGER,
    center_lat NUMERIC,
    center_lng NUMERIC,
    resolution_rate NUMERIC DEFAULT 0,
    total_reports INTEGER DEFAULT 0,
    resolved_reports INTEGER DEFAULT 0
);

-- 2. Profiles Table
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    email TEXT,
    role TEXT DEFAULT 'citizen',
    ward_id UUID REFERENCES wards(id),
    onesignal_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Complaints Table
CREATE TABLE IF NOT EXISTS complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    citizen_id UUID REFERENCES profiles(id),
    user_id UUID REFERENCES profiles(id),
    category TEXT NOT NULL,
    description TEXT,
    location extensions.geography(Point, 4326),
    ward_id UUID REFERENCES wards(id),
    ward_name TEXT,
    severity TEXT,
    status TEXT DEFAULT 'Submitted',
    upvote_count INTEGER DEFAULT 1,
    media_urls TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure all columns exist in case table was created earlier with fewer columns
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS citizen_id UUID REFERENCES profiles(id);
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id);
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS ward_id UUID REFERENCES wards(id);
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS ward_name TEXT;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS severity TEXT;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Submitted';
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS upvote_count INTEGER DEFAULT 1;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS media_urls TEXT[];
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'citizen';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ward_id UUID REFERENCES wards(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onesignal_id TEXT;

-- Create GiST spatial index on complaints location if not exists
CREATE INDEX IF NOT EXISTS complaints_location_idx ON complaints USING GIST (location);

-- 4. AI Assessments Table
CREATE TABLE IF NOT EXISTS ai_assessments (
    complaint_id UUID PRIMARY KEY REFERENCES complaints(id) ON DELETE CASCADE,
    severity TEXT NOT NULL,
    confidence NUMERIC NOT NULL,
    reason TEXT,
    duplicate_of UUID REFERENCES complaints(id)
);

-- 5. Work Orders Table
CREATE TABLE IF NOT EXISTS work_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID REFERENCES complaints(id) ON DELETE CASCADE NOT NULL,
    engineer_id UUID REFERENCES profiles(id),
    priority TEXT,
    sla_deadline TIMESTAMPTZ,
    stage TEXT DEFAULT 'Assigned',
    history JSONB DEFAULT '[]'::jsonb
);

-- Enable RLS on all tables
ALTER TABLE wards ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_orders ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user role securely
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- RLS Policies
DROP POLICY IF EXISTS "Anyone authenticated can read wards" ON wards;
CREATE POLICY "Anyone authenticated can read wards" ON wards FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can read profiles" ON profiles;
CREATE POLICY "Anyone can read profiles" ON profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Anyone can read complaints" ON complaints;
CREATE POLICY "Anyone can read complaints" ON complaints FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can insert complaints" ON complaints;
CREATE POLICY "Anyone can insert complaints" ON complaints FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can update complaints" ON complaints;
CREATE POLICY "Anyone can update complaints" ON complaints FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Anyone can read ai assessments" ON ai_assessments;
CREATE POLICY "Anyone can read ai assessments" ON ai_assessments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can read work orders" ON work_orders;
CREATE POLICY "Anyone can read work orders" ON work_orders FOR SELECT USING (true);
