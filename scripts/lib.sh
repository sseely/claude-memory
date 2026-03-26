#!/usr/bin/env bash
# Shared utilities for memory system scripts.

QDRANT_URL="http://localhost:6333/healthz"
MEM0_MCP_URL="http://localhost:8050/sse"

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
