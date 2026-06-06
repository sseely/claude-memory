# claude-memory

Agent intelligence system combining persistent memory (OpenMemory/Mem0)
with real-time code navigation (Serena). Agents remember what they've
learned and see code at the symbol level.

## Architecture

Two complementary MCP servers:

- **OpenMemory stack** (Docker) — long-term semantic memory
  - Qdrant (port 6333) — vector database
  - OpenMemory MCP (port 8765) — memory API + MCP endpoint for Claude Code
  - OpenMemory UI (port 8766) — browser dashboard for browsing and managing memories
- **Serena** (local, stdio) — code intelligence via LSP
  - Symbol-level navigation across 40+ languages
  - Precise editing without reading entire files
  - Claude Code spawns it automatically

The OpenMemory stack is built from the
[mem0 monorepo](https://github.com/mem0ai/mem0) source rather than the
Docker Hub image, which was 12 months old at the time of writing. Building
from source keeps the stack current with active development. See the
[vendor patches](#vendor-patches) section for integration fixes that are
applied on top.

See [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) for the full specification.

## Prerequisites

- Docker and Docker Compose v2+
- Python 3.11+ and [uv](https://docs.astral.sh/uv/) (`brew install uv`)
- [Ollama](https://ollama.com/) running locally with `nomic-embed-text-v2-moe` pulled:
  ```bash
  ollama pull nomic-embed-text-v2-moe
  ```
- Docker Desktop with [Model Runner](https://docs.docker.com/desktop/features/model-runner/) enabled and model pulled:
  ```bash
  docker model pull ai/gpt-oss:120B-UD-Q4_K_XL
  ```
- LSP servers for your languages (see MEMORY_SYSTEM.md)
- [bats-core](https://github.com/bats-core/bats-core) (optional, for tests)

## Quick start

```bash
# 1. Configure environment
cp .env.example .env

# 2. Register Serena with Claude Code (one-time)
claude mcp add serena \
  -- uvx --from git+https://github.com/oraios/serena \
  serena start-mcp-server

# 3. Start stack and verify
./scripts/start.sh

# 4. Check health
./scripts/health-check.sh
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MEM0_DEFAULT_USER_ID` | `default` | User scope for memories |
| `OPENAI_API_KEY` | `docker` | Passed to OpenMemory's OpenAI client (routed to Model Runner) |
| `OPENAI_BASE_URL` | `http://model-runner.docker.internal/engines/v1` | Docker Model Runner endpoint |
| `LLM_PROVIDER` | `openai` | LLM backend |
| `LLM_MODEL` | `ai/gpt-oss:120B-UD-Q4_K_XL` | Extraction model via Docker Model Runner |
| `EMBEDDER_PROVIDER` | `ollama` | Embedding backend |
| `EMBEDDER_MODEL` | `nomic-embed-text-v2-moe` | Embedding model (768-dim MoE, ~100 languages) |
| `EMBEDDER_MODEL_DIMS` | `768` | Must match the embedding model's output dimensions |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama endpoint reachable from Docker |

All defaults are set in `.env.example`. Copy it and start.

## MCP client configuration

Add both servers to `~/.claude/.mcp.json`:

```json
{
  "mcpServers": {
    "mem0": {
      "type": "http",
      "url": "http://localhost:8765/mcp/claude-code/http/default"
    },
    "serena": {
      "command": "uv",
      "args": [
        "--directory", "/path/to/serena",
        "run", "serena", "start-mcp-server",
        "--context", "claude-code",
        "--project", "/path/to/your/project"
      ]
    }
  }
}
```

## Vendor patches

The OpenMemory container is built from source, and three integration
bugs required patching before it worked with a local Ollama embedder.
The patches live in `vendor/` and are bind-mounted over the originals
at container start — the image itself is unchanged.

| File | Patches |
|------|---------|
| `vendor/openmemory_memory_utils.py` | Propagates `embedding_dims` from the embedder config into `QdrantConfig.embedding_model_dims`. Without this, the Qdrant collection is always created at 1536 dimensions (the OpenAI default) regardless of the configured embedder. |
| `vendor/openmemory_mcp_server.py` | Fixes `limit=10` → `top_k=10` in the vector store search call. The mem0 Qdrant store uses `top_k`; the original code passed `limit`, which raised a `TypeError`. |
| `vendor/openmemory_entrypoint.sh` | Replaces the default startup command. Runs the warm-up script before starting uvicorn. |
| `vendor/openmemory_warmup.py` | Calls Ollama's `/api/embed` with `keep_alive=-1` before the server starts. This loads the embedding model into memory and pins it there, preventing cold-start timeouts on the first MCP request. |

Note: `docker compose restart` does **not** re-apply volume mount changes.
If you modify `docker-compose.yml` volumes, use `docker compose up -d` to
recreate the container.

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
