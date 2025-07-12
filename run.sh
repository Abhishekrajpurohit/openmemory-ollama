#!/bin/bash

set -e

echo "🚀 Starting OpenMemory-Ollama installation..."

# Auto-detect container runtime
if command -v podman &> /dev/null && command -v podman-compose &> /dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman-compose"
    echo "🐳 Using Podman"
    
    # Check Podman machine memory allocation
    if command -v podman-machine &> /dev/null; then
        MACHINE_MEMORY=$(podman machine inspect 2>/dev/null | grep '"Memory"' | grep -o '[0-9]*' || echo "0")
        if [ "$MACHINE_MEMORY" -lt 3072 ]; then
            echo "⚠️  Warning: Podman machine has ${MACHINE_MEMORY}MB memory"
            echo "   gemma3:1b requires 1600MB+ available memory"
            echo "   Consider increasing: podman machine set --memory 4096"
            echo ""
        fi
    fi
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker compose"
    echo "🐳 Using Docker"
else
    echo "❌ Neither Podman nor Docker found. Please install one of them:"
    echo "   - Podman: brew install podman && pip install podman-compose"
    echo "   - Docker: Install Docker Desktop"
    exit 1
fi

# Set environment variables
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
USER="${USER:-$(whoami)}"
NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-http://localhost:8765}"

echo "🔧 Using Ollama host: $OLLAMA_HOST"
echo "👤 Using user: $USER"

# Check if old containers exist and remove them
if [ $($CONTAINER_CMD ps -aq -f name=mem0_ui) ]; then
  echo "⚠️ Found existing container 'mem0_ui'. Removing it..."
  $CONTAINER_CMD rm -f mem0_ui
fi

# Create .env file if it doesn't exist
if [ ! -f api/.env ]; then
    echo "📝 Creating api/.env file..."
    cp api/.env.example api/.env
fi

# Export required variables for Compose
export OLLAMA_HOST
export USER
export NEXT_PUBLIC_API_URL
export NEXT_PUBLIC_USER_ID="$USER"

# Use existing docker-compose.yml (no need to generate)
echo "📝 Using existing docker-compose.yml configuration..."

# Start services
echo "🚀 Starting all services..."
$COMPOSE_CMD up -d

# Wait for Ollama to be ready
echo "⏳ Waiting for Ollama to be ready..."
sleep 15

# Pull required models
echo "📥 Pulling required Ollama models (this may take 5-10 minutes)..."

# Get the exact Ollama container name
OLLAMA_CONTAINER=$($CONTAINER_CMD ps --format "{{.Names}}" | grep "ollama_1$" | head -1)

echo "🔄 Pulling gemma3:1b (LLM)..."
$CONTAINER_CMD exec $OLLAMA_CONTAINER ollama pull gemma3:1b

echo "🔄 Pulling all-minilm:latest (Embeddings)..."
$CONTAINER_CMD exec $OLLAMA_CONTAINER ollama pull all-minilm:latest

echo "✅ Models downloaded successfully!"

# Fix Qdrant dimensions for Ollama embeddings
echo "🔧 Configuring Qdrant for Ollama embeddings..."
if [ -f "./scripts/fix_qdrant_dimensions.sh" ]; then
    ./scripts/fix_qdrant_dimensions.sh
else
    echo "⚠️  Qdrant dimension fix script not found, continuing..."
fi

# Find frontend port
FRONTEND_PORT=3000
if command -v lsof &> /dev/null; then
    for port in {3000..3010}; do
      if ! lsof -i:$port >/dev/null 2>&1; then
        FRONTEND_PORT=$port
        break
      fi
    done
fi

echo "✅ Setup complete!"
echo "✅ Backend API: http://localhost:8765"
echo "✅ Frontend UI: http://localhost:$FRONTEND_PORT" 
echo "✅ Ollama Service: http://localhost:11434"
echo ""
echo "🎉 OpenMemory-Ollama is ready to use!"

# Check status and offer to open browser
echo ""
echo "📋 Checking service status..."
$COMPOSE_CMD ps

echo ""
echo "🌐 To open the UI in your browser:"
echo "   - Frontend: http://localhost:3000"
echo "   - API Docs: http://localhost:8765/docs"

# Optionally open browser
if command -v open > /dev/null; then
  read -p "Open frontend in browser? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "http://localhost:3000"
  fi
elif command -v xdg-open > /dev/null; then
  read -p "Open frontend in browser? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    xdg-open "http://localhost:3000"
  fi
fi

echo ""
echo "🎯 Next steps:"
echo "   1. Visit http://localhost:3000 to use the memory interface"
echo "   2. Check ./manage_models.sh for additional model management"
echo "   3. See SETUP.md for Claude Desktop MCP integration"
