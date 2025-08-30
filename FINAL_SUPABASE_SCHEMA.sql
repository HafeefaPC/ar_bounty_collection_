-- FaceReflector Final Supabase Schema
-- This schema supports the complete AR bounty collection app with blockchain integration

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Users table for wallet-based authentication
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_address TEXT NOT NULL UNIQUE,
  username TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  preferences JSONB DEFAULT '{}',
  stats JSONB DEFAULT '{
    "total_events_joined": 0,
    "total_boundaries_claimed": 0,
    "total_nfts_earned": 0
  }'
);

-- Events table with blockchain integration
CREATE TABLE IF NOT EXISTS public.events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  
  -- Blockchain specific fields
  event_factory_contract_address TEXT,
  boundary_nft_contract_address TEXT,
  chain_id INTEGER DEFAULT 43113, -- Avalanche Fuji testnet
  deployment_tx_hash TEXT,
  ipfs_metadata_hash TEXT,
  
  -- Configuration
  nft_supply_count INTEGER DEFAULT 50,
  event_image_url TEXT,
  boundary_description TEXT,
  notification_distances INTEGER[] DEFAULT ARRAY[100, 50, 20, 10, 5],
  visibility_radius DOUBLE PRECISION DEFAULT 2.0,
  
  -- Status
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'deploying', 'active', 'paused', 'ended')),
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Metrics
  total_participants INTEGER DEFAULT 0,
  total_boundaries_claimed INTEGER DEFAULT 0,
  
  CONSTRAINT valid_dates CHECK (end_date > start_date),
  CONSTRAINT valid_coordinates CHECK (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
);

-- Boundaries table with NFT integration
CREATE TABLE IF NOT EXISTS public.boundaries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  
  -- Basic information
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT NOT NULL,
  
  -- Location data
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius DOUBLE PRECISION DEFAULT 2.0,
  location GEOGRAPHY(POINT, 4326), -- PostGIS geography column for spatial queries
  
  -- NFT specific fields
  nft_token_id TEXT,
  nft_contract_address TEXT,
  nft_metadata_ipfs_hash TEXT,
  nft_image_ipfs_hash TEXT,
  
  -- Claiming information
  is_claimed BOOLEAN DEFAULT FALSE,
  claimed_by TEXT, -- wallet address
  claimed_at TIMESTAMP WITH TIME ZONE,
  claim_tx_hash TEXT,
  
  -- AR positioning
  ar_position JSONB DEFAULT '{"x": 0, "y": 0, "z": -2}',
  ar_rotation JSONB DEFAULT '{"x": 0, "y": 0, "z": 0}',
  ar_scale JSONB DEFAULT '{"x": 1, "y": 1, "z": 1}',
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Additional fields for backward compatibility
  event_name TEXT,
  event_code TEXT,
  claim_progress DOUBLE PRECISION DEFAULT 0.0,
  is_visible BOOLEAN DEFAULT TRUE,
  
  CONSTRAINT valid_coordinates CHECK (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180),
  CONSTRAINT valid_radius CHECK (radius > 0 AND radius <= 1000)
);

-- Create geography column from lat/lng
CREATE OR REPLACE FUNCTION update_boundary_location()
RETURNS TRIGGER AS $$
BEGIN
  NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_boundary_location
  BEFORE INSERT OR UPDATE ON public.boundaries
  FOR EACH ROW EXECUTE FUNCTION update_boundary_location();

-- Event participants table
CREATE TABLE IF NOT EXISTS public.event_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_wallet_address TEXT NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'banned')),
  
  -- Progress tracking
  boundaries_claimed INTEGER DEFAULT 0,
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  total_time_spent INTEGER DEFAULT 0, -- in seconds
  
  UNIQUE(event_id, user_wallet_address)
);

-- User proximity logs for analytics and verification
CREATE TABLE IF NOT EXISTS public.user_proximity_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_wallet_address TEXT NOT NULL,
  boundary_id UUID REFERENCES public.boundaries(id) ON DELETE CASCADE,
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  
  -- Location data
  distance_meters DOUBLE PRECISION NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  gps_accuracy DOUBLE PRECISION,
  
  -- Timing
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Additional metadata
  device_info JSONB,
  app_version TEXT,
  
  CONSTRAINT valid_distance CHECK (distance_meters >= 0)
);

-- NFT claims table for detailed tracking
CREATE TABLE IF NOT EXISTS public.nft_claims (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  boundary_id UUID NOT NULL REFERENCES public.boundaries(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  claimer_wallet_address TEXT NOT NULL,
  
  -- Blockchain data
  transaction_hash TEXT NOT NULL,
  block_number BIGINT,
  gas_used BIGINT,
  gas_price BIGINT,
  
  -- Location verification
  claim_latitude DOUBLE PRECISION NOT NULL,
  claim_longitude DOUBLE PRECISION NOT NULL,
  verified_distance DOUBLE PRECISION,
  
  -- Timing
  claimed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  confirmed_at TIMESTAMP WITH TIME ZONE,
  
  -- Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'failed', 'reverted')),
  
  UNIQUE(boundary_id, claimer_wallet_address)
);

