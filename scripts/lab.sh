#!/bin/bash
# Convenience wrapper around docker compose.
#
#   scripts/lab.sh up baseline|hardened   start the lab with that profile (recreates it)
#   scripts/lab.sh down                   stop and remove the lab (keeps the subscriber DB)
#   scripts/lab.sh status                 container state + UE attach state
#   scripts/lab.sh rogue                  start the unauthorised eNB (attack demo)
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  up)
    PROFILE=${2:?baseline|hardened}
    python3 scripts/gen_configs.py >/dev/null
    export PROFILE
    if [ "$PROFILE" = hardened ]; then
      export CORE_ISOLATION=yes S1_ALLOW=10.20.2.20     # UPF core isolation + MME S1 allow-list
    fi
    docker compose --profile rogue down --remove-orphans >/dev/null 2>&1 || true
    docker compose up -d mongo hss pcrf mme sgwc sgwu smf upf dn-server
    echo "waiting for the EPC (Diameter links HSS-MME and SMF-PCRF)..."
    sleep 10
    ./scripts/provision.sh >/dev/null
    for _ in $(seq 1 150); do
      if docker compose logs hss 2>&1 | grep -q "CONNECTED TO 'mme.gradiant'" && \
         docker compose logs smf 2>&1 | grep -q "CONNECTED TO 'pcrf.gradiant'"; then break; fi
      sleep 2
    done
    docker compose up -d enb ue
    sleep 25
    "$0" status
    ;;
  down)
    docker compose --profile rogue down --remove-orphans
    ;;
  status)
    docker compose ps --format 'table {{.Name}}\t{{.Status}}'
    printf 'ue: '
    docker compose exec -T ue ip -4 -o addr show tun_srsue 2>/dev/null | awk '{print "tun_srsue " $4}' || true
    docker compose logs ue 2>&1 | grep -E 'Network attach successful|Attach reject|Found Cell' | tail -2 || true
    ;;
  rogue)
    docker compose --profile rogue up rogue-enb
    ;;
  *)
    sed -n '2,8p' "$0"; exit 1;;
esac
