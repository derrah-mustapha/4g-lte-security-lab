# Results: baseline profile

_generated 2026-11-12 17:08 UTC by scripts/run_experiments.sh_

## Analysis of baseline (S1-MME + S6a + S11 seen at the MME, GTP-U seen at the SGW-U)

### E1. Subscriber identity in the Attach Request (S1AP/NAS)
1 .... .001 = Type of identity: IMSI (1)
1 IMSI: 999700000000001

### E2. NAS algorithms chosen by the MME (Security Mode Command)
1 .000 .... = Type of ciphering algorithm: EPS encryption algorithm EEA0 (null ciphering algorithm) (0)
1 .... .010 = Type of integrity protection algorithm: EPS integrity algorithm 128-EIA2 (2)

### E3. Diameter S6a/Gx (HSS and PCRF control plane)
- readable Diameter frames (plain, port 3868) : 6
- Diameter-port TCP segments (3868 or TLS 5868): 10
- encrypted TLS application-data records      : 0
- distinct auth-vector secrets in clear        : 4 (RAND, XRES, AUTN, K_ASME; K_ASME present: yes)

### E4. GTP (S11 control, S1-U/S5-U user plane), not covered by any fix in this lab
- GTPv2-C messages carrying the IMSI in clear : 1
- user ICMP packets readable inside GTP-U     : 16

### E5. Rogue eNB (unauthorised node 10.20.2.66) tries to join the MME over S1-MME
```
11/12 17:08:52.568: [mme] INFO: eNB-S1 accepted[10.20.2.66] in master_sm module (../src/mme/mme-sm.c:108)
11/12 17:08:52.568: [mme] INFO: [Added] Number of eNBs is now 2 (../src/mme/mme-context.c:2842)
```
**Result: the MME accepted the rogue eNB and registered it as a second eNB.**

### E6. Can a UE reach the core network through the user plane?
UE address: 10.45.0.3
```
ping 10.20.1.11  (MME): reachable
ping 10.20.1.10  (HSS): reachable
ping 10.20.1.14  (UPF): reachable
tcp  10.20.1.2:27017 (MongoDB): OPEN (subscriber database reachable from the UE)
```

### E7. Performance through the UPF (dn-server 10.20.3.50, 5 MHz virtual radio)

| UE IP | RTT avg (ms) | TCP throughput (Mbit/s) |
|---|---|---|
| 10.45.0.3 | 31.724 | 8.5 |
