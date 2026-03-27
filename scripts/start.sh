#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

POLL_INTERVAL="${POLL_INTERVAL:-5}"
TIMEOUT="${TIMEOUT:-120}"

cd "${PROJECT_ROOT}"

# --- Mem0 stack (Docker) ---

echo "Starting docker compose services..."
if ! docker compose up -d; then
  echo "ERROR: docker compose startup failed" >&2
  exit 1
fi

wait_for_service() {
  local name="$1"
  local url="$2"
  local deadline=$(( $(date +%s) + TIMEOUT ))

  while [[ "$(date +%s)" -lt "${deadline}" ]]; do
    if check_endpoint "${url}"; then
      echo "  ${name}: OK"
      return 0
    fi
    sleep "${POLL_INTERVAL}"
  done

  echo "  ${name}: TIMEOUT after ${TIMEOUT}s" >&2
  return 1
}

echo "Waiting for Mem0 stack..."

qdrant_ok=0
mcp_ok=0

wait_for_service "qdrant" "${QDRANT_URL}" &
qdrant_pid=$!

wait_for_service "mem0-mcp" "${MEM0_MCP_URL}" &
mcp_pid=$!

wait "${qdrant_pid}" || qdrant_ok=1
wait "${mcp_pid}" || mcp_ok=1

# --- Serena (local, stdio) ---

echo ""
echo "Checking Serena..."
if check_serena; then
  echo "  serena: OK (uvx available)"
else
  echo "  serena: NOT INSTALLED"
  echo "  Install: pip install uv && uvx --from git+https://github.com/oraios/serena serena --help"
  qdrant_ok=1
fi

overall_exit=$(( qdrant_ok | mcp_ok ))

echo ""
if [[ "${overall_exit}" -eq 0 ]]; then
  echo "All services ready."
else
  echo "Some services failed. Check output above."
fi

exit "${overall_exit}"
