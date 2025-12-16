-- Create user_devices table to store FCM tokens
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

-- Create index on user_id for faster queriesa
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);

-- Enable RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only read their own devices
CREATE POLICY "Users can view own devices"
  ON user_devices
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own devices
CREATE POLICY "Users can insert own devices"
  ON user_devices
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own devices
CREATE POLICY "Users can update own devices"
  ON user_devices
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own devices
CREATE POLICY "Users can delete own devices"
  ON user_devices
  FOR DELETE
  USING (auth.uid() = user_id);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_user_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_devices_updated_at
  BEFORE UPDATE ON user_devices
  FOR EACH ROW
  EXECUTE FUNCTION update_user_devices_updated_at();
