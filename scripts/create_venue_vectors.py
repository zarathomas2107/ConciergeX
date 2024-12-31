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

def create_vector_tables():
    """Create vector tables for theatres and restaurants"""
    try:
        print("Creating vector tables...")
        
        # First, let's check the structure of existing tables
        check_tables = """
        SELECT 
            table_name, 
            column_name, 
            data_type 
        FROM information_schema.columns 
        WHERE table_name IN ('theatre_details', 'restaurants');
        """
        
        table_info = supabase.rpc('exec_sql', {'sql_query': check_tables}).execute()
        print("Existing table structure:", table_info.data)
        
        # Create theatre vectors table without foreign key for now
        theatre_table = """
        DROP TABLE IF EXISTS theatre_vectors;
        
        CREATE TABLE theatre_vectors (
            id SERIAL PRIMARY KEY,
            theatre_id TEXT,
            name TEXT,
            embedding vector(384)
        );
        """
        
        # Create restaurant vectors table without foreign key for now
        restaurant_table = """
        DROP TABLE IF EXISTS restaurant_vectors;
        
        CREATE TABLE restaurant_vectors (
            id SERIAL PRIMARY KEY,
            restaurant_id TEXT,
            name TEXT,
            embedding vector(384)
        );
        """
        
        # Execute the SQL statements
        supabase.rpc('exec_sql', {'sql_query': theatre_table}).execute()
        print("Theatre vector table created successfully")
        
        supabase.rpc('exec_sql', {'sql_query': restaurant_table}).execute()
        print("Restaurant vector table created successfully")
        
        return True
        
    except Exception as e:
        print(f"Error creating vector tables: {str(e)}")
        print(f"Full error details: {type(e).__name__}: {str(e)}")
        return False

def generate_theatre_embeddings():
    """Generate embeddings for theatres"""
    try:
        print("Fetching theatres...")
        response = supabase.table("theatre_details").select(
            "place_id, name, address, types"
        ).execute()
        theatres = response.data
        print(f"Found {len(theatres)} theatres")
        
        # Clear existing vectors
        supabase.rpc('exec_sql', {'sql_query': 'TRUNCATE TABLE theatre_vectors;'}).execute()
        print("Cleared existing theatre vectors")
        
        success_count = 0
        for theatre in theatres:
            try:
                print(f"\nProcessing theatre: {theatre['name']}")
                text_to_embed = " ".join(filter(None, [
                    theatre.get('name', ''),
                    theatre.get('types', ''),
                    theatre.get('address', '')
                ]))
                
                embedding = model.encode(text_to_embed)
                
                insert_sql = f"""
                INSERT INTO theatre_vectors (theatre_id, name, embedding)
                VALUES (
                    '{theatre['place_id']}',
                    $${theatre['name']}$$,
                    '{str(embedding.tolist())}'::vector
                );
                """
                
                supabase.rpc('exec_sql', {'sql_query': insert_sql}).execute()
                print(f"Generated embedding for {theatre['name']}")
                success_count += 1
                
            except Exception as e:
                print(f"Error generating embedding for theatre {theatre.get('place_id', 'unknown')}: {str(e)}")
                continue
                
        print(f"\nCompleted theatre embeddings. Successfully processed {success_count} out of {len(theatres)} theatres.")
        
    except Exception as e:
        print(f"Error processing theatres: {str(e)}")

def generate_restaurant_embeddings():
    """Generate embeddings for restaurants"""
    try:
        print("\n=== Starting Restaurant Embeddings ===")
        print("Fetching restaurants...")
        
        # First verify the table exists and has data
        count_response = supabase.table("restaurants").select("*", count="exact").execute()
        print(f"Total restaurants in database: {len(count_response.data)}")
        
        # Get a sample record to verify column names
        sample = supabase.table("restaurants").select("*").limit(1).execute()
        if sample.data:
            print(f"Sample restaurant record columns: {list(sample.data[0].keys())}")
        
        response = supabase.table("restaurants").select(
            "RestaurantID, Name, Address, CuisineType"
        ).execute()
        restaurants = response.data
        print(f"Found {len(restaurants)} restaurants to process")
        
        if not restaurants:
            print("No restaurants found in database!")
            return
            
        # Clear existing vectors - Fixed DELETE statement
        print("\nClearing existing vectors...")
        clear_sql = "DELETE FROM restaurant_vectors WHERE true;"  # Added WHERE clause
        supabase.rpc('exec_sql', {'sql_query': clear_sql}).execute()
        print("Cleared existing restaurant vectors")
        
        success_count = 0
        for restaurant in restaurants:
            try:
                print(f"\nProcessing restaurant: {restaurant['Name']}")
                text_to_embed = " ".join(filter(None, [
                    restaurant.get('Name', ''),
                    restaurant.get('CuisineType', ''),
                    restaurant.get('Address', '')
                ]))
                
                print(f"Text being embedded: {text_to_embed}")
                embedding = model.encode(text_to_embed)
                
                # Verify the embedding
                print(f"Embedding shape: {embedding.shape}")
                
                # Escape single quotes in text fields
                name = restaurant['Name'].replace("'", "''")
                
                insert_sql = f"""
                INSERT INTO restaurant_vectors (restaurant_id, name, embedding)
                VALUES (
                    '{restaurant['RestaurantID']}',
                    '{name}',
                    '{str(embedding.tolist())}'::vector
                );
                """
                
                supabase.rpc('exec_sql', {'sql_query': insert_sql}).execute()
                success_count += 1
                print(f"Successfully processed {success_count} restaurants")
                
            except Exception as e:
                print(f"Error generating embedding for restaurant {restaurant.get('RestaurantID', 'unknown')}")
                print(f"Error details: {str(e)}")
                print(f"Restaurant data: {restaurant}")
                continue
                
        print(f"\nCompleted restaurant embeddings. Successfully processed {success_count} out of {len(restaurants)} restaurants")
        
        # Verify vectors were created
        verify = supabase.table("restaurant_vectors").select("*", count="exact").execute()
        print(f"Final vector count in database: {len(verify.data)}")
        
    except Exception as e:
        print(f"Error processing restaurants: {str(e)}")
        import traceback
        print(f"Full error: {traceback.format_exc()}")

