#!/bin/bash

set -e

echo "🤖 OpenMemory-Ollama Model Management"
echo "====================================="

# Detect container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman-compose"
else
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker-compose"
fi

# Function to check if Ollama container is running and get container name
check_ollama_running() {
    OLLAMA_CONTAINER=$($CONTAINER_CMD ps --format "{{.Names}}" | grep "ollama" | grep -v "mcp" | head -1)
    if [ -z "$OLLAMA_CONTAINER" ]; then
        echo "❌ Ollama container is not running. Please start the services first:"
        echo "   $COMPOSE_CMD up -d"
        exit 1
    fi
    echo "🔗 Found Ollama container: $OLLAMA_CONTAINER"
}

# Function to pull required models
pull_required_models() {
    echo "📥 Pulling required models..."
    
    echo "🔄 Pulling gemma3:1b (LLM)..."
    $CONTAINER_CMD exec -t $OLLAMA_CONTAINER ollama pull gemma3:1b
    
    echo "🔄 Pulling all-minilm:latest (Embeddings)..."
    $CONTAINER_CMD exec -t $OLLAMA_CONTAINER ollama pull all-minilm:latest
    
    echo "✅ Required models pulled successfully!"
    
    # Check if we need to fix Qdrant dimensions
    echo "🔧 Checking Qdrant dimensions..."
    if [ -f "../scripts/fix_qdrant_dimensions.sh" ]; then
        ../scripts/fix_qdrant_dimensions.sh
    elif [ -f "./scripts/fix_qdrant_dimensions.sh" ]; then
        ./scripts/fix_qdrant_dimensions.sh
    else
        echo "⚠️  Qdrant dimension fix script not found"
        echo "   If you encounter dimension errors, manually run:"
        echo "   ./scripts/fix_qdrant_dimensions.sh"
    fi
}

# Function to list available models
list_models() {
    echo "📋 Available models:"
    $CONTAINER_CMD exec -t $OLLAMA_CONTAINER ollama list
}

# Function to pull a specific model
pull_model() {
    if [ -z "$1" ]; then
        echo "❌ Please specify a model name."
        echo "   Usage: $0 pull <model-name>"
        exit 1
    fi
    
    echo "📥 Pulling model: $1"
    $CONTAINER_CMD exec -t $OLLAMA_CONTAINER ollama pull "$1"
    echo "✅ Model $1 pulled successfully!"
}

# Function to remove a model
remove_model() {
    if [ -z "$1" ]; then
        echo "❌ Please specify a model name."
        echo "   Usage: $0 remove <model-name>"
        exit 1
    fi
    
    echo "🗑️  Removing model: $1"
    $CONTAINER_CMD exec -t $OLLAMA_CONTAINER ollama rm "$1"
    echo "✅ Model $1 removed successfully!"
}

# Function to show model information
show_model_info() {
    if [ -z "$1" ]; then
        echo "❌ Please specify a model name."
        echo "   Usage: $0 info <model-name>"
        exit 1
    fi
    
    echo "ℹ️  Model information for: $1"
    $CONTAINER_CMD exec -t $OLLAMA_CONTAINER ollama show "$1"
}

# Function to show help
show_help() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  setup          Pull all required models (gemma3:1b, all-minilm)"
    echo "  list           List all available models"
    echo "  pull <model>   Pull a specific model"
    echo "  remove <model> Remove a specific model"
    echo "  info <model>   Show information about a model"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 list"
    echo "  $0 pull llama3.1:latest"
    echo "  $0 remove llama3.1:latest"
    echo "  $0 info gemma3:1b"
}

# Main script logic
case "$1" in
    "setup")
        check_ollama_running
        pull_required_models
        ;;
    "list")
        check_ollama_running
        list_models
        ;;
    "pull")
        check_ollama_running
        pull_model "$2"
        ;;
    "remove")
        check_ollama_running
        remove_model "$2"
        ;;
    "info")
        check_ollama_running
        show_model_info "$2"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        echo "❌ No command specified."
        echo ""
        show_help
        exit 1
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac