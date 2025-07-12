# OpenMemory-Ollama Setup Guide

## Overview

OpenMemory-Ollama is a completely local version of OpenMemory that uses Ollama for AI models instead of external APIs. This provides a personal memory layer for AI applications with MCP (Model Context Protocol) support for Claude Desktop integration - all while keeping your data 100% private and incurring zero API costs.

## Prerequisites

### Required Software
- **Container Runtime**: Either:
  - **Docker** and **Docker Compose** - Traditional containerization
  - **Podman** and **podman-compose** - Rootless alternative (recommended for security)
- **Node.js** (for MCP client installation)
- **Claude Desktop** - For MCP integration

#### Installing Container Runtime

**Option 1: Docker**
```bash
# macOS
brew install docker docker-compose

# Linux
sudo apt update && sudo apt install docker.io docker-compose-v2
```

**Option 2: Podman (Recommended)**
```bash
# macOS
brew install podman
pip install podman-compose

# Linux
sudo apt update && sudo apt install podman
pip install podman-compose
```

### API Key Requirements
- **None!** - Everything runs locally with Ollama

## Quick Start (Recommended)

### 1. One-Line Installation
```bash
cd openmemory-ollama
bash run.sh
```

This script will:
- Automatically detect Docker or Podman
- Set up Ollama service with required models
- Download and configure gemma3:1b (LLM) and all-minilm (embeddings)
- Start all required containers
- Open the UI in your browser

**Note**: First run may take 10-15 minutes as it downloads AI models (~2GB total).

### 2. Verify Installation
After running the script, you should see:
- **Backend API**: http://localhost:8765
- **Frontend UI**: http://localhost:3000 (or next available port)
- **API Documentation**: http://localhost:8765/docs
- **Ollama Service**: http://localhost:11434

## Manual Setup

### 1. Environment Configuration (Optional)
```bash
cd openmemory-ollama
cp api/.env.example api/.env
```

Edit `api/.env` (optional - has sensible defaults):
```env
# Ollama Configuration (optional - will use defaults if not set)
OLLAMA_HOST=http://localhost:11434
USER=your_user_id
```

### 2. Build and Start Services

**With Docker:**
```bash
# Build the containers
make build

# Start all services
make up

# Or use docker-compose directly
docker-compose up -d
```

**With Podman:**
```bash
# Start all services with podman-compose
podman-compose up -d

# Or use the run.sh script (recommended)
bash run.sh
```

### 3. Setup Required Models
```bash
# Setup models using the management script
./manage_models.sh setup

# Or using make
make models
```

### 4. Verify Services

**With Docker:**
```bash
# Check running containers
docker-compose ps

# View logs
docker-compose logs -f openmemory-ollama-mcp
```

**With Podman:**
```bash
# Check running containers
podman-compose ps

# View logs
podman-compose logs -f openmemory-ollama-mcp
```

## Model Management

### Required Models
The system uses these local models:
- **LLM**: `gemma3:1b` (1.4GB) - Fast, efficient language model
- **Embeddings**: `all-minilm:latest` (133MB) - Optimized embedding model

### Model Management Commands
```bash
# Setup all required models
./manage_models.sh setup

# List installed models
./manage_models.sh list

# Pull a specific model
./manage_models.sh pull llama3.1:latest

# Remove a model
./manage_models.sh remove old-model:tag

# Get model information
./manage_models.sh info gemma3:1b

# Or use make commands
make models        # Setup required models
make models-list   # List available models
```

### Alternative Models

You can modify `api/default_config.json` to use different Ollama models:

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

**Popular LLM Models**:
- `gemma3:1b` (1.4GB) - Fast, lightweight
- `llama3.1:8b` (4.7GB) - Better quality, more resource intensive
- `qwen2.5:3b` (1.9GB) - Good balance of speed and quality
- `phi3:mini` (2.3GB) - Microsoft's efficient model

**Popular Embedding Models**:
- `all-minilm:latest` (133MB) - Fast, good quality
- `nomic-embed-text:latest` (274MB) - High quality embeddings
- `mxbai-embed-large:latest` (669MB) - Best quality, slower

## Claude Desktop MCP Integration

### Step 1: Install MCP Client Tool
```bash
npm install -g @openmemory/install
```

### Step 2: Configure Claude Desktop

1. **Open Claude Desktop Settings**
   - Open Claude Desktop
   - Go to Settings (from the menu bar, not in-app)
   - Click "Developer" in the sidebar
   - Click "Edit Config"

2. **Add OpenMemory-Ollama MCP Server**
   
   Add this configuration to your `claude_desktop_config.json`:
   ```json
   {
     "mcpServers": {
       "openmemory-ollama": {
         "command": "npx",
         "args": [
           "-y",
           "@openmemory/install",
           "local",
           "http://localhost:8765/mcp/claude/sse/your_user_id",
           "--client",
           "claude"
         ]
       }
     }
   }
   ```
   
   Replace `your_user_id` with the same user ID you set in your `.env` file.

### Step 3: Restart Claude Desktop
- Close Claude Desktop completely
- Restart the application
- Look for the tools icon (🔨) in the bottom-right corner of Claude

### Alternative MCP Configuration

If the above doesn't work, try this simpler configuration:

```json
{
  "mcpServers": {
    "openmemory-ollama": {
      "command": "node",
      "args": [
        "-e",
        "const { spawn } = require('child_process'); const proc = spawn('curl', ['-N', '-H', 'Accept: text/event-stream', 'http://localhost:8765/mcp/claude/sse/your_user_id'], { stdio: 'inherit' }); proc.on('close', process.exit);"
      ]
    }
  }
}
```

