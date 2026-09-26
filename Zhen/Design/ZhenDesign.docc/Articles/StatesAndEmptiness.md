# States and emptiness

Every empty, partial and error state in one place.

## Overview

The artboards draw the happy path. Real networks mostly do not produce it: on the
reference network seven devices out of ten have no name, no vendor and no model, two of
them never answered a ping at all, and the most common failure — a denied Local Network
permission — produces a screen with nothing on it.

So these states are not edge cases to add at the end. They are the majority of what the
app shows, and every one of them has to read as an answer rather than as a failure.

## The acceptance case

A device with an address, a randomised hardware address and nothing else.

``DeviceRowModel/anonymousNeighbourOnly`` is the emptiest row the product can produce: no
name, no vendor, no model, and no ping reply — so not even a TTL to hint at an operating
system. It renders as an ordinary row with "Unidentified device" as the name and
"Randomized MAC · no vendor · in ARP table, no ping reply" underneath.

No placeholder dashes across the columns, no collapsed height, no error styling. The
subtitle is doing the work: it says what we *do* know, which is the difference between a
row that is empty and a row that is unexplained.

``DeviceDetailModel/unidentified`` is the same case one level in, where every card is
empty or nearly so and the screen still has to look deliberate.

## Devices

| State | What shows |
|---|---|
| Never scanned | ``EmptyStateView/neverScanned`` — "No scan yet", with **Scan Now** |
| Scan found nothing | ``EmptyStateView/nothingAnswered`` — "Nothing answered" |
| Loaded | the table |
| Loaded from a partial run | ``PartialRunStrip`` under the header, footer dot amber |
| Search with no match | ``EmptyStateView/noMatches(for:)``, header counts unchanged |

**"Nothing answered" is the most important empty state in the app.** An empty device list
with no explanation is the single most likely way a new user concludes the app is broken,
when in fact the OS withheld a permission nobody told them about. Its copy names the
likely cause and offers the way to fix it.

Note what the search-with-no-match state does *not* do: the header counts stay as they
were. The network did not change because somebody typed in a box.

## The partial run

**The artboards have no state for this and they need one.** When a run hits its deadline
or loses a source, the results are still valid and still worth showing — but a green dot
over an incomplete scan is a lie of omission.

So the sidebar footer dot turns amber, and ``PartialRunStrip`` sits under the Devices
header with a one-line summary and a disclosure that opens the same ``DegradationBanner``
rows the live scan showed. Degradations do not evaporate when the scan ends.

## Device detail

| Card | Empty state |
|---|---|
| Identity history | the single MAC, caption "no identity changes seen" |
| Known by | sources that offered nothing show "— not advertised" |
| Open ports | "No port scan yet" with a **Scan ports** button |
| Recent events | "Nothing has changed since this device was first seen." |

"Known by" is the one to get right. A source that offered nothing is **shown**, not
hidden: the absence is information. It is how a person sees that we asked Bonjour, UPnP,
NetBIOS and reverse DNS and got one answer — rather than that we only asked one.

Offline does not disable anything. The status dot goes hollow and the header subtitle
becomes "Last seen 2 h ago", but the actions stay enabled, because rescanning a device
that stopped answering is exactly what you would want to do.

## Activity

| State | What shows |
|---|---|
| No events at all | ``EmptyStateView/nothingHasChanged`` |
| Filter matches nothing | chips and histogram stay, "No <kind> events in this window" |
| Under two hours of history | the histogram hides; the list stands alone |

Selecting a chip filters **both** the list and the histogram. If the histogram keeps
showing everything while the list is filtered, the two stop agreeing and a person reading
a tall bar over an empty list has been told something false.

## Live scan

| State | What shows |
|---|---|
| Starting | all stages queued, list reads "Listening…" |
| Running | stage strip with the running card bordered, rows arriving |
| A host still resolving | italic "Resolving name…" plus what is in flight |
| Every stage done | hands off to Devices automatically |
| Stopped by the user | partial results kept, with **Scan Again** |

Two of those are worth defending. The italic placeholder is the difference between a
scanner that looks like it is thinking and one that looks stuck — and it names the source
still in flight, so the wait is explained rather than merely endured. And **nothing is
discarded because someone pressed stop**: the results found so far stay on screen.
