# Claude Code — Project Instructions

## Memory + Code Intelligence

See [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) for the full architecture:
Mem0 (persistent memory) + Serena (code intelligence via LSP).

## Local observations

Write observations to `.agent-notes/` during task execution.
Do not write directly to Mem0 — the memory curator agent handles
promotion.

## Commands

```bash
./scripts/start.sh          # start Mem0 stack, verify Serena
./scripts/health-check.sh   # check all services
docker compose up -d         # start Mem0 stack only
docker compose down          # stop Mem0 stack
docker compose logs -f       # tail Mem0 service logs
bats test/                   # run shell script tests
```

## Services

| Service | Transport | Health |
|---------|-----------|--------|
| Qdrant | Docker, port 6333 | `http://localhost:6333/healthz` |
| Mem0 | Docker, port 8080 | `http://localhost:8080` |
| Mem0 MCP | Docker, port 8050 | `http://localhost:8050/sse` |
| Serena | stdio (Claude spawns) | `uvx` available on PATH |
