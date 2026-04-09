#!/bin/bash
# Run experiments E1-E7 against the running lab and write results/<profile>.md
#   scripts/lab.sh up <profile> && scripts/run_experiments.sh <profile>
set -euo pipefail
cd "$(dirname "$0")/.."
PROFILE=${1:?usage: run_experiments.sh baseline|hardened}
export PROFILE
[ "$PROFILE" = hardened ] && export CORE_ISOLATION=yes S1_ALLOW=10.20.2.20
mkdir -p results
OUT="results/$PROFILE.md"
UEX=./scripts/ue-exec.sh

{
echo "# Results: $PROFILE profile"
echo
echo "_generated $(date -u '+%Y-%m-%d %H:%M UTC') by scripts/run_experiments.sh_"
echo
./scripts/capture.sh "$PROFILE" 90 >&2
./scripts/analyze_pcap.sh "$PROFILE"

echo
echo "### E5. Rogue eNB (unauthorised node 10.20.2.66) tries to join the MME over S1-MME"
docker compose --profile rogue up -d rogue-enb >/dev/null 2>&1
sleep 15
SINCE=$(docker compose logs --since 40s mme 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'eNB-S1 accepted\[10\.20\.2\.66\] in master|Number of eNBs' | sed 's/^[^|]*| //' | head -3 || true)
if [ -n "$SINCE" ]; then
  echo '```'; echo "$SINCE"; echo '```'
  echo "**Result: the MME accepted the rogue eNB and registered it as a second eNB.**"
else
  echo "**Result: the MME never saw the rogue eNB (S1 allow-list dropped its SCTP packets).**"
fi
docker compose --profile rogue rm -sf rogue-enb >/dev/null 2>&1 || true

echo
echo "### E6. Can a UE reach the core network through the user plane?"
UEIP=$(docker compose exec -T ue ip -4 -o addr show tun_srsue | awk '{print $4}' | cut -d/ -f1)
echo "UE address: $UEIP"
echo '```'
for tgt in "10.20.1.11 MME" "10.20.1.10 HSS" "10.20.1.14 UPF"; do
  set -- $tgt
  if $UEX ping -I tun_srsue -c 3 -W 2 "$1" >/dev/null 2>&1; then r="reachable"; else r="BLOCKED"; fi
  printf 'ping %-11s (%s): %s\n' "$1" "$2" "$r"
done
if $UEX nc -zv -w 4 10.20.1.2 27017 >/dev/null 2>&1; then r="OPEN (subscriber database reachable from the UE)"; else r="BLOCKED"; fi
printf 'tcp  10.20.1.2:27017 (MongoDB): %s\n' "$r"
echo '```'

echo
echo "### E7. Performance through the UPF (dn-server 10.20.3.50, 5 MHz virtual radio)"
RTT=$($UEX ping -I tun_srsue -c 10 -W 2 10.20.3.50 | awk -F'/' '/^rtt/{print $5}')
TPUT=$($UEX iperf3 -B "$UEIP" -c 10.20.3.50 -t 8 -J | python3 -c "import sys,json;d=json.load(sys.stdin);print(round(d['end']['sum_received']['bits_per_second']/1e6,1))")
echo
echo "| UE IP | RTT avg (ms) | TCP throughput (Mbit/s) |"
echo "|---|---|---|"
echo "| $UEIP | $RTT | $TPUT |"
} > "$OUT"
echo "wrote $OUT"
