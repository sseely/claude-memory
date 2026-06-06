#!/bin/sh
set -e

echo "Warming up embedding model: ${EMBEDDING_MODEL:-nomic-embed-text-v2-moe}"
python3 /usr/src/openmemory/warmup.py

exec uvicorn main:app --host 0.0.0.0 --port 8765 --workers 1
