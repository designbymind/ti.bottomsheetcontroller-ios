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
  if (requestedIdentifier == nil) {
    return;
  }

  TiThreadPerformOnMainThread(^{
    if (@available(iOS 15.0, macCatalyst 15.0, *)) {
      if (self->bottomSheet == nil) {
        return;
      }

      UISheetPresentationControllerDetentIdentifier nativeIdentifier = TiNativeDetentIdentifier(requestedIdentifier);

      if (![self->configuredDetentIdentifiers containsObject:nativeIdentifier]) {
        NSLog(@"[WARN] BottomSheet detent '%@' is not configured. Ignoring changeCurrentDetent().", requestedIdentifier);
        return;
      }

      NSString *currentIdentifier = TiPublicDetentIdentifier(self->bottomSheet.selectedDetentIdentifier);
      NSString *targetIdentifier = TiPublicDetentIdentifier(nativeIdentifier);

      if ([currentIdentifier isEqualToString:targetIdentifier]) {
        return;
      }

      [self->bottomSheet animateChanges:^{
        self->bottomSheet.selectedDetentIdentifier = nativeIdentifier;
      }];

      // UISheetPresentationController's delegate reliably reports interactive
      // detent changes, but programmatic selectedDetentIdentifier assignments do
      // not consistently invoke that callback. Emit the same normalized event here
      // so Titanium observes both interaction paths uniformly.
      [self fireEvent:@"detentChange" withObject:@{ @"selectedDetentIdentifier" : targetIdentifier }];
    }
  }, NO);
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

- (void)setPrefersScrollingExpandsWhenScrolledToEdge:(id)value
{
  BOOL enabled = [TiUtils boolValue:value];
  [self replaceValue:[NSNumber numberWithBool:enabled] forKey:@"prefersScrollingExpandsWhenScrolledToEdge" notification:NO];

  TiThreadPerformOnMainThread(^{
    if (@available(iOS 15.0, macCatalyst 15.0, *)) {
      if (self->bottomSheet != nil) {
        self->bottomSheet.prefersScrollingExpandsWhenScrolledToEdge = enabled;
      }
    }
  }, NO);
}

- (void)setPrefersEdgeAttachedInCompactHeight:(id)value
{
  BOOL enabled = [TiUtils boolValue:value];
  [self replaceValue:[NSNumber numberWithBool:enabled] forKey:@"prefersEdgeAttachedInCompactHeight" notification:NO];

  TiThreadPerformOnMainThread(^{
    if (@available(iOS 15.0, macCatalyst 15.0, *)) {
      if (self->bottomSheet != nil) {
        self->bottomSheet.prefersEdgeAttachedInCompactHeight = enabled;
      }
    }
  }, NO);
}

- (void)setWidthFollowsPreferredContentSizeWhenEdgeAttached:(id)value
{
  BOOL enabled = [TiUtils boolValue:value];
  [self replaceValue:[NSNumber numberWithBool:enabled] forKey:@"widthFollowsPreferredContentSizeWhenEdgeAttached" notification:NO];

  TiThreadPerformOnMainThread(^{
    if (@available(iOS 15.0, macCatalyst 15.0, *)) {
      if (self->bottomSheet != nil) {
        self->bottomSheet.widthFollowsPreferredContentSizeWhenEdgeAttached = enabled;
      }
    }
  }, NO);
}

- (void)setPrefersGrabberVisible:(id)value
{
  BOOL visible = [TiUtils boolValue:value];
  [self replaceValue:[NSNumber numberWithBool:visible] forKey:@"prefersGrabberVisible" notification:NO];

  TiThreadPerformOnMainThread(^{
    if (@available(iOS 15.0, macCatalyst 15.0, *)) {
      if (self->bottomSheet != nil) {
        self->bottomSheet.prefersGrabberVisible = visible;
      }
    }
  }, NO);
}

- (void)setPreferredCornerRadius:(id)value
{
  [self replaceValue:value forKey:@"preferredCornerRadius" notification:NO];

  TiThreadPerformOnMainThread(^{
    if (@available(iOS 15.0, macCatalyst 15.0, *)) {
      if (self->bottomSheet != nil) {
        self->bottomSheet.preferredCornerRadius = [TiUtils floatValue:value];
      }
    }
  }, NO);
}

