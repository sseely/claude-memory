# claude-memory

Two-tier agent memory system: local observations in `.agent-notes/`
with long-term semantic recall via Mem0.

## Architecture

Three Docker services provide the memory infrastructure:

- **Qdrant** (port 6333) — vector database for semantic search
- **Mem0** (port 8080) — memory extraction, deduplication, management
- **Mem0 MCP Server** (port 8050) — exposes Mem0 as MCP tools for agents

See [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) for the full specification.

## Prerequisites

- Docker and Docker Compose v2+

## Quick start

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your MEM0_API_KEY and optional MEM0_DEFAULT_USER_ID

# 2. Start services
./scripts/start.sh

# 3. Verify health
./scripts/health-check.sh
```

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MEM0_API_KEY` | Yes | — | API key for Mem0 |
| `MEM0_DEFAULT_USER_ID` | No | `default` | Default user scope for memories |

Copy `.env.example` to `.env` and fill in values before starting.

## MCP client configuration

Point agents at the MCP server by adding to your MCP config:

```json
{
  "mcpServers": {
    "mem0": {
      "transport": "sse",
      "url": "http://localhost:8050/sse"
    }
  }
}
```

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/start.sh` | Start all services and wait for health |
| `scripts/health-check.sh` | Point-in-time health check of all endpoints |

## Memory curator agent

The memory curator agent at `~/.claude/agents/memory-curator.md`
is sourced from this repo. It reads `.agent-notes/*.md` files,
evaluates observations against sponge-worthy criteria, and promotes
qualifying insights to Mem0.

To install or update:

```bash
cp ~/.claude/agents/memory-curator.md ~/.claude/agents/memory-curator.md.bak 2>/dev/null
# The agent is written directly by the build process.
# If updating manually, copy from the repo's plans or regenerate via T3.
```

## Stopping services

```bash
docker compose down      # stop containers, preserve data
docker compose down -v   # stop containers (data in ./data/ survives)
```
