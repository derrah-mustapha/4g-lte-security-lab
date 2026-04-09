#!/bin/bash
# Insert the lab subscriber into the Open5GS database (MongoDB), read by the HSS.
# Idempotent: an existing subscriber with the same IMSI is replaced.
set -euo pipefail
cd "$(dirname "$0")/.."

K=465B5CE8B199B49FAA5F0A2EE238A6BC
OPC=E8ED289DEBA952E4283B54E88E6183CA
IMSI=999700000000001

docker compose exec -T mongo mongosh --quiet open5gs <<EOF
db.subscribers.deleteMany({imsi: "$IMSI"});
db.subscribers.insertOne({
  imsi: "$IMSI",
  security: { k: "$K", opc: "$OPC", amf: "8000", sqn: NumberLong(0) },
  ambr: { downlink: { value: 1, unit: 3 }, uplink: { value: 1, unit: 3 } },
  slice: [{
    sst: 1, default_indicator: true,
    session: [{
      name: "internet", type: 1,
      qos: { index: 9, arp: { priority_level: 8, pre_emption_capability: 1, pre_emption_vulnerability: 1 } },
      ambr: { downlink: { value: 1, unit: 3 }, uplink: { value: 1, unit: 3 } }
    }]
  }],
  access_restriction_data: 32, subscriber_status: 0, network_access_mode: 0,
  subscribed_rau_tau_timer: 12, schema_version: 1
});
print("subscribers: " + db.subscribers.countDocuments())
EOF
