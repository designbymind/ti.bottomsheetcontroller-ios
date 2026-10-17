# Titanium BottomSheetController for iOS

`ti.bottomsheetcontroller` provides native detent sheets through Apple's `UISheetPresentationController`, plus an optional UIKit full-screen presentation mode.

Version 2.0.0 removes the legacy custom/fallback sheet implementation and focuses on native UIKit behavior: system gestures, named detents, runtime dismissal control, background interaction, scrolling/keyboard coordination, accessibility, and the current iOS sheet appearance including Liquid Glass on iOS 26+.

## Requirements

- iOS 18+
- Native system and public custom detents supported
- Titanium SDK 13.3.0.GA or newer, per the module manifest

## Install

Add the module to `tiapp.xml`:

```xml
<modules>
  <module platform="iphone" version="2.0.0">ti.bottomsheetcontroller</module>
</modules>
```

Then require it from JavaScript:

```js
const BottomSheet = require('ti.bottomsheetcontroller');
```

## Basic usage

```js
const content = Ti.UI.createView({
  backgroundColor: 'transparent'
});

content.add(Ti.UI.createLabel({
  text: 'Hello from the sheet'
}));

const sheet = BottomSheet.createBottomSheet({
  contentView: content,
  detents: ['medium', 'large'],
  startDetent: 'medium'
});

sheet.open();
```

When no `backgroundColor` is supplied, UIKit owns the sheet background. On iOS 26+ this allows the native Liquid Glass sheet appearance to show through.

## Ordered detents

For new code, use the ordered `detents` array. Entries are passed to UIKit in the order supplied and should be listed from smallest to largest.

```js
const sheet = BottomSheet.createBottomSheet({
  contentView: content,
  detents: [
    { identifier: 'bar', height: 76 },
    { identifier: 'reply', height: 390 },
    'large'
  ],
  startDetent: 'bar',
  dismissible: false,
  largestUndimmedDetentIdentifier: 'bar'
});
```

Supported ordered entries:

```js
'medium'
'large'
{ identifier: 'name', height: 320 }
```

Custom detents use Apple's public iOS 16+ custom-detent API.

### Legacy-compatible detent syntax

The older dictionary form remains supported:

```js
detents: {
  medium: true,
  large: true
},
customDetents: {
  preview: 320,
  compose: 600
}
```

For mixed native/custom configurations, the ordered array is recommended because it explicitly defines UIKit's smallest-to-largest order.

## Persistent floating bottom bar

A small custom detent can act as a persistent bottom bar:

```js
const sheet = BottomSheet.createBottomSheet({
  contentView: content,
  detents: [
    { identifier: 'bar', height: 76 },
    'medium',
    'large'
  ],
  startDetent: 'bar',
  dismissible: false,
  largestUndimmedDetentIdentifier: 'bar',
  prefersGrabberVisible: false
});
```

With `dismissible: false`, the user can still drag between detents but cannot drag the sheet away below the lowest detent. `sheet.close()` always remains available for programmatic dismissal.

## Methods and properties

### `open({ animated })`

Presents the sheet.

```js
sheet.open({ animated: true });
```

### `close({ animated })`

Programmatically dismisses the sheet regardless of `dismissible`.

```js
sheet.close({ animated: true });
```

### `selectedDetentIdentifier`

Read-only current detent identifier. System detents are normalized to `medium` and `large`; custom detents return their configured names.

```js
Ti.API.info(sheet.selectedDetentIdentifier);
```

### `changeCurrentDetent(identifier)`

Animates to any configured system or custom detent.

```js
sheet.changeCurrentDetent('reply');
sheet.changeCurrentDetent('large');
```

Invalid or unconfigured identifiers are ignored with a warning.

### `dismissible`

Default: `true`.

```js
sheet.dismissible = false;
sheet.dismissible = true;
```

When `false`, interactive dismissal is blocked while detent-to-detent dragging and programmatic `close()` remain available.

### `largestUndimmedDetentIdentifier`

Specifies the largest configured detent at which the presenting view remains undimmed and interactive.

```js
sheet.largestUndimmedDetentIdentifier = 'bar';
```

Supports `medium`, `large`, and configured custom identifiers.

### Native sheet appearance and interaction properties

These properties map directly to `UISheetPresentationController` and may be set at creation time. Phase 7 also supports updating them on an already-presented sheet:

