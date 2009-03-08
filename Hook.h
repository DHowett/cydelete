#import <UIKit/UIKit.h>
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

@interface QuikDel : NSObject {
	SBIcon *_SBIcon;
	NSString *_pkgName;
}
+ (id)showHUDonSpringBoard:(id)message;
+ killHUD:(id)hud;
- (id)initWithIcon:(SBIcon *)icon package:(NSString *)pkgName;
- askDelete;
- dealloc;
@end
