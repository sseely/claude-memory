# claude-memory

Agent intelligence system combining persistent memory (OpenMemory/Mem0)
with real-time code navigation (Serena). Agents remember what they've
learned and see code at the symbol level.

## Architecture

Two complementary MCP servers:

- **OpenMemory stack** (Docker) — long-term semantic memory
  - Qdrant (port 6333) — vector database
  - OpenMemory MCP (port 8765) — memory API + MCP tools
- **Serena** (local, stdio) — code intelligence via LSP
  - Symbol-level navigation across 40+ languages
  - Precise editing without reading entire files
  - Claude Code spawns it automatically

See [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) for the full specification.

## Prerequisites

- Docker and Docker Compose v2+
- Python 3.11+ and [uv](https://docs.astral.sh/uv/) (`brew install uv`)
- `curl` on the host (used by health check scripts)
- [Ollama](https://ollama.com/) running locally with `llama3.1` and `nomic-embed-text` models pulled
- LSP servers for your languages (see MEMORY_SYSTEM.md)
- [bats-core](https://github.com/bats-core/bats-core) (optional, for tests)

## Quick start

```bash
# 1. Configure environment
cp .env.example .env
# Defaults work if Ollama is running with llama3.1 and nomic-embed-text

# 2. Register Serena with Claude Code
claude mcp add serena \
  -- uvx --from git+https://github.com/oraios/serena \
  serena start-mcp-server

# 3. Start stack and verify
./scripts/start.sh

# 4. Check health
./scripts/health-check.sh
```

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `USER` | No | `default` | User scope for memories |
| `LLM_PROVIDER` | — | `ollama` | LLM backend |
| `LLM_MODEL` | — | `llama3.1:latest` | Extraction model |
| `EMBEDDER_PROVIDER` | — | `ollama` | Embedding backend |
| `EMBEDDER_MODEL` | — | `nomic-embed-text` | Embedding model |
| `EMBEDDER_MODEL_DIMS` | — | `768` | Embedding dimensions (must match model) |
| `OLLAMA_BASE_URL` | — | `http://host.docker.internal:11434` | Ollama endpoint |

All defaults are set in `.env.example`. Just copy and start.

## MCP client configuration

Both servers in `~/.claude/.mcp.json`:

```json
{
  "mcpServers": {
    "mem0": {
      "transport": "sse",
      "url": "http://localhost:8765/sse"
    },
    "serena": {
      "command": "uvx",
      "args": [
        "--from", "git+https://github.com/oraios/serena",
        "serena", "start-mcp-server"
      ]
    }
  }
}
```

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/start.sh` | Start Docker stack, verify Serena installed |
| `scripts/health-check.sh` | Check all services |
| `scripts/setup-machine.sh` | One-time machine setup (MCP config + launchd) |
| `scripts/lib.sh` | Shared utilities |

`start.sh` supports environment overrides: `TIMEOUT` (default 120s)
and `POLL_INTERVAL` (default 5s).

## Testing

```bash
bats test/
```

## Per-project Serena config

Create `.serena/project.yml` in each repo:

```yaml
languages:
  - name: typescript
    language_server: typescript-language-server --stdio
```

## Memory curator agent

The memory curator agent at
`~/.claude/agents/09-meta-orchestration/memory-curator.md`
is sourced from this repo. It evaluates `.agent-notes/*.md`
observations against sponge-worthy criteria and promotes
qualifying insights to Mem0.

## Stopping services

```bash
docker compose down      # stop Docker stack, preserve data
# Serena stops automatically when Claude Code exits
```
