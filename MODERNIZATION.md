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

## Phase 1 — System-sheet-only cleanup ✅

- Remove all `nonSystemSheet` configuration and runtime branches.
- Remove the custom fallback controller implementation.
- Keep `UISheetPresentationController` as the only sheet engine.
- Preserve existing native-sheet properties and lifecycle behavior.

Phase 1 has been build-tested successfully. A Titanium lifecycle regression discovered during testing was corrected by restoring deferred content layout before presentation.

## Phase 2 — Runtime dismissal control ✅

Add `dismissible` (default `true`).

- `dismissible = false` prevents user-initiated interactive dismissal.
- Detent-to-detent dragging remains available.
- `sheet.close()` remains available regardless of `dismissible`.
- Changing `dismissible` while the sheet is presented takes effect immediately.

Example:

```js
const sheet = BottomSheet.createBottomSheet({
  contentView: content,
  dismissible: false
});

sheet.open();

// Runtime changes take effect immediately.
sheet.dismissible = true;
sheet.dismissible = false;

// Programmatic dismissal is always allowed.
sheet.close();
```

Implementation uses the presented controller's public `modalInPresentation` property together with the presentation-controller delegate. The `dismissing` event is emitted only when an interactive dismissal is actually allowed.

Phase 2 has been build-tested successfully, including runtime enable/disable in both directions, detent panning, and programmatic `close()`.

## Phase 3 — Public named custom detents ✅

Replace the legacy private detent API with Apple's public iOS 16+ custom-detent resolver API.

Legacy-compatible example:

```js
customDetents: {
  bar: 76,
  preview: 320,
  compose: 600
}
```

Custom identifiers such as `bar`, `preview`, and `compose` are now the actual UIKit `UISheetPresentationControllerDetentIdentifier` values. Static custom heights are clamped to UIKit's `maximumDetentValue`.

On iOS 15, native `medium` / `large` detents remain supported, while custom detents are ignored with a warning because Apple's public custom-detent resolver API starts in iOS 16.

Phase 3 has been build-tested successfully with custom-only and mixed custom/native detent configurations, including named `startDetent` behavior.

## Phase 4 — Unified detent selection and events ✅

Native and custom detents share the same Titanium-facing identifier path:

```js
sheet.changeCurrentDetent('bar');
sheet.changeCurrentDetent('medium');
sheet.changeCurrentDetent('large');
```

- `selectedDetentIdentifier` returns friendly `medium` / `large` names for system detents and the configured name for custom detents.
- `changeCurrentDetent(identifier)` accepts any configured detent identifier and animates to it with `animateChanges:`.
- Invalid/unconfigured identifiers are ignored with a warning rather than being sent to UIKit.
- `detentChange` emits the same normalized identifier for manual and programmatic changes.
- The proxy maintains a registry of identifiers actually installed on the current sheet.

Phase 4 has been build-tested successfully for manual and programmatic transitions across custom and system detents.

## Phase 5 — Floating bottom-bar behavior ✅

Phase 5 adds an ordered detent API so the native sheet itself can serve as a persistent floating bottom bar at its smallest detent and expand upward through larger states.

Recommended v2 configuration:

```js
const sheet = BottomSheet.createBottomSheet({
  contentView: content,

  // Explicitly smallest -> largest.
  detents: [
    { identifier: 'bar', height: 76 },
    { identifier: 'reply', height: 390 },
    'medium',
    'large'
  ],

  startDetent: 'bar',
  dismissible: false,
  largestUndimmedDetentIdentifier: 'bar',
  prefersGrabberVisible: false
});
```

Ordered `detents` entries may be:

- `'medium'`
- `'large'`
- `{ identifier: 'name', height: number }`

The array order is passed directly to UIKit and must be smallest to largest. This avoids relying on dictionary enumeration or attempting to infer where dynamically sized system detents belong relative to fixed custom detents.

With `dismissible: false`, the sheet can pan between all configured detents but cannot be dragged away below the smallest detent. Programmatic `close()` still works. Setting `largestUndimmedDetentIdentifier: 'bar'` keeps the presenting content interactive while the sheet rests at the bar detent and allows UIKit's normal dimming behavior above it.

The legacy API remains supported:

```js
detents: {
  medium: true,
  large: true
},
customDetents: {
  bar: 76,
  reply: 390
}
```

For new mixed custom/system configurations, the ordered array form is preferred. If ordered `detents` is supplied, separate `customDetents` is ignored with a warning.

Phase 5 has been build-tested successfully, including the ordered detent API, persistent lowest-detent behavior, manual and programmatic transitions, background interaction at the undimmed detent, dismissal prevention, and programmatic `close()`.

## Phase 5.5 — Native Liquid Glass appearance ✅

The module no longer paints a default light-gray background over the presented sheet. When no `backgroundColor` is provided, the presented controller view is transparent so UIKit can render the native system sheet material, including Liquid Glass on iOS 26+.

```js
const sheet = BottomSheet.createBottomSheet({
  contentView: content,
  detents: [
    { identifier: 'bar', height: 76 },
    'medium',
    'large'
  ],
  startDetent: 'bar',
  dismissible: false
});
```

No `backgroundColor` means UIKit owns the sheet appearance. An explicitly supplied `backgroundColor` remains supported as an intentional override. `backgroundColor: 'transparent'` also maps to a clear controller background.

This phase intentionally does not add a custom `UIVisualEffectView` or simulated blur; it preserves the system presentation so current iOS appearance and behavior can evolve with UIKit.

Phase 5.5 has been build-tested successfully on iOS 26 and confirmed to display the native Liquid Glass sheet appearance when no custom background color is supplied.

## Phase 6 — Continuous detent progress — DEFERRED

Continuous frame-by-frame detent progress is intentionally deferred. The current module remains a thin UIKit wrapper without a custom display-link/geometry-sampling subsystem. The feature can be revisited later if a concrete UI requirement justifies the added native and bridge complexity.

## Phase 7 — Scroll, keyboard, and interaction parity — IMPLEMENTED, TEST PENDING

Phase 7 focuses on native UIKit parity rather than adding custom interaction machinery.

- UIKit defaults are now preserved unless a Titanium property explicitly overrides them. This applies to scrolling expansion, compact-height edge attachment, edge-attached width behavior, grabber visibility, and corner radius.
- `prefersScrollingExpandsWhenScrolledToEdge`, `prefersEdgeAttachedInCompactHeight`, `widthFollowsPreferredContentSizeWhenEdgeAttached`, `prefersGrabberVisible`, and `preferredCornerRadius` can now update the presented system sheet at runtime.
- `largestUndimmedDetentIdentifier` supports runtime updates using friendly/custom identifiers and validates that the target detent is actually configured before applying it.
- `changeCurrentDetent()` now dispatches UIKit detent animation work onto the main thread.
- Keyboard resizing, scroll-view handoff, accessibility, and iOS 26+ floating/Liquid Glass presentation remain UIKit-owned. No custom keyboard observer, gesture recognizer, or accessibility replacement was added.

Recommended validation covers scroll views at multiple detents, keyboard presentation/dismissal, background interaction at the configured undimmed detent, runtime property changes, rotation/compact-height behavior, VoiceOver, and manual/programmatic detent transitions.

## Phase 8 — API/documentation cleanup

- Remove obsolete fallback documentation and examples.
- Add updated Titanium examples for persistent floating bars and expanding sheets.
- Document events, runtime properties, supported iOS versions, and migration notes.
