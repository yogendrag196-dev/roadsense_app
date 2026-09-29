-- Make ward_id nullable so complaints can be submitted even if ward is detected by name
ALTER TABLE complaints ALTER COLUMN ward_id DROP NOT NULL;

-- Ensure default public BBMP wards exist
INSERT INTO wards (name, ward_number, center_lat, center_lng, resolution_rate, total_reports, resolved_reports)
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

-- Grant full permissions on complaints
GRANT ALL ON complaints TO authenticated, anon, service_role;
GRANT ALL ON ai_assessments TO authenticated, anon, service_role;
GRANT ALL ON work_orders TO authenticated, anon, service_role;
