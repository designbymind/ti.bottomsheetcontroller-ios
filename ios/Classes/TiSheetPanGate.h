#import <UIKit/UIKit.h>

// Suspends pans on presentation wrappers only. Content descendants are untouched.
@interface TiSheetPanGate : NSObject
- (instancetype)initWithController:(UIViewController *)controller;
- (void)setEnabled:(BOOL)enabled;
- (void)refresh;
// Bracket programmatic selection inside the proxy's animateChanges block.
- (void)restoreDetentsForSelection;
- (void)restrictToSelectedDetent;
- (void)invalidate;
@end
