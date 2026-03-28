# Agent Memory System

## Architecture

This system combines two complementary capabilities:

- **Memory** (Mem0) — persistent cross-session knowledge: what agents have learned over time
- **Code intelligence** (Serena) — real-time code navigation via LSP: what agents can see right now

Together they form a feedback loop: Serena helps agents explore code
efficiently, discoveries flow through `.agent-notes/` to the curator,
and Mem0 stores the durable insights that make future Serena queries
more targeted.

### Three tiers

1. **Local observations** — raw notes written to `.agent-notes/` during task execution
2. **Long-term memory** (Mem0) — curated, high-value discoveries stored via MCP
3. **Code intelligence** (Serena) — symbol-level navigation, references, and precise edits via LSP

All agents have access to both Mem0 and Serena MCP tools.

## Infrastructure Setup

### OpenMemory stack (Docker)

The memory layer runs as two containers via Docker Compose, using the
[OpenMemory MCP](https://github.com/mem0ai/mem0/tree/main/openmemory)
architecture:

- **Qdrant** — vector database for semantic search over stored memories
- **OpenMemory MCP** — memory extraction, deduplication, and MCP tools (FastAPI server backed by Mem0)

Default setup uses OpenAI (gpt-5-nano for extraction,
text-embedding-3-small for embeddings). Swap both for Ollama models
to go fully offline — see `.env.example`.

### Docker Compose

See `docker-compose.yml` for the full definition. Key properties:

- **Qdrant** — `qdrant/qdrant:v1.17.0`, port 6333, bind mount at `./data/qdrant:/qdrant/storage`
- **OpenMemory MCP** — `mem0/openmemory-mcp:latest`, port 8765, reads `.env` for provider config
- Health checks on both services, `depends_on: condition: service_healthy`
- Localhost-only port bindings (`127.0.0.1:...`)

Design choices:
- **Bind mounts** instead of named volumes — data survives
  `docker compose down -v`, is visible on the host, and is
  straightforward to back up.
- **Localhost-only ports** prevent unauthenticated network access.
- **Two services, not three** — OpenMemory MCP includes the Mem0
  memory layer internally; no separate API server needed.

### Startup

```bash
docker compose up -d
```

### MCP Client Configuration (Mem0 only)

```json
{
  "mcpServers": {
    "mem0": {
      "transport": "sse",
      "url": "http://localhost:8765/sse"
    }
  }
}
```

### Environment Variables

Copy `.env.example` to `.env`. Default uses OpenAI:

```
OPENAI_API_KEY=sk-your-key-here
USER=default
```

For fully offline operation with Ollama, see `.env.example` for the
complete Ollama configuration (LLM_PROVIDER, EMBEDDER_PROVIDER, etc.).

### Verification

After `docker compose up -d`, confirm both services are healthy:

```bash
# Qdrant health
curl http://localhost:6333/healthz

# OpenMemory MCP
curl http://localhost:8765
```

### Notes

- Bind-mounted `./data/qdrant/` persists memories across container restarts
- OpenMemory MCP handles embedding generation, memory extraction, and MCP tools in one container
- If the MCP server goes down, agents lose memory tools but continue working — they just won't have recall
- Qdrant is pinned to v1.17.0; OpenMemory MCP uses `:latest` — update periodically

### Serena (local, stdio)

Serena is an MCP server that provides IDE-like code intelligence via
LSP. Claude Code spawns it automatically — no long-running process needed.

**Prerequisites:**

- Python 3.11+ and [uv](https://docs.astral.sh/uv/) (`pip install uv`)
- LSP servers for your languages (many auto-install):
  - TypeScript: `npm i -g typescript-language-server typescript`
  - Python: `pip install python-lsp-server`
  - Go: `go install golang.org/x/tools/gopls@latest`
  - Rust: installed with `rustup component add rust-analyzer`

**Register with Claude Code:**

```bash
claude mcp add serena \
  -- uvx --from git+https://github.com/oraios/serena \
  serena start-mcp-server
```

**Per-project configuration:**

Create `.serena/project.yml` in each repo:

```yaml
languages:
  - name: typescript
    language_server: typescript-language-server --stdio
```

Serena creates `.serena/memories/` (markdown notes) and
`.serena/cache/` (symbol indexes) per project. Add `.serena/cache/`
to `.gitignore`; optionally commit `.serena/memories/` for shared
team context.

**Key tools provided:**

| Tool | Use |
|------|-----|
| `find_symbol` | Find a class, function, or variable by name |
| `find_referencing_symbols` | Find all callers of a symbol |
| `get_symbol_definition` | Get full source of a symbol |
| `insert_after_symbol` | Edit code precisely without reading the file |
| `replace_symbol` | Replace a symbol's implementation |
| `activate_project` | Switch Serena to a different repo |

### Combined MCP Configuration

Configure both servers in `.mcp.json`:

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

### How they work together

```
  Serena (real-time)              Mem0 (persistent)
  ┌─────────────────┐            ┌─────────────────┐
  │ find_symbol      │            │ search_memories  │
  │ find_references  │──discover──▶ .agent-notes/   │
  │ get_definition   │            │     │            │
  └─────────────────┘            │  curator         │
         ▲                       │     │            │
         │                       │  add_memory      │
         │ targeted queries      │     │            │
         └───────────────────────│  "entry points   │
                                 │   are X, Y, Z"   │
                                 └─────────────────┘
```

1. Agent starts a task → searches Mem0 for prior knowledge
2. Mem0 returns: "this repo uses repository pattern, entry points are routes.ts and worker.ts"
3. Agent uses Serena to navigate: `find_symbol("UserRepository")` → exact definition
4. Agent discovers something non-obvious during work → writes to `.agent-notes/`
5. Curator evaluates → promotes durable insights to Mem0 for next session

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

1. **Recall** — search Mem0 for prior discoveries related to the task, codebase, or pattern
2. **Read** — check local `.agent-notes/` files in the working directory
3. **Orient** — if Serena is available, use `find_symbol` or `activate_project` to understand the codebase structure before diving in
4. **Skip** — do not re-investigate what is already known from steps 1-3

State what you found and how it affects your approach before proceeding.

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
