# OpenMemory-Ollama

A fully local, privacy-focused memory system using Ollama for LLM and embedding models. This version eliminates the need for external APIs like OpenAI, keeping all your data on your machine.

![OpenMemory](https://github.com/user-attachments/assets/3c701757-ad82-4afa-bfbe-e049c2b4320b)

## ⚠️ Important Notices

### Memory Requirements
- **Minimum**: 4GB RAM allocated to containers
- **Recommended**: 6GB+ for optimal performance  
- **Critical**: gemma3:1b model requires 1.6GB available memory

### Known Issues & Auto-Fixes
- ✅ **Vector Dimension Mismatch**: Automatically fixed during setup
- ✅ **Memory Constraints**: Detected and warnings provided
- ✅ **Model Download**: Automated with progress tracking
- ✅ **Container Runtime**: Auto-detects Podman/Docker

## Features

- **🔒 100% Local & Private**: All processing happens on your machine
- **💰 Zero API Costs**: No external service dependencies  
- **🤖 Ollama Integration**: Uses local Ollama models for LLM and embeddings
- **🔌 MCP Support**: Full Model Context Protocol integration for Claude Desktop
- **📦 Container-Based**: Easy deployment with Docker/Podman
- **🎯 Drop-in Replacement**: Compatible with existing OpenMemory workflows
- **🛠️ Auto-Healing**: Built-in fixes for common issues

## Quick Start

```bash
# Clone and setup
git clone <repository-url>
cd openmemory-ollama

# One-command setup (auto-detects Docker/Podman)
./run.sh
```

**⏱️ First Run**: Expect 10-15 minutes for model downloads (~860MB)

## What's Included

- **API Server**: Memory management with REST API
- **Web UI**: Browser-based memory interface  
- **Ollama Service**: Local LLM and embedding models
- **Vector Store**: Qdrant for semantic search
- **MCP Server**: Claude Desktop integration
- **Health Monitoring**: Automated diagnostics and fixes

## Models Used

- **LLM**: `gemma3:1b` (815MB) - Fast, efficient language model
- **Embeddings**: `all-minilm:latest` (45MB) - Optimized for semantic search

## System Requirements

- **RAM**: 4GB+ allocated to containers (6GB+ recommended)
- **Disk**: 3GB+ free space for models and containers
- **Container Runtime**: Docker Desktop or Podman
- **OS**: macOS, Linux, Windows (with WSL2)

## ⚠️ Critical Setup Warnings

### 1. Memory Allocation Issues

**Podman Users - MOST COMMON ISSUE**:
```bash
# Check current allocation
podman machine inspect | grep Memory

# If less than 3072MB, increase it:
podman machine stop
podman machine set --memory 4096  # 4GB recommended
podman machine start
```

**Docker Users**:
- Docker Desktop → Settings → Resources → Memory → Set to 4GB+

### 2. Vector Dimension Conflicts

**Issue**: If you've used OpenMemory before, Qdrant may have wrong dimensions
**Auto-Fix**: The setup script automatically detects and fixes this
**Manual Fix**: `./scripts/fix_qdrant_dimensions.sh`

### 3. Port Conflicts

**Common Conflicts**:
- Port 11434 (Ollama) - Check for existing Ollama instances
- Port 3000 (Frontend) - Auto-detects alternative ports
- Port 8765 (API) - Modify docker-compose.yml if needed
- Port 6333 (Qdrant) - Ensure no other vector DBs running

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   Claude MCP    │───▶│  API Server  │───▶│   Ollama    │
│   Integration   │    │              │    │  (gemma3:1b)│
└─────────────────┘    └──────┬───────┘    └─────────────┘
                               │
                               ▼
                       ┌──────────────┐
                       │   Qdrant     │
                       │ Vector Store │
                       └──────────────┘
```

## Differences from Original OpenMemory

| Feature | Original OpenMemory | OpenMemory-Ollama |
|---------|-------------------|-------------------|
| **API Dependencies** | OpenAI/Anthropic API | None (fully local) |
| **Cost** | Pay-per-token | Free after setup |
| **Privacy** | Data sent to APIs | 100% local processing |
| **Internet Required** | Always | Only for initial setup |
| **Model Choice** | Fixed API models | Customizable local models |
| **Setup Complexity** | API keys needed | One-command deployment |

## Getting Started

### Prerequisites

**Container Runtime** (choose one):
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (recommended for beginners)
- [Podman](https://podman.io/getting-started/installation) + podman-compose (more secure)

**Installation**:
```bash
# Docker
brew install docker docker-compose  # macOS
# or download Docker Desktop

# Podman (alternative)
brew install podman                 # macOS
pip install podman-compose
```

### Installation

1. **Clone the repository**:
```bash
git clone <repository-url>
cd openmemory-ollama
```

2. **Run the setup script**:
```bash
chmod +x run.sh
./run.sh
```

The script will:
- ✅ Auto-detect your container runtime
- ✅ Check memory allocation (warn if insufficient)
- ✅ Pull required models (~860MB download)
- ✅ Start all services
- ✅ Configure Qdrant for Ollama embeddings (384 dimensions)
- ✅ Verify system health
- ✅ Open the UI in your browser

3. **Verify installation**:
```bash
# Comprehensive health check
./scripts/health_check.sh

# Or manually check services
docker-compose ps  # or podman-compose ps
```

### Service URLs

After setup, access these services:

- **🖥️ Web UI**: http://localhost:3000
- **📡 API**: http://localhost:8765/docs  
- **🤖 Ollama**: http://localhost:11434
- **🔍 Qdrant**: http://localhost:6333/dashboard

## Claude Desktop Integration

1. **Install MCP client**:
```bash
npm install -g @openmemory/install
```

2. **Configure Claude Desktop**:

Add to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "openmemory-ollama": {
      "command": "npx",
      "args": [
        "-y", "@openmemory/install", "local",
        "http://localhost:8765/mcp/claude/sse/your_user_id",
        "--client", "claude"
      ]
    }
  }
}
```

3. **Restart Claude Desktop** and look for the tools icon (🔨)

## ⚠️ Troubleshooting Guide

### Issue 1: Memory Constraint Error
```
Error: model requires more system memory (1.6 GiB) than is available (1.2 GiB)
```

**Root Cause**: Container doesn't have enough memory allocated
**Solutions**:

**For Podman** (Most Common):
```bash
podman machine stop
podman machine set --memory 4096
podman machine start
podman-compose down && podman-compose up -d
```

**For Docker**:
- Docker Desktop → Settings → Resources → Memory → Increase to 4GB+
- Restart Docker Desktop
- Restart containers: `docker-compose restart`

### Issue 2: Vector Dimension Error
```
Error: Vector dimension error: expected dim: 1536, got 384
```

**Root Cause**: Existing Qdrant collection configured for OpenAI (1536) vs Ollama (384)
**Auto-Fix**: Run the automated fix script:
```bash
./scripts/fix_qdrant_dimensions.sh
```

**Manual Fix**:
```bash
curl -X DELETE "http://localhost:6333/collections/openmemory"
curl -X PUT "http://localhost:6333/collections/openmemory" \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 384, "distance": "Cosine"}}'
```

### Issue 3: Models Not Downloaded
```
Error: model not found
```

**Fix**:
```bash
./manage_models.sh setup
# or individually:
./manage_models.sh pull gemma3:1b
./manage_models.sh pull all-minilm:latest
```

### Issue 4: Container Runtime Issues

**Podman Issues**:
```bash
# Check if Podman machine is running
podman machine list

# Start if stopped
podman machine start
```

**Docker Issues**:
```bash
# Check Docker daemon
docker info

# Restart Docker Desktop if needed
```

### Issue 5: Port Conflicts

**Check for conflicts**:
```bash
# Check what's using ports
lsof -i :11434  # Ollama
lsof -i :8765   # API
lsof -i :3000   # Frontend
lsof -i :6333   # Qdrant
```

**Fix**:
- Stop conflicting services
- Or modify ports in `docker-compose.yml`

## Health Monitoring

### Comprehensive Health Check
```bash
./scripts/health_check.sh
```

This checks:
- ✅ Container status and health
- ✅ Service endpoint responses
- ✅ Memory allocation adequacy
- ✅ Model availability
- ✅ Vector store configuration
- ✅ API functionality
- ✅ Dimension compatibility

### Manual Monitoring
```bash
# Service status
docker-compose ps

# Resource usage
docker stats

# Logs
docker-compose logs -f ollama
docker-compose logs -f openmemory-ollama-mcp

# Test endpoints
curl http://localhost:11434/api/tags     # Ollama
curl http://localhost:8765/docs          # API
curl http://localhost:6333/collections   # Qdrant
```

## Usage

### Adding Memories
Memories are automatically extracted when you chat with Claude Desktop, or manually via the API:

```bash
curl -X POST "http://localhost:8765/api/v1/memories/" \
  -H "Content-Type: application/json" \
  -d '{"text": "I love working with local AI models", "user_id": "your_user_id"}'
```

### Searching Memories
```bash
curl -X GET "http://localhost:8765/api/v1/memories/search?query=AI&user_id=your_user_id"
```

### Model Management
```bash
# List available models
./manage_models.sh list

# Pull a new model
./manage_models.sh pull llama3.1:8b

# Setup required models
./manage_models.sh setup

# Get model info
./manage_models.sh info gemma3:1b
```

## Customization

### Using Different Models

Edit `api/config.json`:
```json
{
  "mem0": {
    "llm": {
      "provider": "ollama",
      "config": {
        "model": "llama3.1:8b",
        "temperature": 0.1,
        "max_tokens": 2000,
        "ollama_base_url": "http://ollama:11434"
      }
    },
    "embedder": {
      "provider": "ollama", 
      "config": {
        "model": "nomic-embed-text:latest",
        "ollama_base_url": "http://ollama:11434"
      }
    }
  }
}
```

**⚠️ Important**: When changing embedding models, the vector dimensions may differ. Run `./scripts/fix_qdrant_dimensions.sh` after model changes.

### Popular Model Alternatives

**LLM Models**:
- `gemma3:1b` (815MB) - Default, fast and efficient
- `llama3.1:8b` (4.7GB) - Higher quality, needs more RAM  
- `qwen2.5:3b` (1.9GB) - Good balance of speed/quality
- `phi3:mini` (2.3GB) - Microsoft's efficient model

**Embedding Models**:
- `all-minilm:latest` (45MB) - Default, fast
- `nomic-embed-text:latest` (274MB) - Higher quality
- `mxbai-embed-large:latest` (669MB) - Best quality, slower

### Resource Requirements by Model

| Model | RAM Needed | Disk Size | Quality | Speed | Use Case |
|-------|-----------|-----------|---------|-------|----------|
| gemma3:1b | 1.6GB | 815MB | Good | Fast | Default, laptops |
| llama3.1:8b | 5GB | 4.7GB | Excellent | Medium | High-end systems |
| qwen2.5:3b | 2.5GB | 1.9GB | Very Good | Medium | Balanced option |

## Performance Optimization

### For Better Performance:
1. **Enable GPU support** (NVIDIA only):
   - Uncomment GPU sections in `docker-compose.yml`
   
2. **Use faster storage**:
   - Store Docker volumes on SSD
   
3. **Increase memory allocation**:
   - Docker: 8GB+ recommended
   - Podman: `podman machine set --memory 8192`
   
4. **Choose appropriate models**:
   - Use `gemma3:1b` for speed
   - Use `llama3.1:8b` for quality (needs more RAM)

## Development

### Building from Source
```bash
git clone <repository-url>
cd openmemory-ollama

# Edit configuration if needed
cp api/.env.example api/.env

# Build and run
docker-compose up --build
```

### Running Tests
```bash
cd api
pip install -r requirements.txt
pytest
```

## Security & Privacy

- **🔒 100% Local Processing**: No data sent to external services
- **🔐 No API Keys Required**: Eliminates key management risks  
- **🏠 Local Network Only**: Services bound to localhost by default
- **📁 Encrypted Storage**: Docker volumes provide secure data storage
- **🚫 No Telemetry**: No usage data collection

## Emergency Recovery

### Complete Reset
```bash
# Stop all services
docker-compose down

# Remove all data (WARNING: deletes all memories)
docker volume rm openmemory-ollama_mem0_storage openmemory-ollama_ollama_models

# Fresh start
./run.sh
```

### Selective Reset
```bash
# Reset only Qdrant (keeps models)
docker-compose stop mem0_store
docker volume rm openmemory-ollama_mem0_storage
docker-compose up -d mem0_store
./scripts/fix_qdrant_dimensions.sh
```

## Contributing

We are a team of developers passionate about the future of AI and open-source software. With years of experience in both fields, we believe in the power of community-driven development and are excited to build tools that make AI more accessible and personalized.

We welcome all forms of contributions:
- Bug reports and feature requests
- Documentation improvements
- Code contributions
- Testing and feedback
- Community support

How to contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b openmemory/feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin openmemory/feature/amazing-feature`)
5. Open a Pull Request

Join us in building the future of AI memory management! Your contributions help make OpenMemory-Ollama better for everyone.

## Support

**Need help?**
1. Run the health check: `./scripts/health_check.sh`
2. Check the troubleshooting section above
3. Review service logs: `docker-compose logs -f`
4. Ensure system requirements are met

**Quick Fix Commands**:
- **Memory issues**: Increase container memory allocation
- **Model errors**: `./manage_models.sh setup`
- **Dimension errors**: `./scripts/fix_qdrant_dimensions.sh`
- **Port conflicts**: Check `lsof -i :PORT` and stop conflicting services
- **Complete reset**: `docker-compose down && docker volume rm openmemory-ollama_*`

## License

Same license as the original OpenMemory project.