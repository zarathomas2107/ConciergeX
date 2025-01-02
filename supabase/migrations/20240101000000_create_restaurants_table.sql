-- Create restaurants table
CREATE TABLE IF NOT EXISTS restaurants (
    id text PRIMARY KEY,
    name text NOT NULL,
    cuisine_type text,
    rating numeric,
    price_level integer,
    address text,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    dietary_options text[] DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create index for spatial queries
CREATE INDEX IF NOT EXISTS restaurants_location_idx 
ON restaurants USING gist (ll_to_earth(latitude, longitude));

-- Create index for cuisine type searches
CREATE INDEX IF NOT EXISTS restaurants_cuisine_idx
ON restaurants USING gin (cuisine_type gin_trgm_ops);

-- Create index for dietary options
CREATE INDEX IF NOT EXISTS restaurants_dietary_idx
ON restaurants USING gin (dietary_options); 