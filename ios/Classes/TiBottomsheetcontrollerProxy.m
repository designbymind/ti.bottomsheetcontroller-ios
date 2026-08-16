/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2021 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#define USE_TI_UINAVIGATIONWINDOW

#import "TiBottomsheetcontrollerProxy.h"
#import "TiBottomsheetcontrollerModule.h"
#import "UISheetPresentationControllerDetent+CustomDetent.h"
#import <TitaniumKit/TiApp.h>
#import <TitaniumKit/TiUtils.h>
#import <TitaniumKit/TiWindowProxy.h>

static NSString *TiPublicDetentIdentifier(UISheetPresentationControllerDetentIdentifier identifier)
{
  if (identifier == nil) {
    return nil;
  }

  if ([identifier isEqualToString:UISheetPresentationControllerDetentIdentifierMedium]) {
    return @"medium";
  }

  if ([identifier isEqualToString:UISheetPresentationControllerDetentIdentifierLarge]) {
    return @"large";
  }

  return identifier;
}

static UISheetPresentationControllerDetentIdentifier TiNativeDetentIdentifier(NSString *identifier)
{
  if ([identifier isEqualToString:@"medium"]) {
    return UISheetPresentationControllerDetentIdentifierMedium;
  }

  if ([identifier isEqualToString:@"large"]) {
    return UISheetPresentationControllerDetentIdentifierLarge;
  }

  return (UISheetPresentationControllerDetentIdentifier)identifier;
}

@implementation TiBottomsheetcontrollerProxy

#pragma mark - Setup

- (id)init
{
  if (self = [super init]) {
    poWidth = TiDimensionUndefined;
    poHeight = TiDimensionUndefined;
    bottomSheetInitialized = NO;
    eventFired = NO;
    isDismissing = NO;
    dismissible = YES;
    deviceRotated = NO;
    configuredDetentIdentifiers = [[NSMutableSet alloc] init];

    UIViewController<TiControllerContainment> *topContainerController = [[[TiApp app] controller] topContainerController];
    bottomSheetSafeAreaInset = [[topContainerController hostingView] safeAreaInsets];
  }

  return self;
}

- (void)dealloc
{
  if (viewController != nil && viewController.isViewLoaded) {
    @try {
      [viewController.view removeObserver:self forKeyPath:@"safeAreaInsets"];
    } @catch (NSException *exception) {
      // Observer may already have been removed during cleanup.
    }
  }

  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
    bottomSheet.delegate = nil;
  }

  RELEASE_TO_NIL(bottomSheet);
  RELEASE_TO_NIL(viewController);
  RELEASE_TO_NIL(contentViewProxy);
  RELEASE_TO_NIL(closeButtonProxy);
  RELEASE_TO_NIL(closeButtonView);
  RELEASE_TO_NIL(configuredDetentIdentifiers);
  RELEASE_TO_NIL(_detents);
  RELEASE_TO_NIL(_largestUndimmedDetentIdentifier);

  [super dealloc];
}

#pragma mark - Public API

- (NSString *)apiName
{
  return @"Ti.UI.BottomSheetController";
}

- (NSString *)selectedDetentIdentifier
{
  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
    NSString *identifier = TiPublicDetentIdentifier(bottomSheet.selectedDetentIdentifier);
    if (identifier != nil) {
      return identifier;
    }
  }

  return @"none";
}

- (void)changeCurrentDetent:(id)value
{
  ENSURE_ARG_COUNT(value, 1);

  NSString *requestedIdentifier = [TiUtils stringValue:[value objectAtIndex:0]];

  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
    if (bottomSheet == nil || requestedIdentifier == nil) {
      return;
    }

    UISheetPresentationControllerDetentIdentifier nativeIdentifier = TiNativeDetentIdentifier(requestedIdentifier);

    if (![configuredDetentIdentifiers containsObject:nativeIdentifier]) {
      NSLog(@"[WARN] BottomSheet detent '%@' is not configured. Ignoring changeCurrentDetent().", requestedIdentifier);
      return;
    }

    [bottomSheet animateChanges:^{
      self->bottomSheet.selectedDetentIdentifier = nativeIdentifier;
    }];
  }
}

- (void)setDismissible:(id)value
{
  dismissible = [TiUtils boolValue:value def:YES];
  [self replaceValue:[NSNumber numberWithBool:dismissible] forKey:@"dismissible" notification:NO];

  TiThreadPerformOnMainThread(^{
    if (self->viewController != nil) {
      self->viewController.modalInPresentation = !self->dismissible;
    }
  }, NO);
}

