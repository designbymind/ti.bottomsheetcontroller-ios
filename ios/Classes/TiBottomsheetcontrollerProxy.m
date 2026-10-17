/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2021 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#define USE_TI_UINAVIGATIONWINDOW

#import "TiBottomsheetcontrollerProxy.h"
#import "TiSheetPanGate.h"
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

// Optional content effects only: UIKit continues to own sheet geometry and gestures.
@interface TiSheetEffectTarget : NSObject
@property(nonatomic, retain) TiViewProxy *proxy;
@property(nonatomic, retain) NSDictionary *from;
@property(nonatomic, retain) NSDictionary *to;
@property(nonatomic, assign) CATransform3D originalTransform;
@property(nonatomic, assign) float originalOpacity;
@property(nonatomic, assign) CGFloat originalRadius;
@property(nonatomic, assign) BOOL originalMasks;
@end
@implementation TiSheetEffectTarget
- (void)dealloc { [_proxy release]; [_from release]; [_to release]; [super dealloc]; }
@end

@interface TiSheetEffectTracker : NSObject {
  UIViewController *_controller; // Non-owning; proxy stops tracker before controller teardown.
  CADisplayLink *_displayLink;
  NSMutableArray *_targets;
  CGFloat _startHeight, _endHeight;
}
- (instancetype)initWithController:(UIViewController *)controller configuration:(NSDictionary *)config;
- (void)tick:(CADisplayLink *)link;
- (void)stop;
- (void)setPaused:(BOOL)paused;
@end

static CGFloat TiSheetEffectValue(NSDictionary *state, NSString *key, CGFloat fallback)
{
  id value = [state objectForKey:key];
  if (![value isKindOfClass:[NSNumber class]]) return fallback;
  CGFloat number = [value doubleValue];
  return isfinite(number) ? number : fallback;
}

