# ti.bottomsheetcontroller iOS module

This directory contains the native iOS implementation for `ti.bottomsheetcontroller` 2.3.2.

The default native mode uses Apple's public `UISheetPresentationController` APIs. Version 2.2 adds a separate, optional UIKit full-screen presentation path.

## Platform support

- iOS 18+
- Native system and public custom detents supported
- Titanium SDK 13.3.0.GA or newer, per `manifest`

## Build

Build the module using your normal Titanium iOS module workflow. The module manifest version is `2.3.2`.

## Architecture

Version 2 intentionally keeps the native implementation thin:

- UIKit owns sheet presentation and gestures.
- UIKit owns scrolling/keyboard coordination and accessibility.
- Native/custom detents are configured through public APIs.
- Interactive dismissal is controlled with `modalInPresentation` and the presentation-controller delegate.
- No fallback sheet engine or private detent API remains.
- No custom blur is injected; leaving the background unset allows native UIKit sheet materials such as Liquid Glass to render.

## Public JavaScript API

See the repository root `README.md` for the supported properties, methods, events, migration notes, and working examples.

See `MODERNIZATION.md` for the implementation history and design decisions behind version 2.0.0.

Version 2.1 adds optional native content effects configured with `detentEffects`.
See the root README for configuration and ownership rules.

`hide()`/`show()` retain sheet content between native presentations; `close()` disposes it even while hidden.

Full-screen transitions and scroll coordination live in `TiFullScreenSheetTransition.h/.m`; the proxy retains shared lifecycle ownership.

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
