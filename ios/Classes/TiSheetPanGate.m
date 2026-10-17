#import "TiSheetPanGate.h"

@implementation TiSheetPanGate {
  UIViewController *_controller; // Non-owning; the proxy invalidates before teardown.
  NSHashTable *_disabledPans;
  CADisplayLink *_displayLink;
  BOOL _enabled;
  NSArray *_availableDetents;
}
- (instancetype)initWithController:(UIViewController *)controller
{
  if ((self = [super init])) {
    _controller = controller;
    _enabled = YES;
    _disabledPans = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsStrongMemory capacity:0];
  }
  return self;
}
- (void)setEnabled:(BOOL)enabled
{
  _enabled = enabled;
  if (enabled) {
    [_displayLink invalidate];
    [_displayLink release]; _displayLink = nil;
    // Only recognizers actually disabled by this gate are restored.
    for (UIGestureRecognizer *pan in _disabledPans) pan.enabled = YES;
    [_disabledPans removeAllObjects];
    [self restoreDetentsForSelection];
    [_availableDetents release]; _availableDetents = nil;
  } else {
    UISheetPresentationController *sheet = _controller.sheetPresentationController;
    if (!_availableDetents && sheet) _availableDetents = [sheet.detents copy];
    [self restrictToSelectedDetent];
    [self refresh];
    if (!_displayLink) {
      _displayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)] retain];
      [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
  }
}
- (void)restoreDetentsForSelection
{
  if (_availableDetents) _controller.sheetPresentationController.detents = _availableDetents;
}
- (void)restrictToSelectedDetent
{
  if (_enabled || !_availableDetents.count) return;
  if (@available(iOS 16.0, macCatalyst 16.0, *)) {
    UISheetPresentationController *sheet = _controller.sheetPresentationController;
    NSString *selected = sheet.selectedDetentIdentifier;
    for (UISheetPresentationControllerDetent *detent in _availableDetents) {
      if ((!selected && detent == _availableDetents.firstObject) || [detent.identifier isEqualToString:selected]) {
        sheet.detents = @[detent];
        break;
      }
    }
  }
}
- (void)tick:(CADisplayLink *)link { [self refresh]; }
- (void)refresh
{
  if (_enabled || !_controller.isViewLoaded) return;
  UIPresentationController *presentation = _controller.presentationController;
  if (![presentation isKindOfClass:UISheetPresentationController.class]) return;
  UIView *container = presentation.containerView;
  UIView *content = _controller.view;
  if (!container || ![content isDescendantOfView:container]) return;
  // Never enumerate the content subtree or window-wide system recognizers.
  // No private classes, selectors, targets, or replacement delegates are used.
  for (UIView *wrapper = content.superview; wrapper; wrapper = wrapper.superview) {
    for (UIGestureRecognizer *pan in wrapper.gestureRecognizers) {
      if ([pan isKindOfClass:UIPanGestureRecognizer.class]
          && ![pan isKindOfClass:UIScreenEdgePanGestureRecognizer.class] && pan.enabled) {
        [_disabledPans addObject:pan];
        pan.enabled = NO;
      }
    }
    if (wrapper == container) break;
  }
}
- (void)invalidate
{
  [self setEnabled:YES];
  _controller = nil;
}
- (void)dealloc
{
  [self invalidate];
  [_disabledPans release];
  [super dealloc];
}
@end
