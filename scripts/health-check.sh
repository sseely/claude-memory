#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

overall_exit=0

echo "OpenMemory stack:"
if check_endpoint "${QDRANT_URL}"; then
  echo "  qdrant:          OK"
else
  echo "  qdrant:          FAIL"
  overall_exit=1
fi

if check_endpoint "${OPENMEMORY_URL}"; then
  echo "  openmemory-mcp:  OK"
else
  echo "  openmemory-mcp:  FAIL"
  overall_exit=1
fi

echo ""
echo "Code intelligence:"
if check_serena; then
  echo "  serena:          OK (uvx available)"
else
  echo "  serena:          NOT INSTALLED"
  overall_exit=1
fi

exit "${overall_exit}"