@implementation TiSheetEffectTracker
- (instancetype)initWithController:(UIViewController *)controller configuration:(NSDictionary *)config
{
  if ((self = [super init])) {
    _controller = controller;
    _startHeight = TiSheetEffectValue(config, @"startHeight", NAN);
    _endHeight = TiSheetEffectValue(config, @"endHeight", NAN);
    if (!isfinite(_startHeight) || !isfinite(_endHeight) || _startHeight < 0 || _endHeight <= _startHeight) {
      NSLog(@"[WARN] detentEffects requires finite startHeight >= 0 and endHeight > startHeight.");
      [self release]; return nil;
    }
    _targets = [[NSMutableArray alloc] init];
    id entries = [config objectForKey:@"views"];
    if ([entries isKindOfClass:[NSArray class]]) for (id entry in entries) {
      if (![entry isKindOfClass:[NSDictionary class]]) continue;
      id proxy = [entry objectForKey:@"view"];
      if (![proxy isKindOfClass:[TiViewProxy class]]) continue;
      UIView *view = [(TiViewProxy *)proxy view];
      if (view == controller.view || ![view isDescendantOfView:controller.view]) {
        NSLog(@"[WARN] detentEffects targets must be descendants of the sheet content.");
        continue;
      }
      BOOL duplicate = NO;
      for (TiSheetEffectTarget *existing in _targets) if (existing.proxy == proxy) duplicate = YES;
      if (duplicate) continue;
      TiSheetEffectTarget *target = [[[TiSheetEffectTarget alloc] init] autorelease];
      target.proxy = proxy;
      id from = [entry objectForKey:@"from"], to = [entry objectForKey:@"to"];
      target.from = [from isKindOfClass:[NSDictionary class]] ? from : @{};
      target.to = [to isKindOfClass:[NSDictionary class]] ? to : @{};
      target.originalTransform = view.layer.transform;
      target.originalOpacity = view.layer.opacity;
      target.originalRadius = view.layer.cornerRadius;
      target.originalMasks = view.layer.masksToBounds;
      [_targets addObject:target];
    }
    if (_targets.count > 0) {
      _displayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)] retain];
      [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
      [self tick:nil];
    }
  }
  return self;
}
- (void)tick:(CADisplayLink *)link
{
  UIView *presented = _controller.presentationController.presentedView;
  UIView *container = _controller.presentationController.containerView;
  if (!presented || !container) return;
  CALayer *layer = presented.layer.presentationLayer ?: presented.layer;
  CALayer *containerLayer = container.layer.presentationLayer ?: container.layer;
  CGRect frame = [layer convertRect:layer.bounds toLayer:containerLayer];
  CGRect visible = CGRectIntersection(frame, containerLayer.bounds);
  if (CGRectIsNull(visible)) return;
  // Custom detent values exclude the bottom safe area when edge-attached.
  CGFloat inset = fabs(CGRectGetMaxY(frame) - CGRectGetMaxY(containerLayer.bounds)) < 1.0
      ? _controller.view.safeAreaInsets.bottom : 0;
  CGFloat height = MAX(0, CGRectGetHeight(visible) - inset);
  CGFloat progress = MIN(1, MAX(0, (height - _startHeight) / (_endHeight - _startHeight)));
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  for (TiSheetEffectTarget *target in _targets) {
    CALayer *targetLayer = target.proxy.view.layer;
    CGFloat scaleFrom = TiSheetEffectValue(target.from, @"scale", 1);
    CGFloat scaleTo = TiSheetEffectValue(target.to, @"scale", scaleFrom);
    CGFloat scale = MAX(0.001, scaleFrom + (scaleTo - scaleFrom) * progress);
    CGFloat xFrom = TiSheetEffectValue(target.from, @"translationX", 0);
    CGFloat yFrom = TiSheetEffectValue(target.from, @"translationY", 0);
    CGFloat x = xFrom + (TiSheetEffectValue(target.to, @"translationX", xFrom) - xFrom) * progress;
    CGFloat y = yFrom + (TiSheetEffectValue(target.to, @"translationY", yFrom) - yFrom) * progress;
    CATransform3D effect = CATransform3DMakeTranslation(x, y, 0);
    effect = CATransform3DScale(effect, scale, scale, 1);
    targetLayer.transform = CATransform3DConcat(target.originalTransform, effect);
    if ([target.from objectForKey:@"opacity"] || [target.to objectForKey:@"opacity"]) {
      CGFloat a = TiSheetEffectValue(target.from, @"opacity", target.originalOpacity);
      CGFloat b = TiSheetEffectValue(target.to, @"opacity", a);
      targetLayer.opacity = MIN(1, MAX(0, a + (b - a) * progress));
    }
    if ([target.from objectForKey:@"cornerRadius"] || [target.to objectForKey:@"cornerRadius"]) {
      CGFloat a = TiSheetEffectValue(target.from, @"cornerRadius", target.originalRadius);
      CGFloat b = TiSheetEffectValue(target.to, @"cornerRadius", a);
      targetLayer.cornerRadius = MAX(0, a + (b - a) * progress);
      targetLayer.masksToBounds = YES;
    }
  }
  [CATransaction commit];
}
- (void)setPaused:(BOOL)paused
{
  _displayLink.paused = paused;
  if (!paused) [self tick:nil];
}
- (void)stop
{
  [_displayLink invalidate];
  [_displayLink release]; _displayLink = nil;
  [CATransaction begin]; [CATransaction setDisableActions:YES];
  for (TiSheetEffectTarget *target in _targets) {
    CALayer *layer = target.proxy.view.layer;
    layer.transform = target.originalTransform;
    layer.opacity = target.originalOpacity;
    layer.cornerRadius = target.originalRadius;
    layer.masksToBounds = target.originalMasks;
  }
  [CATransaction commit];
  [_targets removeAllObjects];
  _controller = nil;
}
- (void)dealloc { [self stop]; [_targets release]; [super dealloc]; }
@end

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
    interactiveGesturesEnabled = YES;
    deviceRotated = NO;
    configuredDetentIdentifiers = [[NSMutableSet alloc] init];

    UIViewController<TiControllerContainment> *topContainerController = [[[TiApp app] controller] topContainerController];
    bottomSheetSafeAreaInset = [[topContainerController hostingView] safeAreaInsets];
  }

  return self;
}