-- Goodies table (for future features)
CREATE TABLE IF NOT EXISTS public.goodies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  logo_url TEXT NOT NULL,
  
  -- Location
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  claim_radius DOUBLE PRECISION DEFAULT 15.0,
  
  -- Status
  is_claimed BOOLEAN DEFAULT FALSE,
  claimed_by TEXT,
  claimed_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_events_organizer ON public.events(organizer_wallet_address);
CREATE INDEX IF NOT EXISTS idx_events_code ON public.events(event_code);
CREATE INDEX IF NOT EXISTS idx_events_active ON public.events(is_active, status);
CREATE INDEX IF NOT EXISTS idx_events_dates ON public.events(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_boundaries_event ON public.boundaries(event_id);
CREATE INDEX IF NOT EXISTS idx_boundaries_claimed ON public.boundaries(is_claimed);
CREATE INDEX IF NOT EXISTS idx_boundaries_claimer ON public.boundaries(claimed_by);
CREATE INDEX IF NOT EXISTS idx_boundaries_location ON public.boundaries USING GIST(location);

CREATE INDEX IF NOT EXISTS idx_participants_event ON public.event_participants(event_id);
CREATE INDEX IF NOT EXISTS idx_participants_user ON public.event_participants(user_wallet_address);

CREATE INDEX IF NOT EXISTS idx_proximity_user ON public.user_proximity_logs(user_wallet_address);
CREATE INDEX IF NOT EXISTS idx_proximity_boundary ON public.user_proximity_logs(boundary_id);
CREATE INDEX IF NOT EXISTS idx_proximity_time ON public.user_proximity_logs(created_at);

CREATE INDEX IF NOT EXISTS idx_claims_boundary ON public.nft_claims(boundary_id);
CREATE INDEX IF NOT EXISTS idx_claims_claimer ON public.nft_claims(claimer_wallet_address);
CREATE INDEX IF NOT EXISTS idx_claims_tx ON public.nft_claims(transaction_hash);

-- Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boundaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_proximity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nft_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goodies ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users policies
CREATE POLICY "Users can view their own data" ON public.users
  FOR SELECT USING (wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address');

CREATE POLICY "Users can update their own data" ON public.users
  FOR UPDATE USING (wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address');

CREATE POLICY "Users can insert their own data" ON public.users
  FOR INSERT WITH CHECK (wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address');

-- Events policies
CREATE POLICY "Events are viewable by everyone" ON public.events
  FOR SELECT USING (true);

CREATE POLICY "Events can be created by authenticated users" ON public.events
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Events can be updated by organizers" ON public.events
  FOR UPDATE USING (organizer_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address');

-- Boundaries policies
CREATE POLICY "Boundaries are viewable by everyone" ON public.boundaries
  FOR SELECT USING (true);

CREATE POLICY "Boundaries can be created by event organizers" ON public.boundaries
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.events 
      WHERE id = event_id 
      AND organizer_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
    )
  );

CREATE POLICY "Boundaries can be updated by organizers or when claimed" ON public.boundaries
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.events 
      WHERE id = event_id 
      AND organizer_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
    ) OR (
      NOT is_claimed AND 
      current_setting('request.jwt.claims', true)::json->>'wallet_address' IS NOT NULL
    )
  );

-- Event participants policies
CREATE POLICY "Participants are viewable by event organizers and themselves" ON public.event_participants
  FOR SELECT USING (
    user_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
    OR EXISTS (
      SELECT 1 FROM public.events 
      WHERE id = event_id 
      AND organizer_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
    )
  );

CREATE POLICY "Users can join events" ON public.event_participants
  FOR INSERT WITH CHECK (
    user_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
  );

-- Proximity logs policies
CREATE POLICY "Proximity logs viewable by organizers" ON public.user_proximity_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.events 
      WHERE id = event_id 
      AND organizer_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
    )
  );

CREATE POLICY "Users can insert their proximity logs" ON public.user_proximity_logs
  FOR INSERT WITH CHECK (
    user_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
  );

-- NFT claims policies
CREATE POLICY "Claims are viewable by everyone" ON public.nft_claims
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own claims" ON public.nft_claims
  FOR INSERT WITH CHECK (
    claimer_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
  );

-- Goodies policies
CREATE POLICY "Goodies are viewable by everyone" ON public.goodies
  FOR SELECT USING (true);

CREATE POLICY "Goodies can be created by event organizers" ON public.goodies
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.events 
      WHERE id = event_id 
      AND organizer_wallet_address = current_setting('request.jwt.claims', true)::json->>'wallet_address'
    )
  );

CREATE POLICY "Goodies can be updated when claimed" ON public.goodies
  FOR UPDATE USING (true);

-- Functions for common operations

