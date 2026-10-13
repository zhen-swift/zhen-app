# Accessibility

The floor every screen stands on, and how it is checked.

## Overview

### Contrast

Text clears WCAG AA, 4.5:1, against every surface it is drawn on, and 7:1 with Increase
Contrast; lines and marks clear 3:1 there. Every pair is resolved from the compiled
catalogue in four appearances by `PaletteContrastTests`:

| Foreground | On | Standard | Increase Contrast |
|---|---|---|---|
| `textPrimary`, `textSecondary` | surfaces, selection | 4.5 | 7 |
| `textTertiary` | surfaces | 4.5 | 7 |
| `accent` | surfaces, `accentFill` | 4.5 | 7 |
| `onAccent` | `accent` | 4.5 | 7 |
| status text | surfaces | 4.5 | 7 |
| white | `SystemAccent` (AppKit's selections and switches) | 4.5 | 7 |
| lines and marks | surfaces | — | 3 |

### Never colour alone

A status dot always has words beside it. Online is filled, offline is a ring. With
Differentiate Without Colour on, every tone draws its own symbol
(`StatusDot.Tone.symbol`). Offline rows are never dimmed: the ring and the last-seen
weight say it.

### Names, roles, identifiers

Every interactive element has a name and a stable identifier. A row, cell or card that
combines its children into one element is given a role — static text, or image for a
chart, meter or dot — so VoiceOver can say what it is. Lists and tables have names
("Devices", "Events", "Found so far").

### Keyboard

Every room, the detail, the live scan and Settings are usable without a pointer
(`KeyboardUITests`). Return opens a row; ⌘[ goes back; ⌘. stops a scan.

### How it is checked

- `AccessibilityAuditUITests`: the project's rule, that every control on every screen
  has an identifier and a name.
- `SystemAccessibilityAuditUITests`: Apple's `performAccessibilityAudit` on every
  screen and every empty and partial state. Contrast is measured on the element's own
  pixels against 4.5:1. What it excuses is drawn by AppKit or SwiftUI, matched exactly,
  with the reason given:
  - Form pickers
  - container groups with named content
  - the selected sidebar row, which is filled with the person's own accent colour
- `AppearanceUITests`: every room in all four appearances.