- (void)dealloc
{
  [sheetPanGate invalidate];
  RELEASE_TO_NIL(sheetPanGate);
  [fullScreenTransition invalidate];
  RELEASE_TO_NIL(fullScreenTransition);
  [detentEffectTracker stop];
  RELEASE_TO_NIL(detentEffectTracker);
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

  RELEASE_TO_NIL(retainedSelectedDetent);
  RELEASE_TO_NIL(bottomSheet);
  RELEASE_TO_NIL(viewController);
  RELEASE_TO_NIL(underlyingWindowProxy);
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
  if (sheetHidden && retainedSelectedDetent != nil) return TiPublicDetentIdentifier(retainedSelectedDetent);
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

      if (self->sheetHidden) {
        RELEASE_TO_NIL(self->retainedSelectedDetent);
        self->retainedSelectedDetent = [nativeIdentifier copy];
      }
      NSString *currentIdentifier = TiPublicDetentIdentifier(self->bottomSheet.selectedDetentIdentifier);
      NSString *targetIdentifier = TiPublicDetentIdentifier(nativeIdentifier);

      if ([currentIdentifier isEqualToString:targetIdentifier]) {
        return;
      }

      [self->bottomSheet animateChanges:^{
        [self->sheetPanGate restoreDetentsForSelection];
        self->bottomSheet.selectedDetentIdentifier = nativeIdentifier;
        [self->sheetPanGate restrictToSelectedDetent];
      }];

      // UISheetPresentationController's delegate reliably reports interactive
      // detent changes, but programmatic selectedDetentIdentifier assignments do
      // not consistently invoke that callback. Emit the same normalized event here
      // so Titanium observes both interaction paths uniformly.
      [self fireEvent:@"detentChange" withObject:@{ @"selectedDetentIdentifier" : targetIdentifier }];
    }
  }, NO);
}

- (void)setInteractiveGesturesEnabled:(id)value
{
  BOOL enabled = [TiUtils boolValue:value def:YES];
  [self replaceValue:@(enabled) forKey:@"interactiveGesturesEnabled" notification:NO];
  TiThreadPerformOnMainThread(^{
    self->interactiveGesturesEnabled = enabled;
    [self->sheetPanGate setEnabled:enabled || self->sheetHidden];
    [self->fullScreenTransition setInteractiveGesturesEnabled:enabled];
  }, YES);
}

- (NSNumber *)interactiveGesturesEnabled { return @(interactiveGesturesEnabled); }

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

- (NSNumber *)dismissible
{
  return [NSNumber numberWithBool:dismissible];
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
    [self->fullScreenTransition setGrabberVisible:visible];
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

// Requests: 1 hide, 2 show, 3 final close. UIKit transitions are serialized.
- (void)finishSheetTransition
{
  sheetTransitioning = NO;
  NSInteger request = pendingSheetRequest;
  BOOL requestAnimated = pendingSheetAnimated;
  pendingSheetRequest = 0;
  if (request != 0) [self performSheetRequest:request animated:requestAnimated];
}

- (void)open:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);
  BOOL requestedAnimation = [TiUtils boolValue:@"animated" properties:args def:YES];
  TiThreadPerformOnMainThread(^{
    if (self->bottomSheetInitialized || self->contentViewProxy == nil) {
      NSLog(@"[WARN] BottomSheet already initialized or has no contentView. Ignoring open().");
      return;
    }
    NSString *mode = [TiUtils stringValue:[self valueForKey:@"presentationMode"]];
    if (mode != nil && ![mode isEqualToString:@"native"] && ![mode isEqualToString:@"fullScreen"]) {
      NSLog(@"[WARN] presentationMode must be 'native' or 'fullScreen'. Ignoring open().");
      return;
    }
    self->fullScreenMode = [mode isEqualToString:@"fullScreen"];
    self->eventFired = NO;
    self->bottomSheetInitialized = YES;
    self->sheetHidden = NO;
    self->sheetTransitioning = YES;
    self->pendingSheetRequest = 0;
    self->isDismissing = NO;
    self->animated = requestedAnimation;
    [self rememberSelf];
    [self retain];
    [self initAndShowSheetController];
  }, YES);
}

