# ``ZhenDesign``

The zhen design system: tokens, components and screen compositions, as real code.

## Overview

This module is the design, expressed in Swift. It holds every colour, type style,
dimension and component the app is built from, and it renders every screen from static
fixtures — no store, no `ZhenCore`, no network. That is deliberate and it is
checkable: if a screen needs live data to look right, its states are not finished.

It was measured from six exported artboards rather than invented. Where a measured value
is wrong — and four of them are — the value shipped here is the corrected one and
<doc:Corrections> says why.

@Row {
    @Column {
        ![The devices list, dark](artboard-devices-dark)
    }
    @Column {
        ![The devices list, light](artboard-devices-light)
    }
}

## Who this is for

The product's rule, from the README, decides more layout questions than anything else in
these documents:

> An everyday user opens this and immediately sees what is on their network, in their
> words. A network engineer opens the same app and finds the depth one level down, where
> it doesn't tax anyone who wasn't looking for it.

In practice that is why ``ConfidenceMeter`` is bound to ``Identification`` and never to
identity-key stability; why the engineering quantity is *placed* rather than removed; and
why the device row is 52pt tall — the second line is the whole product for a device
nothing could name.

## Read order

Three appendices, in order. Read <doc:Foundations> before <doc:Components>, and both
before <doc:BuildingAScreen>.

## Topics

### Appendices

- <doc:Foundations>
- <doc:Components>

### Articles

- <doc:BuildingAScreen>
- <doc:StatesAndEmptiness>
- <doc:Accessibility>
- <doc:Corrections>

### Tokens

- ``Palette``
- ``Metrics``
- ``Symbols``
- ``Motion``
- ``Tracking``

### Component views

- ``StatusDot``
- ``ConfidenceMeter``
- ``Chip``
- ``DeviceRow``
- ``DeviceTableHeader``
- ``Card``
- ``CardRows``
- ``KeyValueGrid``
- ``PrimaryButton``
- ``SecondaryButton``
- ``LinkButton``
- ``SearchField``
- ``StageCard``
- ``ProgressTrack``
- ``DegradationBanner``
- ``PartialRunStrip``
- ``EventRow``
- ``EventPalette``
- ``TimelineHistogram``
- ``SectionLabel``
- ``ToggleRow``
- ``MenuRow``
- ``StaticRow``
- ``EmptyStateView``

### Screens

- ``ZhenWindow``
- ``Sidebar``
- ``DeviceListView``
- ``DeviceDetailView``
- ``ActivityView``
- ``LiveScanView``
- ``SettingsView``

### Models

- ``DeviceRowModel``
- ``DeviceDetailModel``
- ``Identification``
- ``Presence``
- ``KeyValuePair``
- ``IdentityRecordModel``
- ``NameCandidateModel``
- ``PortModel``
- ``EventModel``
- ``EventDayModel``
- ``EventKind``
- ``EventCategory``
- ``HistogramBucket``
- ``StageModel``
- ``ScanStage``
- ``StageState``
- ``DegradationModel``
- ``ScanFindingModel``
- ``ScanActivity``
- ``Room``
- ``DeviceListState``
- ``LiveScanState``
- ``HelperState``
