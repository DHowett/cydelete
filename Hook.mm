#import "Hook.h"

#define SpringBoard_ "/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"

@implementation CyDelete

- (void)startHUD:(id)message {
	[_hud setText:message];
	[_hud show:YES];
	[_win makeKeyAndVisible];
	[_win addSubview:_hud];
}

- (void)killHUD {
	[_hud show:NO];
	[_hud removeFromSuperview];
	[_win resignKeyWindow];
	[_win setHidden:YES];
}

+ (NSInteger)getFinish:(NSString *)text {
	static NSArray *Finishes_;
	if(!Finishes_)
		Finishes_ = [NSArray arrayWithObjects:@"return", @"reopen", @"restart", @"reload", @"reboot", nil];
	if([text length] > 0)
		return [Finishes_ indexOfObject:text];
	else
		return NSNotFound;
}

+ (NSString *)getFinishString:(NSInteger)finish {
	switch(finish) {
		default:
		case 0:
		case 1:
			return @"Okay";
		case 2:
			return @"Restart SpringBoard";
		case 3:
			return @"Reload SpringBoard";
		case 4:
			return @"Reboot";
	}
}

- (id)initWithIcon:(SBIcon *)icon path:(NSString *)path {
	self = [super init];
	_finish = -1;
	_SBIcon = [icon retain];
	_path = [path retain];
	_win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	_hud = [[UIProgressHUD alloc] initWithWindow:_win];
	return self;
}

- (void)_closeBoxClicked {
	[self startHUD:@"Looking Up Package..."];
	[NSThread detachNewThreadSelector:@selector(closeBoxClicked_thread:) toTarget:self withObject:[NSThread currentThread]];
}

- (void)closeBoxClicked_thread:(id)callingThread {
	Class $SBApplicationController = objc_getClass("SBApplicationController");
	id sharedSBApplicationController = [$SBApplicationController sharedInstance];
	id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]];
	NSString *bundle = [[app bundle] bundleIdentifier];
	NSString *title = [app displayName];
	NSString *dpkgCmd = [NSString stringWithFormat:@"/usr/libexec/cydelete/owner.sh \"%@\" \"%@\" \"%@/Info.plist\"", bundle, title, _path];
	NSMutableString *dpkgOutput =  __CyDelete_outputForShellCommand(dpkgCmd);
	[self killHUD];
	[self performSelector:@selector(closeBoxClicked_finish:) onThread:callingThread withObject:dpkgOutput waitUntilDone:NO];
}

- (void)closeBoxClicked_finish:(id)dpkgOutput {
	if(!dpkgOutput) {
		NSString *body = [[NSString alloc] initWithFormat:@"%@ was not installed by Cydia. You should not see this message, unless you installed this application yourself, in which case, I cannot remove it for you.", [_SBIcon displayName]];
		UIAlertView *alertUnknown = [[UIAlertView alloc] initWithTitle:@"Not Installed by Cydia"
								message:body
								delegate:nil
								cancelButtonTitle:@"OK"
								otherButtonTitles:nil];
		[body release];
		[alertUnknown show];
		[alertUnknown release];
		return;
	} else {
		_pkgName = [dpkgOutput copy];
		[self askDelete];
		return;
	}
}

// The [self retain] here does NOT seem right.
- (void)askDelete {
	NSString *title = [NSString stringWithFormat:@"Delete \"%@\"", [_SBIcon displayName]];
	NSString *body = [NSString stringWithFormat:@"Deleting \"%@\" will uninstall \"%@\"", [_SBIcon displayName], _pkgName];
	id delSheet = [[[UIActionSheet alloc]
			initWithTitle:title
			buttons:[NSArray arrayWithObjects:@"Delete", @"Cancel", nil]
			defaultButtonIndex:2
			delegate:[self retain]
			context:@"askDelete"]
		autorelease];
	[delSheet setNumberOfRows:1];
	[delSheet setBodyText:body];
	[delSheet popupAlertAnimated:YES];
}

- (void)alertSheet:(UIActionSheet *)alertSheet buttonClicked:(NSInteger)buttonIndex {
	NSString *context = [alertSheet context];
	[alertSheet dismiss];
	if([context isEqualToString:@"askDelete"]) {
		if(buttonIndex == 1) {
			[self _uninstall];
		}
	} else if([context isEqualToString:@"finish"]) {
		[self finishUninstall];
	}
}

- (void)_uninstall {
	[self startHUD:@"Uninstalling..."];
	[NSThread detachNewThreadSelector:@selector(uninstall_thread:) toTarget:self withObject:[NSThread currentThread]];
}

