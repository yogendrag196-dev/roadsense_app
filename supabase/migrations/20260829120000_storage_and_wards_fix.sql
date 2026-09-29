-- 1. Create Storage Buckets for complaint media
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('complaint-media', 'complaint-media', true),
  ('complaints_media', 'complaints_media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage policies
DROP POLICY IF EXISTS "Public complaint-media Access" ON storage.objects;
CREATE POLICY "Public complaint-media Access" 
ON storage.objects FOR SELECT 
USING (bucket_id IN ('complaint-media', 'complaints_media'));

DROP POLICY IF EXISTS "Authenticated complaint-media Upload" ON storage.objects;
CREATE POLICY "Authenticated complaint-media Upload" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id IN ('complaint-media', 'complaints_media'));

DROP POLICY IF EXISTS "Authenticated complaint-media Update" ON storage.objects;
CREATE POLICY "Authenticated complaint-media Update" 
ON storage.objects FOR UPDATE 
USING (bucket_id IN ('complaint-media', 'complaints_media'));

-- 2. Helper function to find the nearest Bangalore Ward from lat & lng
CREATE OR REPLACE FUNCTION get_nearest_ward(p_lat NUMERIC, p_lng NUMERIC)
RETURNS JSON AS $$
DECLARE
    v_ward_id UUID;
    v_ward_name TEXT;
BEGIN
    SELECT id, name INTO v_ward_id, v_ward_name
    FROM wards
    WHERE center_lat IS NOT NULL AND center_lng IS NOT NULL
    ORDER BY (
        (center_lat - p_lat) * (center_lat - p_lat) + 
        (center_lng - p_lng) * (center_lng - p_lng)
    ) ASC
    LIMIT 1;

    IF v_ward_id IS NULL THEN
        -- Fallback to first available ward
        SELECT id, name INTO v_ward_id, v_ward_name FROM wards LIMIT 1;
    END IF;

    RETURN json_build_object(
        'ward_id', v_ward_id,
        'ward_name', v_ward_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_nearest_ward(NUMERIC, NUMERIC) TO authenticated, anon, service_role;
