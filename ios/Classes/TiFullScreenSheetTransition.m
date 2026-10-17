#import "TiFullScreenSheetTransition.h"
#import <TitaniumKit/TiUtils.h>

@interface TiFullScreenSheetPresentation : UIPresentationController
@property(nonatomic, assign) TiFullScreenSheetTransition *owner;
@end
@implementation TiFullScreenSheetPresentation
- (CGRect)frameOfPresentedViewInContainerView { return self.containerView.bounds; }
- (BOOL)shouldRemovePresentersView { return NO; }
- (void)containerViewWillLayoutSubviews
{
  [super containerViewWillLayoutSubviews];
  [self.owner layoutInContainer:self.containerView];
}
- (void)dismissalTransitionDidEnd:(BOOL)completed
{
  [super dismissalTransitionDidEnd:completed];
  [self.owner dismissalEnded:completed];
}
@end

static char TiFullScreenOffsetContext;

static CGFloat TiFullScreenNumber(NSDictionary *config, NSString *key, CGFloat fallback)
{
  id value = config[key];
  if (![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue])) return fallback;
  return [value doubleValue];
}

@implementation TiFullScreenSheetTransition {
  UIViewController *_controller; // Non-owning; proxy retains its content controller.
  UIScrollView *_scrollView;
  UIPanGestureRecognizer *_pan;
  UIPercentDrivenInteractiveTransition *_interaction;
  UIViewPropertyAnimator *_animator;
  UIView *_presenterView;
  UIView *_backdrop;
  UIView *_dimmingView;
  UIView *_grabber;
  UIView *_closeButtonView; // Owned by proxy/presented hierarchy.
  TiFullScreenSheetPresentation *_presentation; // Non-owning; UIKit owns it.
  BOOL _presenting, _interactive, _tracking, _scrollLocked, _scrollWasBouncing, _touchInScroll;
  BOOL _observingOffset, _pinningOffset;
  BOOL _scalesPresenter, _fadesPresenter, _originalMasks, _contentMasks;
  CGFloat _scale, _presenterRadius, _sheetRadius, _startTranslation;
  CGFloat _touchStartY, _lastTranslation;
  CGFloat _originalRadius, _contentRadius;
  CGAffineTransform _originalTransform;
  UIColor *_underlayColor;
  CGSize _lastSize;
}

- (instancetype)initWithController:(UIViewController *)controller scrollView:(UIScrollView *)scrollView configuration:(NSDictionary *)config
{
  if ((self = [super init])) {
    _controller = controller;
    _scrollView = [scrollView retain];
    _scalesPresenter = [TiUtils boolValue:config[@"scalesPresentingView"] def:NO];
    _fadesPresenter = [TiUtils boolValue:config[@"fadesPresentingView"] def:NO];
    _scale = MIN(1, MAX(0.5, TiFullScreenNumber(config, @"presentingViewScale", 0.9)));
    _presenterRadius = MAX(0, TiFullScreenNumber(config, @"presentingViewCornerRadius", 50));
    _sheetRadius = MAX(0, TiFullScreenNumber(config, @"fullScreenCornerRadius", 30));
    _underlayColor = config[@"underlayColor"] ? [[[TiUtils colorValue:config[@"underlayColor"]] _color] retain] : [UIColor.blackColor retain];
    _contentRadius = controller.view.layer.cornerRadius;
    _contentMasks = controller.view.layer.masksToBounds;
    controller.view.layer.cornerRadius = _sheetRadius;
    controller.view.layer.masksToBounds = YES;
    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _pan.delegate = self;
    _pan.maximumNumberOfTouches = 1;
    _pan.cancelsTouchesInView = NO;
    [controller.view addGestureRecognizer:_pan];
    {
      _grabber = [[UIView alloc] initWithFrame:CGRectZero];
      _grabber.hidden = ![TiUtils boolValue:config[@"prefersGrabberVisible"] def:YES];
      _grabber.backgroundColor = UIColor.secondaryLabelColor;
      _grabber.layer.cornerRadius = 2.5;
      _grabber.userInteractionEnabled = NO;
      _grabber.accessibilityLabel = @"Full-screen sheet grabber";
      _grabber.isAccessibilityElement = YES;
      [controller.view addSubview:_grabber];
    }
  }
  return self;
}

- (void)setInteractiveGesturesEnabled:(BOOL)enabled { _pan.enabled = enabled; }
- (void)setGrabberVisible:(BOOL)visible { _grabber.hidden = !visible; }
- (void)setCloseButtonView:(UIView *)view { _closeButtonView = view; }

- (void)layoutInContainer:(UIView *)container
{
  UIView *view = _controller.view;
  CGSize size = container.bounds.size;
  if (_interaction && !CGSizeEqualToSize(_lastSize, size)) [_interaction cancelInteractiveTransition];
  _lastSize = size;
  // Bounds/center preserve the transition's transform, unlike assigning frame.
  view.bounds = (CGRect){ CGPointZero, size };
  view.center = CGPointMake(CGRectGetMidX(container.bounds), CGRectGetMidY(container.bounds));
  CGFloat safeTop = view.safeAreaInsets.top;
  _grabber.frame = CGRectMake((size.width - 45) / 2, safeTop + 10, 45, 5);
  if (_grabber) [view bringSubviewToFront:_grabber];
  if (_closeButtonView) {
    _closeButtonView.center = CGPointMake(size.width - CGRectGetWidth(_closeButtonView.bounds) / 2 - 12, safeTop + 24);
    [view bringSubviewToFront:_closeButtonView];
  }
}

