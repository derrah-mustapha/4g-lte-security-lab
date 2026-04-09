#!/bin/bash
# Capture what an eavesdropper on the core network sees while the UE performs a fresh attach
# and sends a few packets.
#
#   scripts/capture.sh <label> [seconds]
#     captures/<label>.pcap            S1-MME (S1AP/NAS), S6a (Diameter), S11/S5 (GTPv2-C), seen at the MME
#     captures/<label>-userplane.pcap  S1-U / S5-U (GTP-U with the users' IP packets), seen at the SGW-U
#
# The sniffers are throw-away containers that join the MME / SGW-U network namespaces.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=${1:?usage: capture.sh <label> [seconds]}
SECS=${2:-30}
mkdir -p captures
rm -f "captures/$LABEL.pcap" "captures/$LABEL-userplane.pcap"

sniff() {  # name target-service outfile
  docker rm -f "$1" >/dev/null 2>&1 || true
  docker run -d --name "$1" --net "container:$(docker compose ps -q "$2")" --cap-add NET_RAW --cap-add NET_ADMIN \
    -v "$PWD/captures:/captures" nicolaka/netshoot tcpdump -U -i any -n -w "/captures/$3" >/dev/null
}
sniff lab-sniff-mme mme "$LABEL.pcap"
sniff lab-sniff-sgwu sgwu "$LABEL-userplane.pcap"
sleep 2

./scripts/reattach.sh "$SECS"                       # forces a fresh attach + default bearer
./scripts/ue-exec.sh ping -I tun_srsue -c 5 -W 2 10.20.3.50 >/dev/null 2>&1 || true

docker stop -t 3 lab-sniff-mme lab-sniff-sgwu >/dev/null
docker rm lab-sniff-mme lab-sniff-sgwu >/dev/null
docker run --rm -v "$PWD/captures:/c" nicolaka/netshoot chown "$(id -u):$(id -g)" "/c/$LABEL.pcap" "/c/$LABEL-userplane.pcap"
echo "captured -> captures/$LABEL.pcap ($(du -h "captures/$LABEL.pcap" | cut -f1)), captures/$LABEL-userplane.pcap ($(du -h "captures/$LABEL-userplane.pcap" | cut -f1))"
