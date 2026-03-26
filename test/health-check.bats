#!/usr/bin/env bats
# Tests for scripts/health-check.sh
# Requires: bats-core (https://github.com/bats-core/bats-core)

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "health-check exits 0 when all endpoints return 200" {
  # Stub curl to always return 200
  curl() { echo "200"; }
  export -f curl
  run "${PROJECT_ROOT}/scripts/health-check.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"qdrant:   OK"* ]]
  [[ "$output" == *"mem0-mcp: OK"* ]]
}

@test "health-check exits non-zero when qdrant is down" {
  # Stub curl to fail for qdrant, succeed for mem0-mcp
  curl() {
    if [[ "$*" == *"6333"* ]]; then echo "000"; return 1; fi
    echo "200"
  }
  export -f curl
  run "${PROJECT_ROOT}/scripts/health-check.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"qdrant:   FAIL"* ]]
}

@test "health-check exits non-zero when mem0-mcp is down" {
  curl() {
    if [[ "$*" == *"8050"* ]]; then echo "000"; return 1; fi
    echo "200"
  }
  export -f curl
  run "${PROJECT_ROOT}/scripts/health-check.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"mem0-mcp: FAIL"* ]]
}

@test "health-check exits non-zero when all endpoints are down" {
  curl() { echo "000"; return 1; }
  export -f curl
  run "${PROJECT_ROOT}/scripts/health-check.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"qdrant:   FAIL"* ]]
  [[ "$output" == *"mem0-mcp: FAIL"* ]]
}
