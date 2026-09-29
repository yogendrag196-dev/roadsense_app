-- 1. Add onesignal_id to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS onesignal_id TEXT;
