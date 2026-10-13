#!/usr/bin/env python3 -I
"""anonymise-scan.py — turn a real `zhen scan --json` report into a fixture this public
repository can hold.

Usage:
  Scripts/anonymise-scan.py <raw.json> > Zhen/Fixtures/home-network.json
  Scripts/anonymise-scan.py --verify <raw.json> <fixture.json>

The raw report never enters the repository. It is captured on the home LAN, kept outside
the tree, and only this script's output is committed. A fixture with real MAC addresses,
link-local addresses and Bonjour names publishes the network it was taken from.

What is rewritten, and what is kept. The point of a real capture is its SHAPE, so every
rewrite keeps the property the app's layout depends on:

| Field                  | Rewritten to                                   | Shape kept                     |
|------------------------|------------------------------------------------|--------------------------------|
| universal MAC          | 00:00:5E:00:53:nn (RFC 7042 documentation)     | universal bit, distinctness    |
| randomised MAC         | a synthetic locally-administered address        | local bit, distinctness        |
| IPv4                   | 192.168.50.x, in the same order                 | gateway stays .1, ordering     |
| IPv6 link-local        | rebuilt from the rewritten MAC when EUI-64,     | EUI-64 or opaque, scope        |
|                        | otherwise a synthetic opaque interface id       |                                |
| Bonjour / UPnP names   | a synthetic name of the same class              | curly apostrophe, long Spanish |
|                        |                                                 | name, single token             |
| TLS subject, banner    | kept only when it is a bare product string      | port findings                  |
| filtered ports         | dropped                                         | open and closed are kept       |
| run id, timestamps     | a fixed id; times shifted to 2026-01-01 12:00Z  | every duration and gap         |

Model strings (`AppleTV5,3`), TTLs, round trips, discovery sources, identification and
stability are not identifying and are kept as measured.

Names are never mapped by a table of real → synthetic values, because that table would
publish the real values. A name is assigned from a pool by its class, in order of first
appearance, so the same input always gives the same output.

`--verify` is the gate: it fails if any MAC, address or name from the raw report appears
anywhere in the fixture's text.
"""
import json
import re
import sys
import uuid

NETWORK = "192.168.50"
EPOCH_MS = 1_767_268_800_000  # 2026-01-01T12:00:00Z
RUN_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, "zhen-app/fixture/home-network"))

POOLS = {
    # A possessive with a typographic apostrophe: the case that breaks naive escaping.
    "possessive": ["Alex’s MacBook Pro", "Sam’s iPad", "Noa’s iPhone"],
    # Several words, long, not English: the case that breaks a fixed-width column.
    "phrase": ["Sala de estar principal", "Cuarto de huéspedes", "Estudio del jardín"],
    # One token, the way an appliance names itself.
    "token": ["SpeakerConnect", "LivingRoomHub", "PrinterLink"],
}

PRODUCT = re.compile(r"^[A-Za-z][A-Za-z -]{0,30}$")
BANNER = re.compile(r"^(HTTP/1\.[01] [0-9]{3} [A-Za-z ]+|[A-Za-z]+/[0-9.]+)$")


class Anonymiser:
    def __init__(self):
        self.macs = {}
        self.ipv4 = {}
        self.ipv6 = {}
        self.names = {}
        self.used = {key: 0 for key in POOLS}
        self.universal = 0
        self.local = 0

    def mac(self, value):
        if value is None:
            return None
        if value not in self.macs:
            first = int(value.split(":")[0], 16)
            if first & 0x02:
                self.local += 1
                n = self.local
                # Locally administered, unicast: low bits 10 in the first octet.
                octet = ((0x1A + 0x10 * n) & 0xFC) | 0x02
                self.macs[value] = f"{octet:02X}:5C:00:00:00:{n:02X}"
            else:
                self.universal += 1
                self.macs[value] = f"00:00:5E:00:53:{self.universal:02X}"
        return self.macs[value]

    def plan_ipv4(self, addresses):
        hosts = sorted({int(a.split(".")[3]) for a in addresses})
        others = [h for h in hosts if h != 1]
        for h in hosts:
            if h == 1:
                new = 1
            else:
                new = 10 + 3 * others.index(h)
            original = next(a for a in addresses if int(a.split(".")[3]) == h)
            self.ipv4[original] = f"{NETWORK}.{new}"

    def address(self, value, mac):
        if ":" not in value:
            return self.ipv4[value]
        if value in self.ipv6:
            return self.ipv6[value]
        body, _, scope = value.partition("%")
        groups = body.split("::")[-1].split(":")
        eui64 = len(groups) == 4 and groups[1].endswith("ff") and groups[2].startswith("fe")
        if eui64 and mac:
            b = [int(x, 16) for x in self.mac(mac).split(":")]
            b[0] ^= 0x02
            iid = f"{b[0]:02x}{b[1]:02x}:{b[2]:02x}ff:fe{b[3]:02x}:{b[4]:02x}{b[5]:02x}"
        else:
            iid = f"1000:0:0:{len(self.ipv6) + 1:x}"
        rewritten = f"fe80::{iid}" + (f"%{scope}" if scope else "")
        self.ipv6[value] = rewritten
        return rewritten

    def name(self, value):
        if value not in self.names:
            if "’" in value or "'" in value:
                kind = "possessive"
            elif " " in value.strip():
                kind = "phrase"
            else:
                kind = "token"
            pool = POOLS[kind]
            index = self.used[kind]
            self.used[kind] += 1
            self.names[value] = pool[index % len(pool)] + ("" if index < len(pool) else f" {index}")
        return self.names[value]