- (BOOL)dismissible
{
  return dismissible;
}

- (void)setLargestUndimmedDetentIdentifier:(id)value
{
  NSString *identifier = [TiUtils stringValue:value];

  RELEASE_TO_NIL(_largestUndimmedDetentIdentifier);

  if ([identifier isEqualToString:@"large"]) {
    _largestUndimmedDetentIdentifier = [UISheetPresentationControllerDetentIdentifierLarge copy];
  } else if ([identifier isEqualToString:@"medium"]) {
    _largestUndimmedDetentIdentifier = [UISheetPresentationControllerDetentIdentifierMedium copy];
  } else {
    _largestUndimmedDetentIdentifier = [identifier copy];
  }

  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
    if (bottomSheet != nil) {
      bottomSheet.largestUndimmedDetentIdentifier = _largestUndimmedDetentIdentifier;
    }
  }
}

- (void)setCloseButton:(id)value
{
  ENSURE_SINGLE_ARG(value, TiViewProxy);

  RELEASE_TO_NIL(closeButtonProxy);
  closeButtonProxy = [(TiViewProxy *)value retain];
  [self replaceValue:closeButtonProxy forKey:@"closeButton" notification:NO];
}

- (void)setContentView:(id)value
{
  ENSURE_SINGLE_ARG(value, TiViewProxy);

  RELEASE_TO_NIL(contentViewProxy);
  contentViewProxy = [(TiViewProxy *)value retain];
  self.viewProxy = contentViewProxy;
  [self replaceValue:contentViewProxy forKey:@"contentView" notification:NO];
}

- (void)addEventListener:(NSArray *)args
{
  NSString *type = [args objectAtIndex:0];
  if (![self _hasListeners:type]) {
    [super addEventListener:args];
  }
}

- (void)open:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);

  if (bottomSheetInitialized) {
    NSLog(@"[ERROR] BottomSheet is open. Ignoring call");
    return;
  }

  if (contentViewProxy == nil) {
    NSLog(@"[ERROR] BottomSheet has no contentView. Ignoring call");
    return;
  }

  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
    eventFired = NO;
    bottomSheetInitialized = YES;
    animated = [TiUtils boolValue:@"animated" properties:args def:YES];

    [self rememberSelf];
    [self retain];

    TiThreadPerformOnMainThread(^{
      [self initAndShowSheetController];
      self->isDismissing = NO;
    }, YES);
  } else {
    NSLog(@"[ERROR] ti.bottomsheetcontroller requires iOS 15.0 or newer.");
  }
}

- (void)close:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);

  if (!bottomSheetInitialized) {
    NSLog(@"BottomSheet is not open. Ignoring call");
    return;
  }

  TiThreadPerformOnMainThread(^{
    [self->contentViewProxy windowWillClose];
    self->animated = [TiUtils boolValue:@"animated" properties:args def:YES];

    [[self viewController] dismissViewControllerAnimated:self->animated completion:^{
      if (!self->eventFired) {
        self->eventFired = YES;
        [self fireEvent:@"close" withObject:nil];
        [self cleanup];
      }
    }];
  }, YES);
}

#pragma mark - Controller lifecycle

- (UIViewController *)viewController
{
  if (viewController == nil) {
    if ([contentViewProxy isKindOfClass:[TiWindowProxy class]]) {
      [(TiWindowProxy *)contentViewProxy setIsManaged:YES];
      viewController = [[(TiWindowProxy *)contentViewProxy hostingController] retain];
    } else {
      viewController = [[TiViewController alloc] initWithViewProxy:contentViewProxy];
    }

    [viewController.view addObserver:self
                          forKeyPath:@"safeAreaInsets"
                             options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                             context:nil];
  }

  viewController.view.clipsToBounds = NO;
  return viewController;
}

