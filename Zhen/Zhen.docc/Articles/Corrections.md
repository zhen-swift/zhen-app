# Corrections

Where the app deliberately differs from the artboards, and why.

## Overview

Written down, a difference is a decision. Undocumented, the next person "fixes" it back to
match the artboards. Each line names what forced it; the measurements are in the phase
ledgers (`Docs/process/`).

### Structure

- **Two rooms, not five.** Omada is gone from the project; Events folded into Activity,
  one dataset with one door; Settings is a `Settings` scene, ⌘,.
- **Device detail is pushed, in one column.** The artboards' second column was Omada's.
- **The live scan is not a room.** It replaces the Devices content and hands back.
- **Activity is a `List` with day sections**, not a table: events are sentences read in
  time order.

### Colour and contrast

- **Two contrast tokens moved from the artboards' greys**, which failed 4.5:1.
- **Offline rows keep their name at full contrast**; a ring and the last-seen weight say
  offline, not dimming.
- **Sidebar selection is the system highlight**, not `#373548`: tertiary text measured
  3.89:1 on that tint, and the system's follows the person's accent.
- **Prominent buttons, switches and the Activity picker follow the person's accent**;
  the app's purple stays in chips, meters and links. When the Mac's accent is
  Multicolour, AppKit uses the app's `SystemAccent`, a darker purple than the `accent`
  text colour: white on the text colour measured 2.61:1 in dark mode.

### The table

- **Rows are 40 pt, not 52** — `Table`'s own height for a two-line cell. Provisional
  until the designer's round 3.
- **Column headers are AppKit's**, not 11 pt tracked capitals; restyling them means
  leaving `Table`.
- **Columns are measured, not declared.** The declared widths cost 332 pt of minimum
  window.
- **Link-local IPv6 drops `%en0` in the table**; the scope made the address column the
  widest.
- **The `reassigned` chip sits on the name line.** A3 asks for its own line; that would
  make it the one three-line row in a table held to equal row heights.

### Copy

- **Presence and Addresses**, not Appearances and Network (designer, round 2).
- **"Left" for a device that disappeared**: "Disappeared" is 2.4× the kind column.
- **The partial-run strip** exists at all: the artboards had no state for a partial run,
  and a green dot over an incomplete scan is a lie of omission.
- **The Local Network copy is hedged** ("appears to be denied"): the grant cannot be
  queried, only inferred.
- **"Check ports on every scan"**, not "Deep-scan new devices": zhen-core's port stage is
  one switch per run.

### The detail

- **Identity history lists merges, renames and moves**, not one row per MAC: zhen-core
  keeps only the current MAC.
- **"Name query in flight" names no protocol**: core reports which stage runs, not which
  query is outstanding for a host.
- **A port scan of one device is kept for the session**, and says so: recorded as a run,
  it marked every other device offline.
