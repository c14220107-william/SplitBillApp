-- =====================================================
-- SUPABASE STORAGE POLICIES
-- =====================================================
-- Run these policies in Supabase SQL Editor
-- to allow users to upload avatars and payment proofs
-- =====================================================
-- NOTE: If policies already exist, use DROP POLICY first
-- or check existing policies in Storage > Policies
-- =====================================================

-- =====================================================
-- AVATARS BUCKET POLICIES
-- =====================================================

-- Drop existing policies if needed (uncomment if updating)
-- DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
-- DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
-- DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
-- DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;

-- Allow authenticated users to upload their own avatar
CREATE POLICY "Users can upload their own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to update their own avatar
CREATE POLICY "Users can update their own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to delete their own avatar
CREATE POLICY "Users can delete their own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow anyone to view avatars (public read)
CREATE POLICY "Anyone can view avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- =====================================================
-- PAYMENT_PROOFS BUCKET POLICIES
-- =====================================================

-- Allow authenticated users to upload payment proofs
CREATE POLICY "Users can upload payment proofs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'payment_proofs' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to update their own payment proofs
CREATE POLICY "Users can update their own payment proofs"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'payment_proofs' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to delete their own payment proofs
CREATE POLICY "Users can delete their own payment proofs"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'payment_proofs' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to view payment proofs
-- (host needs to see member's payment proofs)
CREATE POLICY "Authenticated users can view payment proofs"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'payment_proofs');

-- =====================================================
-- NOTES
-- =====================================================
-- 1. Make sure buckets 'avatars' and 'payment_proofs' are created
-- 2. File path structure: bucket_id/user_id/filename
--    Example: avatars/user-123/avatar.jpg
--             payment_proofs/user-123/bill-456.jpg
-- 3. Adjust policies as needed for your security requirements
-- =====================================================
