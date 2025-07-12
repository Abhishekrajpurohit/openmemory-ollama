#!/bin/bash

set -e

echo "🏥 OpenMemory-Ollama Health Check"
echo "================================="

# Detect container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman-compose"
else
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker-compose"
fi

echo "📦 Container Runtime: $CONTAINER_CMD"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_service() {
    local service=$1
    local url=$2
    local expected_response=$3
    
    printf "%-20s" "$service:"
    
    if curl -s --max-time 5 "$url" | grep -q "$expected_response"; then
        echo -e "${GREEN}✅ Running${NC}"
        return 0
    else
        echo -e "${RED}❌ Not responding${NC}"
        return 1
    fi
}

check_container() {
    local container_pattern=$1
    local service_name=$2
    
    printf "%-20s" "$service_name:"
    
    local container_id=$($CONTAINER_CMD ps -q -f name="$container_pattern")
    if [ -n "$container_id" ]; then
        local status=$($CONTAINER_CMD ps --format "{{.Status}}" -f id="$container_id")
        if echo "$status" | grep -q "Up"; then
            echo -e "${GREEN}✅ Running${NC}"
            return 0
        else
            echo -e "${RED}❌ Stopped${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Not found${NC}"
        return 1
    fi
}

check_memory_allocation() {
    echo ""
    echo "💾 Memory Check:"
    echo "==============="
    
    if command -v podman-machine &> /dev/null; then
        local machine_memory=$(podman machine inspect | grep '"Memory"' | grep -o '[0-9]*')
        printf "%-20s" "Podman Machine:"
        if [ "$machine_memory" -ge 3072 ]; then
            echo -e "${GREEN}✅ ${machine_memory}MB (sufficient)${NC}"
        else
            echo -e "${YELLOW}⚠️  ${machine_memory}MB (may be insufficient for gemma3:1b)${NC}"
            echo "   Recommendation: podman machine set --memory 4096"
        fi
    fi
    
    # Check available memory in Ollama container
    local ollama_container=$($CONTAINER_CMD ps -q -f name="ollama")
    if [ -n "$ollama_container" ]; then
        printf "%-20s" "Ollama Container:"
        local available_mem=$($CONTAINER_CMD exec "$ollama_container" sh -c "free -m | grep '^Mem:' | awk '{print \$7}'")
        if [ "$available_mem" -ge 1600 ]; then
            echo -e "${GREEN}✅ ${available_mem}MB available${NC}"
        else
            echo -e "${RED}❌ ${available_mem}MB available (need 1600MB+ for gemma3:1b)${NC}"
        fi
    fi
}

check_models() {
    echo ""
    echo "🤖 Model Check:"
    echo "=============="
    
    local ollama_container=$($CONTAINER_CMD ps -q -f name="ollama")
    if [ -n "$ollama_container" ]; then
        local models=$($CONTAINER_CMD exec "$ollama_container" ollama list 2>/dev/null || echo "")
        
        printf "%-20s" "gemma3:1b:"
        if echo "$models" | grep -q "gemma3:1b"; then
            echo -e "${GREEN}✅ Installed${NC}"
        else
            echo -e "${RED}❌ Not found${NC}"
            echo "   Run: ./manage_models.sh pull gemma3:1b"
        fi
        
        printf "%-20s" "all-minilm:"
        if echo "$models" | grep -q "all-minilm"; then
            echo -e "${GREEN}✅ Installed${NC}"
        else
            echo -e "${RED}❌ Not found${NC}"
            echo "   Run: ./manage_models.sh pull all-minilm:latest"
        fi
    else
        echo -e "${RED}❌ Ollama container not running${NC}"
    fi
}

check_qdrant_dimensions() {
    echo ""
    echo "📊 Vector Store Check:"
    echo "====================="
    
    printf "%-20s" "Qdrant Service:"
    if curl -s --max-time 5 "http://localhost:6333/collections" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Running${NC}"
        
        printf "%-20s" "Collection Setup:"
        local collection_info=$(curl -s "http://localhost:6333/collections/openmemory" 2>/dev/null || echo "null")
        
        if echo "$collection_info" | grep -q '"status":"ok"'; then
            local dimensions=$(echo "$collection_info" | grep -o '"size":[0-9]*' | cut -d':' -f2)
            if [ "$dimensions" = "384" ]; then
                echo -e "${GREEN}✅ Correct dimensions (384)${NC}"
            else
                echo -e "${RED}❌ Wrong dimensions ($dimensions, need 384)${NC}"
                echo "   Run: ./scripts/fix_qdrant_dimensions.sh"
            fi
        else
            echo -e "${YELLOW}⚠️  Collection not found${NC}"
            echo "   Will be created automatically on first use"
        fi
    else
        echo -e "${RED}❌ Not responding${NC}"
    fi
}

check_api_functionality() {
    echo ""
    echo "🔌 API Functionality:"
    echo "===================="
    
    local user_id="${USER:-default_user}"
    
    printf "%-20s" "Health Endpoint:"
    if curl -s --max-time 5 "http://localhost:8765/docs" | grep -q "OpenMemory" 2>/dev/null; then
        echo -e "${GREEN}✅ Responding${NC}"
    else
        echo -e "${RED}❌ Not responding${NC}"
    fi
    
    printf "%-20s" "Memory Test:"
    local test_response=$(curl -s --max-time 10 -X POST "http://localhost:8765/api/v1/memories/" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"Health check test $(date)\", \"user_id\": \"$user_id\"}" 2>/dev/null || echo "error")
    
    if echo "$test_response" | grep -q '"id"'; then
        echo -e "${GREEN}✅ Memory creation works${NC}"
    else
        echo -e "${RED}❌ Memory creation failed${NC}"
        if echo "$test_response" | grep -q "dimension"; then
            echo "   Issue: Vector dimension mismatch"
            echo "   Fix: ./scripts/fix_qdrant_dimensions.sh"
        elif echo "$test_response" | grep -q "memory"; then
            echo "   Issue: Insufficient memory for model"
            echo "   Fix: Increase container memory allocation"
        fi
    fi
}

# Main health check
echo "🔍 Checking Services:"
echo "===================="

# Check containers
check_container "ollama" "Ollama"
check_container "mem0_store" "Qdrant"
check_container "openmemory.*mcp" "API Server"
check_container "openmemory.*ui" "Frontend"

echo ""
echo "🌐 Checking Service Endpoints:"
echo "=============================="

# Check service endpoints
check_service "Ollama API" "http://localhost:11434/api/tags" "models"
check_service "Qdrant API" "http://localhost:6333/collections" "result"
check_service "Memory API" "http://localhost:8765/docs" "OpenMemory"
check_service "Frontend UI" "http://localhost:3000" "html"

# Detailed checks
check_memory_allocation
check_models
check_qdrant_dimensions
check_api_functionality

echo ""
echo "📋 Quick Fix Commands:"
echo "====================="
echo "🔧 Fix dimensions:     ./scripts/fix_qdrant_dimensions.sh"
echo "🤖 Setup models:      ./manage_models.sh setup"
echo "🔄 Restart services:   $COMPOSE_CMD restart"
echo "📊 View logs:         $COMPOSE_CMD logs -f"
echo "📈 Monitor resources: $CONTAINER_CMD stats"

echo ""
echo "💡 If issues persist:"
echo "   1. Check system requirements (4GB+ RAM)"
echo "   2. Verify all models are downloaded"
echo "   3. Ensure no port conflicts"
echo "   4. Review service logs for errors"