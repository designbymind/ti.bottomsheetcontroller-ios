# ti.bottomsheetcontroller

Native iOS bottom sheets for Titanium, backed by `UISheetPresentationController`.

Version 2.0.0 is system-sheet-only and supports native UIKit gestures, system detents, named custom detents, runtime dismissal control, background interaction, and native iOS appearance including Liquid Glass on iOS 26+.

## Access

```js
const BottomSheet = require('ti.bottomsheetcontroller');
```

## Create a sheet

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
  largestUndimmedDetentIdentifier: 'bar'
});

sheet.open();
```

## Methods

- `open({ animated })`
- `close({ animated })`
- `changeCurrentDetent(identifier)`

## Properties

- `selectedDetentIdentifier` — read-only current detent name.
- `dismissible` — enables/disables interactive dismissal at runtime.
- `detents` — ordered array of `medium`, `large`, or `{ identifier, height }` custom detents.
- `customDetents` — legacy-compatible custom-detent dictionary.
- `startDetent` — initial configured detent identifier.
- `largestUndimmedDetentIdentifier` — largest detent that keeps the presenting view undimmed/interactable.
- `prefersScrollingExpandsWhenScrolledToEdge`
- `prefersEdgeAttachedInCompactHeight`
- `widthFollowsPreferredContentSizeWhenEdgeAttached`
- `prefersGrabberVisible`
- `preferredCornerRadius`
- `backgroundColor`
- `contentView`
- `closeButton`

Unless explicitly supplied, native UIKit sheet properties keep their system defaults.

## Events

- `open`
- `close`
- `dismissing`
- `detentChange` — payload contains `selectedDetentIdentifier`.

## Platform behavior

- iOS 15+ uses `UISheetPresentationController`.
- Custom detents require iOS 16+.
- Leaving `backgroundColor` unset allows UIKit to render its native sheet material, including Liquid Glass on iOS 26+.
- Keyboard coordination, scroll handoff, accessibility, and sheet gestures remain UIKit-owned.

## Migration from 1.x

The legacy custom/fallback sheet implementation and all `nonSystemSheet*` properties were removed in 2.0.0. Migrate to native detents, `dismissible`, and `largestUndimmedDetentIdentifier`.

See the repository `README.md` for complete examples and `MODERNIZATION.md` for the v2 implementation history.

## License

MIT
