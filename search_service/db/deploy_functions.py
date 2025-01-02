import os
import subprocess
from dotenv import load_dotenv

def read_sql_file(filename):
    with open(filename, 'r') as f:
        return f.read()

def main():
    # Load environment variables
    load_dotenv()
    
    # Get Supabase credentials
    db_url = os.getenv('SUPABASE_DB_URL')
    if not db_url:
        raise ValueError("SUPABASE_DB_URL environment variable is not set")
    
    # SQL files to deploy
    sql_files = [
        'process_search_query.sql',
        'execute_search_query.sql'
    ]
    
    # Deploy each SQL file
    for sql_file in sql_files:
        print(f"\nDeploying {sql_file}...")
        sql_path = os.path.join(os.path.dirname(__file__), sql_file)
        
        try:
            # Read SQL content
            sql_content = read_sql_file(sql_path)
            
            # Execute SQL using psql
            process = subprocess.Popen(
                ['psql', db_url],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            stdout, stderr = process.communicate(input=sql_content)
            
            if process.returncode == 0:
                print(f"Successfully deployed {sql_file}")
                if stdout:
                    print("Output:", stdout)
            else:
                print(f"Error deploying {sql_file}")
                if stderr:
                    print("Error:", stderr)
                
        except Exception as e:
            print(f"Error deploying {sql_file}: {str(e)}")

if __name__ == "__main__":
    main()