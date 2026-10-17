#import <UIKit/UIKit.h>

@protocol TiFullScreenSheetDelegate <NSObject>
- (BOOL)fullScreenSheetCanDismiss;
- (void)fullScreenSheetWillDismiss;
- (void)fullScreenSheetDidDismiss:(BOOL)completed;
@end

// UIKit-only presentation, animation and scroll handoff. The proxy owns this object.
@interface TiFullScreenSheetTransition : NSObject <UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning, UIGestureRecognizerDelegate>
@property(nonatomic, assign) id<TiFullScreenSheetDelegate> delegate;
- (instancetype)initWithController:(UIViewController *)controller
                       scrollView:(UIScrollView *)scrollView
                    configuration:(NSDictionary *)configuration;
- (void)setInteractiveGesturesEnabled:(BOOL)enabled;
- (void)setGrabberVisible:(BOOL)visible;
- (void)setCloseButtonView:(UIView *)view;
- (void)layoutInContainer:(UIView *)container;
- (void)dismissalEnded:(BOOL)completed;
- (void)invalidate;
@end
