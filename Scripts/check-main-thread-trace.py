#!/usr/bin/env python3 -I
"""check-main-thread-trace.py — no scanning work on the main thread, read from a trace.

Usage:
  xcrun xctrace record --template 'Time Profiler' --output scan.trace \\
      --launch -- build/release/Zhen.app/Contents/MacOS/Zhen     # then Scan Now, wait for it
  Scripts/check-main-thread-trace.py scan.trace

Reads the Time Profiler table out of the trace with `xctrace export` and looks at every
sample's backtrace. A frame from the engine — `ZhenDarwin`, `ZhenScan`, `ZhenPrivilege`, or
core's concurrency and engine types — is scanning work. Any such frame on the main thread
fails the check. So does a trace in which the engine never appears at all: that recorded
no scan, and a pass on nothing is not a pass.

`ZhenCore` value types (addresses, `HostFacts`, `Device`) are allowed on the main thread:
the view model reads them in `ScanSession.apply`. That is presentation of results, not
probing for them.
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ENGINE = re.compile(
    r"\b(ZhenDarwin|ZhenScan|ZhenPrivilege)\."
    r"|\bZhenCore\.(CompositeDiscovery|BoundedPool|FanOut|ProbeStream|ProbeCounters|"
    r"SweepClock|RTTEstimator|NameResolution|ICMP|BPF)"
)
MAIN_ROOT = ("NSApplicationMain", "-[NSApplication run]")


def export(trace):
    query = '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]'
    result = subprocess.run(
        ["xcrun", "xctrace", "export", "--input", trace, "--xpath", query],
        check=True, capture_output=True,
    )
    return result.stdout


def rows(xml_bytes):
    """Each sample as (thread label, [frame names]), refs resolved."""
    root = ET.fromstring(xml_bytes)
    by_id = {}
    for element in root.iter():
        if "id" in element.attrib:
            by_id[element.attrib["id"]] = element

    def resolve(element):
        return by_id.get(element.attrib["ref"], element) if "ref" in element.attrib else element

    for row in root.iter("row"):
        thread = row.find("thread")
        label = resolve(thread).attrib.get("fmt", "") if thread is not None else ""
        frames = []
        tagged = row.find("tagged-backtrace")
        if tagged is not None:
            tagged = resolve(tagged)
            backtrace = tagged.find("backtrace")
            if backtrace is not None:
                for frame in resolve(backtrace).iter("frame"):
                    frames.append(resolve(frame).attrib.get("name", ""))
        yield label, frames


def is_main(label, frames):
    return "Main Thread" in label or any(name in MAIN_ROOT for name in frames)


def main(argv):
    if len(argv) != 2:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    source = argv[1]
    data = open(source, "rb").read() if source.endswith(".xml") else export(source)
    samples = main_samples = engine = 0
    offenders = []
    for label, frames in rows(data):
        samples += 1
        hits = [name for name in frames if ENGINE.search(name)]
        if hits:
            engine += 1
        if is_main(label, frames):
            main_samples += 1
            if hits:
                offenders.append(hits[0])
    print(f"check-main-thread-trace: {samples} samples, {main_samples} on the main thread, "
          f"{engine} with engine frames")
    if samples == 0:
        print("  no samples at all — FAIL")
        return 1
    if engine == 0:
        print("  the engine never appears: this trace recorded no scan — FAIL")
        return 1
    if offenders:
        print(f"  {len(offenders)} main-thread samples were scanning — FAIL")
        for name in sorted(set(offenders))[:10]:
            print(f"    {name}")
        return 1
    print("  every engine sample is off the main thread — PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
