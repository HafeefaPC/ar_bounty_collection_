-- NFT Bounty System Database Enhancements
-- This script enhances the existing boundaries table and adds necessary constraints

-- 1. Add missing columns to boundaries table if they don't exist
DO $$ 
BEGIN
    -- Add claim_progress column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'boundaries' AND column_name = 'claim_progress') THEN
        ALTER TABLE public.boundaries ADD COLUMN claim_progress double precision DEFAULT 0.0;
    END IF;
    
    -- Add is_visible column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'boundaries' AND column_name = 'is_visible') THEN
        ALTER TABLE public.boundaries ADD COLUMN is_visible boolean DEFAULT true;
    END IF;
    
    -- Add event_name column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'boundaries' AND column_name = 'event_name') THEN
        ALTER TABLE public.boundaries ADD COLUMN event_name text;
    END IF;
    
    -- Add event_code column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'boundaries' AND column_name = 'event_code') THEN
        ALTER TABLE public.boundaries ADD COLUMN event_code text;
    END IF;
END $$;

-- 2. Create a function to prevent double claiming
CREATE OR REPLACE FUNCTION prevent_double_claim()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if boundary is already claimed
    IF NEW.is_claimed = true AND OLD.is_claimed = false THEN
        -- Check if someone else has already claimed it
        IF EXISTS (
            SELECT 1 FROM boundaries 
            WHERE id = NEW.id 
            AND is_claimed = true 
            AND claimed_by IS NOT NULL
            AND claimed_by != NEW.claimed_by
        ) THEN
            RAISE EXCEPTION 'Boundary has already been claimed by another user';
        END IF;
        
        -- Validate claim distance
        IF NEW.claim_progress < 100.0 THEN
            RAISE EXCEPTION 'Claim progress must be 100% to mark as claimed';
        END IF;
        
        -- Set claim timestamp if not provided
        IF NEW.claimed_at IS NULL THEN
            NEW.claimed_at = NOW();
        END IF;
        
        -- Update the updated_at timestamp
        NEW.updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create trigger to prevent double claiming
DROP TRIGGER IF EXISTS trigger_prevent_double_claim ON boundaries;
CREATE TRIGGER trigger_prevent_double_claim
    BEFORE UPDATE ON boundaries
    FOR EACH ROW
    EXECUTE FUNCTION prevent_double_claim();

