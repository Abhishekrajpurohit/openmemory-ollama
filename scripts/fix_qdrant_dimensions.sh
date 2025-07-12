#!/bin/bash

set -e

echo "🔧 OpenMemory-Ollama Qdrant Dimension Fix"
echo "========================================"

# Detect container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman-compose"
else
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker-compose"
fi

echo "📦 Using container runtime: $CONTAINER_CMD"

# Check if Qdrant is running
QDRANT_URL="http://localhost:6333"
MAX_RETRIES=30
RETRY_COUNT=0

echo "⏳ Waiting for Qdrant to be ready..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s "$QDRANT_URL/collections" >/dev/null 2>&1; then
        echo "✅ Qdrant is ready"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Attempt $RETRY_COUNT/$MAX_RETRIES - waiting..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Error: Qdrant is not responding after $MAX_RETRIES attempts"
    echo "   Please ensure services are running with: $COMPOSE_CMD up -d"
    exit 1
fi

# Check if openmemory collection exists and get its info
echo "🔍 Checking existing collection..."
COLLECTION_INFO=$(curl -s "$QDRANT_URL/collections/openmemory" 2>/dev/null || echo "null")

if echo "$COLLECTION_INFO" | grep -q '"status":"ok"'; then
    # Collection exists, check dimensions
    CURRENT_DIM=$(echo "$COLLECTION_INFO" | grep -o '"size":[0-9]*' | cut -d':' -f2)
    
    echo "📊 Current collection dimension: $CURRENT_DIM"
    
    if [ "$CURRENT_DIM" = "384" ]; then
        echo "✅ Collection already has correct dimensions (384)"
        exit 0
    else
        echo "⚠️  Collection has wrong dimensions ($CURRENT_DIM), expected 384"
        echo "🗑️  Deleting existing collection..."
        
        DELETE_RESPONSE=$(curl -s -X DELETE "$QDRANT_URL/collections/openmemory")
        if echo "$DELETE_RESPONSE" | grep -q '"result":true'; then
            echo "✅ Collection deleted successfully"
        else
            echo "❌ Failed to delete collection: $DELETE_RESPONSE"
            exit 1
        fi
    fi
else
    echo "📝 No existing collection found"
fi

# Create new collection with correct dimensions
echo "🏗️  Creating new collection with 384 dimensions..."
CREATE_RESPONSE=$(curl -s -X PUT "$QDRANT_URL/collections/openmemory" \
    -H "Content-Type: application/json" \
    -d '{"vectors": {"size": 384, "distance": "Cosine"}}')

if echo "$CREATE_RESPONSE" | grep -q '"result":true'; then
    echo "✅ Collection created successfully with 384 dimensions"
else
    echo "❌ Failed to create collection: $CREATE_RESPONSE"
    exit 1
fi

# Verify the new collection
echo "🔍 Verifying new collection..."
VERIFY_INFO=$(curl -s "$QDRANT_URL/collections/openmemory")
VERIFY_DIM=$(echo "$VERIFY_INFO" | grep -o '"size":[0-9]*' | cut -d':' -f2)

if [ "$VERIFY_DIM" = "384" ]; then
    echo "✅ Collection verification successful - dimensions: $VERIFY_DIM"
else
    echo "❌ Collection verification failed - dimensions: $VERIFY_DIM"
    exit 1
fi

# Restart API service to clear any cached connections
echo "🔄 Restarting API service..."
$COMPOSE_CMD restart openmemory-ollama-mcp

echo "✅ Qdrant dimension fix completed successfully!"
echo ""
echo "📋 Summary:"
echo "   - Collection 'openmemory' configured for 384-dimensional vectors"
echo "   - Compatible with Ollama all-minilm embedding model"
echo "   - API service restarted"
echo ""
echo "🎯 You can now add memories without dimension errors!"