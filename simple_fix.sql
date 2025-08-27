-- Simple fix for missing columns
-- Run this in your Supabase SQL Editor

-- Add missing columns to events table
ALTER TABLE public.events 
ADD COLUMN IF NOT EXISTS nft_supply_count integer DEFAULT 50,
ADD COLUMN IF NOT EXISTS event_image_url text,
ADD COLUMN IF NOT EXISTS boundary_description text,
ADD COLUMN IF NOT EXISTS notification_distances integer[] DEFAULT ARRAY[100, 50, 20, 10, 5],
ADD COLUMN IF NOT EXISTS visibility_radius double precision DEFAULT 2.0;

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

-- Verify the columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'events' 
AND column_name IN ('nft_supply_count', 'event_image_url', 'boundary_description', 'notification_distances', 'visibility_radius')
ORDER BY column_name;
