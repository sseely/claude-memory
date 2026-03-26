#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

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
