# Bottom Sheet Modernization Plan

This branch modernizes `ti.bottomsheetcontroller` around Apple's native `UISheetPresentationController` APIs.

## Goals

- Use the system sheet exclusively; remove the legacy non-system/fallback implementation.
- Support named custom detents using public UIKit APIs.
- Allow interactive dismissal to be enabled/disabled at runtime without preventing programmatic `close()`.
- Treat all detents (custom, medium, large) uniformly for selection and events.
- Support a persistent floating-bar detent that expands upward through additional detents.
- Expose continuous normalized drag progress between neighboring detents for synchronized UI effects.
- Preserve native UIKit gestures, scrolling coordination, keyboard handling, accessibility, and current iOS appearance.

## Phase 1 — System-sheet-only cleanup

- Remove all `nonSystemSheet` configuration and runtime branches.
- Remove the custom fallback controller implementation.
- Keep `UISheetPresentationController` as the only sheet engine.
- Preserve existing native-sheet properties and lifecycle behavior.

## Phase 2 — Runtime dismissal control

Add `dismissible` (default `true`).

- `dismissible = false` prevents user-initiated interactive dismissal.
- Detent-to-detent dragging remains available.
- `sheet.close()` remains available regardless of `dismissible`.
- Changing `dismissible` while the sheet is presented takes effect immediately.

## Phase 3 — Public named custom detents

Replace the legacy private detent API with Apple's public custom-detent resolver API.

Example:

```js
customDetents: {
  bar: 76,
  preview: 320,
  compose: 600
}
```

Custom identifiers such as `bar`, `preview`, and `compose` become real UIKit detent identifiers.

## Phase 4 — Unified detent selection and events

Update the API so native and custom detents behave identically:

```js
sheet.changeCurrentDetent('bar');
sheet.changeCurrentDetent('medium');
sheet.changeCurrentDetent('large');
```

`selectedDetentIdentifier` and `detentChange` return the actual identifier for every detent.

## Phase 5 — Floating bottom-bar behavior

Support a small persistent lowest detent such as:

```js
customDetents: {
  bar: 76,
  reply: 390
},
startDetent: 'bar',
dismissible: false
```

The sheet may move between `bar`, `reply`, `medium`, and/or `large`, but cannot be dragged below the lowest detent when dismissal is disabled.

## Phase 6 — Continuous detent progress

Add a continuous `detentProgress` event synchronized with the sheet's live position.

For neighboring detents at 400 pt and 800 pt:

- 400 pt => `progress: 0.0`
- 600 pt => `progress: 0.5`
- 800 pt => `progress: 1.0`

Proposed event payload:

```js
{
  progress: 0.5,
  lowerDetent: 'one',
  upperDetent: 'two',
  lowerHeight: 400,
  upperHeight: 800,
  currentHeight: 600,
  direction: 'up'
}
```

Progress is always normalized from the lower detent (`0.0`) to the upper detent (`1.0`), independent of drag direction. `direction` separately reports `up` or `down`.

The native implementation will sample the presented sheet geometry with a `CADisplayLink` while the sheet is moving, calculate the two neighboring detents, and emit frame-synchronized progress values without replacing UIKit's native gesture handling.

A read-only `detentProgress` property may also expose the most recent normalized value.

## Phase 7 — Scroll, keyboard, and interaction parity

Compare behavior with TrueSheet and close remaining UX gaps while staying on public UIKit APIs:

- scroll-view handoff
- keyboard resizing/coordination
- background interaction through `largestUndimmedDetentIdentifier`
- accessibility
- programmatic detent transitions
- iOS 26+ floating sheet appearance

## Phase 8 — API/documentation cleanup

- Remove obsolete fallback documentation and examples.
- Add updated Titanium examples for persistent floating bars and expanding sheets.
- Document events, runtime properties, supported iOS versions, and migration notes.
