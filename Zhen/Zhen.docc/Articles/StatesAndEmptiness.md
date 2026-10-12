# States and emptiness

Every empty, partial and error state in the app, in one place.

## Overview

An empty screen always says why it is empty and what would change that. A partial result
always says it is partial, on the screen that shows it and on the screens after. Nothing
here is a modal: a scan that lost a source is still a useful scan.

### Devices

| State | What it shows |
|---|---|
| Never scanned | "No scan yet" with Scan Now. The footer says "Never scanned" |
| First scan running | the live scan, rows streaming in as hosts answer — never a spinner over an empty table |
| Loaded | the table |
| Loaded from a partial run | an amber footer dot and a strip under the header — "Last scan ran out of time", "was stopped", or "completed with partial results — N sources unavailable" — opening onto the same rows the live scan showed |
| Nothing answered | an explanation, with core's Local Network finding and a button to the setting |
| Search with no match | "No matches", with the header counts unchanged |
| Two rows at one address | both rows stay; the absent one's address is secondary ink and it carries a `reassigned` chip |

### Live scan

| State | What it shows |
|---|---|
| Starting | every stage queued, "Listening…" |
| Running | the current stage's progress; hosts newest first; "Resolving name…" in italic while naming runs |
| Degraded | the banner, pinned, with the action that helps: System Settings for Local Network, Zhen's Settings for the helper, Scan Again otherwise |
| Done | hands back to Devices on its own; degradations go with it |
| Stopped | "Stopped after 0:47 · 4 devices found", everything found kept, Scan Again |

### Device detail

| State | What it shows |
|---|---|
| Unidentified | an ordinary detail: "Unidentified device", the `questionmark.circle` tile, every name source "— not advertised" |
| Never port-scanned | "No port scan yet" with Scan Ports |
| Port scan running | progress in the ports card; the window is not taken over |
| Port scan this session | the ports, captioned "this session, not saved to history" |
| Port scan found nothing | the reason: stopped, or the device did not answer |
| No identity changes | the current MAC and "No identity changes seen" |
| Offline | a hollow dot and "Last seen …"; every action still available |

### Activity

| State | What it shows |
|---|---|
| Nothing at all | "Nothing has changed" |
| Filter with no match | the filter and histogram stay; "No ⟨kind⟩ events in this window" |
| Under two hours of history | the histogram hides; the list stands alone |

### Settings and the helper

| State | What it shows |
|---|---|
| Not installed | what it is, what it can and cannot do, Install; Remove beside it, disabled |
| Awaiting approval | "Allow Zhen under Login Items", Open Login Items, Remove |
| Installed | the helper's own answer, Show in System Settings, Remove |
| Unavailable | the sentence macOS gave |
| History under a fixture | "In memory — this launch uses a fixture", never a size |
