#import <UIKit/UIProgressHUD.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplication.h>
#import <DHHookCommon.h>

NSMutableString *__CyDelete_outputForShellCommand(NSString *cmd);
static void CDUpdatePrefs();
extern "C" void CyDeleteInitialize();

@interface CyDelete : NSObject {
	NSAutoreleasePool *_pool;
	SBIcon *_SBIcon;
	NSString *_pkgName;
	NSString *_path;
	UIProgressHUD *_hud;
	UIWindow *_win;
	bool _cydiaManaged;
}
- (void)startHUD:(id)message;
- (void)killHUD;
- (id)initWithIcon:(SBIcon *)icon path:(NSString *)path;
- (void)_closeBoxClicked;
- (void)closeBoxClicked_thread:(id)callingThread;
- (void)closeBoxClicked_finish;
- (void)askDelete;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)_uninstall;
- (void)uninstall_thread_dpkg:(NSThread *)callingThread;
- (void)uninstall_thread_nondpkg:(NSThread *)callingThread;
- (void)uninstalled:(NSString *)body;
- (void)dealloc;
@end
