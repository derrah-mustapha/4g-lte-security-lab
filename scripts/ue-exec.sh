#!/bin/bash
# Run a command inside the UE's network namespace (the srsUE image has no iperf3/nc).
# Adds the default route through the UE tunnel first, as a real phone has.
#   scripts/ue-exec.sh ping -I tun_srsue -c 3 10.20.3.50
set -euo pipefail
cd "$(dirname "$0")/.."
UE=$(docker compose ps -q ue)
exec docker run --rm --net "container:$UE" --cap-add NET_ADMIN --cap-add NET_RAW nicolaka/netshoot \
  sh -c 'ip route replace default dev tun_srsue 2>/dev/null; exec "$@"' _ "$@"