- (void)preparePresenter:(UIView *)presenter
{
  if (!_scalesPresenter || _presenterView) return;
  _presenterView = [presenter retain];
  _originalTransform = presenter.transform;
  _originalRadius = presenter.layer.cornerRadius;
  _originalMasks = presenter.layer.masksToBounds;
  if (presenter.superview) {
    _backdrop = [[UIView alloc] initWithFrame:presenter.superview.bounds];
    _backdrop.backgroundColor = _underlayColor;
    _backdrop.userInteractionEnabled = NO;
    _backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [presenter.superview insertSubview:_backdrop belowSubview:presenter];
  }
}

- (void)setPresenterRecessed:(BOOL)recessed
{
  _dimmingView.alpha = recessed ? 0.4 : 0;
  if (!_presenterView) return;
  CGFloat scale = recessed ? _scale : 1;
  CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
  transform = CGAffineTransformTranslate(transform, 0, CGRectGetHeight(_presenterView.bounds) * (1 - scale) / 2);
  _presenterView.transform = CGAffineTransformConcat(_originalTransform, transform);
  _presenterView.layer.cornerRadius = recessed ? _presenterRadius : _originalRadius;
  _presenterView.layer.masksToBounds = YES; // Keep clipping throughout reversal; restore originals on completion.
}