```js
sheet.prefersScrollingExpandsWhenScrolledToEdge = true;
sheet.prefersEdgeAttachedInCompactHeight = true;
sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true;
sheet.prefersGrabberVisible = true;
sheet.preferredCornerRadius = 28;
```

If these properties are not supplied, the module preserves UIKit's native defaults.

### `backgroundColor`

Optional. Leave unset to allow the native system sheet material to render.

```js
// Native UIKit material / Liquid Glass on supported iOS versions
const sheet = BottomSheet.createBottomSheet({
  contentView: content
});

// Explicit visual override
const opaqueSheet = BottomSheet.createBottomSheet({
  contentView: content,
  backgroundColor: '#ffffff'
});
```

`backgroundColor: 'transparent'` explicitly sets the presented controller background to clear.

### `contentView`

The Titanium View, Window, or NavigationWindow presented by the sheet.

### `closeButton`

Optional Titanium View or Button added over the sheet content.

## Events

### `open`

Fired after UIKit finishes presenting the sheet.

### `close`

Fired after the sheet has been dismissed.

### `dismissing`

Fired when an allowed interactive dismissal is beginning.

### `detentChange`

Fired after manual detent changes and supported programmatic transitions.

```js
sheet.addEventListener('detentChange', e => {
  Ti.API.info('Selected detent: ' + e.selectedDetentIdentifier);
});
```

Example payload:

```js
{
  selectedDetentIdentifier: 'reply'
}
```

## Complete example

```js
const BottomSheet = require('ti.bottomsheetcontroller');

const win = Ti.UI.createWindow({
  backgroundColor: '#f5f5f5'
});

const openButton = Ti.UI.createButton({
  title: 'Open Bottom Sheet'
});

win.add(openButton);
win.open();

openButton.addEventListener('click', () => {
  const content = Ti.UI.createView({
    backgroundColor: 'transparent'
  });

  content.add(Ti.UI.createLabel({
    text: 'Drag the sheet between detents',
    top: 30
  }));

  const sheet = BottomSheet.createBottomSheet({
    contentView: content,
    detents: [
      { identifier: 'bar', height: 96 },
      { identifier: 'preview', height: 320 },
      'large'
    ],
    startDetent: 'bar',
    dismissible: false,
    largestUndimmedDetentIdentifier: 'bar',
    prefersGrabberVisible: true
  });

  sheet.addEventListener('detentChange', e => {
    Ti.API.info('detentChange: ' + e.selectedDetentIdentifier);
  });

  sheet.addEventListener('close', () => {
    Ti.API.info('Bottom sheet closed');
  });

  sheet.open({ animated: true });
});
```

## Migration from 1.x

Version 2.0.0 is system-sheet-only. The legacy `nonSystemSheet*` properties and fallback controller have been removed. Applications should migrate to native system/custom detents, `dismissible`, and `largestUndimmedDetentIdentifier`.

Notable v2 behavior:

- Native UIKit presentation only.
- Public named custom detents on iOS 16+.
- Ordered mixed detents.
- Runtime `dismissible` control.
- Friendly `medium` / `large` identifiers.
- Runtime native sheet appearance/interaction properties.
- Native Liquid Glass appearance when no custom background is supplied on iOS 26+.
- Continuous frame-by-frame detent progress is intentionally not implemented in v2.0.0.

See `MODERNIZATION.md` for the implementation history and design decisions.

## License

MIT

## Author

Marc Bender & DesignByMind


## Optional native image effects (2.1.0)

`detentEffects` is a creation-time configuration for visual effects on existing
Titanium views inside the sheet. Omit it for ordinary sheet behavior. UIKit still
owns detents, gestures, scrolling, presentation, and dismissal. Effects run on the
native main thread without per-frame JavaScript events.

```js
detentEffects: {
  startHeight: 96,
  endHeight: 420,
  views: [{
    view: coverImage,
    from: { scale: 0.25, opacity: 0.6, translationY: -120, cornerRadius: 64 },
    to:   { scale: 1, opacity: 1, translationY: 0, cornerRadius: 0 }
  }]
}
```

