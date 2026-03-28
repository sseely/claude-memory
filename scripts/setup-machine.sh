#!/usr/bin/env bash
set -euo pipefail

# One-time machine setup for the claude-memory system.
# Installs MCP config, launchd agent, and verifies prerequisites.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLIST_NAME="com.claude-memory.mem0"
PLIST_SRC="${PROJECT_ROOT}/launchd/${PLIST_NAME}.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"
MCP_CONFIG="${HOME}/.claude/.mcp.json"
LOG_FILE="${HOME}/Library/Logs/claude-memory-mem0.log"

echo "=== claude-memory machine setup ==="
echo ""

# --- Prerequisites ---

echo "Checking prerequisites..."
ok=true

if ! command -v docker &>/dev/null; then
  echo "  FAIL: docker not found. Install Docker Desktop."
  ok=false
else
  echo "  OK: docker"
fi

if ! command -v uvx &>/dev/null; then
  echo "  FAIL: uvx not found. Run: brew install uv"
  ok=false
else
  echo "  OK: uvx ($(uvx --version 2>/dev/null | head -1))"
fi

if [[ "${ok}" != "true" ]]; then
  echo ""
  echo "Fix missing prerequisites and re-run."
  exit 1
fi

# --- .env ---

echo ""
if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
  echo "Creating .env from .env.example..."
  cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
  echo "  Defaults use Ollama — ensure ollama is running with llama3.1 and nomic-embed-text"
else
  echo ".env already exists."
fi

# --- MCP config ---

echo ""
echo "Configuring MCP servers..."

if [[ -f "${MCP_CONFIG}" ]]; then
  echo "  ${MCP_CONFIG} already exists — skipping."
  echo "  Verify it contains mem0 and serena entries."
else
  mkdir -p "$(dirname "${MCP_CONFIG}")"
  cat > "${MCP_CONFIG}" << 'MCPEOF'
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
MCPEOF
  echo "  Created ${MCP_CONFIG}"
fi

# --- launchd ---

echo ""
echo "Installing launchd agent..."

if launchctl list "${PLIST_NAME}" &>/dev/null; then
  echo "  Unloading existing agent..."
  launchctl bootout "gui/$(id -u)" "${PLIST_DST}" 2>/dev/null || true
fi

sed -e "s|__PROJECT_ROOT__|${PROJECT_ROOT}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "${PLIST_SRC}" > "${PLIST_DST}"
launchctl bootstrap "gui/$(id -u)" "${PLIST_DST}"
echo "  Installed and loaded ${PLIST_NAME}"
echo "  Logs: ${LOG_FILE}"

# --- Verify ---

echo ""
echo "Starting Mem0 stack..."
"${SCRIPT_DIR}/start.sh"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Remaining manual steps:"
echo "  1. Create .serena/project.yml in repos you want code intelligence for"
echo "  2. Restart Claude Code to pick up MCP config"
