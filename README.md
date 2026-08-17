# Titanium BottomSheetController for iOS

`ti.bottomsheetcontroller` is a Titanium iOS module backed exclusively by Apple's native `UISheetPresentationController`.

Version 2.0.0 removes the legacy custom/fallback sheet implementation and focuses on native UIKit behavior: system gestures, named detents, runtime dismissal control, background interaction, scrolling/keyboard coordination, accessibility, and the current iOS sheet appearance including Liquid Glass on iOS 26+.

## Requirements

- iOS 15+ for native `UISheetPresentationController`
- iOS 16+ for public custom detents
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