## Configuration Options

### GPU Support (Optional)

For better performance, you can enable GPU support by uncommenting the GPU configuration in `docker-compose.yml`:

```yaml
ollama:
  image: ollama/ollama:latest
  ports:
    - "11434:11434"
  volumes:
    - ollama_models:/root/.ollama
  environment:
    - OLLAMA_HOST=0.0.0.0
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

### Custom Ollama Host

If you're running Ollama separately or on a different machine:

```env
# In api/.env
OLLAMA_HOST=http://your-ollama-host:11434
```

## Usage

### MCP Tools Available in Claude

Once configured, Claude Desktop will have access to these memory operations:

1. **add_memories** - Automatically stores information about you and your preferences
2. **search_memory** - Searches through your stored memories (called automatically)
3. **list_memories** - Lists all your stored memories
4. **delete_all_memories** - Clears all stored memories

### Memory Management via UI

Access the web interface at http://localhost:3000 to:
- View all stored memories
- Search through memories
- Delete specific memories
- Monitor memory usage and statistics

### Direct Ollama Access

You can also interact with Ollama directly:
```bash
# Chat with the model directly
curl http://localhost:11434/api/generate -d '{
  "model": "gemma3:1b",
  "prompt": "Hello, how are you?",
  "stream": false
}'

# Generate embeddings
curl http://localhost:11434/api/embeddings -d '{
  "model": "all-minilm:latest",
  "prompt": "The quick brown fox"
}'
```

## Troubleshooting

### Common Issues

#### 1. Models Not Downloaded
```
Error: model not found
```
**Solution**: Run the model setup:
```bash
./manage_models.sh setup
# or
make models
```

#### 2. Claude Desktop Not Connecting
**Symptoms**: No tools icon in Claude Desktop
**Solutions**:
- Verify OpenMemory-Ollama is running: `docker-compose ps`
- Check Claude Desktop config file syntax
- Restart Claude Desktop completely
- Check logs: `docker-compose logs openmemory-ollama-mcp`

#### 3. Port Conflicts
```
Error: Port 11434 already in use
```
**Solution**: 
- Stop existing Ollama: `docker stop $(docker ps -q -f "name=ollama")`
- Or change port in `docker-compose.yml`

#### 4. Docker Issues
```
Error: Docker not found
```
**Solution**: Install Docker Desktop from https://www.docker.com/products/docker-desktop/

#### 5. Slow Performance
**Symptoms**: Long response times
**Solutions**:
- Use smaller models (gemma3:1b is optimized for speed)
- Enable GPU support if available
- Check system resources: `docker stats`

### Memory and Disk Space

Models require disk space:
- `gemma3:1b`: ~1.4GB
- `all-minilm:latest`: ~133MB
- Container images: ~2GB
- **Total**: ~4GB minimum free space recommended

### Performance Optimization

**For better performance**:
1. Use SSD storage for Docker volumes
2. Allocate more RAM to Docker (8GB+ recommended)
3. Enable GPU support if you have NVIDIA GPU
4. Use smaller models for faster inference

## Development

### Building from Source
```bash
# Clone the repository
git clone <repo-url>
cd openmemory-ollama

# Set up environment (optional)
cp api/.env.example api/.env

# Build and run
docker-compose up --build
```

### Customizing Memory Behavior

Edit `api/app/utils/memory.py` to modify:
- Default model configurations
- Memory extraction prompts
- Vector store settings

### Running Tests
```bash
cd api
pip install -r requirements.txt
pytest
```

### Adding New Models

1. Pull the model:
```bash
./manage_models.sh pull new-model:tag
```

2. Update configuration in `api/default_config.json`

3. Restart services:
```bash
docker-compose restart openmemory-ollama-mcp
```

## Security Notes

- **100% Local**: All data stays on your machine
- **No Internet Required**: After initial model download
- **Private**: No data sent to external APIs
- **Encrypted Storage**: Docker volumes provide secure storage
- **Local Network Only**: MCP server only accepts local connections by default

## Support

If you encounter issues:
1. Check the logs: `docker-compose logs -f`
2. Verify all prerequisites are installed
3. Ensure models are downloaded: `./manage_models.sh list`
4. Check system resources: `docker stats`
5. Verify Ollama is responding: `curl http://localhost:11434/api/tags`

## Performance Comparison

| Model | Size | Speed | Quality | Recommended Use |
|-------|------|-------|---------|-----------------|
| gemma3:1b | 1.4GB | Fast | Good | Default, laptops |
| llama3.1:8b | 4.7GB | Medium | Excellent | High-end systems |
| qwen2.5:3b | 1.9GB | Medium | Very Good | Balanced option |

## Differences from Original OpenMemory

- **No API Keys**: Uses local Ollama models
- **Zero Cost**: No external API charges
- **Offline Capable**: Works without internet after setup
- **Privacy First**: All processing happens locally
- **Customizable Models**: Easy to switch between different local models
- **Resource Efficient**: Optimized for local hardware

## Advanced Configuration

### Custom Docker Networks
```yaml
# In docker-compose.yml
networks:
  openmemory:
    driver: bridge

services:
  ollama:
    networks:
      - openmemory
```

### Persistent Model Storage
Models are automatically stored in Docker volumes. To back up:
```bash
# Backup models
docker run --rm -v openmemory-ollama_ollama_models:/data -v $(pwd):/backup ubuntu tar czf /backup/ollama_models.tar.gz -C /data .

# Restore models
docker run --rm -v openmemory-ollama_ollama_models:/data -v $(pwd):/backup ubuntu tar xzf /backup/ollama_models.tar.gz -C /data
```

## License

Same as the original OpenMemory project.