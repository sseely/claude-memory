#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

QDRANT_URL="http://localhost:6333/healthz"
MEM0_MCP_URL="http://localhost:8050/sse"
POLL_INTERVAL=5
TIMEOUT=120

cd "${PROJECT_ROOT}"

echo "Starting docker compose services..."
docker compose up -d

check_endpoint() {
  local name="$1"
  local url="$2"
  local http_code
  http_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "${url}" 2>/dev/null || echo "000")"
  if [[ "${http_code}" =~ ^2[0-9]{2}$ ]]; then
    return 0
  else
    return 1
  fi
}

wait_for_service() {
  local name="$1"
  local url="$2"
  local deadline=$(( $(date +%s) + TIMEOUT ))

  echo "Waiting for ${name} at ${url}..."
  while [[ "$(date +%s)" -lt "${deadline}" ]]; do
    if check_endpoint "${name}" "${url}"; then
      echo "  ${name}: OK"
      return 0
    fi
    sleep "${POLL_INTERVAL}"
  done

  echo "  ${name}: TIMEOUT after ${TIMEOUT}s"
  return 1
}

overall_exit=0

wait_for_service "qdrant"   "${QDRANT_URL}"   || overall_exit=1
wait_for_service "mem0-mcp" "${MEM0_MCP_URL}" || overall_exit=1

echo ""
echo "Service status:"
if check_endpoint "qdrant"   "${QDRANT_URL}";   then echo "  qdrant:   OK"; else echo "  qdrant:   FAIL"; overall_exit=1; fi
if check_endpoint "mem0-mcp" "${MEM0_MCP_URL}"; then echo "  mem0-mcp: OK"; else echo "  mem0-mcp: FAIL"; overall_exit=1; fi

exit "${overall_exit}"