- (void)cleanup
{
  [contentViewProxy setProxyObserver:nil];
  [contentViewProxy windowWillClose];
  [contentViewProxy windowDidClose];

  if ([contentViewProxy isKindOfClass:[TiWindowProxy class]]) {
    UIView *topWindowView = [[[TiApp app] controller] topWindowProxyView];
    if ([topWindowView isKindOfClass:[TiUIView class]]) {
      TiViewProxy *theProxy = (TiViewProxy *)[(TiUIView *)topWindowView proxy];
      if ([theProxy conformsToProtocol:@protocol(TiWindowProtocol)]) {
        [(id<TiWindowProtocol>)theProxy gainFocus];
      }
    }
  }

  if (viewController != nil && viewController.isViewLoaded) {
    @try {
      [viewController.view removeObserver:self forKeyPath:@"safeAreaInsets"];
    } @catch (NSException *exception) {
      // Observer may already have been removed.
    }
  }

  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
    bottomSheet.delegate = nil;
  }

  bottomSheetInitialized = NO;
  isDismissing = NO;
  [configuredDetentIdentifiers removeAllObjects];

  RELEASE_TO_NIL(bottomSheet);
  RELEASE_TO_NIL(viewController);
  RELEASE_TO_NIL(closeButtonView);
  RELEASE_TO_NIL(closeButtonProxy);
  RELEASE_TO_NIL(contentViewProxy);
  RELEASE_TO_NIL(_detents);
  RELEASE_TO_NIL(_largestUndimmedDetentIdentifier);

  [self forgetSelf];
  [self _destroy];
  [self autorelease];
}

- (void)initAndShowSheetController
{
  deviceRotated = NO;
  [contentViewProxy setProxyObserver:self];

  if ([contentViewProxy isKindOfClass:[TiWindowProxy class]]) {
    UIView *topWindowView = [[[TiApp app] controller] topWindowProxyView];
    if ([topWindowView isKindOfClass:[TiUIView class]]) {
      TiViewProxy *theProxy = (TiViewProxy *)[(TiUIView *)topWindowView proxy];
      if ([theProxy conformsToProtocol:@protocol(TiWindowProtocol)]) {
        [(id<TiWindowProtocol>)theProxy resignFocus];
      }
    }

    [(TiWindowProxy *)contentViewProxy setIsManaged:YES];
    [(TiWindowProxy *)contentViewProxy open:nil];
    [(TiWindowProxy *)contentViewProxy gainFocus];
    [(TiWindowProxy *)contentViewProxy reposition];
    [(TiWindowProxy *)contentViewProxy layoutChildrenIfNeeded];
  } else {
    [contentViewProxy windowWillOpen];
    [contentViewProxy reposition];
    [contentViewProxy layoutChildrenIfNeeded];
  }

  if (closeButtonProxy != nil) {
    [closeButtonProxy windowWillOpen];
    [closeButtonProxy reposition];
    [closeButtonProxy layoutChildrenIfNeeded];

    CGFloat width = [closeButtonProxy autoWidthForSize:CGSizeMake(1000, 1000)];
    CGFloat height = [closeButtonProxy autoHeightForSize:CGSizeMake(width, 0)];
    closeButtonView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
  }

  // Titanium may not have completed the native view hierarchy/layout during the
  // same call stack as windowWillOpen/open. Preserve the original module's short
  // defer before sizing and presenting the system sheet so contentView is fully
  // materialized and laid out before UIKit presents its view controller.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (!self->bottomSheetInitialized || self->contentViewProxy == nil) {
      return;
    }

    [self updateContentSize];
    [self->contentViewProxy reposition];
    [self->contentViewProxy layoutChildrenIfNeeded];
    [self updatePopoverNow];
    [self->contentViewProxy windowDidOpen];
  });
}

#pragma mark - Sizing

- (CGSize)contentSize:(TiViewProxy *)thisProxy
{
#ifndef TI_USE_AUTOLAYOUT
  CGSize screenSize = [[UIScreen mainScreen] bounds].size;

  if (poWidth.type != TiDimensionTypeUndefined) {
    [thisProxy layoutProperties]->width.type = poWidth.type;
    [thisProxy layoutProperties]->width.value = poWidth.value;
    poWidth = TiDimensionUndefined;
  }

  if (poHeight.type != TiDimensionTypeUndefined) {
    [thisProxy layoutProperties]->height.type = poHeight.type;
    [thisProxy layoutProperties]->height.value = poHeight.value;
    poHeight = TiDimensionUndefined;
  }

  TiBottomSheetContentSize = SizeConstraintViewWithSizeAddingResizing([thisProxy layoutProperties], thisProxy, screenSize, NULL);
  return TiBottomSheetContentSize;
#else
  return CGSizeZero;
#endif
}

- (void)updateContentSize
{
  CGSize newSize = [self contentSize:contentViewProxy];
  [[self viewController] setPreferredContentSize:newSize];
  [contentViewProxy reposition];
}

#pragma mark - Native sheet configuration

