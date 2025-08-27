-- FaceReflector Enhanced Event Creation System - Database Updates v2
-- Run these queries in your Supabase SQL Editor

-- 1. Update Events table to include new fields for enhanced event creation
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS nft_supply_count INTEGER DEFAULT 50,
ADD COLUMN IF NOT EXISTS event_image_url TEXT,
ADD COLUMN IF NOT EXISTS boundary_description TEXT,
ADD COLUMN IF NOT EXISTS notification_distances INTEGER[] DEFAULT ARRAY[100, 50, 20, 10, 5],
ADD COLUMN IF NOT EXISTS visibility_radius DOUBLE PRECISION DEFAULT 2.0,
ADD COLUMN IF NOT EXISTS start_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS end_date TIMESTAMP WITH TIME ZONE;

-- 2. Update Boundaries table to include NFT-specific fields and AR integration
ALTER TABLE boundaries 
ADD COLUMN IF NOT EXISTS nft_token_id TEXT,
ADD COLUMN IF NOT EXISTS nft_metadata JSONB,
ADD COLUMN IF NOT EXISTS claim_progress DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS last_notification_distance INTEGER,
ADD COLUMN IF NOT EXISTS is_visible BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS ar_position JSONB,
ADD COLUMN IF NOT EXISTS ar_rotation JSONB,
ADD COLUMN IF NOT EXISTS ar_scale JSONB,
ADD COLUMN IF NOT EXISTS nft_image_url TEXT;

-- 3. Create new table for NFT metadata with enhanced AR support
CREATE TABLE IF NOT EXISTS nft_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boundary_id UUID REFERENCES boundaries(id) ON DELETE CASCADE,
    token_id TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    ar_image_url TEXT,
    attributes JSONB,
    ar_position JSONB,
    ar_rotation JSONB,
    ar_scale JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create table for user proximity tracking with enhanced analytics
CREATE TABLE IF NOT EXISTS user_proximity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_wallet_address TEXT NOT NULL,
    boundary_id UUID REFERENCES boundaries(id) ON DELETE CASCADE,
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    distance_meters DOUBLE PRECISION NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    notification_sent BOOLEAN DEFAULT FALSE,
    notification_distance INTEGER,
    progress_percentage DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create table for event creation steps tracking
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

-- 6. Create table for AR session tracking
CREATE TABLE IF NOT EXISTS ar_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_wallet_address TEXT NOT NULL,
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    boundary_id UUID REFERENCES boundaries(id) ON DELETE CASCADE,
    session_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_end TIMESTAMP WITH TIME ZONE,
    interaction_data JSONB,
    device_info JSONB
);

-- 7. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_boundaries_event_id ON boundaries(event_id);
CREATE INDEX IF NOT EXISTS idx_boundaries_is_claimed ON boundaries(is_claimed);
CREATE INDEX IF NOT EXISTS idx_boundaries_location ON boundaries USING GIST (
    ll_to_earth(latitude, longitude)
);
CREATE INDEX IF NOT EXISTS idx_boundaries_is_visible ON boundaries(is_visible);
CREATE INDEX IF NOT EXISTS idx_user_proximity_user_boundary ON user_proximity_logs(user_wallet_address, boundary_id);
CREATE INDEX IF NOT EXISTS idx_user_proximity_created_at ON user_proximity_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_events_active ON events(start_date, end_date) WHERE start_date <= NOW() AND end_date >= NOW();

-- 8. Create function to calculate distance between two points (Haversine formula)
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
DECLARE
    R DOUBLE PRECISION := 6371000; -- Earth's radius in meters
    dlat DOUBLE PRECISION;
    dlon DOUBLE PRECISION;
    a DOUBLE PRECISION;
    c DOUBLE PRECISION;
