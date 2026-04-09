#!/bin/bash
# Summarise the security-relevant content of the captures made with capture.sh.
#   scripts/analyze_pcap.sh <label>
# tshark runs in a container (nicolaka/netshoot); nothing needs installing on the host.
set -euo pipefail
cd "$(dirname "$0")/.."
LABEL=${1:?usage: analyze_pcap.sh <label>}
T() { f=$1; shift; docker run --rm -v "$PWD/captures:/c" nicolaka/netshoot tshark -r "/c/$f" "$@" 2>/dev/null; }
MME="$LABEL.pcap"; UP="$LABEL-userplane.pcap"

echo "## Analysis of $LABEL (S1-MME + S6a + S11 seen at the MME, GTP-U seen at the SGW-U)"
echo
echo "### E1. Subscriber identity in the Attach Request (S1AP/NAS)"
T "$MME" -Y 'nas-eps.nas_msg_emm_type == 0x41' -V | grep -E '^\s+(IMSI|GUTI)|Type of identity' \
  | grep -v Association | sed 's/^ *//' | sort | uniq -c | sed 's/^ *//'
echo
echo "### E2. NAS algorithms chosen by the MME (Security Mode Command)"
T "$MME" -Y 'nas-eps.nas_msg_emm_type == 0x5d' -V | grep -E 'Type of (ciphering|integrity)' | sed 's/^ *//' | sort | uniq -c | sed 's/^ *//'
echo
echo "### E3. Diameter S6a/Gx (HSS and PCRF control plane)"
DIAM=$(T "$MME" -Y diameter | wc -l) || true
TLS=$(T "$MME" -Y 'tcp.port==3868 || tcp.port==5868' | wc -l) || true
TLSAPP=$(T "$MME" -Y 'tls.record.content_type == 23' | wc -l) || true
VEC=$(T "$MME" -Y diameter -V | grep -E '^\s+(RAND|XRES|AUTN|KASME):' | sed 's/^ *//' | sort -u | wc -l) || true
KAS=$(T "$MME" -Y diameter -V | grep -E '^\s+KASME:' | sort -u | wc -l) || true
echo "- readable Diameter frames (plain, port 3868) : $DIAM"
echo "- Diameter-port TCP segments (3868 or TLS 5868): $TLS"
echo "- encrypted TLS application-data records      : $TLSAPP"
echo "- distinct auth-vector secrets in clear        : $VEC (RAND, XRES, AUTN, K_ASME; K_ASME present: $([ "$KAS" -gt 0 ] && echo yes || echo no))"
echo
echo "### E4. GTP (S11 control, S1-U/S5-U user plane), not covered by any fix in this lab"
GTPC=$(T "$MME" -Y 'gtpv2 && e212.imsi' | wc -l) || true
GTPU=$(T "$UP" -Y 'gtp && icmp' | wc -l) || true
echo "- GTPv2-C messages carrying the IMSI in clear : $GTPC"
echo "- user ICMP packets readable inside GTP-U     : $GTPU"
