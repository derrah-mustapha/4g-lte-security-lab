#!/bin/bash
# UPF (PGW-U) start-up: create the ogstun device for the UE pool, NAT it towards every
# network the UPF is attached to, then run the Open5GS UPF.
# Hardened profile (CORE_ISOLATION=yes): UE traffic may only leave through the SGi
# (data network). It cannot be forwarded to, or terminate at, the core/radio networks.
set -e

ip tuntap add name ogstun mode tun 2>/dev/null || true
ip addr add 10.45.0.1/24 dev ogstun 2>/dev/null || true
ip link set ogstun up

iptables -t nat -A POSTROUTING -s 10.45.0.0/24 ! -o ogstun -j MASQUERADE

if [ "${CORE_ISOLATION:-no}" = "yes" ]; then
  iptables -A FORWARD -i ogstun -d 10.20.1.0/24 -j DROP     # epc
  iptables -A FORWARD -i ogstun -d 10.20.2.0/24 -j DROP     # ran
  iptables -A INPUT   -i ogstun -j DROP                     # UPF itself
  echo "core isolation: ON (UE traffic confined to the data network)"
fi

exec open5gs-upfd -c /opt/open5gs/etc/open5gs/upf.yaml
