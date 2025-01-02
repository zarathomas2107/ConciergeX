// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.2.1'
import { corsHeaders } from '../_shared/cors.ts'
import { LangChainOrchestrator } from '../../../search_service/agents/langchain_orchestrator.py'

interface SearchRequest {
  query: string
  user_id: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('Received request:', req.method)
    
    // Allow anonymous access
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      console.log('No auth header, proceeding with anonymous access')
    } else {
      console.log('Auth header present')
    }

    const body = await req.json()
    console.log('Request body:', body)
    
    const { query, user_id } = body as SearchRequest

    if (!query || !user_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required parameters: query and user_id',
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    // Initialize LangChainOrchestrator
    const orchestrator = new LangChainOrchestrator()
    
    // Process query using the orchestrator
    const result = await orchestrator.process_query(query, user_id)
    
    if (!result.success) {
      throw new Error(result.error || 'Failed to process query')
    }

    // Create Supabase client with service role key for anonymous access
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('Executing SQL query:', result.sql_query)
    console.log('With parameters:', result.parameters)
    
    // Execute the query
    const { data: restaurants, error: queryError } = await supabaseClient.rpc(
      'execute_search_query',
      {
        query_text: result.sql_query,
        query_params: result.parameters
      }
    )

    if (queryError) {
      console.error('Query error:', queryError)
      throw queryError
    }

    console.log('Query executed successfully')
    console.log('Found restaurants:', restaurants?.length ?? 0)
    
    return new Response(
      JSON.stringify({
        success: true,
        restaurants: restaurants || [],
        summary: result.summary
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error:', error.message)
    console.error('Stack trace:', error.stack)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        stack: error.stack
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/search-restaurants' \
    --header 'Authorization: Bearer ' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
