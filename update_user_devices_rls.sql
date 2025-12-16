-- Update RLS policy to allow reading FCM tokens for sending notifications
-- This is needed so users can send push notifications to other users

-- Drop the restrictive SELECT policy
DROP POLICY IF EXISTS "Users can view own devices" ON user_devices;

-- Create new policy: authenticated users can read FCM tokens
-- This allows NotificationService to query tokens for push notifications
CREATE POLICY "Authenticated users can read FCM tokens"
  ON user_devices
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Keep INSERT/UPDATE/DELETE restricted to own devices
-- (These policies already exist, just listing for clarity)

-- Alternative: If you want more restrictive, only allow reading tokens of users
-- in the same bills. But that requires JOIN which is complex in RLS.
-- For now, allowing authenticated users to read tokens is acceptable since:
-- 1. FCM tokens are not sensitive data (they're device identifiers)
-- 2. Users can only send notifications if they share a bill (enforced in app logic)
-- 3. Tokens expire/change frequently