- (void)uninstall_thread:(NSThread *)callingThread {
	NSString *command = [NSString stringWithFormat:@"/usr/libexec/cydelete/setuid /usr/libexec/cydelete/uninstall_.sh %@", _pkgName];
	NSString *body = __CyDelete_outputForShellCommand(command);
	[self killHUD];
	[self performSelector:@selector(uninstalled:) onThread:callingThread withObject:body waitUntilDone:NO];
}

- (void)uninstalled:(NSString *)body {
	if(!body) {
		body = [[NSString alloc] initWithFormat:@"%@ failed uninstall.", _pkgName];
		UIAlertView *delView = [[UIAlertView alloc] initWithTitle:@"Error Uninstalling" message:body delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
		[delView show];
		[delView release];
		[body release];
	} else {
		Class $SBIconController = objc_getClass("SBIconController");
		id sharedSBIconController = [$SBIconController sharedInstance];
		[sharedSBIconController uninstallIcon:_SBIcon animate:YES];
		if([body length] > 0) {
			_finish = [CyDelete getFinish:body];
			if(_finish != NSNotFound && _finish > 1) {
				[self notifyFinish];
			}
		}
	}

	[self autorelease];
}

- (void)notifyFinish {
	NSString *body = [NSString stringWithFormat:@"To complete the uninstall of %@, you must %@.", [_SBIcon displayName], [CyDelete getFinishString:_finish]];
	id finishSheet = [[[UIActionSheet alloc]
			initWithTitle:@"Action Required"
			buttons:[NSArray arrayWithObjects:[CyDelete getFinishString:_finish], nil]
			defaultButtonIndex:1
			delegate:self
			context:@"finish"]
		autorelease];
	[finishSheet setBodyText:body];
	[finishSheet popupAlertAnimated:YES];
}

- (void)finishUninstall {
	switch(_finish) {
		default:
		case 0:
		case 1:
			return;
		case 2:
			system("/usr/libexec/cydelete/setuid /bin/launchctl stop com.apple.SpringBoard");
			break;
		case 3:
			system("/usr/libexec/cydelete/setuid /bin/launchctl unload "SpringBoard_"; /usr/libexec/cydelete/setuid /bin/launchctl load "SpringBoard_);
			break;
		case 4:
			system("/usr/libexec/cydelete/setuid /sbin/reboot");
			break;
	}
	return;
}

- dealloc {
	[self killHUD];
	[_hud release];
	[_win release];
	[_path release];
	[_pkgName release];
	[_SBIcon release];
	[super dealloc];
}

@end

NSMutableString *__CyDelete_outputForShellCommand(NSString *cmd) {
	FILE *fp;
	char buf[1024];
	NSMutableString* finalRet;

	fp = popen([cmd UTF8String], "r");
	if (fp == NULL) {
		return nil;
	}

	fgets(buf, 1024, fp);
	finalRet = [NSString stringWithUTF8String:buf];

	if(pclose(fp) != 0) {
		[finalRet release];
		return nil;
	}

	return finalRet;
}


static BOOL __$CyDelete_allowsCloseBox(SBIcon<CyDelete> *_SBIcon) {
	if([_SBIcon __OriginalMethodPrefix_allowsCloseBox]) return YES;

	NSString *bundle = [_SBIcon displayIdentifier];
	if([bundle hasPrefix:@"com.apple."]) return NO;
	else if([bundle isEqualToString:@"com.saurik.Cydia"]) return NO;
	else return YES;
}

static void __$CyDelete_closeBoxClicked(SBIcon<CyDelete> *_SBIcon, id fp8) {

	NSString *path;
	Class $SBApplicationController = objc_getClass("SBApplicationController");
	id sharedSBApplicationController = [$SBApplicationController sharedInstance];
	path = [[sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]] path];

	if([path isEqualToString:@"/Applications/Web.app"] ||
		   [path hasPrefix:@"/private/var/mobile"] ||
		   [path hasPrefix:@"/var/mobile"]) {
		[_SBIcon __OriginalMethodPrefix_closeBoxClicked:fp8];
		return;
	}
	id qd = [[CyDelete alloc] initWithIcon:_SBIcon path:path];
	[qd _closeBoxClicked];
}

extern "C" void CyDeleteInitialize() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Class _$SBIcon = objc_getClass("SBIcon");
	MSHookMessage(_$SBIcon, @selector(allowsCloseBox), (IMP) &__$CyDelete_allowsCloseBox, "__OriginalMethodPrefix_");
	MSHookMessage(_$SBIcon, @selector(closeBoxClicked:), (IMP) &__$CyDelete_closeBoxClicked, "__OriginalMethodPrefix_");

	[pool release];
}
