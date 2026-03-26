#!/usr/bin/env bash
set -euo pipefail

QDRANT_URL="http://localhost:6333/healthz"
MEM0_MCP_URL="http://localhost:8050/sse"

check_endpoint() {
  local url="$1"
  local http_code
  http_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "${url}" 2>/dev/null || echo "000")"
  if [[ "${http_code}" =~ ^2[0-9]{2}$ ]]; then
    return 0
  else
    return 1
  fi
}

overall_exit=0

if check_endpoint "${QDRANT_URL}"; then
  echo "qdrant:   OK"
else
  echo "qdrant:   FAIL"
  overall_exit=1
fi

if check_endpoint "${MEM0_MCP_URL}"; then
  echo "mem0-mcp: OK"
else
  echo "mem0-mcp: FAIL"
  overall_exit=1
fi

exit "${overall_exit}"
