-- Cleaned Database Schema for FaceReflector
-- Removed redundant fields and kept only essential ones

-- Events table (cleaned)
CREATE TABLE public.events (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  organizer_wallet_address TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
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
  visibility_radius DOUBLE PRECISION DEFAULT 2.0,
  CONSTRAINT events_pkey PRIMARY KEY (id)
);

-- Boundaries table (cleaned - removed redundant fields)
CREATE TABLE public.boundaries (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius DOUBLE PRECISION DEFAULT 2.0,
  is_claimed BOOLEAN DEFAULT FALSE,
  claimed_by TEXT,
  claimed_at TIMESTAMP WITH TIME ZONE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  nft_token_id TEXT,
  nft_metadata JSONB,
  claim_progress DOUBLE PRECISION DEFAULT 0.0,
  is_visible BOOLEAN DEFAULT TRUE,
  -- AR positioning fields (consolidated)
  ar_position JSONB DEFAULT '{"x": 0, "y": 0, "z": -2}'::jsonb,
  ar_rotation JSONB DEFAULT '{"x": 0, "y": 0, "z": 0}'::jsonb,
  ar_scale JSONB DEFAULT '{"x": 1, "y": 1, "z": 1}'::jsonb,
  CONSTRAINT boundaries_pkey PRIMARY KEY (id)
);

-- Users table (cleaned)
CREATE TABLE public.users (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  wallet_address TEXT NOT NULL UNIQUE,
  username TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- Goodies table (cleaned)
CREATE TABLE public.goodies (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  logo_url TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  claim_radius DOUBLE PRECISION DEFAULT 15.0,
  is_claimed BOOLEAN DEFAULT FALSE,
  claimed_by TEXT,
  claimed_at TIMESTAMP WITH TIME ZONE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT goodies_pkey PRIMARY KEY (id)
);

-- User proximity logs (for analytics)
CREATE TABLE public.user_proximity_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_wallet_address TEXT NOT NULL,
  boundary_id UUID REFERENCES boundaries(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  distance_meters DOUBLE PRECISION NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT user_proximity_logs_pkey PRIMARY KEY (id)
);

-- Event statistics view
CREATE VIEW public.event_statistics AS
SELECT 
  e.id as event_id,
  e.name as event_name,
  COUNT(b.id) as total_boundaries,
  COUNT(CASE WHEN b.is_claimed THEN 1 END) as claimed_boundaries,
  COUNT(CASE WHEN NOT b.is_claimed THEN 1 END) as unclaimed_boundaries,
  ROUND(
    (COUNT(CASE WHEN b.is_claimed THEN 1 END)::float / COUNT(b.id)::float) * 100, 2
  ) as claim_percentage
FROM events e
LEFT JOIN boundaries b ON e.id = b.event_id
GROUP BY e.id, e.name;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_boundaries_event_id ON boundaries(event_id);
CREATE INDEX IF NOT EXISTS idx_boundaries_location ON boundaries USING GIST (
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
);
CREATE INDEX IF NOT EXISTS idx_boundaries_claimed ON boundaries(is_claimed);
CREATE INDEX IF NOT EXISTS idx_goodies_event_id ON goodies(event_id);
CREATE INDEX IF NOT EXISTS idx_user_proximity_logs_user ON user_proximity_logs(user_wallet_address);
CREATE INDEX IF NOT EXISTS idx_user_proximity_logs_boundary ON user_proximity_logs(boundary_id);

-- Functions for distance calculations
CREATE OR REPLACE FUNCTION calculate_distance(
  lat1 DOUBLE PRECISION,
  lng1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
BEGIN
  RETURN ST_Distance(
    ST_SetSRID(ST_MakePoint(lng1, lat1), 4326)::geography,
    ST_SetSRID(ST_MakePoint(lng2, lat2), 4326)::geography
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get nearby boundaries
CREATE OR REPLACE FUNCTION get_nearby_boundaries(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  max_distance DOUBLE PRECISION DEFAULT 100.0
) RETURNS TABLE (
  boundary_id UUID,
  boundary_name TEXT,
  distance_meters DOUBLE PRECISION,
  is_claimable BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.name,
    calculate_distance(user_lat, user_lng, b.latitude, b.longitude) as distance_meters,
    calculate_distance(user_lat, user_lng, b.latitude, b.longitude) <= b.radius as is_claimable
  FROM boundaries b
  WHERE 
    calculate_distance(user_lat, user_lng, b.latitude, b.longitude) <= max_distance
    AND NOT b.is_claimed
    AND b.is_visible = TRUE
  ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;

-- Function to update boundary visibility
CREATE OR REPLACE FUNCTION update_boundary_visibility(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  visibility_radius DOUBLE PRECISION DEFAULT 5.0
) RETURNS VOID AS $$
BEGIN
  -- This function can be used to update boundary visibility based on user proximity
  -- For now, it's a placeholder for future enhancements
  NULL;
END;
$$ LANGUAGE plpgsql;
