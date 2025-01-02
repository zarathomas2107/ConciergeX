-- Create storage bucket if it doesn't exist
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('profile_pictures', 'profile_pictures', true)
    ON CONFLICT (id) DO NOTHING;
END $$;

-- Enable RLS on the storage.objects table
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can upload their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Public read access to profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Allow public to download profile pictures" ON storage.objects;

-- Create policy to allow authenticated users to upload their own profile picture
CREATE POLICY "Users can upload their own profile picture" ON storage.objects
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        bucket_id = 'profile_pictures' 
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Create policy to allow users to update their own profile picture
CREATE POLICY "Users can update their own profile picture" ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'profile_pictures'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Create policy to allow users to delete their own profile picture
CREATE POLICY "Users can delete their own profile picture" ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'profile_pictures'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Create policy to allow public read access to profile pictures
CREATE POLICY "Public read access to profile pictures" ON storage.objects
    FOR SELECT
    TO public
    USING (bucket_id = 'profile_pictures');

-- Create policy to allow downloading profile pictures
CREATE POLICY "Allow public to download profile pictures" ON storage.objects
    FOR SELECT
    TO public
    USING (bucket_id = 'profile_pictures'); 