def shift(ms, delta):
    return None if ms is None else ms + delta


def transform(report):
    a = Anonymiser()
    v4 = [x for d in report["devices"] for x in d["addresses"] if ":" not in x]
    a.plan_ipv4(v4)
    delta = EPOCH_MS - report["run"]["started_at"]

    run = report["run"]
    run["id"] = RUN_ID
    run["started_at"] = shift(run["started_at"], delta)
    run["finished_at"] = shift(run.get("finished_at"), delta)
    run["target"] = f"{NETWORK}.0/{run['target'].split('/')[1]}"

    for device in report["devices"]:
        raw_mac = device.get("mac")
        device["addresses"] = sorted(a.address(x, raw_mac) for x in device["addresses"])
        device["mac"] = a.mac(raw_mac)
        for candidate in device.get("names", []):
            candidate["value"] = a.name(candidate["value"])
        for key in ("reverse_dns", "dhcp_hostname"):
            if device.get(key):
                device[key] = a.name(device[key])
        ports = []
        for port in device.get("ports", []):
            if port["state"] == "filtered":
                continue
            if port.get("address"):
                port["address"] = a.address(port["address"], raw_mac)
            service = port.get("service")
            if service:
                if service.get("tls_subject") and not PRODUCT.match(service["tls_subject"]):
                    del service["tls_subject"]
                if service.get("banner") and not BANNER.match(service["banner"]):
                    del service["banner"]
            ports.append(port)
        device["ports"] = ports
        device["first_seen"] = shift(device["first_seen"], delta)
        device["last_seen"] = shift(device["last_seen"], delta)
    report["devices"].sort(key=lambda d: d["addresses"][0])
    return report


def identifiers(report):
    """Every value in the raw report that would identify the network it came from."""
    found = set()
    for device in report["devices"]:
        if device.get("mac"):
            found.add(device["mac"].lower())
        for address in device["addresses"]:
            found.add(address.split("%")[0].lower())
        for candidate in device.get("names", []):
            found.add(candidate["value"].lower())
        for key in ("reverse_dns", "dhcp_hostname"):
            if device.get(key):
                found.add(device[key].lower())
    found.add(report["run"]["id"].lower())
    return found


def verify(raw_path, fixture_path):
    with open(raw_path, encoding="utf-8") as f:
        raw = json.load(f)
    with open(fixture_path, encoding="utf-8") as f:
        text = f.read().lower()
    leaks = sorted(value for value in identifiers(raw) if value in text)
    checked = len(identifiers(raw))
    if leaks:
        print(f"anonymise-scan: {len(leaks)} of {checked} raw identifiers appear in the fixture — FAIL")
        for value in leaks:
            # Say which kind leaked, never the value: this output can end up in a log.
            kind = "mac" if re.fullmatch(r"([0-9a-f]{2}:){5}[0-9a-f]{2}", value) else "address or name"
            print(f"  leaked: a {kind} ({len(value)} chars)")
        return 1
    print(f"anonymise-scan: {checked} raw identifiers checked, none in the fixture — PASS")
    return 0


def main(argv):
    if len(argv) == 4 and argv[1] == "--verify":
        return verify(argv[2], argv[3])
    if len(argv) != 2:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        report = json.load(f)
    json.dump(transform(report), sys.stdout, ensure_ascii=False, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
