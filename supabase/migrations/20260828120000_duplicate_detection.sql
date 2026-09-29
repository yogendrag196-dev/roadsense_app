-- 1. Add upvote_count to complaints
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS upvote_count INTEGER DEFAULT 1;

-- 2. Create duplicate_log table
CREATE TABLE IF NOT EXISTS duplicate_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    new_complaint_id UUID REFERENCES complaints(id) ON DELETE CASCADE,
    duplicate_of_id UUID REFERENCES complaints(id) ON DELETE CASCADE,
    distance NUMERIC,
    category TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for duplicate_log
ALTER TABLE duplicate_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read duplicate log" ON duplicate_log;
CREATE POLICY "Anyone can read duplicate log" 
ON duplicate_log FOR SELECT 
USING (true);

-- 3. Create detect_duplicate_rpc Postgres function
CREATE OR REPLACE FUNCTION detect_duplicate_rpc(p_new_complaint_id UUID)
RETURNS JSON AS $$
DECLARE
    v_new_location extensions.geography;
    v_new_category TEXT;
    v_duplicate_id UUID;
    v_distance NUMERIC;
    v_result JSON;
BEGIN
    -- Get the new complaint's details
    SELECT location, category INTO v_new_location, v_new_category
    FROM complaints
    WHERE id = p_new_complaint_id;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Complaint not found');
    END IF;

    -- Find the closest matching complaint within 50 meters, created in the last 30 days, not completed/merged
    SELECT id, extensions.ST_Distance(location, v_new_location) INTO v_duplicate_id, v_distance
    FROM complaints
    WHERE id != p_new_complaint_id
      AND category = v_new_category
      AND created_at >= NOW() - INTERVAL '30 days'
      AND status NOT IN ('completed', 'merged', 'Completed', 'Merged')
      AND extensions.ST_DWithin(location, v_new_location, 50)
    ORDER BY extensions.ST_Distance(location, v_new_location) ASC
    LIMIT 1;

    -- If a duplicate is found
    IF v_duplicate_id IS NOT NULL THEN
        -- Mark new complaint as merged
        UPDATE complaints SET status = 'merged' WHERE id = p_new_complaint_id;

        -- Update ai_assessments to point to the duplicate
        UPDATE ai_assessments SET duplicate_of = v_duplicate_id WHERE complaint_id = p_new_complaint_id;

        -- Increment upvote_count on the original complaint
        UPDATE complaints SET upvote_count = COALESCE(upvote_count, 1) + 1 WHERE id = v_duplicate_id;

        -- Log the decision
        INSERT INTO duplicate_log (new_complaint_id, duplicate_of_id, distance, category)
        VALUES (p_new_complaint_id, v_duplicate_id, v_distance, v_new_category);

        v_result := json_build_object(
            'is_duplicate', true,
            'duplicate_id', v_duplicate_id,
            'distance', v_distance
        );
    ELSE
        v_result := json_build_object('is_duplicate', false);
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
