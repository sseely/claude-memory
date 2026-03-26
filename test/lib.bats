#!/usr/bin/env bats
# Tests for scripts/lib.sh
# Requires: bats-core (https://github.com/bats-core/bats-core)

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  source "${PROJECT_ROOT}/scripts/lib.sh"
}

@test "QDRANT_URL is set" {
  [ -n "${QDRANT_URL}" ]
  [[ "${QDRANT_URL}" == *"6333"* ]]
}

@test "MEM0_MCP_URL is set" {
  [ -n "${MEM0_MCP_URL}" ]
  [[ "${MEM0_MCP_URL}" == *"8050"* ]]
}

@test "check_endpoint returns 0 for HTTP 200" {
  curl() { printf "200"; }
  export -f curl
  run check_endpoint "http://localhost:6333/healthz"
  [ "$status" -eq 0 ]
}

@test "check_endpoint returns 1 for HTTP 500" {
  curl() { printf "500"; }
  export -f curl
  run check_endpoint "http://localhost:6333/healthz"
  [ "$status" -eq 1 ]
}

@test "check_endpoint returns 1 for connection failure" {
  curl() { printf "000"; return 1; }
  export -f curl
  run check_endpoint "http://localhost:6333/healthz"
  [ "$status" -eq 1 ]
}

@test "check_endpoint accepts HTTP 204" {
  curl() { printf "204"; }
  export -f curl
  run check_endpoint "http://localhost:8050/sse"
  [ "$status" -eq 0 ]
}
