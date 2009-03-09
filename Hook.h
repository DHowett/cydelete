#import <UIKit/UIKit.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIInterface.h>
#import <UIKit/UIAlert.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIProgressHUD.h>
#import <UIKit/UIActivityIndicatorView.h>
#import <Foundation/Foundation.h>
#import "SpringBoard/SBIcon.h"
#import "SpringBoard/SBIconController.h"
#import "SpringBoard/SBApplicationController.h"
#import "SpringBoard/SBApplication.h"
#import <objc/runtime.h>
#import "substrate.h"

@protocol QuikDel

- (BOOL)__OriginalMethodPrefix_allowsCloseBox;
- (void)__OriginalMethodPrefix_closeBoxClicked:(id)fp8;
@end

NSMutableString *__QuikDel_outputForShellCommand(NSString *cmd);
static BOOL __$QuikDel_allowsCloseBox(SBIcon<QuikDel> *_SBIcon);
static void __$QuikDel_closeBoxClicked(SBIcon<QuikDel> *_SBIcon, id fp8);
extern "C" void QuikDelInitialize();

@interface QuikDel : NSObject<UIAlertViewDelegate> {
	SBIcon *_SBIcon;
	NSString *_pkgName;
	NSString *_path;
	UIProgressHUD *_hud;
	UIWindow *_win;
}
- (void)startHUD:(id)message;
- (void)killHUD;
+ (NSInteger)getFinish:(NSString *)text;
- (id)initWithIcon:(SBIcon *)icon path:(NSString *)path;
- (void)_closeBoxClicked;
- (void)closeBoxClicked;
- (void)_uninstall;
- (void)uninstall;
- (void)askDelete;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- dealloc;
@end

@interface QuikDelFinishHandler : NSObject<UIAlertViewDelegate> {
	NSInteger _finish;
}
- (id)initWithFinish:(SBIcon *)_SBIcon finish:(NSInteger)finish;
+ (id)finishString:(NSInteger)num;
- (void)doFinish;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end
