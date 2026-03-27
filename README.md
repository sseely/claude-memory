# claude-memory

Agent intelligence system combining persistent memory (Mem0) with
real-time code navigation (Serena). Agents remember what they've
learned and see code at the symbol level.

## Architecture

Two complementary MCP servers:

- **Mem0 stack** (Docker) — long-term semantic memory
  - Qdrant (port 6333) — vector database
  - Mem0 (port 8080) — memory extraction and deduplication
  - Mem0 MCP Server (port 8050) — exposes Mem0 as MCP tools
- **Serena** (local, stdio) — code intelligence via LSP
  - Symbol-level navigation across 40+ languages
  - Precise editing without reading entire files
  - Claude Code spawns it automatically

See [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) for the full specification.

## Prerequisites

- Docker and Docker Compose v2+
- Python 3.11+ and [uv](https://docs.astral.sh/uv/) (`pip install uv`)
- `curl` on the host (used by health check scripts)
- LSP servers for your languages (see MEMORY_SYSTEM.md for list)
- [bats-core](https://github.com/bats-core/bats-core) (optional, for tests)

## Quick start

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your MEM0_API_KEY and optional MEM0_DEFAULT_USER_ID

# 2. Register Serena with Claude Code
claude mcp add serena \
  -- uvx --from git+https://github.com/oraios/serena \
  serena start-mcp-server

# 3. Start Mem0 stack and verify everything
./scripts/start.sh

# 4. Verify health
./scripts/health-check.sh
```

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MEM0_API_KEY` | Yes | — | API key for Mem0 |
| `MEM0_DEFAULT_USER_ID` | No | `default` | Default user scope for memories |

Copy `.env.example` to `.env` and fill in values before starting.

## MCP client configuration

Configure both servers in `.mcp.json`:

```json
{
  "mcpServers": {
    "mem0": {
      "transport": "sse",
      "url": "http://localhost:8050/sse"
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
| `scripts/start.sh` | Start Mem0 stack, verify Serena installed |
| `scripts/health-check.sh` | Check all services (Mem0 endpoints + Serena) |
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
qualifying insights to Mem0 — including structural maps
discovered via Serena.

## Stopping services

```bash
docker compose down      # stop Mem0 stack, preserve data
docker compose down -v   # stop (data in ./data/ survives)
# Serena stops automatically when Claude Code exits
```
