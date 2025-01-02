import os
import shutil
import subprocess
from dotenv import load_dotenv

def package_code():
    # Create a temporary directory
    temp_dir = '/tmp/search_service'
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir)

    # Copy the necessary files
    src_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)))  # search_service directory
    dirs_to_copy = ['agents', 'db']
    
    for dir_name in dirs_to_copy:
        src_path = os.path.join(src_dir, dir_name)
        dst_path = os.path.join(temp_dir, dir_name)
        if os.path.exists(src_path):
            shutil.copytree(src_path, dst_path)

    # Create a tar.gz archive
    archive_path = '/tmp/search_service.tar.gz'
    subprocess.run(['tar', '-czf', archive_path, '-C', '/tmp', 'search_service'])
    
    return archive_path

def upload_to_supabase(archive_path):
    # Load environment variables
    load_dotenv()
    
    # Get Supabase credentials
    db_url = os.getenv('SUPABASE_DB_URL')
    if not db_url:
        raise ValueError("SUPABASE_DB_URL environment variable is not set")

    # Upload the archive to the database server
    print("\nUploading code to database server...")
    cmd = [
        'psql',
        db_url,
        '-c', """
        CREATE OR REPLACE FUNCTION upload_search_service()
        RETURNS void
        LANGUAGE plpython3u
        AS $$
import os
import shutil
import tarfile

# Create the directory if it doesn't exist
target_dir = '/var/lib/postgresql'
if not os.path.exists(target_dir):
    os.makedirs(target_dir)

# Extract the uploaded archive
with tarfile.open('/tmp/search_service.tar.gz', 'r:gz') as tar:
    tar.extractall(target_dir)
$$;
        """
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("Error creating upload function:", result.stderr)
        return False

    # Copy the archive to the database server
    cmd = ['psql', db_url, '-c', "\\lo_import '/tmp/search_service.tar.gz'"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("Error uploading archive:", result.stderr)
        return False

    print("Successfully uploaded code to database")
    return True

def main():
    try:
        # Package the code
        print("Packaging code...")
        archive_path = package_code()
        print(f"Created archive at: {archive_path}")

        # Upload to Supabase
        success = upload_to_supabase(archive_path)
        
        if success:
            print("\nCode upload completed successfully!")
        else:
            print("\nFailed to upload code")

    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    main() 