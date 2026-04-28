# Threat model (STRIDE) of the 4G lab

Scope: the EPC and its interfaces as deployed in `docker-compose.yml`. Attacker models:
(A1) a passive observer on a core or RAN network segment, (A2) an active host on the RAN segment,
(A3) a compromised or malicious subscriber device.

| Interface / asset | STRIDE | Threat | Lab evidence | Mitigation in `hardened` | Residual risk |
|---|---|---|---|---|---|
| Uu: subscriber identity | **I**nformation disclosure | Passive observer reads the IMSI from the Attach Request | E1: baseline and hardened pcaps both show `IMSI: 999700000000001` | None possible in 4G | Inherent to LTE; 5G SUCI fixes it (see the 5G lab) |
| S1/NAS: confidentiality | **I** | Signalling sent unencrypted (EEA0) | E2: Security Mode Command selects EEA0 | Remove EEA0/EIA0 from MME lists | UEs supporting only EEA0 can no longer attach (intended) |
| S6a/Gx Diameter | **I**, **S** | A1 reads RAND/XRES/AUTN and K_ASME; a host could speak Diameter as an MME | E3: 6 readable frames, 4 distinct secrets | Diameter over TLS (CA-signed node certs) | Test certificates; no revocation/rotation; Diameter peers are statically configured |
| S1-MME: eNB admission | **S**poofing, **T**ampering | Unauthorised node completes S1 setup | E5: rogue eNB registered as eNB #2 | MME source allow-list | Address spoofing on the same L2 segment; needs IPsec/mutual authentication |
| S11 / S5-C / S1-U / S5-U (GTP) | **I**, **T** | Observer reads IMSI in GTPv2-C and user packets in GTP-U; injector forges GTP-U | E4: IMSI and ICMP readable in both profiles | None in this lab | Needs IPsec (3GPP NDS/IP) or equivalent |
| User plane to core | **E**levation of privilege | A subscriber device reaches core nodes and the subscriber DB through the UPF | E6: UE pings MME/HSS/UPF and opens MongoDB | UPF drops ogstun to epc/ran forwarding and input | IP-level only; no per-subscriber policy |
| Subscriber database (MongoDB) | **T**, **I** | Anyone on `epc` can read K/OPc | E6 shows it was reachable from a UE in baseline | Network isolation (UE blocked) | No DB authentication or encryption at rest |
| UE credentials | **S** | Stolen K/OPc lets an attacker impersonate a subscriber | Lab keys are well-known test values | Out of scope for the core | Real deployments keep K/OPc in a SIM/HSM |
| Availability of MME/HSS | **D**enial of service | Floods of attaches or Diameter requests | Not tested | None | Open item |

## Out of scope / not tested

Radio-layer attacks, paging/TAU attacks, 2G/3G downgrade, denial-of-service, roaming interfaces (S8, Diameter
agents/DEA), PFCP (N4 equivalent) authentication, and GTP-U encryption. PFCP between SGW-C/SGW-U and SMF/UPF is
plain UDP in both profiles.
