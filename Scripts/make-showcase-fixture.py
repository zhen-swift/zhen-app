#!/usr/bin/env python3 -I
"""make-showcase-fixture.py — the invented network the App Store and README captures show.

Usage:
  Scripts/make-showcase-fixture.py > Zhen/Fixtures/showcase-network.json
  Scripts/make-showcase-fixture.py --check Zhen/Fixtures/showcase-network.json

`home-network.json` is a real home network, anonymised: right for tests, because its shape
was measured, and wrong for marketing, because that network leaves most of its devices
unnamed and none with a vendor. This network was never scanned. It is written here, as a
table, and `-ShowcaseData` loads it.

Nothing in it identifies anyone: universal MACs are 00:00:5E:00:53:nn (RFC 7042
documentation), private ones are synthetic, every address is 192.168.50.x, and the names
are generic. The vendors are the labels an OUI lookup would print for that kind of device.

The table states what was observed: names, vendor, TTL, ports, how a host was found. What
zhen-core derives from those is computed, by core's own rules, so a hand edit cannot
leave a device claiming an identification its evidence does not support:

| Field                    | Rule (zhen-core 0.7.0)                                         |
|--------------------------|----------------------------------------------------------------|
| identification_evidence  | IdentificationEvidence(names:vendor:ttl:), Model/Device.swift  |
| identification           | Identification(evidence:)                                      |
| identity_stability       | the strongest identity key: universal MAC, Bonjour instance or |
|                          | DHCP name, private MAC, else the lease                         |

`ShowcaseFixtureTests` checks the same rules against core itself, and `--check` fails when
the committed JSON is not this script's output.
"""
import json
import sys
import uuid

NETWORK = "192.168.50"
EPOCH_MS = 1_767_268_800_000  # 2026-01-01T12:00:00Z, the home capture's epoch
RUN_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, "zhen-app/fixture/showcase-network"))
HOME = "Zhen/Fixtures/home-network.json"

PRIORITY = {"administrative": 0, "mdns": 1, "ssdp": 2, "netbios": 3, "dns": 4}
SELF_SUFFICIENT = {"administrative", "mdns", "ssdp"}


def http(banner="HTTP/1.1 200 OK"):
    return {"name": "http", "evidence": "banner", "banner": banner}


def https(subject):
    return {"name": "https", "evidence": "tls_certificate", "tls_subject": subject}