- (void)setLargestUndimmedDetentIdentifier:(id)value
{
  NSString *identifier = [TiUtils stringValue:value];

  RELEASE_TO_NIL(_largestUndimmedDetentIdentifier);
  _largestUndimmedDetentIdentifier = [TiNativeDetentIdentifier(identifier) copy];
  [self replaceValue:(identifier != nil ? identifier : (id)[NSNull null]) forKey:@"largestUndimmedDetentIdentifier" notification:NO];

  TiThreadPerformOnMainThread(^{
    if (@available(iOS 15.0, macCatalyst 15.0, *)) {
      if (self->bottomSheet == nil) {
        return;
      }

      if (self->_largestUndimmedDetentIdentifier != nil &&
          ![self->configuredDetentIdentifiers containsObject:self->_largestUndimmedDetentIdentifier]) {
        NSLog(@"[WARN] BottomSheet largestUndimmedDetentIdentifier '%@' is not configured. Ignoring runtime update.", identifier);
        return;
      }

      self->bottomSheet.largestUndimmedDetentIdentifier = self->_largestUndimmedDetentIdentifier;
    }
  }, NO);
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

#pragma mark - Detent configuration

- (void)addSystemDetentWithIdentifier:(NSString *)identifier toArray:(NSMutableArray *)detentsOfController
{
  UISheetPresentationControllerDetentIdentifier nativeIdentifier = TiNativeDetentIdentifier(identifier);

  if ([configuredDetentIdentifiers containsObject:nativeIdentifier]) {
    NSLog(@"[WARN] Duplicate BottomSheet detent '%@' ignored.", identifier);
    return;
  }

  if ([identifier isEqualToString:@"medium"]) {
    [detentsOfController addObject:[UISheetPresentationControllerDetent mediumDetent]];
    [configuredDetentIdentifiers addObject:UISheetPresentationControllerDetentIdentifierMedium];
  } else if ([identifier isEqualToString:@"large"]) {
    [detentsOfController addObject:[UISheetPresentationControllerDetent largeDetent]];
    [configuredDetentIdentifiers addObject:UISheetPresentationControllerDetentIdentifierLarge];
  } else {
    NSLog(@"[WARN] Unsupported system BottomSheet detent '%@' ignored.", identifier);
  }
}

- (void)addCustomDetentWithIdentifier:(NSString *)identifier height:(CGFloat)height toArray:(NSMutableArray *)detentsOfController
{
  if (identifier.length == 0) {
    NSLog(@"[WARN] BottomSheet custom detent requires a non-empty identifier.");
    return;
  }

  UISheetPresentationControllerDetentIdentifier nativeIdentifier = TiNativeDetentIdentifier(identifier);
  if ([configuredDetentIdentifiers containsObject:nativeIdentifier]) {
    NSLog(@"[WARN] Duplicate BottomSheet detent '%@' ignored.", identifier);
    return;
  }

  if ([identifier isEqualToString:@"medium"] || [identifier isEqualToString:@"large"]) {
    NSLog(@"[WARN] BottomSheet custom detent identifier '%@' is reserved. Use the system detent string instead.", identifier);
    return;
  }

  if (@available(iOS 16.0, macCatalyst 16.0, *)) {
    [detentsOfController addObject:[UISheetPresentationControllerDetent ti_customDetentWithIdentifier:(UISheetPresentationControllerDetentIdentifier)identifier
                                                                                               height:height]];
    [configuredDetentIdentifiers addObject:(UISheetPresentationControllerDetentIdentifier)identifier];
  } else {
    NSLog(@"[WARN] custom detents require iOS 16.0 or newer and '%@' was ignored.", identifier);
  }
}

- (void)configureOrderedDetents:(NSArray *)orderedDetents intoArray:(NSMutableArray *)detentsOfController
{
  for (id entry in orderedDetents) {
    if ([entry isKindOfClass:[NSString class]]) {
      [self addSystemDetentWithIdentifier:(NSString *)entry toArray:detentsOfController];
      continue;
    }

    if ([entry isKindOfClass:[NSDictionary class]]) {
      NSDictionary *definition = (NSDictionary *)entry;
      NSString *identifier = [TiUtils stringValue:[definition objectForKey:@"identifier"]];
      id heightValue = [definition objectForKey:@"height"];

      if (identifier == nil || heightValue == nil) {
        NSLog(@"[WARN] Ordered BottomSheet custom detents require { identifier, height }. Entry ignored.");
        continue;
      }

      [self addCustomDetentWithIdentifier:identifier
                                  height:[TiUtils floatValue:heightValue]
                                 toArray:detentsOfController];
      continue;
    }

    NSLog(@"[WARN] Unsupported BottomSheet detent definition ignored: %@", entry);
  }
}

- (void)configureLegacyDetents:(NSDictionary *)legacyDetents customDetents:(NSDictionary *)legacyCustomDetents intoArray:(NSMutableArray *)detentsOfController
{
  // Preserve the pre-v2 dictionary API for compatibility. New floating-bar
  // configurations should use the ordered array form so UIKit receives detents
  // explicitly from smallest to largest.
  if ([TiUtils boolValue:[legacyDetents valueForKey:@"medium"] def:NO]) {
    [self addSystemDetentWithIdentifier:@"medium" toArray:detentsOfController];
  }

  if ([TiUtils boolValue:[legacyDetents valueForKey:@"large"] def:NO]) {
    [self addSystemDetentWithIdentifier:@"large" toArray:detentsOfController];
  }

  if (legacyCustomDetents.count > 0) {
    NSArray *sortedCustomDetentKeys = [legacyCustomDetents keysSortedByValueUsingComparator:^NSComparisonResult(id value1, id value2) {
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
      [self addCustomDetentWithIdentifier:key
                                  height:[TiUtils floatValue:[legacyCustomDetents objectForKey:key]]
                                 toArray:detentsOfController];
    }
  }
}

#pragma mark - Native sheet configuration

- (void)updatePopoverNow
{
  if (@available(iOS 15.0, macCatalyst 15.0, *)) {
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

    // Preserve UIKit defaults unless Titanium explicitly configures an override.
    // This keeps scrolling, compact-height layout, grabber appearance, and future
    // system behavior aligned with the native sheet implementation.
    id preferredCornerRadiusValue = [self valueForKey:@"preferredCornerRadius"];
    if (preferredCornerRadiusValue != nil) {
      bottomSheet.preferredCornerRadius = [TiUtils floatValue:preferredCornerRadiusValue];
    }

    id scrollingExpandsValue = [self valueForKey:@"prefersScrollingExpandsWhenScrolledToEdge"];
    if (scrollingExpandsValue != nil) {
      bottomSheet.prefersScrollingExpandsWhenScrolledToEdge = [TiUtils boolValue:scrollingExpandsValue];
    }

    id edgeAttachedValue = [self valueForKey:@"prefersEdgeAttachedInCompactHeight"];
    if (edgeAttachedValue != nil) {
      bottomSheet.prefersEdgeAttachedInCompactHeight = [TiUtils boolValue:edgeAttachedValue];
    }

    id widthFollowsValue = [self valueForKey:@"widthFollowsPreferredContentSizeWhenEdgeAttached"];
    if (widthFollowsValue != nil) {
      bottomSheet.widthFollowsPreferredContentSizeWhenEdgeAttached = [TiUtils boolValue:widthFollowsValue];
    }

    id grabberVisibleValue = [self valueForKey:@"prefersGrabberVisible"];
    if (grabberVisibleValue != nil) {
      bottomSheet.prefersGrabberVisible = [TiUtils boolValue:grabberVisibleValue];
    }

    userDetents = [self valueForKey:@"detents"];
    customDetents = [self valueForKey:@"customDetents"];

    [configuredDetentIdentifiers removeAllObjects];
    NSMutableArray *detentsOfController = [NSMutableArray array];

    if ([userDetents isKindOfClass:[NSArray class]]) {
      [self configureOrderedDetents:(NSArray *)userDetents intoArray:detentsOfController];

      if (customDetents.count > 0) {
        NSLog(@"[WARN] BottomSheet customDetents is ignored when detents uses the ordered array form.");
      }
    } else {
      NSDictionary *legacyDetents = [userDetents isKindOfClass:[NSDictionary class]] ? (NSDictionary *)userDetents : nil;
      [self configureLegacyDetents:legacyDetents customDetents:customDetents intoArray:detentsOfController];
    }

    if (detentsOfController.count == 0) {
      [self addSystemDetentWithIdentifier:@"medium" toArray:detentsOfController];
    }

    bottomSheet.detents = detentsOfController;

    NSString *startDetent = [TiUtils stringValue:[self valueForKey:@"startDetent"]];
    if (startDetent != nil) {
      UISheetPresentationControllerDetentIdentifier startIdentifier = TiNativeDetentIdentifier(startDetent);
      if ([configuredDetentIdentifiers containsObject:startIdentifier]) {
        initalSelectedDetent = startIdentifier;
      } else {
        NSLog(@"[WARN] BottomSheet startDetent '%@' is not configured. UIKit will use its default detent.", startDetent);
      }
    }

    if (initalSelectedDetent != nil && [configuredDetentIdentifiers containsObject:initalSelectedDetent]) {
      bottomSheet.selectedDetentIdentifier = initalSelectedDetent;
    }

    if (_largestUndimmedDetentIdentifier != nil) {
      if ([configuredDetentIdentifiers containsObject:_largestUndimmedDetentIdentifier]) {
        bottomSheet.largestUndimmedDetentIdentifier = _largestUndimmedDetentIdentifier;
      } else {
        NSLog(@"[WARN] BottomSheet largestUndimmedDetentIdentifier '%@' is not configured. UIKit default dimming will be used.", TiPublicDetentIdentifier(_largestUndimmedDetentIdentifier));
      }
    } else if ([self valueForKey:@"largestUndimmedDetentIdentifier"]) {
      [self setLargestUndimmedDetentIdentifier:[self valueForKey:@"largestUndimmedDetentIdentifier"]];
    }

    // Do not paint a default background over the system sheet. Leaving the
    // controller view transparent allows UIKit to provide its native sheet
    // material (including Liquid Glass on iOS 26+). An explicitly supplied
    // Titanium backgroundColor remains an intentional visual override.
    id backgroundColorValue = [self valueForKey:@"backgroundColor"];
    if (backgroundColorValue != nil) {
      if ([[TiUtils stringValue:backgroundColorValue] isEqualToString:@"transparent"]) {
        theController.view.backgroundColor = [UIColor clearColor];
      } else {
        theController.view.backgroundColor = [[TiUtils colorValue:backgroundColorValue] _color];
      }
    } else {
      theController.view.backgroundColor = [UIColor clearColor];
    }

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
