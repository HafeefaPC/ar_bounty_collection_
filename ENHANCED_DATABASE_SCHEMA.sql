-- Enhanced Database Schema for AR Boundary Claims

-- Users table (for tracking user claims)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  wallet_address TEXT NOT NULL UNIQUE,
  username TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  last_login TIMESTAMP WITH TIME ZONE,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- Events table
CREATE TABLE IF NOT EXISTS public.events (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  organizer_wallet_address TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  venue_name TEXT NOT NULL,
  event_code TEXT NOT NULL UNIQUE,
  nft_supply_count INTEGER DEFAULT 50,
  event_image_url TEXT,
  boundary_description TEXT,
  notification_distances INTEGER[] DEFAULT ARRAY[100, 50, 20, 10, 5],
  visibility_radius DOUBLE PRECISION DEFAULT 2.0, -- Configurable visibility radius
  CONSTRAINT events_pkey PRIMARY KEY (id)
);

-- Boundaries table
CREATE TABLE IF NOT EXISTS public.boundaries (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius DOUBLE PRECISION DEFAULT 2.0,
  is_claimed BOOLEAN DEFAULT false,
  claimed_by TEXT, -- Wallet address of claimer
  claimed_at TIMESTAMP WITH TIME ZONE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  nft_token_id TEXT,
  nft_metadata JSONB,
  claim_progress DOUBLE PRECISION DEFAULT 0.0,
  is_visible BOOLEAN DEFAULT true,
  ar_position JSONB, -- {x, y, z}
  ar_rotation JSONB, -- {x, y, z}
  ar_scale JSONB, -- {x, y, z}
  CONSTRAINT boundaries_pkey PRIMARY KEY (id)
);

-- User Boundary Claims table (for tracking individual user claims)
CREATE TABLE IF NOT EXISTS public.user_boundary_claims (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_wallet_address TEXT NOT NULL,
  boundary_id UUID NOT NULL REFERENCES boundaries(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  claimed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  claim_distance DOUBLE PRECISION, -- Distance when claimed
  CONSTRAINT user_boundary_claims_pkey PRIMARY KEY (id),
  CONSTRAINT user_boundary_claims_unique UNIQUE (user_wallet_address, boundary_id)
);

-- Goodies table
CREATE TABLE IF NOT EXISTS public.goodies (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  logo_url TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  claim_radius DOUBLE PRECISION DEFAULT 15.0,
  is_claimed BOOLEAN DEFAULT false,
  claimed_by TEXT,
  claimed_at TIMESTAMP WITH TIME ZONE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT goodies_pkey PRIMARY KEY (id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_boundaries_event_id ON boundaries(event_id);
CREATE INDEX IF NOT EXISTS idx_boundaries_location ON boundaries USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326));
CREATE INDEX IF NOT EXISTS idx_boundaries_claimed ON boundaries(is_claimed);
CREATE INDEX IF NOT EXISTS idx_user_claims_wallet ON user_boundary_claims(user_wallet_address);
CREATE INDEX IF NOT EXISTS idx_user_claims_event ON user_boundary_claims(event_id);
CREATE INDEX IF NOT EXISTS idx_events_code ON events(event_code);

-- Functions for AR functionality
CREATE OR REPLACE FUNCTION get_nearby_boundaries(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  event_id UUID,
  max_distance DOUBLE PRECISION DEFAULT 5.0
) RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  image_url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  radius DOUBLE PRECISION,
  distance DOUBLE PRECISION,
  is_claimed BOOLEAN
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
    ST_Distance(
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(b.longitude, b.latitude), 4326)::geography
    ) as distance,
    b.is_claimed
  FROM boundaries b
  WHERE b.event_id = get_nearby_boundaries.event_id
    AND b.is_visible = true
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(b.longitude, b.latitude), 4326)::geography,
      max_distance
    )
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql;

-- Function to claim a boundary
CREATE OR REPLACE FUNCTION claim_boundary(
  boundary_id UUID,
  user_wallet TEXT,
  claim_distance DOUBLE PRECISION
) RETURNS BOOLEAN AS $$
DECLARE
  event_uuid UUID;
BEGIN
  -- Get event ID for the boundary
  SELECT event_id INTO event_uuid FROM boundaries WHERE id = boundary_id;
  
  -- Check if boundary is already claimed
  IF EXISTS (SELECT 1 FROM boundaries WHERE id = boundary_id AND is_claimed = true) THEN
    RETURN false;
  END IF;
  
  -- Update boundary as claimed
  UPDATE boundaries 
  SET is_claimed = true, claimed_by = user_wallet, claimed_at = now()
  WHERE id = boundary_id;
  
  -- Record user claim
  INSERT INTO user_boundary_claims (user_wallet_address, boundary_id, event_id, claim_distance)
  VALUES (user_wallet, boundary_id, event_uuid, claim_distance)
  ON CONFLICT (user_wallet_address, boundary_id) DO NOTHING;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's claimed boundaries
CREATE OR REPLACE FUNCTION get_user_claims(user_wallet TEXT)
RETURNS TABLE (
  boundary_id UUID,
  boundary_name TEXT,
  event_id UUID,
  event_name TEXT,
  event_code TEXT,
  claimed_at TIMESTAMP WITH TIME ZONE,
  claim_distance DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.name,
    e.id,
    e.name,
    e.event_code,
    ubc.claimed_at,
    ubc.claim_distance
  FROM user_boundary_claims ubc
  JOIN boundaries b ON ubc.boundary_id = b.id
  JOIN events e ON ubc.event_id = e.id
  WHERE ubc.user_wallet_address = get_user_claims.user_wallet
  ORDER BY ubc.claimed_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get event statistics
CREATE OR REPLACE FUNCTION get_event_stats(event_id UUID)
RETURNS TABLE (
  total_boundaries INTEGER,
  claimed_boundaries INTEGER,
  unique_claimers INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER as total_boundaries,
    COUNT(*) FILTER (WHERE is_claimed = true)::INTEGER as claimed_boundaries,
    COUNT(DISTINCT claimed_by) FILTER (WHERE is_claimed = true)::INTEGER as unique_claimers
  FROM boundaries
  WHERE boundaries.event_id = get_event_stats.event_id;
END;
$$ LANGUAGE plpgsql;