def find_similar_venues(query_text, venue_type, threshold=0.3, limit=5):
    """Find similar venues (theatres or restaurants)"""
    try:
        print(f"Searching for {venue_type} similar to: {query_text}")
        
        # Generate embedding for query text
        query_embedding = model.encode(query_text)
        
        # Select appropriate table
        table_name = f"{venue_type}_vectors"
        
        # First, verify we have vectors in the table
        count_response = supabase.table(table_name).select("*", count="exact").execute()
        print(f"\nNumber of vectors in {table_name}: {len(count_response.data)}")
        
        if not count_response.data:
            print(f"No vectors found in {table_name}! Please generate embeddings first.")
            return []
        
        # Get all vectors
        print("\nFetching vectors...")
        response = supabase.table(table_name).select("*").execute()
        vectors = response.data
        print(f"Retrieved {len(vectors)} vectors")
        
        # Sample the first vector to verify structure
        if vectors:
            print(f"\nSample vector record: {vectors[0]}")
        
        # Calculate similarities
        print("\nCalculating similarities...")
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
                    f'{venue_type}_id': vector[f'{venue_type}_id'],
                    'similarity': float(similarity)
                })
                
            except Exception as e:
                print(f"Error processing vector for {vector.get('name', 'unknown')}: {str(e)}")
                print(f"Vector data: {vector}")
                continue
        
        print(f"\nProcessed {len(similarities)} similarities")
        
        # Sort by similarity
        similarities.sort(key=lambda x: x['similarity'], reverse=True)
        
        # Filter by threshold and limit
        results = [s for s in similarities if s['similarity'] >= threshold][:limit]
        
        if not results:
            print(f"\nNo results found above threshold {threshold}")
            # Return top matches anyway
            return similarities[:limit]
        
        return results
        
    except Exception as e:
        print(f"Error finding similar venues: {str(e)}")
        print(f"Full error details: {type(e).__name__}: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return []

if __name__ == "__main__":
    try:
        print("Starting vector database creation...")
        
        if create_vector_tables():
            print("\nGenerating theatre embeddings...")
            generate_theatre_embeddings()
            
            print("\nGenerating restaurant embeddings...")
            generate_restaurant_embeddings()
            
            print("\nTesting similarity search...")
            
            # Test restaurant search first
            restaurant_queries = [
                "italian restaurant",
                "sushi",
                "fine dining"
            ]
            
            print("\n=== Restaurant Search Tests ===")
            for query in restaurant_queries:
                print(f"\nSearching for restaurants similar to: {query}")
                results = find_similar_venues(query, "restaurant", threshold=0.3, limit=5)
                print(f"Results for '{query}':")
                if results:
                    for result in results:
                        print(f"- {result['name']} (similarity: {result['similarity']:.2f})")
                else:
                    print("No results found")
            
            # Test theatre search
            theatre_queries = [
                "west end theatre",
                "musical theatre",
                "shakespeare"
            ]
            
            print("\n=== Theatre Search Tests ===")
            for query in theatre_queries:
                print(f"\nSearching for theatres similar to: {query}")
                results = find_similar_venues(query, "theatre", threshold=0.3, limit=5)
                print(f"Results for '{query}':")
                if results:
                    for result in results:
                        print(f"- {result['name']} (similarity: {result['similarity']:.2f})")
                else:
                    print("No results found")
        
        print("\nProcess completed!")
        
    except Exception as e:
        print(f"Error in main process: {str(e)}") 