- (void)updatePopoverNow
{
  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
    if (![self valueForKey:@"backgroundColor"] || [[self valueForKey:@"backgroundColor"] isEqual:@"transparent"]) {
      [self replaceValue:[TiUtils hexColorValue:[UIColor lightGrayColor]] forKey:@"backgroundColor" notification:YES];
    }

    UIViewController *theController = [self viewController];

    // UISheetPresentationController is only available for sheet-style presentations.
    // Configure the presentation style before asking UIKit for the sheet controller.
    NSString *modalPresentation = [TiUtils stringValue:[self valueForKey:@"modalPresentation"]];
    if ([modalPresentation isEqualToString:@"fullScreen"]) {
      theController.modalPresentationStyle = UIModalPresentationFullScreen;
    } else if ([modalPresentation isEqualToString:@"currentContext"]) {
      theController.modalPresentationStyle = UIModalPresentationCurrentContext;
    } else if ([modalPresentation isEqualToString:@"overCurrentContext"]) {
      theController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    } else {
      theController.modalPresentationStyle = UIModalPresentationPageSheet;
    }

    // modalInPresentation blocks interactive dismissal but does not prevent
    // programmatic dismissal via close(). It can also be changed at runtime.
    theController.modalInPresentation = !dismissible;

    bottomSheet = [[theController sheetPresentationController] retain];
    if (bottomSheet == nil) {
      NSLog(@"[ERROR] Unable to create UISheetPresentationController. Use pageSheet presentation for bottom-sheet behavior.");
      bottomSheetInitialized = NO;
      return;
    }

    bottomSheet.delegate = self;

    if ([self valueForKey:@"preferredCornerRadius"]) {
      bottomSheet.preferredCornerRadius = [TiUtils floatValue:[self valueForKey:@"preferredCornerRadius"]];
    }

    bottomSheet.prefersScrollingExpandsWhenScrolledToEdge = [TiUtils boolValue:[self valueForKey:@"prefersScrollingExpandsWhenScrolledToEdge"] def:NO];
    bottomSheet.prefersEdgeAttachedInCompactHeight = [TiUtils boolValue:[self valueForKey:@"prefersEdgeAttachedInCompactHeight"] def:NO];
    bottomSheet.widthFollowsPreferredContentSizeWhenEdgeAttached = [TiUtils boolValue:[self valueForKey:@"widthFollowsPreferredContentSizeWhenEdgeAttached"] def:NO];
    bottomSheet.prefersGrabberVisible = [TiUtils boolValue:[self valueForKey:@"prefersGrabberVisible"] def:YES];

    userDetents = [self valueForKey:@"detents"];
    customDetents = [self valueForKey:@"customDetents"];

    [configuredDetentIdentifiers removeAllObjects];
    NSMutableArray *detentsOfController = [NSMutableArray array];

    if ([TiUtils boolValue:[userDetents valueForKey:@"medium"] def:NO]) {
      [detentsOfController addObject:[UISheetPresentationControllerDetent mediumDetent]];
      [configuredDetentIdentifiers addObject:UISheetPresentationControllerDetentIdentifierMedium];
    }

    if ([TiUtils boolValue:[userDetents valueForKey:@"large"] def:NO]) {
      [detentsOfController addObject:[UISheetPresentationControllerDetent largeDetent]];
      [configuredDetentIdentifiers addObject:UISheetPresentationControllerDetentIdentifierLarge];
    }

    if (customDetents.count > 0) {
      if (@available(iOS 16.0, macCatalyst 16.0, *)) {
        NSArray *sortedCustomDetentKeys = [customDetents keysSortedByValueUsingComparator:^NSComparisonResult(id value1, id value2) {
          CGFloat height1 = [TiUtils floatValue:value1];
          CGFloat height2 = [TiUtils floatValue:value2];

          if (height1 < height2) {
            return NSOrderedAscending;
          }
          if (height1 > height2) {
            return NSOrderedDescending;
          }
          return NSOrderedSame;
        }];

        for (NSString *key in sortedCustomDetentKeys) {
          CGFloat value = [TiUtils floatValue:[customDetents objectForKey:key]];
          UISheetPresentationControllerDetentIdentifier identifier = (UISheetPresentationControllerDetentIdentifier)key;

          [detentsOfController addObject:[UISheetPresentationControllerDetent ti_customDetentWithIdentifier:identifier
                                                                                                     height:value]];
          [configuredDetentIdentifiers addObject:identifier];

          if ([[TiUtils stringValue:[self valueForKey:@"startDetent"]] isEqualToString:key]) {
            initalSelectedDetent = identifier;
          }
        }
      } else {
        NSLog(@"[WARN] customDetents require iOS 16.0 or newer and were ignored.");
      }
    }

    if (detentsOfController.count == 0) {
      [detentsOfController addObject:[UISheetPresentationControllerDetent mediumDetent]];
      [configuredDetentIdentifiers addObject:UISheetPresentationControllerDetentIdentifierMedium];
    }

    bottomSheet.detents = detentsOfController;

    NSString *startDetent = [TiUtils stringValue:[self valueForKey:@"startDetent"]];
    if ([startDetent isEqualToString:@"large"] && [configuredDetentIdentifiers containsObject:UISheetPresentationControllerDetentIdentifierLarge]) {
      initalSelectedDetent = UISheetPresentationControllerDetentIdentifierLarge;
    } else if ([startDetent isEqualToString:@"medium"] && [configuredDetentIdentifiers containsObject:UISheetPresentationControllerDetentIdentifierMedium]) {
      initalSelectedDetent = UISheetPresentationControllerDetentIdentifierMedium;
    }

    if (initalSelectedDetent != nil && [configuredDetentIdentifiers containsObject:initalSelectedDetent]) {
      bottomSheet.selectedDetentIdentifier = initalSelectedDetent;
    }

    if (_largestUndimmedDetentIdentifier != nil) {
      bottomSheet.largestUndimmedDetentIdentifier = _largestUndimmedDetentIdentifier;
    } else if ([self valueForKey:@"largestUndimmedDetentIdentifier"]) {
      [self setLargestUndimmedDetentIdentifier:[self valueForKey:@"largestUndimmedDetentIdentifier"]];
    }

    [theController.view setBackgroundColor:[[TiUtils colorValue:[self valueForKey:@"backgroundColor"]] _color]];

    if (closeButtonView != nil) {
      closeButtonProxy.view.frame = closeButtonView.bounds;
      [closeButtonView addSubview:closeButtonProxy.view];
      [closeButtonProxy reposition];

      CGSize size = theController.view.frame.size;
      [closeButtonView setCenter:CGPointMake(size.width - (closeButtonView.bounds.size.width / 2.0), 24)];
      [theController.view addSubview:closeButtonView];
      [theController.view bringSubviewToFront:closeButtonView];
    }

    [[[[TiApp app] controller] topPresentedController] presentViewController:theController
                                                                   animated:animated
                                                                 completion:^{
      [self fireEvent:@"open" withObject:nil];
    }];
  }
}