- (void)restorePresenter
{
  [_dimmingView removeFromSuperview];
  [_dimmingView release]; _dimmingView = nil;
  if (_presenterView) {
    _presenterView.transform = _originalTransform;
    _presenterView.layer.cornerRadius = _originalRadius;
    _presenterView.layer.masksToBounds = _originalMasks;
    [_presenterView release]; _presenterView = nil;
  }
  [_backdrop removeFromSuperview];
  [_backdrop release]; _backdrop = nil;
}

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source
{
  TiFullScreenSheetPresentation *presentation = [[[TiFullScreenSheetPresentation alloc] initWithPresentedViewController:presented presentingViewController:presenting] autorelease];
  presentation.owner = self;
  _presentation = presentation;
  return presentation;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{ _presenting = YES; return self; }
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{ _presenting = NO; return self; }
- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator
{ return _interaction; }
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context
{ return [context isAnimated] ? 0.425 : 0; }
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context
{
  [[self interruptibleAnimatorForTransition:context] startAnimation];
}
- (id<UIViewImplicitlyAnimating>)interruptibleAnimatorForTransition:(id<UIViewControllerContextTransitioning>)context
{
  if (_animator) return _animator;
  BOOL presenting = _presenting;
  UIView *container = context.containerView;
  UIViewController *controller = [context viewControllerForKey:presenting ? UITransitionContextToViewControllerKey : UITransitionContextFromViewControllerKey];
  UIView *view = controller.view;
  if (presenting) {
    UIViewController *presenter = [context viewControllerForKey:UITransitionContextFromViewControllerKey];
    [self preparePresenter:presenter.view];
    view.transform = CGAffineTransformIdentity;
    view.frame = container.bounds;
    [container addSubview:view];
    if (_fadesPresenter && !_dimmingView) {
      _dimmingView = [[UIView alloc] initWithFrame:container.bounds];
      _dimmingView.backgroundColor = UIColor.blackColor;
      _dimmingView.alpha = 0;
      _dimmingView.userInteractionEnabled = NO;
      _dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      [container insertSubview:_dimmingView belowSubview:view];
    }
    [self layoutInContainer:container];
    view.transform = CGAffineTransformMakeTranslation(0, CGRectGetHeight(container.bounds));
  }
  _animator = [[UIViewPropertyAnimator alloc] initWithDuration:[self transitionDuration:context] curve:UIViewAnimationCurveEaseInOut animations:^{
    view.transform = presenting ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, CGRectGetHeight(container.bounds));
    [self setPresenterRecessed:presenting];
  }];
  [_animator addCompletion:^(UIViewAnimatingPosition position) {
    BOOL completed = !context.transitionWasCancelled;
    if (!completed) {
      view.transform = CGAffineTransformIdentity;
      [self setPresenterRecessed:!presenting];
    }
    if ((!presenting && completed) || (presenting && !completed)) [self restorePresenter];
    [self->_animator release]; self->_animator = nil;
    [context completeTransition:completed];
    if (!presenting && completed) view.transform = CGAffineTransformIdentity;
  }];
  return _animator;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch
{
  if (gesture.numberOfTouches == 0) _touchStartY = [touch locationInView:_controller.view.window].y;
  _touchInScroll = NO;
  // Preserve controls and reject unbound/nested scrolling surfaces.
  for (UIView *view = touch.view; view && view != _controller.view; view = view.superview) {
    if ([view isKindOfClass:UIControl.class]) return NO;
    if ([view isKindOfClass:UIScrollView.class]) {
      _touchInScroll = view == _scrollView;
      return _touchInScroll;
    }
  }
  return YES;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture
{
  CGPoint velocity = [_pan velocityInView:_controller.view.window];
  return !_interactive && !_controller.presentedViewController && [self.delegate fullScreenSheetCanDismiss]
      && velocity.y > 0 && fabs(velocity.y) > fabs(velocity.x);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{ return _scrollView && other == _scrollView.panGestureRecognizer; }

- (void)pinScrollOffset
{
  if (!_scrollLocked || _pinningOffset) return;
  CGFloat top = -_scrollView.adjustedContentInset.top;
  if (fabs(_scrollView.contentOffset.y - top) < 0.1) return;
  _pinningOffset = YES;
  [_scrollView setContentOffset:CGPointMake(_scrollView.contentOffset.x, top) animated:NO];
  _pinningOffset = NO;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (context == &TiFullScreenOffsetContext) { [self pinScrollOffset]; return; }
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
- (void)unlockScroll
{
  if (_observingOffset) {
    [_scrollView removeObserver:self forKeyPath:@"contentOffset" context:&TiFullScreenOffsetContext];
    _observingOffset = NO;
  }
  if (_scrollLocked) _scrollView.bounces = _scrollWasBouncing;
  _scrollLocked = NO;
}
- (void)handlePan:(UIPanGestureRecognizer *)pan
{
  // Keep the first movement too: recognition can begin after a large motion.
  // Use a fixed window coordinate space, not the moving sheet's coordinates.
  BOOL moving = pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged;
  CGFloat translation = moving ? [pan locationInView:_controller.view.window].y - _touchStartY : _lastTranslation;
  if (moving) _lastTranslation = translation;
  CGFloat height = MAX(1, CGRectGetHeight(_controller.presentationController.containerView.bounds));
  if (pan.state == UIGestureRecognizerStateBegan) {
    _tracking = YES;
    _startTranslation = 0;
  }
  if ((pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) && _tracking) {
    if (!_interactive) {
      CGFloat top = _scrollView ? -_scrollView.adjustedContentInset.top : 0;
      if (_touchInScroll && _scrollView && _scrollView.contentOffset.y > top + 1) { _startTranslation = translation; return; }
      if ([pan velocityInView:_controller.view.window].y <= 0) { _startTranslation = translation; return; }
      if (![self.delegate fullScreenSheetCanDismiss]) { _tracking = NO; return; }
      _interactive = YES;
      _interaction = [[UIPercentDrivenInteractiveTransition alloc] init];
      _interaction.completionCurve = UIViewAnimationCurveEaseOut;
      [self.delegate fullScreenSheetWillDismiss];
      if (_touchInScroll && _scrollView) {
        _scrollWasBouncing = _scrollView.bounces;
        _scrollLocked = YES;
        _scrollView.bounces = NO;
        [_scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:&TiFullScreenOffsetContext];
        _observingOffset = YES;
        [self pinScrollOffset];
      }
      [_controller dismissViewControllerAnimated:YES completion:nil];
    }
    CGFloat progress = MIN(1, MAX(0, (translation - _startTranslation) / height));
    [_interaction updateInteractiveTransition:progress];
  } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled || pan.state == UIGestureRecognizerStateFailed) {
    _tracking = NO;
    if (!_interactive) return;
    CGFloat distance = MAX(0, translation - _startTranslation);
    CGFloat velocity = [pan velocityInView:_controller.view.window].y;
    BOOL finish = pan.state == UIGestureRecognizerStateEnded && velocity >= 0 && (distance + MIN(MAX(0, velocity) * 0.2, height * 0.5) > height * 0.5);
    if (finish) [_interaction finishInteractiveTransition];
    else [_interaction cancelInteractiveTransition];
  }
}
- (void)dismissalEnded:(BOOL)completed
{
  BOOL wasInteractive = _interactive;
  _interactive = NO; _tracking = NO;
  [self unlockScroll];
  [_interaction release]; _interaction = nil;
  if (completed) _presentation = nil;
  if (wasInteractive || completed) [self.delegate fullScreenSheetDidDismiss:completed];
}
- (void)invalidate
{
  self.delegate = nil;
  _presentation.owner = nil; _presentation = nil;
  _pan.delegate = nil;
  [_controller.view removeGestureRecognizer:_pan];
  _controller.transitioningDelegate = nil;
  _controller.view.layer.cornerRadius = _contentRadius;
  _controller.view.layer.masksToBounds = _contentMasks;
  [self unlockScroll];
  [self restorePresenter];
  [_grabber removeFromSuperview];
  _controller = nil;
}
- (void)dealloc
{
  if (_controller) [self invalidate];
  [_animator release]; [_pan release]; [_scrollView release]; [_interaction release]; [_grabber release]; [_underlayColor release];
  [super dealloc];
}
@end