Progress is clamped to 0…1 between the configured heights. Values interpolate
linearly in both directions and remain at their endpoints outside that range.
Heights are visible sheet viewport points, excluding the bottom safe area when
edge-attached, matching custom detent height conventions. Use explicit custom
heights for predictable endpoints; `medium` and `large` vary with device and
presentation. Rotation or keyboard changes can also change visible geometry.

Each entry requires a `view` descendant of the sheet content (not the content root).
`from` and `to` accept `scale` (uniform, around the view center), `opacity` (0…1),
`translationX`, `translationY`, and `cornerRadius` (points before scaling).
A radius of 64 at scale 0.25 appears as a 16-point radius. Translation uses points.
Missing `from` values use scale 1, translation 0, and the original opacity/radius;
missing `to` values keep the corresponding start value. Invalid numeric values use
those defaults. Invalid height ranges disable effects with a warning; invalid or
duplicate targets are skipped.

Use a square ImageView sized for its final cover position. Scale/translation alter
its visual presentation without resizing its Titanium layout or moving siblings.
The example includes an original landscape illustration; replace `cover.png` with
your photo. Corner-radius effects enable clipping. Existing layer properties are
restored on close. Do not animate the same properties from JavaScript while the
effect owns them. Target views must remain inside the sheet for its lifetime.

Effects are sampled at display refresh while the sheet is open and configured.
No tracker is created when the option is omitted or contains no valid targets.
There is no continuous progress event, blur, glow, title morph, or scroll-header
behavior in this version. Runtime replacement of this configuration is not
supported; configure it when creating a new sheet.


## Retaining a sheet with hide() and show() (2.1.0)

Call `open()` once, then use `hide({ animated: true })` to dismiss the native
presentation without disposing the sheet or its content. `show({ animated: true })`
presents the retained controller/content again and restores the last selected
detent. Both default to animated transitions. Content values and scroll positions
are retained; UIKit may adjust layout/scrolling if the available geometry changes.

```js
sheet.addEventListener('hide', () => {
  // The native dismissal has completed; show your annotation card here.
});
sheet.hide({ animated: true });
// After the card has closed:
sheet.show({ animated: true });
```

`open` fires only for initial presentation. `hide` and `show` fire when their
respective transitions complete. Hiding does not fire `close` or the interactive
`dismissing` event. `close()` remains the final disposal operation and works while
hidden; a hidden sheet retains memory until you call it. Existing interactive
swipe dismissal still closes/disposes a dismissible sheet.

Calling hide while hidden, show while visible, or either before open/after close
has no effect. Requests during initial opening/hiding/showing are serialized: the
latest pending visibility request wins; a queued close takes priority and cannot
be canceled by show/hide. No-op calls emit no completion event.

Close any modal presented by the sheet itself before hiding it. Before showing,
finish dismissing any intervening card/modal; show presents from Titanium's current
top controller. Hide is rejected if the sheet owns a presented modal, and show is
rejected if its presenter is transitioning or detached. These rejected calls log a
warning and emit no completion event. `open()` does not restore a hidden sheet;
use `show()`. Creation-time detentEffects pause while hidden and resume on show.


## Full-screen presentation (2.2.0)

Version 2.3.1 lays out embedded navigation content before validating `scrollView`,
so a TableView inside a NavigationWindow can be used for full-screen dismissal.
Scroll views outside the content hierarchy are still rejected.

The default `presentationMode: 'native'` retains Apple's detent-based system
sheet. Opt into `presentationMode: 'fullScreen'` for a UIKit full-screen sheet with
interactive downward dismissal. Both use `open`, `hide`, `show`, and `close` and
share lifecycle events. Full-screen mode has one expanded state: native detents,
`changeCurrentDetent`, largest-undimmed settings, and `detentEffects` do not apply;
`selectedDetentIdentifier` returns `none`.

```js
const sheet = BottomSheet.createBottomSheet({
  presentationMode: 'fullScreen',
  contentView: content,
  scrollView: table, // Optional, inside content; omit for non-scrolling content.
  scalesPresentingView: true, // Omit/false for a stationary background.
  fadesPresentingView: true, // Optional dimming, independent of scaling (2.3.2).
  presentingViewScale: 0.9,
  presentingViewCornerRadius: 50,
  fullScreenCornerRadius: 30,
  backgroundColor: '#92603e',
  dismissible: true
});
sheet.open({ animated: true });
```