-- Function to get nearby boundaries
CREATE OR REPLACE FUNCTION get_nearby_boundaries(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  search_radius_meters DOUBLE PRECISION DEFAULT 1000,
  limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
  boundary_id UUID,
  name TEXT,
  description TEXT,
  distance_meters DOUBLE PRECISION,
  is_claimed BOOLEAN,
  nft_token_id TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.name,
    b.description,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      b.location
    ) AS distance_meters,
    b.is_claimed,
    b.nft_token_id
  FROM public.boundaries b
  WHERE b.is_visible = TRUE
    AND b.is_claimed = FALSE
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      b.location,
      search_radius_meters
    )
  ORDER BY distance_meters ASC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can claim boundary
CREATE OR REPLACE FUNCTION can_claim_boundary(
  boundary_uuid UUID,
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  user_wallet TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  boundary_record RECORD;
  distance_meters DOUBLE PRECISION;
BEGIN
  -- Get boundary details
  SELECT * INTO boundary_record
  FROM public.boundaries
  WHERE id = boundary_uuid;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Check if already claimed
  IF boundary_record.is_claimed THEN
    RETURN FALSE;
  END IF;
  
  -- Check distance
  SELECT ST_Distance(
    ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
    boundary_record.location
  ) INTO distance_meters;
  
  -- Must be within boundary radius
  IF distance_meters > boundary_record.radius THEN
    RETURN FALSE;
  END IF;
  
  -- Check if user already claimed this boundary
  IF EXISTS (
    SELECT 1 FROM public.nft_claims
    WHERE boundary_id = boundary_uuid
    AND claimer_wallet_address = user_wallet
    AND status IN ('pending', 'confirmed')
  ) THEN
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update event statistics
CREATE OR REPLACE FUNCTION update_event_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update event participant count and claimed boundaries
  IF TG_TABLE_NAME = 'event_participants' THEN
    UPDATE public.events SET 
      total_participants = (
        SELECT COUNT(*) FROM public.event_participants 
        WHERE event_id = NEW.event_id AND status = 'active'
      )
    WHERE id = NEW.event_id;
  END IF;
  
  -- Update claimed boundaries count
  IF TG_TABLE_NAME = 'boundaries' AND NEW.is_claimed = TRUE AND OLD.is_claimed = FALSE THEN
    UPDATE public.events SET 
      total_boundaries_claimed = (
        SELECT COUNT(*) FROM public.boundaries 
        WHERE event_id = NEW.event_id AND is_claimed = TRUE
      )
    WHERE id = NEW.event_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for statistics
CREATE TRIGGER trigger_update_event_participants_stats
  AFTER INSERT OR UPDATE ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION update_event_stats();

CREATE TRIGGER trigger_update_boundaries_stats
  AFTER UPDATE ON public.boundaries
  FOR EACH ROW EXECUTE FUNCTION update_event_stats();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant read access to anonymous users for public data
GRANT SELECT ON public.events TO anon;
GRANT SELECT ON public.boundaries TO anon;

-- Create initial admin user function
CREATE OR REPLACE FUNCTION create_admin_user(admin_wallet TEXT)
RETURNS void AS $$
BEGIN
  INSERT INTO public.users (wallet_address, username, preferences)
  VALUES (admin_wallet, 'Admin', '{"is_admin": true}')
  ON CONFLICT (wallet_address) DO UPDATE SET
    preferences = public.users.preferences || '{"is_admin": true}';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert sample data for testing (optional)
-- Uncomment the following section if you want sample data

/*
-- Sample event
INSERT INTO public.events (
  name, description, organizer_wallet_address, 
  latitude, longitude, venue_name, event_code,
  start_date, end_date, status
) VALUES (
  'Sample AR Hunt',
  'A sample AR treasure hunt for testing',
  '0x84efBdc3146C76066591496A34e08b4e12fe8d2F',
  37.7749, -122.4194, 'San Francisco',
  'SAMPLE01',
  NOW() + INTERVAL '1 hour',
  NOW() + INTERVAL '1 week',
  'active'
);

-- Sample boundaries
INSERT INTO public.boundaries (
  event_id, name, description, image_url,
  latitude, longitude, radius
) SELECT 
  e.id, 
  'Sample Boundary ' || generate_series(1, 5),
  'A test boundary for the sample event',
  'https://example.com/image.jpg',
  37.7749 + (random() - 0.5) * 0.01,
  -122.4194 + (random() - 0.5) * 0.01,
  10.0
FROM public.events e WHERE e.event_code = 'SAMPLE01';
*/

-- Performance monitoring view
CREATE OR REPLACE VIEW public.performance_stats AS
SELECT 
  'events' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE status = 'active') as active_count
FROM public.events
UNION ALL
SELECT 
  'boundaries' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE is_claimed = true) as claimed_count
FROM public.boundaries
UNION ALL
SELECT 
  'participants' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT user_wallet_address) as unique_users
FROM public.event_participants;

COMMENT ON SCHEMA public IS 'FaceReflector AR Bounty Collection App - Production Schema';