# One row per device, in address order. `mac` is "doc" (00:00:5E:00:53:<host>) or
# "private" (synthetic, locally administered); `v6` adds the link-local address that host
# would hold. Names are (source, value, model, rank); rank orders one source's answers.
# Roles in the 48 hours of history are given by address in FixtureNetwork.Dataset.
DEVICES = [
    dict(host=1, mac="doc", v6=True, vendor="Netgear", ttl=64, via=["probe_reply"],
         names=[("ssdp", "Home Gateway", "RAX50", 1)],
         ports=[(53, None), (80, http()), (443, https("Home Gateway"))], rtt=2.1),
    dict(host=10, mac="doc", v6=True, vendor="Apple", ttl=64, via=["probe_reply"],
         names=[("mdns", "Living Room", "AppleTV14,1", 1), ("mdns", "Living Room", "AppleTV14,1", 3),
                ("mdns", "Living Room", None, 16)],
         ports=[(7000, http("AirTunes/870.14.1"))], rtt=4.8),
    dict(host=12, mac="doc", v6=True, vendor="Apple", ttl=64, via=["probe_reply"],
         names=[("mdns", "Kitchen", "AudioAccessory6,1", 1), ("mdns", "Kitchen", None, 16)],
         ports=[(7000, http("AirTunes/870.14.1"))], rtt=6.3),
    dict(host=14, mac="doc", v6=False, vendor="Sonos", ttl=64, via=["probe_reply"],
         names=[("ssdp", "Bedroom", "Sonos One", 1)],
         ports=[(1400, http())], rtt=7.9),
    dict(host=20, mac="private", v6=True, vendor=None, ttl=64, via=["probe_reply"],
         names=[("mdns", "Maya’s MacBook Air", "Mac15,12", 1)], ports=[], rtt=3.4),
    dict(host=21, mac="private", v6=True, vendor=None, ttl=64, via=["probe_reply", "neighbor_table"],
         names=[("mdns", "Maya’s iPhone", "iPhone16,2", 1)], ports=[], rtt=38.6),
    dict(host=30, mac="doc", v6=False, vendor="HP", ttl=64, via=["probe_reply"],
         names=[("mdns", "Office Printer", "LaserJet MFP M234dw", 1),
                ("ssdp", "HP LaserJet MFP M234dw", "LaserJet MFP M234dw", 1)],
         ports=[(80, http()), (631, None), (9100, None)], rtt=9.2),
    dict(host=32, mac="doc", v6=True, vendor="Synology", ttl=64, via=["probe_reply"],
         names=[("mdns", "Archive", "DS224+", 1)],
         ports=[(443, https("Archive")), (445, None), (5000, http())], rtt=1.7),
    dict(host=35, mac="doc", v6=False, vendor="Signify", ttl=64, via=["probe_reply"],
         names=[("mdns", "Hue Bridge", "BSB002", 1)],
         ports=[(80, http()), (443, https("Hue Bridge"))], rtt=5.5),
    dict(host=40, mac="doc", v6=False, vendor="Nintendo", ttl=64, via=["probe_reply"],
         names=[], ports=[], rtt=24.0),
    dict(host=41, mac="doc", v6=False, vendor="Samsung", ttl=64, via=["probe_reply"],
         names=[("ssdp", "[TV] Samsung Q80 Series", "QN55Q80C", 1)],
         ports=[(8001, None), (8002, None)], rtt=11.4),
    dict(host=50, mac="doc", v6=False, vendor="Raspberry Pi", ttl=64, via=["probe_reply"],
         names=[("netbios", "PIHOLE", None, 1), ("dns", "pihole.home.arpa", None, 1)],
         reverse_dns="pihole.home.arpa", ports=[(22, None), (53, None), (80, http())], rtt=1.2),
    dict(host=60, mac="doc", v6=False, vendor="Intel", ttl=128, via=["probe_reply"],
         names=[("netbios", "STUDIO-PC", None, 1), ("dns", "studio-pc.home.arpa", None, 1)],
         reverse_dns="studio-pc.home.arpa", ports=[(445, None)], rtt=2.6),
    # Honestly unnamed: a guest's phone, a watch on a private address, and something the
    # neighbour table remembers that never answered a probe.
    dict(host=70, mac="private", v6=False, vendor=None, ttl=64, via=["probe_reply"],
         names=[], ports=[], rtt=42.3),
    dict(host=71, mac="private", v6=False, vendor=None, ttl=None, via=["neighbor_table"],
         names=[], ports=[], rtt=None),
    dict(host=72, mac="private", v6=False, vendor=None, ttl=None, via=["neighbor_table"],
         names=[], ports=[], rtt=None),
]


def mac_of(row, private_index):
    if row["mac"] == "doc":
        return f"00:00:5E:00:53:{row['host']:02X}"
    # Locally administered, unicast: 0x2E has bit 1 set and bit 0 clear.
    return f"2E:5A:00:00:01:{private_index:02X}"


def link_local(mac):
    octets = [int(part, 16) for part in mac.split(":")]
    if octets[0] & 0x02:
        # A private address's v6 is opaque, not derived from the MAC.
        return f"fe80::1000:0:0:{octets[5]:x}%en0"
    octets[0] ^= 0x02
    eui = octets[:3] + [0xFF, 0xFE] + octets[3:]
    groups = [f"{eui[i]:02x}{eui[i + 1]:02x}" for i in range(0, 8, 2)]
    return "fe80::" + ":".join(groups) + "%en0"


def best(names):
    return min(names, key=lambda n: (PRIORITY[n["source"]], n["rank"], n["value"]), default=None)


