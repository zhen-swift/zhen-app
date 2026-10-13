#!/usr/bin/env python3 -I
"""apply-translations.py LANG — merge Scripts/translations/LANG.json into Zhen/Localizable.xcstrings.

The catalogue is edited in Xcode for English and here for every other language, so a
translation is a reviewable JSON diff rather than a catalogue diff. A key the catalogue
does not have, a missing key, or a placeholder that differs from the English is an error:
nothing is written. `LocalizationTests` checks the result.
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
lang = sys.argv[1]
catalog_path = root / "Zhen/Localizable.xcstrings"
catalog = json.loads(catalog_path.read_text())
strings = catalog["strings"]
translations = json.loads((root / f"Scripts/translations/{lang}.json").read_text())
translations.pop("_comment", None)

SPEC = re.compile(r"%(?:\d+\$)?(?:lld|@)|%#@\w+@|%arg")
def specs(text):
    return sorted(SPEC.findall(text))

def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}

errors = []
for key in sorted(set(strings) - set(translations)):
    errors.append(f"{key}: no {lang} translation")
for key in sorted(set(translations) - set(strings)):
    errors.append(f"{key}: not in the catalogue")

for key, value in translations.items():
    if key not in strings:
        continue
    en = strings[key]["localizations"]["en"]
    if isinstance(value, str):
        if "stringUnit" not in en or "substitutions" in en:
            errors.append(f"{key}: English is a plural; {lang} is a plain string"); continue
        if specs(value) != specs(en["stringUnit"]["value"]):
            errors.append(f"{key}: placeholders {specs(value)} ≠ {specs(en['stringUnit']['value'])}"); continue
        strings[key]["localizations"][lang] = unit(value)
    elif "value" in value:
        if "substitutions" not in en:
            errors.append(f"{key}: {lang} has a substitution, English does not"); continue
        if specs(value["value"]) != specs(en["stringUnit"]["value"]):
            errors.append(f"{key}: placeholders differ"); continue
        sub = json.loads(json.dumps(en["substitutions"]))
        name = next(iter(sub))
        sub[name]["variations"] = {"plural": {"one": unit(value["one"]), "other": unit(value["other"])}}
        strings[key]["localizations"][lang] = {"stringUnit": {"state": "translated", "value": value["value"]}, "substitutions": sub}
    else:
        if "variations" not in en:
            errors.append(f"{key}: {lang} is a plural, English is not"); continue
        for form in ("one", "other"):
            if specs(value[form]) != specs(en["variations"]["plural"][form]["stringUnit"]["value"]):
                errors.append(f"{key}.{form}: placeholders differ")
        strings[key]["localizations"][lang] = {"variations": {"plural": {"one": unit(value["one"]), "other": unit(value["other"])}}}

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
print(f"apply-translations: {len(translations)} {lang} strings")
