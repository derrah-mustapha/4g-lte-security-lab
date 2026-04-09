#!/bin/bash
# Recreate the radio pair (eNB + UE: the ZeroMQ virtual radio only re-syncs when both are
# recreated) and wait until the UE has attached again (fresh logs, fresh attach).
#   scripts/reattach.sh [max_seconds]
set -euo pipefail
cd "$(dirname "$0")/.."
MAX=${1:-90}
docker compose up -d --force-recreate --no-deps enb ue >/dev/null 2>&1
for _ in $(seq 1 "$MAX"); do
  if docker compose logs ue 2>&1 | grep -q 'Network attach successful'; then
    sleep 3; exit 0
  fi
  sleep 1
done
echo "UE did not attach within ${MAX}s" >&2; exit 1
