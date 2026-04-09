#!/usr/bin/env python3
"""Generate the Open5GS EPC + srsRAN configs for the two lab profiles.

    baseline  - Open5GS defaults: null NAS ciphering allowed (EEA0/EIA0), Diameter
                (S6a, Gx) without TLS, no S1 allow-list, UE traffic can reach the core.
    hardened  - EEA0/EIA0 removed, Diameter over TLS, S1-MME allow-list on the MME,
                UE traffic blocked from the core networks (see scripts/*-start.sh).

The pristine upstream Open5GS configs live in config/open5gs/ and config/freeDiameter/
and are only read.  Output goes to config/profiles/<profile>/.
"""
import pathlib
import re
import shutil

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
UP_YAML = ROOT / "config" / "open5gs"
UP_FD = ROOT / "config" / "freeDiameter"
SRS = ROOT / "config" / "srsran"
OUT = ROOT / "config" / "profiles"

# ---- lab addressing -------------------------------------------------------
EPC, RAN = "10.20.1.", "10.20.2."        # docker networks "epc" and "ran" (both internal)
IP = {"mongo": 2, "hss": 10, "mme": 11, "sgwc": 12, "smf": 13, "upf": 14, "pcrf": 15, "sgwu": 16}
MME_S1 = RAN + "11"                        # S1-MME (S1AP / SCTP)
SGWU_S1U = RAN + "16"                      # S1-U and S5-U GTP-U endpoint of the SGW-U
UPF_S5U = RAN + "14"                       # S5-U GTP-U endpoint of the UPF
ENB, ROGUE, UE = RAN + "20", RAN + "66", RAN + "31"

PLMN = {"mcc": 999, "mnc": 70}
IMSI = "999700000000001"
K = "465B5CE8B199B49FAA5F0A2EE238A6BC"
OPC = "E8ED289DEBA952E4283B54E88E6183CA"
UE_POOL = {"subnet": "10.45.0.0/24", "gateway": "10.45.0.1", "dnn": "internet"}


def load(nf):
    return yaml.safe_load((UP_YAML / f"{nf}.yaml").read_text())


def bind(entries, ip):
    for e in entries or []:
        e.pop("dev", None)
        e["address"] = ip


def build(profile):
    hard = profile == "hardened"
    cfgs = {}
    for nf in ("hss", "mme", "sgwc", "sgwu", "smf", "upf", "pcrf"):
        c = load(nf)
        body = c[nf]
        ip = EPC + str(IP[nf])
        if "db_uri" in c:
            c["db_uri"] = "mongodb://mongo/open5gs"
        if "metrics" in body:
            bind(body["metrics"].get("server"), ip)

        if nf == "mme":
            bind(body["s1ap"]["server"], MME_S1)
            bind(body["gtpc"]["server"], ip)
            body["gtpc"]["client"] = {"sgwc": [{"address": EPC + str(IP["sgwc"]), "tac": 1}],
                                      "smf": [{"address": EPC + str(IP["smf"]), "tac": 1}]}
            body["security"] = (
                {"integrity_order": ["EIA2", "EIA1"], "ciphering_order": ["EEA2", "EEA1"]} if hard else
                {"integrity_order": ["EIA2", "EIA1", "EIA0"], "ciphering_order": ["EEA0", "EEA1", "EEA2"]})
        if nf == "sgwc":
            bind(body["gtpc"]["server"], ip)
            bind(body["pfcp"]["server"], ip)
            body["pfcp"]["client"] = {"sgwu": [{"address": EPC + str(IP["sgwu"]), "tac": 1}]}
        if nf == "sgwu":
            bind(body["pfcp"]["server"], ip)
            bind(body["gtpu"]["server"], SGWU_S1U)
        if nf == "smf":
            # EPC-only deployment: no NRF/SCP, so the SBI block is removed (otherwise the SMF
            # tries to register with an NRF and aborts)
            body.pop("sbi", None)
            bind(body["pfcp"]["server"], ip)
            body["pfcp"]["client"] = {"upf": [{"address": EPC + str(IP["upf"])}]}
            bind(body["gtpc"]["server"], ip)
            bind(body["gtpu"]["server"], ip)
            body["session"] = [dict(UE_POOL)]
            body["dns"] = ["8.8.8.8", "1.1.1.1"]
        if nf == "upf":
            bind(body["pfcp"]["server"], ip)
            body["pfcp"].pop("client", None)
            bind(body["gtpu"]["server"], UPF_S5U)
            body["session"] = [dict(UE_POOL)]
        cfgs[nf] = c
    return cfgs


def freediameter(profile):
    """Copy the Diameter configs; the hardened profile drops 'No_TLS' so S6a and Gx use TLS."""
    files = {}
    for conf in sorted(UP_FD.glob("*.conf")):
        text = conf.read_text()
        if profile == "hardened":
            text = re.sub(r"\s*No_TLS;", "", text)
        files[conf.name] = text
    return files


# ---- srsRAN ----------------------------------------------------------------
def enb_conf(ip, enb_id, tx_port, rx_ue):
    return f"""[enb]
enb_id = {enb_id}
mcc = {PLMN['mcc']}
mnc = {PLMN['mnc']}
mme_addr = {MME_S1}
gtp_bind_addr = {ip}
s1c_bind_addr = {ip}
s1c_bind_port = 0
n_prb = 25

[enb_files]
sib_config = /cfg/sib.conf
rr_config = /cfg/rr.conf
rb_config = /cfg/rb.conf

[rf]
tx_gain = 80
rx_gain = 40
device_name = zmq
device_args = fail_on_disconnect=false,tx_port=tcp://*:{tx_port},rx_port=tcp://{rx_ue},id=enb,base_srate=11.52e6

[log]
all_level = warning
filename = /tmp/enb.log
file_max_size = -1

[gui]
enable = false
"""


def ue_conf():
    return f"""[rf]
freq_offset = 0
tx_gain = 50
device_name = zmq
device_args = tx_port=tcp://*:2001,rx_port=tcp://{ENB}:2000,id=ue,base_srate=11.52e6

[rat.eutra]
dl_earfcn = 3350
nof_carriers = 1

[rat.nr]
nof_carriers = 0

[usim]
mode = soft
algo = milenage
opc = {OPC}
k = {K}
imsi = {IMSI}
imei = 353490069873319

[nas]
apn = internet
apn_protocol = ipv4

[log]
all_level = warning
filename = /tmp/ue.log
file_max_size = -1

[gui]
enable = false
"""


def main():
    for profile in ("baseline", "hardened"):
        out = OUT / profile
        if out.exists():
            shutil.rmtree(out)
        (out / "freeDiameter").mkdir(parents=True)
        for nf, cfg in build(profile).items():
            (out / f"{nf}.yaml").write_text(yaml.safe_dump(cfg, sort_keys=False))
        for name, text in freediameter(profile).items():
            (out / "freeDiameter" / name).write_text(text)
        for pem in UP_FD.glob("*.pem"):
            shutil.copy(pem, out / "freeDiameter" / pem.name)
        for f in ("sib.conf", "rb.conf"):
            shutil.copy(SRS / f, out / f)
        (out / "rr.conf").write_text((SRS / "rr.conf").read_text().replace("${TAC}", "0x0001;"))
        (out / "enb.conf").write_text(enb_conf(ENB, "0x19B", 2000, UE + ":2001"))
        (out / "rogue-enb.conf").write_text(enb_conf(ROGUE, "0x19C", 2002, UE + ":2003"))
        (out / "ue.conf").write_text(ue_conf())
        print("generated", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
