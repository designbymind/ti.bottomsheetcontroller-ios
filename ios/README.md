# ti.bottomsheetcontroller iOS module

This directory contains the native iOS implementation for `ti.bottomsheetcontroller` 2.0.0.

The module is backed exclusively by Apple's public `UISheetPresentationController` APIs.

## Platform support

- iOS 15+ for native system sheets
- iOS 16+ for public custom detents
- Titanium SDK 13.3.0.GA or newer, per `manifest`

## Build

Build the module using your normal Titanium iOS module workflow. The module manifest version is `2.0.0`.

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
