# Claude Code — Project Instructions

## Memory + Code Intelligence

See [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) for the full architecture:
OpenMemory MCP (persistent memory via Qdrant) + Serena (code
intelligence via LSP).

## Local observations

Write observations to `.agent-notes/` during task execution.
Do not write directly to Mem0 — the memory curator agent handles
promotion.

## Commands

```bash
./scripts/start.sh          # start stack, verify Serena
./scripts/health-check.sh   # check all services
docker compose up -d         # start Docker services only
docker compose down          # stop Docker services
docker compose logs -f       # tail service logs
bats test/                   # run shell script tests
```

## Services

| Service | Transport | Health |
|---------|-----------|--------|
| Qdrant | Docker, port 6333 | `http://localhost:6333/healthz` |
| OpenMemory MCP | Docker, port 8765 | `http://localhost:8765` |
| Serena | stdio (Claude spawns) | `uvx` available on PATH |
