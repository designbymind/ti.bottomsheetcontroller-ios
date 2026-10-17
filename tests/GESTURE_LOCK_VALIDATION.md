# 2.3.0 interactive gesture lock — development validation

Recorded October 15, 2026. Consumer: AlloyTestApp, iOS 27 iPhone 18 Pro. Build: Xcode 27.1 beta, Titanium SDK 13.4.1.GA. The module was compiled in an isolated copy with a temporary SDK xcconfig override; the checkout SDK selection was preserved.

Run `DEVELOPER_DIR=/Applications/Xcode-27.1-Beta.app/Contents/Developer python3 tests/run-sheet-pan-gate.py --device <existing-booted-UDID>` for the UIKit harness. Nine checks passed: actual sheet wrapper pan present; lock disables wrapper pans; table/TextArea/keyboard pans stay enabled; navigation content gestures stay enabled; a newly added wrapper pan is captured; programmatic large selection still works; unlock restores owned changes; a pre-disabled pan remains disabled; invalidate restores pans. These are recognizer-state and detent checks, not touch/drag-feel proof.

The module archive passed CRC and manifest checks. Actual library slices: arm64 device and arm64/x86_64 simulator. Older 2.1.0 and 2.2.0 archives retain their pre-change hashes. Initial candidate archive SHA-256: `efb5a5ff8de30abd9e5a6a7ebfae5c72a3c1372890584c77a6197fb436d501b6`.

Installed only under AlloyTestApp/modules/iphone/ti.bottomsheetcontroller/2.3.0. No global registry or remote publication changes. The consumer compiled and loaded successfully. Direct UI checks confirmed medium on open, focus expansion to large with Size disabled and grabber hidden, keyboard display, Hide restoring Size/grabber, and Size returning to medium.

The gate discovers wrapper pans through public UIView/UIGestureRecognizer properties, bounded above the content and below the presentation container. This relies on UIKit hierarchy behavior and needs interaction checks on supported systems. Manual confirmation pending: keyboard pan/reversal while the sheet stays still; multiline growth and history preservation; actual sheet dragging after keyboard hidden; close while editing and reopen. Zoom previously passed manual checks with the older sheet module; no Zoom controller changes were made for 2.3.0.

## User-confirmed iOS 27 interaction results

The initial answer was clarified by the user: focusing expands to large, but dragging the composer moves both the keyboard and sheet down toward medium. The sheet-stays-still claim is withdrawn. Composer layout also misbehaves as the sheet narrows during the drag. After hiding/blurring the keyboard, Size and dragging between medium/large work; sheet dismissal, closing while editing, and reopening also work. Multiline growth/history preservation in this new locked-sheet configuration and physical-device behavior were not independently confirmed by these answers.

## Revised selected-detent lock

After the composer container fix, the user confirmed input/Hide alignment while resizing. They also confirmed that the sheet still moved before the keyboard was hidden; logs showed `detent=medium` while `gestures=false`, input focused, and nonzero keyboard height. The wrapper-pan lock alone was insufficient.

The revised 2.3.0 candidate temporarily removes alternate native detents while locked (iOS 16+), preserving the original detent objects and restoring them on unlock/hide/close. The proxy brackets programmatic selection with restoration/restriction inside UIKit's animation block. All 11 native checks pass, including alternate-detent restriction, restoration of medium/large, and programmatic selection while locked. Temporary native diagnostic logging has been removed. Revised binary candidate SHA-256 before documentation correction: `3d0af832823dd6a1d99e34032f6c15b3e75b690b2188b98dce2cb8f0323cf9c1`. The initial 2.3.0 archive is backed up at `/private/tmp/bottomsheet-2.3.0-initial.zip`; older 2.1.0/2.2.0 packages are unchanged. Gesture confirmation of the revised candidate is pending.

## Revised candidate manual feedback

The user confirmed that the revised candidate stays near large but still bounces/shifts during composer-origin keyboard panning. It must not be described as a complete native gesture lock or a motionless sheet. Resizing/dragging between medium and large after the keyboard is hidden, closing, and reopening all work. Input/Hide alignment was confirmed in the preceding composer-container build and that fix is retained. Architectural preference is pending: retain native sheet elasticity or pursue a custom presentation for strict motion control.

## Accepted native elasticity and coordination checks

The user chose to retain native sheet elasticity and validate composer alignment/keyboard tracking, rather than build a custom presentation. Documentation now explicitly states that `interactiveGesturesEnabled = false` does not guarantee a motionless native sheet. Correcting the packaged HTML changed the archive SHA-256 to `410e3e6c6133f4809b5bb4d554abd198bf1ad5ff896733e6f592b6de8cc02661`; both native libraries were verified byte-identical to the preceding candidate. No native rebuild was needed for that correction. Multiline composer/keyboard tracking and history-preservation questions were sent; results pending.

## Final user coordination confirmation on iOS 27

The user confirmed multiline composer growth followed by keyboard dismissal panning and partial reversal keeps input/Hide aligned, the composer attached without a gap, and the latest message visible above it. While reading older history, composer growth/shrink, keyboard hide/reopen, sheet Size changes after hiding the keyboard, and Append preserve the reading position until Latest is tapped; Latest returns to the bottom. These are manual simulator results for the current Bottom Sheet 2.3.0 / keyboard-control 1.2.1 combination, with the explicitly accepted native sheet elasticity. Physical-device behavior and other iOS versions remain outside this validation.
