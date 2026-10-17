# Local validation

These Classic Titanium harnesses exercise an app-local installation of the module.

## 2.3.2 package validation, October 17, 2026

The module built successfully with Titanium SDK 13.4.1.GA and Xcode 27.1 Beta.
The archive passed CRC and source-manifest checks; its native libraries include
the new `fadesPresentingView` option and contain arm64 device and arm64/x86_64
simulator slices. The example passed JavaScript syntax checking. Dimming's
visual behavior has not yet been verified on a simulator or physical device.

Archive SHA-256: `48fbb3baefaefb97b0636a1f2b8fa8f7b280cf830a04a5710cc49c6031e2ccbc`

- `full-screen-navigation.js`: call `require('full-screen-navigation').run()` with module 2.3.1. Covers nested NavigationWindow/TableView presentation, reopen, gesture-lock properties, hide/show, native-sheet compatibility, and rejection of an unrelated table. Saves `full-screen-navigation-result.json`.

### Navigation regression result, October 17, 2026

Module 2.3.1 passed all 16 checks on the iOS 27.0 iPhone 18 Pro simulator with
Titanium SDK 13.4.1.GA and Xcode 27.1 Beta. Before the fix, a focused UIKit
reproduction showed the table outside the navigation host until layout ran.
The module now lays out the content before checking its explicit scroll reference.
AlloyTestApp also built successfully with its app-local 2.3.1 dependency.
These checks cover presentation and lifecycle; they do not prove keyboard motion
or interactive dismissal feel in the Alloy chat composer.

- `full-screen.js`: call `require('full-screen').run()`. Covers both presenter styles, plain/window content, TableView, ListView, ScrollView, retained hide/show, queued requests, close, and the `dismissible` property.
- `hide-show.js`: call `require('hide-show').run()`. Covers the native detent presentation's retained lifecycle and `dismissible` property.
- `full-screen-gestures.js`: call `require('full-screen-gestures').run()`. Provides interactive fixtures for scrolling, dismissal, cancellation, and dismissal locking.

## Recorded results, October 10, 2026

The test app's saved results report:

- Fullscreen lifecycle: PASS, 74 checks, 24 cycles, two presenter styles.
- Native lifecycle: PASS, 89 checks, 16 cycles; also confirmed by the user.

Interactive TableView and ListView dismissal was exercised in the simulator. The user reports that fullscreen basics work well. Lifecycle checks do not prove gesture handoff or visual correctness.

The user also directly confirmed that pulling down at the top of a regular ScrollView hands off to sheet dismissal. This resolves the earlier concern raised by an automated simulator drag that did not initiate dismissal; no source fix was needed. For future gesture checks, release a short, slow drag to cancel and confirm scrolling still works, pull farther to dismiss, and confirm `Lock drag` prevents dismissal.

## Verified archive

`ios/dist/ti.bottomsheetcontroller-iphone-2.2.0.zip` passed ZIP integrity checks and matches the source manifest. Its XCFramework declares arm64 device and arm64/x86_64 simulator slices. Temporary diagnostic tracing is absent.

SHA-256: `3bb8d5b796ddf562137ba717cb1b2b9eff1e6036b4434b00cb4b244e89e27636`

This is local validation of the candidate archive, not a published release or proof of hardware interaction behavior.