def evidence(names, vendor, ttl):
    """IdentificationEvidence(names:vendor:ttl:), zhen-core Model/Device.swift."""
    winner = best(names)
    ordered = sorted(names, key=lambda n: (PRIORITY[n["source"]], n["rank"], n["value"]))
    model = (winner or {}).get("model") or next((n["model"] for n in ordered if n.get("model")), None)
    name = winner["value"] if winner else None
    just_model = name is not None and model is not None and name.strip().lower() == model.strip().lower()
    return {
        "has_distinct_name": bool(name) and not just_model,
        "name_source_is_self_sufficient": bool(winner) and winner["source"] in SELF_SUFFICIENT,
        "has_model": bool(model),
        "has_vendor": bool(vendor),
        # OSHint(ttl:): 32...64, 96...128, 224...255.
        "has_os_hint": ttl is not None and (32 <= ttl <= 64 or 96 <= ttl <= 128 or 224 <= ttl <= 255),
        "independent_sources": len({n["source"] for n in names}),
    }


def identification(e):
    """Identification(evidence:), zhen-core Model/Device.swift."""
    if e["has_distinct_name"] and (e["name_source_is_self_sufficient"] or e["independent_sources"] >= 2):
        return "identified"
    if e["has_distinct_name"] or e["has_model"] or e["has_vendor"] or e["has_os_hint"]:
        return "partial"
    return "minimal"


def stability(mac, names):
    """The strongest identity key, as HostIdentifier.candidates(for:in:) would weigh it."""
    if mac and not int(mac.split(":")[0], 16) & 0x02:
        return "strong"
    if any(n["source"] == "mdns" and n["value"] for n in names):
        return "moderate"
    return "weak" if mac else "ephemeral"


def device(row, private_index, started, finished):
    mac = mac_of(row, private_index)
    v4 = f"{NETWORK}.{row['host']}"
    names = sorted(
        ({"source": s, "value": v, "rank": r, **({"model": m} if m else {})} for s, v, m, r in row["names"]),
        key=lambda n: (PRIORITY[n["source"]], n["rank"], n["value"]),
    )
    e = evidence(names, row["vendor"], row["ttl"])
    record = {
        "addresses": [v4] + ([link_local(mac)] if row["v6"] else []),
        "discovered_via": row["via"],
        "first_seen": started,
        "identification": identification(e),
        "identification_evidence": e,
        "identity_stability": stability(mac, names),
        "last_seen": finished,
        "mac": mac,
        "names": names,
        "ports": [
            {
                "address": v4, "port": port, "proto": "tcp", "state": "open",
                "rtt": {"millis": round(row["rtt"] or 5.0, 3), "samples": 1},
                **({"service": service} if service else {}),
            }
            for port, service in sorted(row["ports"])
        ],
    }
    if row["vendor"]:
        record["vendor"] = row["vendor"]
    if row.get("reverse_dns"):
        record["reverse_dns"] = row["reverse_dns"]
    if row["ttl"] is not None:
        record["ttl"] = row["ttl"]
    if row["rtt"] is not None:
        millis = row["rtt"]
        record["rtt"] = {"millis": millis, "samples": 1, "smoothed_millis": millis, "variance_millis": millis / 2}
    return record


def report():
    with open(HOME, encoding="utf-8") as f:
        home = json.load(f)
    run = home["run"]
    run["id"] = RUN_ID
    started, finished = run["started_at"], run["finished_at"]
    devices, private = [], 0
    for row in DEVICES:
        if row["mac"] == "private":
            private += 1
        devices.append(device(row, private, started, finished))
    # The engine's counters stay the home capture's; only what they found is this network's.
    for stage in run["timing"]["stages"]:
        if stage["stage"] == "discovery":
            stage["hosts_found"] = sum("probe_reply" in d["discovered_via"] for d in devices)
        elif stage["stage"] == "naming":
            stage["hosts_found"] = sum(bool(d["names"]) for d in devices)
    return {"degradations": [], "devices": devices, "run": run, "schema": home["schema"]}


def text():
    return json.dumps(report(), ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main(argv):
    if len(argv) == 3 and argv[1] == "--check":
        with open(argv[2], encoding="utf-8") as f:
            if f.read() != text():
                print(f"make-showcase-fixture: {argv[2]} is not this script's output — regenerate it", file=sys.stderr)
                return 1
        print(f"make-showcase-fixture: {argv[2]} — PASS")
        return 0
    if len(argv) != 1:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    sys.stdout.write(text())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