- (void)hide:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);
  BOOL requestedAnimation = [TiUtils boolValue:@"animated" properties:args def:YES];
  TiThreadPerformOnMainThread(^{ [self performSheetRequest:1 animated:requestedAnimation]; }, YES);
}

- (void)show:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);
  BOOL requestedAnimation = [TiUtils boolValue:@"animated" properties:args def:YES];
  TiThreadPerformOnMainThread(^{ [self performSheetRequest:2 animated:requestedAnimation]; }, YES);
}

- (void)close:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);
  BOOL requestedAnimation = [TiUtils boolValue:@"animated" properties:args def:YES];
  TiThreadPerformOnMainThread(^{ [self performSheetRequest:3 animated:requestedAnimation]; }, YES);
}

- (void)performSheetRequest:(NSInteger)request animated:(BOOL)requestedAnimation
{
  if (!bottomSheetInitialized || isDismissing) return;
  if (sheetTransitioning) {
    // Once close is queued, later visibility requests must not cancel cleanup.
    if (pendingSheetRequest != 3) {
      pendingSheetRequest = request;
      pendingSheetAnimated = requestedAnimation;
    }
    return;
  }
  if ((request == 1 && sheetHidden) || (request == 2 && !sheetHidden)) return;

  if (request == 2) {
    // Wait for the caller's card/modal to finish closing before calling show().
    UIViewController *presenter = [[TiApp app].controller topPresentedController];
    if (presenter.isBeingDismissed || presenter.isBeingPresented || presenter.view.window == nil) {
      NSLog(@"[WARN] Cannot show BottomSheet while its presenter is transitioning or detached.");
      return;
    }
    sheetTransitioning = YES;
    animated = requestedAnimation;
    if ([contentViewProxy isKindOfClass:[TiWindowProxy class]]) {
      if ([underlyingWindowProxy conformsToProtocol:@protocol(TiWindowProtocol)]) {
        [(id<TiWindowProtocol>)underlyingWindowProxy resignFocus];
      }
      [(TiWindowProxy *)contentViewProxy gainFocus];
    }
    [self updateContentSize];
    [self updatePopoverNow];
    return;
  }

  // Hiding must not also dismiss a modal presented by the sheet itself.
  if (request == 1 && viewController.presentedViewController != nil) {
    NSLog(@"[WARN] Close the sheet's presented controller before hide().");
    return;
  }
  sheetTransitioning = YES;
  animated = requestedAnimation;
  if (request == 1) {
    RELEASE_TO_NIL(retainedSelectedDetent);
    retainedSelectedDetent = [bottomSheet.selectedDetentIdentifier copy];
    [sheetPanGate setEnabled:YES];
    [viewController dismissViewControllerAnimated:animated completion:^{
      self->sheetHidden = YES;
      [self->detentEffectTracker setPaused:YES];
      if ([self->contentViewProxy isKindOfClass:[TiWindowProxy class]]) {
        [(TiWindowProxy *)self->contentViewProxy resignFocus];
        [self restoreUnderlyingWindowFocus];
      }
      [self fireEvent:@"hide" withObject:nil];
      [self finishSheetTransition];
    }];
  } else {
    isDismissing = YES;
    [sheetPanGate setEnabled:YES];
    [contentViewProxy windowWillClose];
    void (^finishClose)(void) = ^{
      if (!self->eventFired) {
        self->eventFired = YES;
        [self fireEvent:@"close" withObject:nil];
        [self cleanup];
      }
    };
    // A hidden controller has no modal to dismiss: still dispose exactly once.
    if (sheetHidden) finishClose();
    else [viewController dismissViewControllerAnimated:animated completion:finishClose];
  }
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

- (void)restoreUnderlyingWindowFocus
{
  if (sheetHidden && [underlyingWindowProxy conformsToProtocol:@protocol(TiWindowProtocol)]) {
    [(id<TiWindowProtocol>)underlyingWindowProxy gainFocus];
    return;
  }
  if ([contentViewProxy isKindOfClass:[TiWindowProxy class]]) {
    UIView *topWindowView = [[[TiApp app] controller] topWindowProxyView];
    if ([topWindowView isKindOfClass:[TiUIView class]]) {
      TiViewProxy *theProxy = (TiViewProxy *)[(TiUIView *)topWindowView proxy];
      if ([theProxy conformsToProtocol:@protocol(TiWindowProtocol)]) {
        [(id<TiWindowProtocol>)theProxy gainFocus];
      }
    }
  }

}

- (void)cleanup
{
  [sheetPanGate invalidate];
  RELEASE_TO_NIL(sheetPanGate);
  [fullScreenTransition invalidate];
  RELEASE_TO_NIL(fullScreenTransition);
  [detentEffectTracker stop];
  RELEASE_TO_NIL(detentEffectTracker);
  [contentViewProxy setProxyObserver:nil];
  [contentViewProxy windowWillClose];
  [contentViewProxy windowDidClose];

  [self restoreUnderlyingWindowFocus];

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
  sheetHidden = NO;
  sheetTransitioning = NO;
  pendingSheetRequest = 0;
  fullScreenInteractive = NO;
  isDismissing = NO;
  RELEASE_TO_NIL(retainedSelectedDetent);
  [configuredDetentIdentifiers removeAllObjects];

  RELEASE_TO_NIL(bottomSheet);
  RELEASE_TO_NIL(viewController);
  RELEASE_TO_NIL(closeButtonView);
  RELEASE_TO_NIL(closeButtonProxy);
  RELEASE_TO_NIL(underlyingWindowProxy);
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
      underlyingWindowProxy = [theProxy retain];
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

// Only descend within the explicit Titanium scrolling-view reference. Do not
// replace its UIScrollView delegate or guess among nested scroll surfaces.
- (UIScrollView *)nativeScrollViewWithin:(UIView *)view
{
  if ([view isKindOfClass:UIScrollView.class]) return (UIScrollView *)view;
  for (UIView *child in view.subviews) {
    UIScrollView *found = [self nativeScrollViewWithin:child];
    if (found) return found;
  }
  return nil;
}

- (void)presentFullScreenSheet
{
  UIViewController *controller = [self viewController];
  BOOL restoring = sheetHidden;
  if (fullScreenTransition == nil) {
    // NavigationWindow embeds a UINavigationController whose visible child is
    // attached during layout. Materialize that hierarchy before validating an
    // explicit scrollView; otherwise valid tables are rejected before presentation.
    [controller.view setNeedsLayout];
    [controller.view layoutIfNeeded];
    id scrollProxy = [self valueForKey:@"scrollView"];
    UIScrollView *scroll = nil;
    if (scrollProxy != nil) {
      UIView *scrollRoot = [scrollProxy isKindOfClass:TiViewProxy.class] ? [(TiViewProxy *)scrollProxy view] : nil;
      if (scrollRoot && [scrollRoot isDescendantOfView:controller.view]) scroll = [self nativeScrollViewWithin:scrollRoot];
      if (scroll == nil) {
        NSLog(@"[ERROR] fullScreen scrollView must refer to a scrolling view inside contentView.");
        isDismissing = YES;
        [self fireEvent:@"close" withObject:@{ @"error": @"Invalid full-screen scrollView." }];
        [self cleanup];
        return;
      }
    }
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"scalesPresentingView", @"fadesPresentingView", @"presentingViewScale", @"presentingViewCornerRadius", @"fullScreenCornerRadius", @"underlayColor", @"prefersGrabberVisible"]) {
      id value = [self valueForKey:key];
      if (value) config[key] = value;
    }
    fullScreenTransition = [[TiFullScreenSheetTransition alloc] initWithController:controller scrollView:scroll configuration:config];
    fullScreenTransition.delegate = self;
    if ([self valueForKey:@"detentEffects"] != nil) NSLog(@"[WARN] detentEffects applies only to native detent sheets.");
  }
  controller.modalPresentationStyle = UIModalPresentationCustom;
  controller.transitioningDelegate = fullScreenTransition;
  controller.modalInPresentation = !dismissible;
  id color = [self valueForKey:@"backgroundColor"];
  controller.view.backgroundColor = color ? [[TiUtils colorValue:color] _color] : UIColor.systemBackgroundColor;
  if (closeButtonView) {
    closeButtonProxy.view.frame = closeButtonView.bounds;
    [closeButtonView addSubview:closeButtonProxy.view];
    [controller.view addSubview:closeButtonView];
    [fullScreenTransition setCloseButtonView:closeButtonView];
  }
  [fullScreenTransition setInteractiveGesturesEnabled:interactiveGesturesEnabled];
  [[[[TiApp app] controller] topPresentedController] presentViewController:controller animated:animated completion:^{
    self->sheetHidden = NO;
    [self fireEvent:restoring ? @"show" : @"open" withObject:nil];
    [self finishSheetTransition];
  }];
}