#pragma mark - Titanium proxy observer

- (void)proxyDidRelayout:(id)sender
{
  TiThreadPerformOnMainThread(^{
    if (sender == self->contentViewProxy && self->viewController != nil) {
      CGSize newSize = [self contentSize:sender];
      if (!CGSizeEqualToSize([self->viewController preferredContentSize], newSize)) {
        [self updateContentSize];
      }
    }
  }, NO);
}

#pragma mark - UISheetPresentationControllerDelegate

- (void)sheetPresentationControllerDidChangeSelectedDetentIdentifier:(UISheetPresentationController *)bottomSheetPresentationController API_AVAILABLE(ios(15.0), macCatalyst(15.0))
{
  NSString *identifier = TiPublicDetentIdentifier(bottomSheetPresentationController.selectedDetentIdentifier);
  if (identifier != nil) {
    [self fireEvent:@"detentChange" withObject:@{ @"selectedDetentIdentifier" : identifier }];
  }
}

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController
{
  if (!dismissible) {
    return NO;
  }

  if ([[self viewController] presentedViewController] != nil) {
    return NO;
  }

  [self fireEvent:@"dismissing" withObject:nil];
  return YES;
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
  if (!eventFired) {
    eventFired = YES;
    [self fireEvent:@"close" withObject:nil];
  }

  [self cleanup];
}

#pragma mark - Safe-area observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
  if (object == viewController.view && [keyPath isEqualToString:@"safeAreaInsets"]) {
    UIEdgeInsets newInsets = [[change objectForKey:@"new"] UIEdgeInsetsValue];
    UIEdgeInsets oldInsets = [[change objectForKey:@"old"] UIEdgeInsetsValue];

    if (!UIEdgeInsetsEqualToEdgeInsets(oldInsets, newInsets)) {
      bottomSheetSafeAreaInset = newInsets;
      deviceRotated = NO;
    }
  }
}

@end