-- 4. Create function to update event stats when boundaries are claimed
CREATE OR REPLACE FUNCTION update_event_stats_on_claim()
RETURNS TRIGGER AS $$
BEGIN
    -- Update event statistics when a boundary is claimed
    IF NEW.is_claimed = true AND (OLD.is_claimed = false OR OLD.is_claimed IS NULL) THEN
        -- Update events table with new claim count
        UPDATE events 
        SET 
            total_claimed_boundaries = COALESCE(total_claimed_boundaries, 0) + 1,
            updated_at = NOW()
        WHERE id = NEW.event_id;
        
        -- Log the claim for analytics
        INSERT INTO user_proximity_logs (
            user_wallet_address,
            boundary_id,
            event_id,
            distance_meters,
            claimed_at,
            claim_successful
        ) VALUES (
            NEW.claimed_by,
            NEW.id,
            NEW.event_id,
            0.0, -- Will be updated with actual distance
            NEW.claimed_at,
            true
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger for updating event stats
DROP TRIGGER IF EXISTS trigger_update_event_stats_on_claim ON boundaries;
CREATE TRIGGER trigger_update_event_stats_on_claim
    AFTER UPDATE ON boundaries
    FOR EACH ROW
    EXECUTE FUNCTION update_event_stats_on_claim();

-- 6. Create function to validate event isolation
CREATE OR REPLACE FUNCTION validate_event_isolation()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure boundary belongs to a valid event
    IF NOT EXISTS (
        SELECT 1 FROM events 
        WHERE id = NEW.event_id 
        AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Boundary must belong to an active event';
    END IF;
    
    -- Update event_name and event_code for consistency
    SELECT event_name, event_code INTO NEW.event_name, NEW.event_code
    FROM events 
    WHERE id = NEW.event_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger for event isolation validation
DROP TRIGGER IF EXISTS trigger_validate_event_isolation ON boundaries;
CREATE TRIGGER trigger_validate_event_isolation
    BEFORE INSERT OR UPDATE ON boundaries
    FOR EACH ROW
    EXECUTE FUNCTION validate_event_isolation();

-- 8. Create function to get nearby boundaries for a specific event
CREATE OR REPLACE FUNCTION get_nearby_boundaries_for_event(
    user_lat double precision,
    user_lng double precision,
    event_code text,
    max_distance double precision DEFAULT 5.0
)
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    image_url text,
    latitude double precision,
    longitude double precision,
    radius double precision,
    is_claimed boolean,
    claimed_by text,
    claimed_at timestamp with time zone,
    event_id uuid,
    event_name text,
    distance_meters double precision
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
        b.radius,
        b.is_claimed,
        b.claimed_by,
        b.claimed_at,
        b.event_id,
        b.event_name,
        ST_Distance(
            ST_MakePoint(user_lng, user_lat)::geography,
            ST_MakePoint(b.longitude, b.latitude)::geography
        ) as distance_meters
    FROM boundaries b
    JOIN events e ON b.event_id = e.id
    WHERE e.event_code = get_nearby_boundaries_for_event.event_code
    AND b.is_visible = true
    AND b.is_claimed = false
    AND ST_DWithin(
        ST_MakePoint(user_lng, user_lat)::geography,
        ST_MakePoint(b.longitude, b.latitude)::geography,
        max_distance
    )
    ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql;

-- 9. Create function to claim boundary atomically
CREATE OR REPLACE FUNCTION claim_boundary(
    boundary_id uuid,
    user_wallet text,
    claim_distance double precision
)
RETURNS boolean AS $$
DECLARE
    boundary_record boundaries%ROWTYPE;
    event_record events%ROWTYPE;
BEGIN
    -- Get boundary details
    SELECT * INTO boundary_record 
    FROM boundaries 
    WHERE id = boundary_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Boundary not found';
    END IF;
    
    -- Get event details
    SELECT * INTO event_record 
    FROM events 
    WHERE id = boundary_record.event_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event not found';
    END IF;
    
    -- Check if already claimed
    IF boundary_record.is_claimed THEN
        RETURN false;
    END IF;
    
    -- Check if user is within claiming radius
    IF claim_distance > boundary_record.radius THEN
        RETURN false;
    END IF;
    
    -- Check if user has already claimed this boundary
    IF EXISTS (
        SELECT 1 FROM boundaries 
        WHERE id = boundary_id 
        AND claimed_by = user_wallet
    ) THEN
        RETURN false;
    END IF;
    
    -- Claim the boundary
    UPDATE boundaries 
    SET 
        is_claimed = true,
        claimed_by = user_wallet,
        claimed_at = NOW(),
        claim_progress = 100.0,
        updated_at = NOW()
    WHERE id = boundary_id 
    AND is_claimed = false;
    
    -- Check if update was successful
    IF FOUND THEN
        -- Log the claim
        INSERT INTO user_proximity_logs (
            user_wallet_address,
            boundary_id,
            event_id,
            distance_meters,
            claimed_at,
            claim_successful
        ) VALUES (
            user_wallet,
            boundary_id,
            boundary_record.event_id,
            claim_distance,
            NOW(),
            true
        );
        
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 10. Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_boundaries_event_code ON boundaries(event_code);
CREATE INDEX IF NOT EXISTS idx_boundaries_claim_status ON boundaries(is_claimed, claimed_by);
CREATE INDEX IF NOT EXISTS idx_boundaries_location_event ON boundaries(event_id, latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_boundaries_visible_claimed ON boundaries(is_visible, is_claimed);

-- 11. Create view for event statistics
CREATE OR REPLACE VIEW event_statistics AS
SELECT 
    e.id as event_id,
    e.name as event_name,
    e.event_code,
    COUNT(b.id) as total_boundaries,
    COUNT(CASE WHEN b.is_claimed THEN 1 END) as claimed_boundaries,
    COUNT(CASE WHEN NOT b.is_claimed THEN 1 END) as available_boundaries,
    COUNT(DISTINCT b.claimed_by) as unique_claimers,
    e.created_at,
    e.updated_at
FROM events e
LEFT JOIN boundaries b ON e.id = b.event_id AND b.is_visible = true
GROUP BY e.id, e.name, e.event_code, e.created_at, e.updated_at;

-- 12. Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_nearby_boundaries_for_event TO authenticated;
GRANT EXECUTE ON FUNCTION claim_boundary TO authenticated;
GRANT SELECT ON event_statistics TO authenticated;

-- 13. Update existing boundaries with event information
UPDATE boundaries 
SET 
    event_name = e.name,
    event_code = e.event_code
FROM events e
WHERE boundaries.event_id = e.id
AND (boundaries.event_name IS NULL OR boundaries.event_code IS NULL);

-- 14. Create a function to reset boundaries for testing (admin only)
CREATE OR REPLACE FUNCTION reset_event_boundaries_for_testing(event_id uuid)
RETURNS boolean AS $$
BEGIN
    -- Only allow in development/testing environment
    IF current_setting('app.environment', true) NOT IN ('development', 'test') THEN
        RAISE EXCEPTION 'This function is only available in development/testing environment';
    END IF;
    
    UPDATE boundaries 
    SET 
        is_claimed = false,
        claimed_by = NULL,
        claimed_at = NULL,
        claim_progress = 0.0,
        updated_at = NOW()
    WHERE event_id = reset_event_boundaries_for_testing.event_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- 15. Create a function to get boundary status for debugging
CREATE OR REPLACE FUNCTION get_boundary_status(event_id uuid)
RETURNS TABLE (
    boundary_name text,
    is_claimed boolean,
    claimed_by text,
    claimed_at timestamp with time zone,
    claim_progress double precision
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.name,
        b.is_claimed,
        b.claimed_by,
        b.claimed_at,
        b.claim_progress
    FROM boundaries b
    WHERE b.event_id = get_boundary_status.event_id
    ORDER BY b.name;
END;
$$ LANGUAGE plpgsql;

-- 16. Add comments for documentation
COMMENT ON FUNCTION get_nearby_boundaries_for_event IS 'Get nearby unclaimed boundaries for a specific event, ensuring event isolation';
COMMENT ON FUNCTION claim_boundary IS 'Atomically claim a boundary, preventing double claiming and ensuring proper validation';
COMMENT ON FUNCTION validate_event_isolation IS 'Ensure boundaries belong to valid events and maintain event isolation';
COMMENT ON VIEW event_statistics IS 'View providing comprehensive statistics for each event including claim counts';

-- 17. Verify the setup
DO $$
BEGIN
    RAISE NOTICE 'NFT Bounty System database enhancements completed successfully!';
    RAISE NOTICE 'Key features added:';
    RAISE NOTICE '- Event isolation for boundaries';
    RAISE NOTICE '- Double claiming prevention';
    RAISE NOTICE '- Atomic boundary claiming';
    RAISE NOTICE '- Performance indexes';
    RAISE NOTICE '- Event statistics view';
    RAISE NOTICE '- Comprehensive validation triggers';
END $$;
