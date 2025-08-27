-- Database Updates for Enhanced Event Creation System
-- Run these queries in your Supabase SQL Editor

-- 1. Update Events table to include new fields
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS nft_supply_count INTEGER DEFAULT 50,
ADD COLUMN IF NOT EXISTS event_image_url TEXT,
ADD COLUMN IF NOT EXISTS boundary_description TEXT,
ADD COLUMN IF NOT EXISTS notification_distances INTEGER[] DEFAULT ARRAY[100, 50, 20, 10, 5],
ADD COLUMN IF NOT EXISTS visibility_radius DOUBLE PRECISION DEFAULT 2.0;

-- 2. Update Boundaries table to include NFT-specific fields
ALTER TABLE boundaries 
ADD COLUMN IF NOT EXISTS nft_token_id TEXT,
ADD COLUMN IF NOT EXISTS nft_metadata JSONB,
ADD COLUMN IF NOT EXISTS claim_progress DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS last_notification_distance INTEGER,
ADD COLUMN IF NOT EXISTS is_visible BOOLEAN DEFAULT TRUE;

-- 3. Create new table for NFT metadata
CREATE TABLE IF NOT EXISTS nft_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boundary_id UUID REFERENCES boundaries(id) ON DELETE CASCADE,
    token_id TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    attributes JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create table for user proximity tracking
CREATE TABLE IF NOT EXISTS user_proximity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_wallet_address TEXT NOT NULL,
    boundary_id UUID REFERENCES boundaries(id) ON DELETE CASCADE,
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    distance_meters DOUBLE PRECISION NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    notification_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create table for event creation steps
CREATE TABLE IF NOT EXISTS event_creation_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL,
    step_name TEXT NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_boundaries_event_id ON boundaries(event_id);
CREATE INDEX IF NOT EXISTS idx_boundaries_is_claimed ON boundaries(is_claimed);
CREATE INDEX IF NOT EXISTS idx_boundaries_location ON boundaries USING GIST (
    ll_to_earth(latitude, longitude)
);
CREATE INDEX IF NOT EXISTS idx_user_proximity_user_boundary ON user_proximity_logs(user_wallet_address, boundary_id);
CREATE INDEX IF NOT EXISTS idx_user_proximity_created_at ON user_proximity_logs(created_at);

-- 7. Create function to calculate distance between two points
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN (
        6371000 * acos(
            cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lon2) - radians(lon1)) +
            sin(radians(lat1)) * sin(radians(lat2))
        )
    );
END;
$$ LANGUAGE plpgsql;

-- 8. Create function to update boundary visibility based on user proximity
CREATE OR REPLACE FUNCTION update_boundary_visibility(
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    user_wallet TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE boundaries 
    SET is_visible = (calculate_distance(latitude, longitude, user_lat, user_lon) <= 2.0)
    WHERE event_id IN (
        SELECT id FROM events WHERE NOW() BETWEEN start_date AND end_date
    );
    
    -- Log proximity for analytics
    INSERT INTO user_proximity_logs (
        user_wallet_address,
        boundary_id,
        event_id,
        distance_meters,
        latitude,
        longitude
    )
    SELECT 
        user_wallet,
        b.id,
        b.event_id,
        calculate_distance(b.latitude, b.longitude, user_lat, user_lon),
        user_lat,
        user_lon
    FROM boundaries b
    WHERE b.event_id IN (
        SELECT id FROM events WHERE NOW() BETWEEN start_date AND end_date
    );
END;
$$ LANGUAGE plpgsql;

-- 9. Create function to get nearby boundaries with progress
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
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    is_claimed BOOLEAN,
    claimed_by TEXT,
    is_visible BOOLEAN,
    progress_percentage DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.name,
        b.description,
        b.image_url,
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
        END as progress_percentage
    FROM boundaries b
    WHERE b.event_id IN (
        SELECT id FROM events WHERE NOW() BETWEEN start_date AND end_date
    )
    AND calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= max_distance
    ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql;

-- 10. Create trigger to update NFT metadata when boundary is created
CREATE OR REPLACE FUNCTION create_nft_metadata_for_boundary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO nft_metadata (
        boundary_id,
        token_id,
        name,
        description,
        image_url,
        attributes
    ) VALUES (
        NEW.id,
        'NFT_' || NEW.id,
        NEW.name,
        NEW.description,
        NEW.image_url,
        jsonb_build_object(
            'event_id', NEW.event_id,
            'boundary_id', NEW.id,
            'created_at', NOW(),
            'type', 'boundary_nft'
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_nft_metadata
    AFTER INSERT ON boundaries
    FOR EACH ROW
    EXECUTE FUNCTION create_nft_metadata_for_boundary();

-- 11. Update RLS policies for new tables
ALTER TABLE nft_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_proximity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_creation_steps ENABLE ROW LEVEL SECURITY;

-- Policies for nft_metadata
CREATE POLICY "NFT metadata viewable by everyone" ON nft_metadata FOR SELECT USING (true);
CREATE POLICY "NFT metadata can be created by event organizers" ON nft_metadata FOR INSERT WITH CHECK (true);

-- Policies for user_proximity_logs
CREATE POLICY "Users can view their own proximity logs" ON user_proximity_logs FOR SELECT USING (user_wallet_address = current_user);
CREATE POLICY "Users can insert their own proximity logs" ON user_proximity_logs FOR INSERT WITH CHECK (user_wallet_address = current_user);

-- Policies for event_creation_steps
CREATE POLICY "Event creation steps viewable by event organizers" ON event_creation_steps FOR SELECT USING (true);
CREATE POLICY "Event creation steps can be created by event organizers" ON event_creation_steps FOR INSERT WITH CHECK (true);
CREATE POLICY "Event creation steps can be updated by event organizers" ON event_creation_steps FOR UPDATE USING (true);

-- 12. Add comments for documentation
COMMENT ON TABLE events IS 'Events table with enhanced NFT and boundary management';
COMMENT ON TABLE boundaries IS 'Boundary locations for NFT claims with proximity tracking';
COMMENT ON TABLE nft_metadata IS 'NFT metadata for each boundary';
COMMENT ON TABLE user_proximity_logs IS 'User proximity tracking for analytics and notifications';
COMMENT ON TABLE event_creation_steps IS 'Event creation workflow steps';

-- 13. Create view for event statistics
CREATE OR REPLACE VIEW event_statistics AS
SELECT 
    e.id as event_id,
    e.name as event_name,
    e.nft_supply_count,
    COUNT(b.id) as total_boundaries,
    COUNT(CASE WHEN b.is_claimed THEN 1 END) as claimed_boundaries,
    COUNT(CASE WHEN NOT b.is_claimed THEN 1 END) as available_boundaries,
    ROUND(
        (COUNT(CASE WHEN b.is_claimed THEN 1 END)::DOUBLE PRECISION / COUNT(b.id)::DOUBLE PRECISION) * 100, 
        2
    ) as claim_percentage
FROM events e
LEFT JOIN boundaries b ON e.id = b.event_id
GROUP BY e.id, e.name, e.nft_supply_count;

-- 14. Grant necessary permissions
GRANT SELECT ON event_statistics TO anon;
GRANT SELECT ON event_statistics TO authenticated;
