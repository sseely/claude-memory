# Agent Memory System

## Architecture

This system uses a two-tier memory architecture:

1. **Local observations** — raw notes written to `.agent-notes/` in the working directory during task execution
2. **Long-term memory** — curated, high-value discoveries stored in Mem0 via MCP

All agents have access to Mem0 MCP tools. Not all agents write directly to long-term memory.

## Infrastructure Setup

The memory system runs as three containers via Docker Compose:

- **Qdrant** — vector database for semantic search over stored memories
- **Mem0** — memory extraction, deduplication, and management layer
- **Mem0 MCP Server** — exposes Mem0 operations as MCP tools for agents

### Docker Compose

The `docker-compose.yml` defines all three services with health checks,
dependency ordering, and localhost-only port bindings:

```yaml
services:
  qdrant:
    image: qdrant/qdrant:v1.17.0
    ports:
      - "127.0.0.1:6333:6333"
      - "127.0.0.1:6334:6334"
    volumes:
      - ./data/qdrant:/qdrant/storage
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/healthz"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  mem0:
    image: mem0ai/mem0:v1.0.7
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      VECTOR_STORE_PROVIDER: qdrant
      QDRANT_HOST: qdrant
      QDRANT_PORT: "6333"
    depends_on:
      qdrant:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  mem0-mcp:
    build: https://github.com/mem0ai/mem0-mcp.git#624024de
    ports:
      - "127.0.0.1:8050:8050"
    environment:
      MEM0_API_KEY: ${MEM0_API_KEY}
      MEM0_DEFAULT_USER_ID: ${MEM0_DEFAULT_USER_ID:-default}
      TRANSPORT: sse
    depends_on:
      mem0:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8050/sse"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
```

Design choices:
- **Bind mounts** (`./data/qdrant/`) instead of named volumes — data
  survives `docker compose down -v`, is visible on the host, and is
  straightforward to back up.
- **`depends_on: condition: service_healthy`** ensures services start
  only after their dependencies pass health checks.
- **`start_period`** on every service gives containers time to
  initialize before Docker marks them unhealthy.
- **Localhost-only ports** (`127.0.0.1:...`) prevent unauthenticated
  network access from other hosts.

### Startup

```bash
docker compose up -d
```

### MCP Client Configuration

Point agents at the MCP server:

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

### Environment Variables

Create a `.env` file alongside the compose file:

```
MEM0_API_KEY=<your-mem0-api-key>
MEM0_DEFAULT_USER_ID=<your-user-id>
```

### Verification

After `docker compose up -d`, confirm all three services are healthy:

```bash
# Qdrant health
curl http://localhost:6333/healthz

# Mem0 MCP tools available
curl http://localhost:8050/sse
```

### Notes

- Bind-mounted `./data/` directories persist memories across container restarts
- The Mem0 container handles embedding generation and memory extraction
- The MCP server is stateless — it proxies to Mem0, which proxies to Qdrant
- If the MCP server goes down, agents lose memory tools but continue working — they just won't have recall
- Image versions are pinned in `docker-compose.yml` — update them periodically and test before deploying

## Memory Scoping

Every memory stored in Mem0 must be tagged with a scope:

- `repo:{name}` — specific to a single repository. Conventions, API quirks, config deviations, codebase-specific patterns.
- `project:{name}` — spans multiple repos within a project. Integration patterns, shared service behaviors, cross-repo dependencies.
- `org` — universally applicable. Cloud provider gotchas, infrastructure patterns, tooling discoveries, language-level findings.

### Curator Scoping Rule

When evaluating a memory, ask: "Would an agent working on a different repo benefit from this?" If yes, it's at least project-scoped. "Would an agent on a completely different project benefit?" If yes, it's org-scoped. Default to the narrowest scope that's accurate.

## Memory Durability

Every memory must be classified as one of:

- `important` — durable fact unlikely to change. API doesn't support pagination. Service X requires auth header Y. This pattern causes memory leaks in Node 20.
- `contextual` — true now, likely to change. Staging is on v2.3. Build is broken due to dependency conflict. Rate limit is currently 100/min.

### Durability Rules

