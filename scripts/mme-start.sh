#!/bin/bash
# MME start-up. S1AP/SCTP on S1-MME has no authentication of its own, so the hardened
# profile restricts who may talk to the MME: only the provisioned eNB address is allowed,
# every other SCTP packet is dropped (matched by protocol number 132, no xt_sctp module needed).
set -e

if [ -n "${S1_ALLOW:-}" ]; then
  iptables -A INPUT -p 132 -s "$S1_ALLOW" -j ACCEPT
  iptables -A INPUT -p 132 -j DROP
  echo "S1 firewall: SCTP accepted only from $S1_ALLOW"
fi

exec su -s /bin/bash open5gs -c "exec open5gs-mmed -c /opt/open5gs/etc/open5gs/mme.yaml"
