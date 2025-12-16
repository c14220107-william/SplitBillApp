-- Add quantity column to item_assignments table
-- Run this SQL in Supabase SQL Editor

ALTER TABLE public.item_assignments 
ADD COLUMN IF NOT EXISTS quantity INTEGER NOT NULL DEFAULT 1;

-- Add comment
COMMENT ON COLUMN public.item_assignments.quantity IS 'Number of items assigned to this user';