- (BOOL)fullScreenSheetCanDismiss
{
  return bottomSheetInitialized && !sheetHidden && !sheetTransitioning && !isDismissing && dismissible && interactiveGesturesEnabled;
}
- (void)fullScreenSheetWillDismiss
{
  fullScreenInteractive = YES;
  sheetTransitioning = YES;
  [self fireEvent:@"dismissing" withObject:nil];
}
- (void)fullScreenSheetDidDismiss:(BOOL)completed
{
  BOOL interactive = fullScreenInteractive;
  fullScreenInteractive = NO;
  // Public hide/close have their own completion and disposal path. An external
  // UIKit dismissal still needs final cleanup, just like native sheet dismissal.
  if (!interactive && sheetTransitioning) return;
  if (!completed) { [self finishSheetTransition]; return; }
  isDismissing = YES;
  if (!eventFired) {
    eventFired = YES;
    [self fireEvent:@"close" withObject:nil];
    [self cleanup];
  }
}

- (void)updatePopoverNow
{
  if (fullScreenMode) { [self presentFullScreenSheet]; return; }
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

    BOOL restoring = sheetHidden;
    RELEASE_TO_NIL(bottomSheet);
    bottomSheet = [[theController sheetPresentationController] retain];
    if (bottomSheet == nil) {
      NSLog(@"[ERROR] Unable to create UISheetPresentationController. Use pageSheet presentation for bottom-sheet behavior.");
      [self fireEvent:@"close" withObject:@{ @"error": @"Unable to create native sheet presentation." }];
      [self cleanup];
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

    if (restoring && retainedSelectedDetent != nil && [configuredDetentIdentifiers containsObject:retainedSelectedDetent]) {
      bottomSheet.selectedDetentIdentifier = retainedSelectedDetent;
    } else if (initalSelectedDetent != nil && [configuredDetentIdentifiers containsObject:initalSelectedDetent]) {
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

    id effectConfig = [self valueForKey:@"detentEffects"];
    if (detentEffectTracker == nil && [effectConfig isKindOfClass:[NSDictionary class]]) {
      detentEffectTracker = [[TiSheetEffectTracker alloc] initWithController:theController configuration:effectConfig];
    }

    [detentEffectTracker setPaused:NO];
    [[[[TiApp app] controller] topPresentedController] presentViewController:theController
                                                                   animated:animated
                                                                 completion:^{
      self->sheetHidden = NO;
      if (!self->sheetPanGate) self->sheetPanGate = [[TiSheetPanGate alloc] initWithController:self->viewController];
      [self->sheetPanGate setEnabled:self->interactiveGesturesEnabled];
      [self fireEvent:restoring ? @"show" : @"open" withObject:nil];
      [self finishSheetTransition];
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
  if (!dismissible || !interactiveGesturesEnabled || sheetTransitioning || sheetHidden) {
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
  // Programmatic hide/close complete through their own serialized callbacks.
  if (sheetTransitioning || sheetHidden || !bottomSheetInitialized) return;
  isDismissing = YES;
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
