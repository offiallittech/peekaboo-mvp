# E Ink-style UI and refresh abstraction

Peekaboo MVP targets Android tablets but uses an E Ink-inspired reading experience: calm contrast, low motion, large touch zones, and refresh behavior isolated from feature logic. This document describes the theme expectations and the refresh abstraction that future hardware-specific integrations can use.

## Design principles

- **Reading first:** page content should dominate the screen; controls stay minimal and predictable.
- **Low glare:** use warm off-white backgrounds and near-black text instead of pure white/black where possible.
- **Low motion:** avoid animated transitions that distract children or cause ghosting on E Ink-like displays.
- **Large targets:** controls should be easy for children to tap on a tablet.
- **Predictable refresh:** page turns and major screen changes can request stronger refreshes without coupling UI code to device APIs.
- **Accessible typography:** generous line height, readable font sizes, and dyslexia-friendly options where feasible.

## Visual tokens

Recommended MVP defaults:

| Token | Suggested value | Purpose |
| --- | --- | --- |
| Background | `#F4F0E6` | Warm paper tone |
| Surface | `#ECE6D8` | Cards/popups |
| Primary text | `#1F1F1B` | Main reading text |
| Secondary text | `#5D5A52` | Metadata/help text |
| Hairline | `#C9C1B2` | Subtle dividers |
| Focus/selection | `#D8C68A` | Word tap highlight |
| Error/caution | muted brown/red | Non-alarming warning state |

Avoid saturated colors for core reading surfaces. If color is used, verify legibility in grayscale.

## Typography

- Body reading text: 22-30 px equivalent on tablets, user adjustable.
- Line height: 1.35-1.6.
- Paragraph spacing: enough to distinguish blocks without excessive pagination churn.
- UI labels: 16-20 px equivalent.
- Avoid thin font weights; prefer regular/medium.

## Motion guidance

Allowed:

- Instant state changes.
- Very short opacity changes for popups if tested on LCD tablets.
- Progress indicators for network calls.

Avoid:

- Page curl animations.
- Rapid shimmer/skeleton animations.
- Background video or auto-playing animation.
- Repeated full-screen flashing.

## Refresh abstraction

Feature modules should request refresh intent through an interface, not call platform APIs directly.

Suggested Dart model:

```dart
enum RefreshMode {
  none,       // No special display handling.
  partial,    // Small region changed, e.g. popup open/close.
  pageTurn,   // Main reading page changed.
  full,       // Major screen transition; reduce ghosting.
}

abstract class EinkRefreshController {
  Future<void> requestRefresh(RefreshMode mode, {String? reason});
}
```

Default Android-tablet implementation can be a no-op plus logging/metrics. Device-specific implementations can later map modes to vendor APIs if available.

## When to request refreshes

| Event | Refresh mode | Notes |
| --- | --- | --- |
| Open book | `full` | Major content transition |
| Page turn | `pageTurn` | Main reading surface replaced |
| Vocabulary popup open/close | `partial` | Localized overlay change |
| Toggle font size/theme | `full` | Re-layout and redraw |
| Start/stop recording | `partial` | Control state change |
| Navigate to parent dashboard | `full` | Major screen transition |
| Minor progress save | `none` | Background state only |

## Integration boundaries

- Reading widgets may request `pageTurn`, but should not know how refresh is implemented.
- Vocabulary widgets may request `partial` when opening or closing overlays.
- Parent dashboard can use normal Flutter rendering and request `full` only on major transitions.
- Tests should be able to inject a fake refresh controller and assert requested modes.

## Performance targets for E Ink-style rendering

- Cached page turn visual response: under 150 ms.
- Full screen transition: under 500 ms when no network data is required.
- Popup open: under 300 ms when definition is cached.
- No more than one full refresh per user action unless required by the platform.

## Child comfort and safety

- Do not use punitive red-heavy feedback for reading mistakes.
- Avoid visual effects that can look like flashing or flickering.
- Keep focus states clear for children with motor or attention challenges.
- Ensure vocabulary popups can be dismissed easily and do not trap the child.

## Verification expectations

The project verifier looks for E Ink-related implementation files in `lib/eink/` for a root Flutter project, `app/lib/eink/` for a nested Flutter project, or equivalent names containing `eink`/`refresh`. The refresh abstraction should be testable independently from platform-specific code.
