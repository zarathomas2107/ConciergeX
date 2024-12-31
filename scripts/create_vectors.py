import os
from supabase import create_client
from sentence_transformers import SentenceTransformer
import numpy as np
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Supabase client
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")

if not all([supabase_url, supabase_key]):
    raise Exception("Missing environment variables. Please set SUPABASE_URL and SUPABASE_KEY")

print(f"Connecting to Supabase at {supabase_url[:20]}...")
supabase = create_client(supabase_url, supabase_key)

# Initialize the sentence transformer model
print("Loading sentence transformer model...")
model = SentenceTransformer('all-MiniLM-L6-v2')

def create_similarity_function():
    """Create a SQL function for similarity search"""
    try:
        function_sql = """
        CREATE OR REPLACE FUNCTION match_cinemas(query_embedding vector(384), match_threshold float, match_count int)
        RETURNS TABLE (
            id bigint,
            cinema_id text,
            name text,
            similarity float
        )
        LANGUAGE plpgsql
        AS $$
        BEGIN
            RETURN QUERY
            SELECT
                cinema_vectors.id::bigint,
                cinema_vectors.cinema_id,
                cinema_vectors.name,
                1 - (cinema_vectors.embedding <=> query_embedding) AS similarity
            FROM cinema_vectors
            WHERE 1 - (cinema_vectors.embedding <=> query_embedding) > match_threshold
            ORDER BY cinema_vectors.embedding <=> query_embedding
            LIMIT match_count;
        END;
        $$;
        """
        
        # Create the function using RPC
        supabase.rpc('exec_sql', {'sql_query': function_sql}).execute()
        print("Created similarity search function")
        return True
        
    except Exception as e:
        print(f"Error creating similarity function: {str(e)}")
        return False

def find_similar_names(query_text, threshold=0.5, limit=5):
    """Find similar cinema names using pgvector"""
    try:
        print(f"Searching for cinemas similar to: {query_text}")
        
        # First, let's verify what's in our vector table using direct table query
        print("\nVerifying vector data...")
        verify_response = supabase.table("cinema_vectors").select("*").limit(3).execute()
        print(f"Number of vectors found: {len(verify_response.data)}")
        
        # Generate embedding for query text
        query_embedding = model.encode(query_text)
        print(f"Query embedding length: {len(query_embedding)}")
        
        # Get all vectors
        response = supabase.table("cinema_vectors").select("*").execute()
        vectors = response.data
        
        # Calculate similarities in Python
        similarities = []
        for vector in vectors:
            try:
                # Convert string embedding back to list of floats
                embedding_str = vector['embedding']
                if isinstance(embedding_str, str):
                    # Remove brackets and split by commas
                    embedding_str = embedding_str.strip('[]')
                    db_embedding = np.array([float(x.strip()) for x in embedding_str.split(',')])
                else:
                    db_embedding = np.array(vector['embedding'])
                
                query_embedding_np = np.array(query_embedding)
                
                # Calculate cosine similarity
                similarity = np.dot(db_embedding, query_embedding_np) / (
                    np.linalg.norm(db_embedding) * np.linalg.norm(query_embedding_np)
                )
                
                similarities.append({
                    'name': vector['name'],
                    'cinema_id': vector['cinema_id'],
                    'similarity': float(similarity)
                })
            except Exception as e:
                print(f"Error processing vector for {vector.get('name', 'unknown')}: {str(e)}")
                continue
        
        # Sort by similarity
        similarities.sort(key=lambda x: x['similarity'], reverse=True)
        
        # Filter by threshold and limit
        results = [s for s in similarities if s['similarity'] >= threshold][:limit]
        
        if results:
            return results
        else:
            # If no results above threshold, return top matches anyway
            return similarities[:limit]
        
    except Exception as e:
        print(f"Error finding similar names: {str(e)}")
        print(f"Full error details: {type(e).__name__}: {str(e)}")
        return []

def create_vector_table():
    """Create vector table for cinemas"""
    try:
        print("Creating vector table...")
        
        # Drop and recreate the table
        create_table = """
        DROP TABLE IF EXISTS cinema_vectors;
        
        CREATE TABLE cinema_vectors (
            id SERIAL PRIMARY KEY,
            cinema_id TEXT REFERENCES cinemas(id),
            name TEXT,
            embedding vector(384)
        );
        """
        
        # Execute the SQL statements
        supabase.rpc('exec_sql', {'sql_query': create_table}).execute()
        print("Vector table created successfully")
        
        return True
        
    except Exception as e:
        print(f"Error creating vector table: {str(e)}")
        return False

def generate_embeddings():
    """Generate embeddings for cinemas"""
    try:
        print("Fetching cinemas...")
        # Remove description from the select
        response = supabase.table("cinemas").select(
            "id, name, address, chain"  # Removed description
        ).execute()
        cinemas = response.data
        print(f"Found {len(cinemas)} cinemas")
        
        if not cinemas:
            print("No cinemas found in database!")
            return
            
        # Clear existing vectors
        supabase.rpc('exec_sql', {'sql_query': 'TRUNCATE TABLE cinema_vectors;'}).execute()
        print("Cleared existing vectors")
        
        success_count = 0
        for cinema in cinemas:
            try:
                print(f"\nProcessing cinema: {cinema['name']}")
                # Combine relevant text fields for richer embeddings
                text_to_embed = " ".join(filter(None, [
                    cinema.get('name', ''),
                    cinema.get('chain', ''),
                    cinema.get('address', '')
                ]))
                
                print(f"Text being embedded: {text_to_embed}")
                
                # Generate embedding for the combined text
                embedding = model.encode(text_to_embed)
                
                # Convert embedding to a string format that PostgreSQL can parse
                embedding_str = str(embedding.tolist())
                
                # Insert using direct SQL with proper escaping
                insert_sql = f"""
                INSERT INTO cinema_vectors (cinema_id, name, embedding)
                VALUES (
                    '{cinema['id']}',
                    $${cinema['name']}$$,
                    '{embedding_str}'::vector
                );
                """
                
                supabase.rpc('exec_sql', {'sql_query': insert_sql}).execute()
                print(f"Successfully generated embedding for {cinema['name']}")
                success_count += 1
                
            except Exception as e:
                print(f"Error generating embedding for cinema {cinema.get('id', 'unknown')}: {str(e)}")
                continue
                
        print(f"\nCompleted embedding generation. Successfully processed {success_count} out of {len(cinemas)} cinemas.")
        
    except Exception as e:
        print(f"Error processing cinemas: {str(e)}")
        import traceback
        print(f"Full error: {traceback.format_exc()}")

if __name__ == "__main__":
    try:
        print("Starting vector database creation...")
        
        if create_vector_table():
            print("\nGenerating embeddings...")
            generate_embeddings()
            
            print("\nTesting similarity search...")
            queries = [
                "odeon cinema",
                "vue cinema",
                "cinema",
                "theatre"
            ]
            
            for query in queries:
                print(f"\nSearching for: {query}")
                results = find_similar_names(query, threshold=0.3, limit=5)  # Lowered threshold
                print(f"Results for '{query}':")
                if results:
                    for result in results:
                        print(f"- {result['name']} (similarity: {result['similarity']:.2f})")
                else:
                    print("No results found")
        
        print("\nProcess completed!")
        
    except Exception as e:
        print(f"Error in main process: {str(e)}")