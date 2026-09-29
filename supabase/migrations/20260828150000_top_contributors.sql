-- Drop existing materialized view or view if exists
DROP MATERIALIZED VIEW IF EXISTS top_contributors_summary;
DROP VIEW IF EXISTS top_contributors_summary;

-- Create Realtime View for Top Contributors Summary
CREATE OR REPLACE VIEW top_contributors_summary AS
SELECT 
    p.id as citizen_id,
    COALESCE(p.name, split_part(p.email, '@', 1), 'Citizen') as name,
    COUNT(c.id) as total_reports,
    COUNT(c.id) FILTER (WHERE lower(c.status) IN ('completed', 'resolved', 'merged')) as resolved_reports,
    COALESCE(SUM(c.upvote_count), 0) as total_upvotes
FROM profiles p
LEFT JOIN complaints c ON (p.id = c.citizen_id OR p.id = c.user_id)
WHERE COALESCE(p.role, 'citizen') = 'citizen'
GROUP BY p.id, p.name, p.email;

-- Grant permissions to authenticated and anon
GRANT SELECT ON top_contributors_summary TO authenticated, anon, service_role;