| Property | Default | Full-screen behavior |
| --- | --- | --- |
| `scrollView` | unset | Explicit Titanium ScrollView, TableView, or ListView within content to coordinate with dismissal. |
| `scalesPresentingView` | `false` | Recess the actual presenting controller's view; restore it during dismissal. |
| `fadesPresentingView` | `false` | Dim the presenting view with a black overlay at 40% opacity. Full-screen only; independent of scaling (2.3.2). |
| `presentingViewScale` | `0.9` | Scale when fully presented, clamped to 0.5–1. |
| `presentingViewCornerRadius` | `50` | Recessed presenter radius in points. |
| `fullScreenCornerRadius` | `30` | Sheet radius in points; zero gives square corners. |
| `underlayColor` | black | Color exposed behind the recessed presenter. |
| `prefersGrabberVisible` | `true` | Show a grabber above the content. |
| `backgroundColor` | system background | Color of the full-screen controller, behind Titanium content. |
| `dismissible` | `true` | Allow gesture dismissal; programmatic hide/close remain available. |

Set `fadesPresentingView: true` for dimming alone, or enable both
`fadesPresentingView` and `scalesPresentingView` for scaling plus dimming. The
dimming follows the same interactive animation, returns on canceled dismissal,
and is removed on hide/close and recreated on show. It leaves the presenting
view's own opacity unchanged. These options do not change native sheet dimming.

Animated full-screen presentation and dismissal use a 425 ms ease-in/ease-out
transition, including optional scaling and dimming. `animated: false` skips it.
Interactive dismissal follows the gesture; its remaining completion time varies
with progress and velocity. Native sheet timing remains controlled by iOS.

Configure mode, scroll reference, and appearance at creation time. Scale, translation,
and corner restoration use the presenter's captured original properties, rather
than assuming it began with an identity transform. Both sheet movement and presenter
scaling use one interruptible native animator. A canceled/insufficient drag returns
them to their presented state. Presentation uses the active controller/container's
geometry and safe areas; it does not select an arbitrary key window or its first
subview. Provide content padding for the grabber and close overlay; the module does
not insert/reflow your Titanium content.

The bound scroll view keeps its existing delegate. It scrolls normally above the
top; a downward drag can transfer to dismissal when its adjusted content offset
reaches the top. While dismissal is active, its content offset is held at the top without disabling
its active pan recognizer. Its original bounce setting is restored on finish/cancel. Horizontal gestures, controls, and unbound or
nested scroll surfaces are excluded. For multiple scrolling regions, select the one
you intend to coordinate; this version does not dynamically choose among them.

Use the explicit `presentationMode` option for this feature, rather than the legacy
`modalPresentation: 'fullScreen'` property. That property belongs to the native-sheet
configuration path. Full-screen mode is a custom UIKit presentation, and does not
promise system-sheet Liquid Glass materials or automatic system detent behavior.

See the two full-screen buttons in `example/app.js` for stationary/scaled styles.

## Interactive gesture control (2.3.0)

`interactiveGesturesEnabled` defaults to `true` and can be changed at creation or runtime. Set it to `false` to lock the selected native detent and suppress wrapper pan recognizers, while content controls, scrolling, and programmatic `close()` / `changeCurrentDetent()` remain available. This does **not** guarantee a motionless native sheet: on iOS 27 the user still observes elastic motion near the locked large detent. It also controls the module-owned drag in full-screen mode. `dismissible` remains the separate policy for allowing dismissal while gestures are enabled.

```js
// Keep medium and large configured. Call when the keyboard gains ownership.
sheet.interactiveGesturesEnabled = false;
sheet.changeCurrentDetent('large');
// Once the keyboard is hidden:
sheet.interactiveGesturesEnabled = true;
```

For native sheets, this opt-in lock disables pan recognizers on the presentation wrappers above the content, bounded by the presentation container. It does not enumerate the content subtree, replace UIKit delegates, or use private classes/selectors. On iOS 16+, the lock also temporarily restricts UIKit to the selected detent, preventing an alternate detent from being selected during interactive keyboard avoidance. The configured detent list is restored on unlock, hide, or close; programmatic selection through `changeCurrentDetent()` remains supported while locked. Only recognizers disabled by the module are restored. Wrapper discovery is refreshed while locked to handle UIKit layout changes; behavior should be checked on each supported iOS release. The selected detent is not automatically restored when unlocking.
