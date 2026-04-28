# Results: hardened profile

_generated 2026-11-12 17:00 UTC by scripts/run_experiments.sh_

## Analysis of hardened (S1-MME + S6a + S11 seen at the MME, GTP-U seen at the SGW-U)

### E1. Subscriber identity in the Attach Request (S1AP/NAS)
1 .... .001 = Type of identity: IMSI (1)
1 IMSI: 999700000000001

### E2. NAS algorithms chosen by the MME (Security Mode Command)
1 .010 .... = Type of ciphering algorithm: EPS encryption algorithm 128-EEA2 (2)
1 .... .010 = Type of integrity protection algorithm: EPS integrity algorithm 128-EIA2 (2)

### E3. Diameter S6a/Gx (HSS and PCRF control plane)
- readable Diameter frames (plain, port 3868) : 0
- Diameter-port TCP segments (3868 or TLS 5868): 10
- encrypted TLS application-data records      : 6
- distinct auth-vector secrets in clear        : 0 (RAND, XRES, AUTN, K_ASME; K_ASME present: no)

### E4. GTP (S11 control, S1-U/S5-U user plane), not covered by any fix in this lab
- GTPv2-C messages carrying the IMSI in clear : 1
- user ICMP packets readable inside GTP-U     : 16

### E5. Rogue eNB (unauthorised node 10.20.2.66) tries to join the MME over S1-MME
**Result: the MME never saw the rogue eNB (S1 allow-list dropped its SCTP packets).**

### E6. Can a UE reach the core network through the user plane?
UE address: 10.45.0.5
```
ping 10.20.1.11  (MME): BLOCKED
ping 10.20.1.10  (HSS): BLOCKED
ping 10.20.1.14  (UPF): BLOCKED
tcp  10.20.1.2:27017 (MongoDB): BLOCKED
```

### E7. Performance through the UPF (dn-server 10.20.3.50, 5 MHz virtual radio)

| UE IP | RTT avg (ms) | TCP throughput (Mbit/s) |
|---|---|---|
| 10.45.0.5 | 28.211 | 8.5 |