- `important` memories persist until explicitly contradicted by a new observation.
- `contextual` memories get a TTL tag (default: 30 days). After TTL, they're flagged for review or automatic removal.
- When a new observation contradicts an `important` memory, update the memory and log the change.

## Search Behavior

### Default: Scoped Search

When an agent searches memory before starting a task:

1. Search `repo:{current-repo}` scope
2. Search `org` scope
3. Merge results, deduplicate, inject into context

### Fallback: Widening Search

If scoped search returns no relevant results:

1. Widen to `project:{current-project}` scope
2. If still empty, widen to global (all scopes, unfiltered)
3. Apply relevance threshold — low-confidence results from wide searches are worse than no results

### Explicit Global Search

When explicitly instructed to search globally, skip scoping entirely and search across all memories. Use this when:

- Investigating whether a problem has been seen anywhere before
- Looking for patterns that might apply cross-project
- Auditing what the system knows about a topic regardless of where it was learned

### Search Result Injection

- Always state what memories were found and from what scope before proceeding
- If a memory is from a different repo/project, flag it: "This was observed in {scope} — verify it applies here before relying on it"
- Never silently apply cross-scope memories as if they are local facts

## Before Starting Any Task

1. Search Mem0 for prior discoveries related to the current task, codebase, file, or pattern
2. Read any local `.agent-notes/` files in the working directory
3. Use what you find to skip redundant discovery — do not re-investigate what is already known

If memory search returns relevant results, state what you found and how it affects your approach before proceeding.

## During Task Execution

When you encounter any of the following, write a note to `.agent-notes/{task-id}.md`:

- Unexpected behavior in code, APIs, or infrastructure
- Undocumented conventions or implicit patterns in the codebase
- Dependency quirks, version-specific gotchas, or compatibility issues
- Configuration that deviates from defaults or documentation
- Error patterns and their root causes
- Performance characteristics observed during execution
- API usage patterns that differ from documentation

Write observations as structured entries:

```markdown
## Observation: {short title}
- **Context**: What you were doing when you found this
- **Finding**: What you discovered
- **Impact**: Why this matters for future work
- **Confidence**: High / Medium / Low
```

Keep observations factual. Do not store opinions, preferences, or speculative interpretations.

## After Completing a Task

1. Review your local notes from this session
2. If no notes were generated, confirm the task produced no novel discoveries
3. Do not write directly to Mem0 — local notes will be evaluated by the memory curator

## Memory Curator (Sponge-Worthy Evaluation)

A dedicated agent reads local `.agent-notes/` files and decides what enters long-term memory. The curator applies the following criteria:

### Store in Mem0 if the observation is:

- **Reusable** — another agent working on a different task would benefit from knowing this
- **Non-obvious** — not something that would be discovered in under 60 seconds of reading docs or code
- **Stable** — unlikely to change in the next sprint/release cycle
- **Actionable** — knowing this changes how you approach the work

### Do not store if:

- It's task-specific context with no future relevance
- It duplicates something already in Mem0 (search first)
- It's a temporary state (build broken, service down, PR pending)
- It's derivable from source code or documentation without significant effort

### When storing to Mem0:

- Deduplicate against existing memories before adding
- Synthesize if multiple agents discovered the same thing — store one clean memory, not three noisy ones
- Tag with scope (`repo:`, `project:`, or `org`) and durability (`important` or `contextual`)
- If a new observation contradicts an existing memory, update or replace — do not create conflicting entries

## Mem0 MCP Tools Reference

Available tools (provided via MCP):

| Tool | Use When |
|---|---|
| `search_memories` | Before starting any task. When encountering unexpected behavior. When you need context you don't have. |
| `add_memory` | Curator agent only. After sponge-worthy evaluation passes. |
| `update_memory` | When a stored memory is partially outdated but still relevant. |
| `delete_memory` | When a stored memory is fully obsolete or incorrect. |
| `list_memories` | When you need to audit what's stored for a given scope. |

## What This System Replaces

This replaces ad-hoc markdown note files as the primary mechanism for cross-session knowledge transfer. Local notes still exist as the ingestion layer, but long-term recall is handled by Mem0's semantic search rather than loading flat files into context.
