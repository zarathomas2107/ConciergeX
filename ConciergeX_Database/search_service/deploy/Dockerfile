# Use Python 3.10 slim image as base
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the entire search_service directory
COPY ConciergeX_Database/search_service /app/search_service

# Create environment file (will be overridden by Cloud Run environment variables)
RUN touch /app/search_service/.env

# Set working directory
WORKDIR /app/search_service

# Install Python dependencies
RUN pip install --no-cache-dir -r api/requirements.txt

# Set environment variables
ENV PORT=8080
ENV PYTHONPATH=/app/search_service
ENV HOST=0.0.0.0
ENV PYTHONUNBUFFERED=1

# Add a healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Expose the port the app runs on
EXPOSE ${PORT}

# Command to run the application
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--worker-class", "uvicorn.workers.UvicornWorker", "api.main:app"]