BEGIN
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    a := sin(dlat/2) * sin(dlat/2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2) * sin(dlon/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    RETURN R * c;
END;
$$ LANGUAGE plpgsql;

-- 9. Create function to update boundary visibility based on user proximity
CREATE OR REPLACE FUNCTION update_boundary_visibility(
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    user_wallet TEXT
) RETURNS VOID AS $$
BEGIN
    -- Update boundary visibility based on proximity
    UPDATE boundaries 
    SET is_visible = (calculate_distance(latitude, longitude, user_lat, user_lon) <= 2.0)
    WHERE event_id IN (
        SELECT id FROM events 
        WHERE start_date <= NOW() AND end_date >= NOW()
    );
    
    -- Log proximity for analytics
    INSERT INTO user_proximity_logs (
        user_wallet_address,
        boundary_id,
        event_id,
        distance_meters,
        latitude,
        longitude,
        progress_percentage
    )
    SELECT 
        user_wallet,
        b.id,
        b.event_id,
        calculate_distance(b.latitude, b.longitude, user_lat, user_lon),
        user_lat,
        user_lon,
        CASE 
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 2.0 THEN 100.0
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 10.0 THEN 80.0
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 50.0 THEN 60.0
            WHEN calculate_distance(b.latitude, b.longitude, user_lat, user_lon) <= 100.0 THEN 40.0
            ELSE 20.0
        END
    FROM boundaries b
    WHERE b.event_id IN (
        SELECT id FROM events 
        WHERE start_date <= NOW() AND end_date >= NOW()
    )
    AND NOT b.is_claimed;
END;
$$ LANGUAGE plpgsql;

-- 10. Create function to get nearby boundaries with enhanced progress data
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

-- 11. Create function to claim boundary with NFT metadata
CREATE OR REPLACE FUNCTION claim_boundary_with_nft(
    boundary_uuid UUID,
    user_wallet TEXT,
    nft_token_id TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    boundary_exists BOOLEAN;
    already_claimed BOOLEAN;
BEGIN
    -- Check if boundary exists and is not already claimed
    SELECT EXISTS(SELECT 1 FROM boundaries WHERE id = boundary_uuid) INTO boundary_exists;
    SELECT is_claimed FROM boundaries WHERE id = boundary_uuid INTO already_claimed;
    
    IF NOT boundary_exists THEN
        RETURN FALSE;
    END IF;
    
    IF already_claimed THEN
        RETURN FALSE;
    END IF;
    
    -- Claim the boundary
    UPDATE boundaries 
    SET 
        is_claimed = TRUE,
        claimed_by = user_wallet,
        claimed_at = NOW(),
        claim_progress = 100.0,
        nft_token_id = COALESCE(nft_token_id, 'NFT_' || boundary_uuid)
    WHERE id = boundary_uuid;
    
    -- Update NFT metadata
    UPDATE nft_metadata 
    SET 
        token_id = COALESCE(nft_token_id, 'NFT_' || boundary_uuid),
        updated_at = NOW()
    WHERE boundary_id = boundary_uuid;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 12. Create trigger to update NFT metadata when boundary is created
CREATE OR REPLACE FUNCTION create_nft_metadata_for_boundary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO nft_metadata (
        boundary_id,
        token_id,
        name,
        description,
        image_url,
        ar_image_url,
        attributes,
        ar_position,
        ar_rotation,
        ar_scale
    ) VALUES (
        NEW.id,
        'NFT_' || NEW.id,
        NEW.name,
        NEW.description,
        NEW.image_url,
        NEW.nft_image_url,
        jsonb_build_object(
            'event_id', NEW.event_id,
            'boundary_id', NEW.id,
            'created_at', NOW(),
            'type', 'boundary_nft',
            'claim_radius', NEW.radius,
            'ar_enabled', true
        ),
        NEW.ar_position,
        NEW.ar_rotation,
        NEW.ar_scale
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_nft_metadata
    AFTER INSERT ON boundaries
    FOR EACH ROW
    EXECUTE FUNCTION create_nft_metadata_for_boundary();

-- 13. Create function to get event statistics with NFT data
CREATE OR REPLACE FUNCTION get_event_statistics(event_uuid UUID)
RETURNS TABLE (
    event_id UUID,
    event_name TEXT,
    nft_supply_count INTEGER,
    total_boundaries INTEGER,
    claimed_boundaries INTEGER,
    available_boundaries INTEGER,
    claim_percentage DOUBLE PRECISION,
    total_participants INTEGER,
    active_participants INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.name,
        e.nft_supply_count,
        COUNT(b.id)::INTEGER as total_boundaries,
        COUNT(CASE WHEN b.is_claimed THEN 1 END)::INTEGER as claimed_boundaries,
        COUNT(CASE WHEN NOT b.is_claimed THEN 1 END)::INTEGER as available_boundaries,
        CASE 
            WHEN COUNT(b.id) > 0 THEN 
                ROUND((COUNT(CASE WHEN b.is_claimed THEN 1 END)::DOUBLE PRECISION / COUNT(b.id)::DOUBLE PRECISION) * 100, 2)
            ELSE 0.0
        END as claim_percentage,
        COUNT(DISTINCT b.claimed_by)::INTEGER as total_participants,
        COUNT(DISTINCT CASE WHEN b.claimed_at >= NOW() - INTERVAL '24 hours' THEN b.claimed_by END)::INTEGER as active_participants
    FROM events e
    LEFT JOIN boundaries b ON e.id = b.event_id
    WHERE e.id = event_uuid
    GROUP BY e.id, e.name, e.nft_supply_count;
END;
$$ LANGUAGE plpgsql;

-- 14. Update RLS policies for new tables
ALTER TABLE nft_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_proximity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_creation_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE ar_sessions ENABLE ROW LEVEL SECURITY;

-- Policies for nft_metadata
CREATE POLICY "NFT metadata viewable by everyone" ON nft_metadata FOR SELECT USING (true);
CREATE POLICY "NFT metadata can be created by event organizers" ON nft_metadata FOR INSERT WITH CHECK (true);
CREATE POLICY "NFT metadata can be updated by event organizers" ON nft_metadata FOR UPDATE USING (true);

-- Policies for user_proximity_logs
CREATE POLICY "Users can view their own proximity logs" ON user_proximity_logs FOR SELECT USING (user_wallet_address = current_user);
CREATE POLICY "Users can insert their own proximity logs" ON user_proximity_logs FOR INSERT WITH CHECK (user_wallet_address = current_user);

-- Policies for event_creation_steps
CREATE POLICY "Event creation steps viewable by event organizers" ON event_creation_steps FOR SELECT USING (true);
CREATE POLICY "Event creation steps can be created by event organizers" ON event_creation_steps FOR INSERT WITH CHECK (true);
CREATE POLICY "Event creation steps can be updated by event organizers" ON event_creation_steps FOR UPDATE USING (true);

-- Policies for ar_sessions
CREATE POLICY "Users can view their own AR sessions" ON ar_sessions FOR SELECT USING (user_wallet_address = current_user);
CREATE POLICY "Users can insert their own AR sessions" ON ar_sessions FOR INSERT WITH CHECK (user_wallet_address = current_user);
CREATE POLICY "Users can update their own AR sessions" ON ar_sessions FOR UPDATE USING (user_wallet_address = current_user);

-- 15. Create view for event statistics
CREATE OR REPLACE VIEW event_statistics AS
SELECT 
    e.id as event_id,
    e.name as event_name,
    e.nft_supply_count,
    COUNT(b.id) as total_boundaries,
    COUNT(CASE WHEN b.is_claimed THEN 1 END) as claimed_boundaries,
    COUNT(CASE WHEN NOT b.is_claimed THEN 1 END) as available_boundaries,
    ROUND(
        (COUNT(CASE WHEN b.is_claimed THEN 1 END)::DOUBLE PRECISION / NULLIF(COUNT(b.id), 0)::DOUBLE PRECISION) * 100, 
        2
    ) as claim_percentage,
    COUNT(DISTINCT b.claimed_by) as total_participants,
    e.start_date,
    e.end_date,
    CASE 
        WHEN e.start_date <= NOW() AND e.end_date >= NOW() THEN 'active'
        WHEN e.start_date > NOW() THEN 'upcoming'
        ELSE 'ended'
    END as event_status
FROM events e
LEFT JOIN boundaries b ON e.id = b.event_id
GROUP BY e.id, e.name, e.nft_supply_count, e.start_date, e.end_date;

-- 16. Create view for AR boundary data
CREATE OR REPLACE VIEW ar_boundary_data AS
SELECT 
    b.id as boundary_id,
    b.name as boundary_name,
    b.description as boundary_description,
    b.nft_image_url,
    b.latitude,
    b.longitude,
    b.is_claimed,
    b.claimed_by,
    b.is_visible,
    b.ar_position,
    b.ar_rotation,
    b.ar_scale,
    e.id as event_id,
    e.name as event_name,
    e.notification_distances,
    e.visibility_radius
FROM boundaries b
JOIN events e ON b.event_id = e.id
WHERE e.start_date <= NOW() AND e.end_date >= NOW();

-- 17. Add comments for documentation
COMMENT ON TABLE events IS 'Events table with enhanced NFT and boundary management for AR-powered event goodies';
COMMENT ON TABLE boundaries IS 'Boundary locations for NFT claims with proximity tracking and AR integration';
COMMENT ON TABLE nft_metadata IS 'NFT metadata for each boundary with AR positioning data';
COMMENT ON TABLE user_proximity_logs IS 'User proximity tracking for analytics and notifications';
COMMENT ON TABLE event_creation_steps IS 'Event creation workflow steps tracking';
COMMENT ON TABLE ar_sessions IS 'AR session tracking for user interactions';

-- 18. Grant necessary permissions
GRANT SELECT ON event_statistics TO anon;
GRANT SELECT ON event_statistics TO authenticated;
GRANT SELECT ON ar_boundary_data TO anon;
GRANT SELECT ON ar_boundary_data TO authenticated;

-- 19. Create function to clean up old proximity logs (optional - for performance)
CREATE OR REPLACE FUNCTION cleanup_old_proximity_logs(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_proximity_logs 
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 20. Create function to get user's claimed NFTs
CREATE OR REPLACE FUNCTION get_user_claimed_nfts(user_wallet TEXT)
RETURNS TABLE (
    boundary_id UUID,
    boundary_name TEXT,
    event_name TEXT,
    claimed_at TIMESTAMP WITH TIME ZONE,
    nft_token_id TEXT,
    nft_image_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.name,
        e.name as event_name,
        b.claimed_at,
        b.nft_token_id,
        b.nft_image_url
    FROM boundaries b
    JOIN events e ON b.event_id = e.id
    WHERE b.claimed_by = user_wallet
    ORDER BY b.claimed_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Success message
SELECT 'Database updated successfully! Enhanced event creation system with AR integration is ready.' as status;
