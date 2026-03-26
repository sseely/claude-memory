# Claude Code — Project Instructions

## Memory workflow

See [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) for the full two-tier
memory architecture, observation format, and sponge-worthy criteria.

## Local observations

Write observations to `.agent-notes/` during task execution.
Do not write directly to Mem0 — the memory curator agent handles
promotion.

## Commands

```bash
./scripts/start.sh          # start services, wait for health
./scripts/health-check.sh   # check service endpoints
docker compose up -d         # start without health polling
docker compose down          # stop services
docker compose logs -f       # tail all service logs
```

## Services

| Service | Port | Health endpoint |
|---------|------|-----------------|
| Qdrant | 6333 | `http://localhost:6333/healthz` |
| Mem0 | 8080 | `http://localhost:8080` |
| Mem0 MCP | 8050 | `http://localhost:8050/sse` |
