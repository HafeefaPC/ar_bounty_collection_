-- Check and add missing columns to boundaries table
-- Run this in your Supabase SQL Editor

-- Add missing columns to boundaries table
ALTER TABLE public.boundaries 
ADD COLUMN IF NOT EXISTS nft_token_id text,
ADD COLUMN IF NOT EXISTS nft_metadata jsonb,
ADD COLUMN IF NOT EXISTS claim_progress double precision DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS last_notification_distance double precision,
ADD COLUMN IF NOT EXISTS is_visible boolean DEFAULT true,
ADD COLUMN IF NOT EXISTS ar_position jsonb,
ADD COLUMN IF NOT EXISTS ar_rotation jsonb,
ADD COLUMN IF NOT EXISTS ar_scale jsonb,
ADD COLUMN IF NOT EXISTS nft_image_url text;

-- Verify the boundaries table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'boundaries' 
ORDER BY ordinal_position;

-- Check if boundaries table exists and has basic structure
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'boundaries'
) as boundaries_table_exists;
