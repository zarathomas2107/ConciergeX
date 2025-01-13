# Restaurant Search API Deployment Guide

This directory contains all the necessary files to deploy the Restaurant Search API to Google Cloud Run.

## Prerequisites

1. Google Cloud SDK installed and configured
2. Docker installed
3. Access to the Google Cloud project
4. Required environment variables in `.env` file

## Directory Structure

```
deploy/
├── Dockerfile          # Container configuration
├── cloudbuild.yaml     # Cloud Build configuration
├── .gcloudignore      # Files to ignore during deployment
└── README.md          # This file
```

## Environment Variables

Ensure you have a `.env` file in the parent directory with the following variables:
```
OPENAI_API_KEY=your_openai_key
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_API_KEY=your_google_places_api_key
GOOGLE_PROJECT_ID=your_project_id
```

## Deployment Steps

1. Navigate to the search_service directory:
   ```bash
   cd path/to/ConciergeX_Database/search_service
   ```

2. Deploy using Cloud Build:
   ```bash
   gcloud builds submit deploy/ --config=deploy/cloudbuild.yaml
   ```

   Or with environment variables from .env:
   ```bash
   gcloud builds submit deploy/ --config=deploy/cloudbuild.yaml \
     --substitutions=_OPENAI_API_KEY="$(grep OPENAI_API_KEY .env | cut -d '=' -f2)",\
     _SUPABASE_URL="$(grep SUPABASE_URL .env | cut -d '=' -f2)",\
     _SUPABASE_ANON_KEY="$(grep SUPABASE_ANON_KEY .env | cut -d '=' -f2)",\
     _GOOGLE_PLACES_API_KEY="$(grep GOOGLE_API_KEY .env | cut -d '=' -f2)"
   ```

3. The deployment will:
   - Build the Docker container
   - Push it to Google Container Registry
   - Deploy to Cloud Run
   - Set up environment variables
   - Configure the service

4. After deployment, you can access the API at:
   ```
   https://restaurant-search-api-378538476539.europe-west2.run.app
   ```

## API Endpoints

- Health Check: `GET /health`
- Search Restaurants: `POST /search`
  ```bash
  curl -X POST https://restaurant-search-api-378538476539.europe-west2.run.app/search \
    -H "Content-Type: application/json" \
    -d '{"query": "Italian restaurant in Covent Garden", "user_id": "your_user_id"}'
  ```

## Troubleshooting

1. If the build fails, check:
   - All required files are present
   - Environment variables are correctly set
   - Google Cloud project has necessary APIs enabled

2. If the service fails to start, check:
   - Cloud Run logs for error messages
   - Environment variables are correctly passed
   - Service account has necessary permissions

3. For permission issues:
   ```bash
   gcloud run services add-iam-policy-binding restaurant-search-api \
     --region=europe-west2 \
     --member=allUsers \
     --role=roles/run.invoker
   ``` 