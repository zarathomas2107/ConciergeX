-- Create spatial index for faster distance queries
CREATE INDEX IF NOT EXISTS idx_restaurants_location ON restaurants 
USING gist (ST_SetSRID(ST_MakePoint("longitude"::double precision, "latitude"::double precision), 4326)::geography); 