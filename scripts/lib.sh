#!/usr/bin/env bash
# Shared utilities for memory system scripts.

# OpenMemory MCP stack endpoints
QDRANT_URL="http://localhost:6333/healthz"
OPENMEMORY_URL="http://localhost:8765"

# Serena MCP server command
SERENA_CMD="uvx --from git+https://github.com/oraios/serena serena"

check_endpoint() {
  local url="$1"
  local http_code
  http_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "${url}" 2>&1 || echo "000")"
  if [[ "${http_code}" =~ ^2[0-9]{2}$ ]]; then
    return 0
  else
    return 1
  fi
}

check_serena() {
  if command -v uvx &>/dev/null; then
    return 0
  else
    return 1
  fi
}
