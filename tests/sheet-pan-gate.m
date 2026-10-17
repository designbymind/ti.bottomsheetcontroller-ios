#import <UIKit/UIKit.h>
#include <stdio.h>
#import "TiSheetPanGate.h"
static int failures;
static void check(BOOL pass,const char *name){printf("%s %s\n",pass?"PASS":"FAIL",name);if(!pass)failures++;}
@interface Scene : UIResponder<UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation Scene
- (void)scene:(UIScene *)s willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)o {
 self.window=[[UIWindow alloc]initWithWindowScene:(UIWindowScene *)s];self.window.rootViewController=[UIViewController new];[self.window makeKeyAndVisible];
 dispatch_async(dispatch_get_main_queue(), ^{
 UIViewController *content=[UIViewController new]; UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:content];nav.modalPresentationStyle=UIModalPresentationPageSheet;nav.sheetPresentationController.detents=@[UISheetPresentationControllerDetent.mediumDetent,UISheetPresentationControllerDetent.largeDetent];
 [self.window.rootViewController presentViewController:nav animated:NO completion:^{
 NSMutableArray *nativePans=[NSMutableArray new];
 UIView *container=nav.presentationController.containerView;
 for(UIView *v=nav.view.superview;v;v=v.superview){for(UIGestureRecognizer *g in v.gestureRecognizers)if([g isKindOfClass:UIPanGestureRecognizer.class]&&g.enabled)[nativePans addObject:g];if(v==container)break;}
 check(nativePans.count>0,"real native sheet wrapper has pan recognizer");
 UIScrollView *table=[UIScrollView new];[content.view addSubview:table];
 UITextView *input=[UITextView new];[content.view addSubview:input];
 UIPanGestureRecognizer *keyboard=[UIPanGestureRecognizer new];[content.view addGestureRecognizer:keyboard];
 UIPanGestureRecognizer *alreadyDisabled=[UIPanGestureRecognizer new];alreadyDisabled.enabled=NO;[nav.view.superview addGestureRecognizer:alreadyDisabled];
 TiSheetPanGate *gate=[[TiSheetPanGate alloc]initWithController:nav];[gate setEnabled:NO];
 BOOL allDisabled=YES;for(UIGestureRecognizer *pan in nativePans)allDisabled &= !pan.enabled;
 check(allDisabled,"lock disables native sheet wrapper pans");
 check(nav.sheetPresentationController.detents.count==1,"lock removes alternate detents");
 check(table.panGestureRecognizer.enabled&&input.panGestureRecognizer.enabled&&keyboard.enabled,"table TextArea and keyboard pans remain enabled");
 check(nav.interactivePopGestureRecognizer.enabled,"navigation content gesture remains enabled");
 UIPanGestureRecognizer *late=[UIPanGestureRecognizer new];[nav.view.superview addGestureRecognizer:late];[gate refresh];
 check(!late.enabled,"wrapper pan added while locked is captured");
 [nav.sheetPresentationController animateChanges:^{[gate restoreDetentsForSelection];nav.sheetPresentationController.selectedDetentIdentifier=UISheetPresentationControllerDetentIdentifierLarge;[gate restrictToSelectedDetent];}];
 check([nav.sheetPresentationController.selectedDetentIdentifier isEqualToString:UISheetPresentationControllerDetentIdentifierLarge],"programmatic large detent still works while locked");
 [gate setEnabled:YES];check(nav.sheetPresentationController.detents.count==2,"unlock restores medium and large detents");BOOL allEnabled=YES;for(UIGestureRecognizer *pan in nativePans)allEnabled &= pan.enabled;
 check(allEnabled&&late.enabled,"unlock restores pans disabled by gate");
 check(!alreadyDisabled.enabled,"unlock preserves preexisting disabled recognizer");
 [gate setEnabled:NO];[gate invalidate];check(((UIGestureRecognizer *)nativePans.firstObject).enabled,"invalidate restores native pans");
 printf("RESULT %d failures\n",failures);
 fflush(stdout);exit(failures?1:0);
 }]; });
}
@end
@interface App : UIResponder<UIApplicationDelegate>@end
@implementation App @end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(App.class));}}
