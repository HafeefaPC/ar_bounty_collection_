-- Add missing columns to events table for enhanced event creation
-- Run this in your Supabase SQL Editor

-- Add new columns to events table
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

-- Create nft_metadata table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.nft_metadata (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    boundary_id uuid REFERENCES public.boundaries(id) ON DELETE CASCADE,
    token_id text,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now()
);

-- Create user_proximity_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_proximity_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_wallet_address text NOT NULL,
    boundary_id uuid REFERENCES public.boundaries(id) ON DELETE CASCADE,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
    distance_meters double precision NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- Create event_creation_steps table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.event_creation_steps (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
    step_number integer NOT NULL,
    step_name text NOT NULL,
    step_data jsonb,
    completed_at timestamp with time zone DEFAULT now()
);

-- Create ar_sessions table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.ar_sessions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_wallet_address text NOT NULL,
    event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
    session_start timestamp with time zone DEFAULT now(),
    session_end timestamp with time zone,
    boundaries_claimed integer DEFAULT 0,
    session_data jsonb
);

-- Add RLS policies for new tables
ALTER TABLE public.nft_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_proximity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_creation_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ar_sessions ENABLE ROW LEVEL SECURITY;

-- Create policies for nft_metadata
CREATE POLICY "Allow public read access to nft_metadata" ON public.nft_metadata
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert to nft_metadata" ON public.nft_metadata
    FOR INSERT WITH CHECK (true);

-- Create policies for user_proximity_logs
CREATE POLICY "Allow public read access to user_proximity_logs" ON public.user_proximity_logs
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert to user_proximity_logs" ON public.user_proximity_logs
    FOR INSERT WITH CHECK (true);

-- Create policies for event_creation_steps
CREATE POLICY "Allow public read access to event_creation_steps" ON public.event_creation_steps
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert to event_creation_steps" ON public.event_creation_steps
    FOR INSERT WITH CHECK (true);

-- Create policies for ar_sessions
CREATE POLICY "Allow public read access to ar_sessions" ON public.ar_sessions
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert to ar_sessions" ON public.ar_sessions
    FOR INSERT WITH CHECK (true);

-- Create the calculate_distance function
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN 6371000 * acos(
        cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lon2) - radians(lon1)) +
        sin(radians(lat1)) * sin(radians(lat2))
    );
END;
$$ LANGUAGE plpgsql;

-- Create the get_nearby_boundaries function
CREATE OR REPLACE FUNCTION get_nearby_boundaries(
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    user_wallet TEXT,
    max_distance DOUBLE PRECISION DEFAULT 1000.0
) RETURNS TABLE (
    boundary_id UUID,
    boundary_name TEXT,
    boundary_description TEXT,
    image_url TEXT,
    nft_image_url TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    is_claimed BOOLEAN,
    claimed_by TEXT,
    is_visible BOOLEAN,
    progress_percentage DOUBLE PRECISION,
    ar_position JSONB,
    ar_rotation JSONB,
    ar_scale JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.name,
        b.description,
        b.image_url,
        b.nft_image_url,
        b.latitude,
        b.longitude,
        calculate_distance(b.latitude, b.longitude, user_lat, user_lon) as distance_meters,
        b.is_claimed,
        b.claimed_by,
        b.is_visible,
        CASE 
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 2.0 THEN 100.0
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 10.0 THEN 80.0
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 50.0 THEN 60.0
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 100.0 THEN 40.0
            ELSE 20.0
        END as progress_percentage,
        b.ar_position,
        b.ar_rotation,
        b.ar_scale
    FROM boundaries b
    WHERE b.event_id IN (
        SELECT id FROM events 
        WHERE start_date <= NOW() AND end_date >= NOW()
    )
    AND calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= max_distance
    ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql;

-- Create the update_boundary_visibility function
CREATE OR REPLACE FUNCTION update_boundary_visibility(
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    user_wallet TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE boundaries 
    SET is_visible = calculate_distance(latitude, longitude, user_lat, user_lon) <= 2.0
    WHERE event_id IN (
        SELECT id FROM events 
        WHERE start_date <= NOW() AND end_date >= NOW()
    );
END;
$$ LANGUAGE plpgsql;

-- Create the claim_boundary_with_nft function
CREATE OR REPLACE FUNCTION claim_boundary_with_nft(
    boundary_id UUID,
    user_wallet TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    boundary_exists BOOLEAN;
BEGIN
    -- Check if boundary exists and is not claimed
    SELECT EXISTS(
        SELECT 1 FROM boundaries 
        WHERE id = boundary_id 
        AND is_claimed = false
    ) INTO boundary_exists;
    
    IF boundary_exists THEN
        -- Claim the boundary
        UPDATE boundaries 
        SET 
            is_claimed = true,
            claimed_by = user_wallet,
            claimed_at = NOW(),
            claim_progress = 100.0
        WHERE id = boundary_id;
        
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create the get_event_statistics function
CREATE OR REPLACE FUNCTION get_event_statistics(event_id UUID)
RETURNS TABLE (
    total_boundaries INTEGER,
    claimed_boundaries INTEGER,
    claim_percentage DOUBLE PRECISION,
    active_participants INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_boundaries,
        COUNT(CASE WHEN is_claimed THEN 1 END)::INTEGER as claimed_boundaries,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                (COUNT(CASE WHEN is_claimed THEN 1 END)::DOUBLE PRECISION / COUNT(*)::DOUBLE PRECISION) * 100
            ELSE 0
        END as claim_percentage,
        COUNT(DISTINCT claimed_by)::INTEGER as active_participants
    FROM boundaries 
    WHERE boundaries.event_id = get_event_statistics.event_id;
END;
$$ LANGUAGE plpgsql;

-- Create views for easier data access
CREATE OR REPLACE VIEW event_statistics AS
SELECT 
    e.id as event_id,
    e.name as event_name,
    COUNT(b.id) as total_boundaries,
    COUNT(CASE WHEN b.is_claimed THEN 1 END) as claimed_boundaries,
    CASE 
        WHEN COUNT(b.id) > 0 THEN 
            (COUNT(CASE WHEN b.is_claimed THEN 1 END)::DOUBLE PRECISION / COUNT(b.id)::DOUBLE PRECISION) * 100
        ELSE 0
    END as claim_percentage
FROM events e
LEFT JOIN boundaries b ON e.id = b.event_id
GROUP BY e.id, e.name;

CREATE OR REPLACE VIEW ar_boundary_data AS
SELECT 
    b.id,
    b.name,
    b.description,
    b.image_url,
    b.nft_image_url,
    b.latitude,
    b.longitude,
    b.radius,
    b.is_claimed,
    b.claimed_by,
    b.is_visible,
    b.ar_position,
    b.ar_rotation,
    b.ar_scale,
    e.name as event_name,
    e.event_code
FROM boundaries b
JOIN events e ON b.event_id = e.id
WHERE e.start_date <= NOW() AND e.end_date >= NOW();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- Verify the changes
SELECT 'Database schema updated successfully!' as status;
