//
//  UISheetPresentationControllerDetent+CustomDetent.m
//  ti.bottomsheetcontroller
//
//  Public UIKit custom-detent helper.
//

#import "UISheetPresentationControllerDetent+CustomDetent.h"

@implementation UISheetPresentationControllerDetent (CustomDetent)

+ (instancetype)ti_customDetentWithIdentifier:(UISheetPresentationControllerDetentIdentifier)identifier
                                       height:(CGFloat)height
{
    return [UISheetPresentationControllerDetent customDetentWithIdentifier:identifier
                                                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
        CGFloat resolvedHeight = MAX(0.0, height);
        return MIN(resolvedHeight, context.maximumDetentValue);
    }];
}

@end
