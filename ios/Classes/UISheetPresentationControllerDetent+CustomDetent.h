//
//  UISheetPresentationControllerDetent+CustomDetent.h
//  ti.bottomsheetcontroller
//
//  Public UIKit custom-detent helper.
//

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface UISheetPresentationControllerDetent (CustomDetent)

/// Creates a named custom detent using Apple's public iOS 16+ resolver API.
/// The identifier is the same identifier exposed to Titanium (for example "bar").
/// The resolved height is clamped to UIKit's maximum detent value.
+ (instancetype)ti_customDetentWithIdentifier:(UISheetPresentationControllerDetentIdentifier)identifier
                                       height:(CGFloat)height API_AVAILABLE(ios(16.0), macCatalyst(16.0));

@end

NS_ASSUME_NONNULL_END
