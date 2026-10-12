#!/usr/bin/env python3 -I
"""catalog-plurals.py Zhen/Localizable.xcstrings — English plurals for the counted strings.

The catalogue is filled from the compiler's extraction:

  xcodebuild build … -derivedDataPath DD
  xcrun xcstringstool sync Zhen/Localizable.xcstrings --stringsdata <each DD/…/Zhen.build/*.stringsdata>

which adds every new string and keeps existing entries. A counted string then needs its
`one` form here; `PluralTests` pins the result.
"""
import json, sys
path = sys.argv[1]
d = json.load(open(path))
strings = d["strings"]

def unit(v): return {"stringUnit": {"state": "translated", "value": v}}

single = {
    "%lld events": ("%lld event", "%lld events"),
    "%lld hosts answered": ("%lld host answered", "%lld hosts answered"),
    "%lld identity changes": ("%lld identity change", "%lld identity changes"),
    "%lld names found": ("%lld name found", "%lld names found"),
    "Last 48 hours · %lld events": ("Last 48 hours · %lld event", "Last 48 hours · %lld events"),
    "Last scan completed with partial results — %lld sources unavailable":
        ("Last scan completed with partial results — %lld source unavailable",
         "Last scan completed with partial results — %lld sources unavailable"),
    "None of the %lld ports checked was open.": ("The %lld port checked was not open.", "None of the %lld ports checked was open."),
}
for key, (one, other) in single.items():
    assert key in strings, key
    strings[key]["localizations"] = {"en": {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}}

# Several arguments: the counted one becomes a substitution, the rest keep their place.
multi = {
    "%lld devices · %lld online · %lld unidentified":
        ("%#@devices@ · %2$lld online · %3$lld unidentified", "devices", 1, "%arg device", "%arg devices"),
    "Stage %lld of %lld · %@ elapsed · %lld devices so far":
        ("Stage %1$lld of %2$lld · %3$@ elapsed · %#@devices@", "devices", 4, "%arg device so far", "%arg devices so far"),
    "Stopped after %@ · %lld devices found":
        ("Stopped after %1$@ · %#@devices@", "devices", 2, "%arg device found", "%arg devices found"),
}
for key, (value, name, arg, one, other) in multi.items():
    assert key in strings, key
    strings[key]["localizations"] = {"en": {
        "stringUnit": {"state": "translated", "value": value},
        "substitutions": {name: {"argNum": arg, "formatSpecifier": "lld",
                                 "variations": {"plural": {"one": unit(one), "other": unit(other)}}}},
    }}
json.dump(d, open(path, "w"), indent=2, ensure_ascii=False, sort_keys=True)
open(path, "a").write("\n")
print("plurals:", len(single) + len(multi))
