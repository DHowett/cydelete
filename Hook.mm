#import "Hook.h"

#define SpringBoard_ "/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"

@implementation QuikDel

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

- (id)initWithIcon:(SBIcon *)icon path:(NSString *)path {
	self = [super init];
	_SBIcon = icon;
	_path = [path retain];
	_win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	_hud = [[UIProgressHUD alloc] initWithWindow:_win];
	return self;
}

- (void)_closeBoxClicked {
	[self startHUD:@"Looking Up Package..."];
	[NSThread detachNewThreadSelector:@selector(closeBoxClicked) toTarget:self withObject:nil];
}

- (void)closeBoxClicked {
	NSString *dpkgCmd = [[NSString alloc] initWithFormat:@"/usr/libexec/quikdel/owner.sh %@/Info.plist", _path];
	NSMutableString *dpkgOutput =  __QuikDel_outputForShellCommand(dpkgCmd);
	[self killHUD];
	[dpkgCmd release];

	if(!dpkgOutput) {
		NSString *body = [[NSString alloc] initWithFormat:@"%@ is not managed by Cydia, but we somehow passed the path check.", _path];
		UIAlertView *alertUnknown = [[UIAlertView alloc] initWithTitle:@"How Bizarre"
								message:body
								delegate:nil
								cancelButtonTitle:@"OK"
								otherButtonTitles:nil];
		[alertUnknown show];
		[alertUnknown autorelease];
		[self release];
	} else {
		_pkgName = [dpkgOutput copy];
		[dpkgOutput release];
		[self askDelete];
	}
}

// The [self retain] here does NOT seem right.
- (void)askDelete {
	NSString *title = [[NSString alloc] initWithFormat:@"Delete \"%@\"", [_SBIcon displayName]];
	NSString *body = [[NSString alloc] initWithFormat:@"Deleting \"%@\" will uninstall \"%@\"", [_SBIcon displayName], _pkgName];
	UIAlertView *delView = [[UIAlertView alloc] initWithTitle:title message:body delegate:[self retain] cancelButtonTitle:@"Delete" otherButtonTitles:@"Cancel", nil];
	[delView show];
	[title release];
	[body release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[alertView release];
	if(buttonIndex == 1) {
		return;
	}
	[self _uninstall];
}

- (void)_uninstall {
	[self startHUD:@"Uninstalling..."];
	[NSThread detachNewThreadSelector:@selector(uninstall) toTarget:self withObject:nil];
}

- (void)uninstall {
	NSString *command = [[NSString alloc] initWithFormat:@"/usr/libexec/quikdel/setuid /usr/libexec/quikdel/uninstall_.sh %@", _pkgName];

	NSString *body = __QuikDel_outputForShellCommand(command);

	[self killHUD];
	if(!body) {
		body = [[NSString alloc] initWithFormat:@"%@ failed uninstall.", _pkgName];
		UIAlertView *delView = [[UIAlertView alloc] initWithTitle:@"Error Uninstalling" message:body delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
		[delView show];
		[delView autorelease];
		[body release];
	} else {
		NSInteger finish = [QuikDel getFinish:body];
		[body release];
		Class $SBIconController = objc_getClass("SBIconController");
		id sharedSBIconController = [$SBIconController sharedInstance];
		[sharedSBIconController uninstallIcon:_SBIcon animate:YES];
		if(finish != NSNotFound && finish > 1) {
			id fh = [[QuikDelFinishHandler alloc] initWithFinish:_SBIcon finish:finish];
		}
	}

	[self release];
}

- dealloc {
	[self killHUD];
	[_hud release];
	[_win release];
	[_path release];
	[_pkgName release];
	[super dealloc];
}

@end

@implementation QuikDelFinishHandler
- (id)initWithFinish:(SBIcon *)_SBIcon finish:(NSInteger)finish {
	NSString *body = [[NSString alloc] initWithFormat:@"To complete the uninstall of %@, you must %@.", [_SBIcon displayName], [QuikDelFinishHandler finishString:finish]];
	_finish = finish;
	UIAlertView *finishView = [[UIAlertView alloc] initWithTitle:@"Action Required" message:body
		delegate:self cancelButtonTitle:[QuikDelFinishHandler finishString:finish] otherButtonTitles:nil];
	[finishView show];
	[finishView autorelease];
	[body release];
}

+ (id)finishString:(NSInteger)num {
	switch(num) {
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

- (void)doFinish {
	switch(_finish) {
		default:
		case 0:
		case 1:
			return;
		case 2:
			system("/usr/libexec/quikdel/setuid /bin/launchctl stop com.apple.SpringBoard");
			break;
		case 3:
			system("/usr/libexec/quikdel/setuid /bin/launchctl unload "SpringBoard_"; /usr/libexec/quikdel/setuid /bin/launchctl load "SpringBoard_);
			break;
		case 4:
			system("/usr/libexec/quikdel/setuid /sbin/reboot");
			break;
	}
	return;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	[self doFinish];
	[self release];
}
@end

NSMutableString *__QuikDel_outputForShellCommand(NSString *cmd) {
	FILE *fp;
	char buf[1024];
	NSMutableString* finalRet = [[NSMutableString alloc] init];

	fp = popen([cmd UTF8String], "r");
	if (fp == NULL) {
		return nil;
	}

	while (fgets(buf, 1024, fp) != NULL) {
		[finalRet appendString: [NSString stringWithUTF8String:buf]];
	}

	if(pclose(fp) != 0) {
		[finalRet release];
		return nil;
	}

	return finalRet;
}


static BOOL __$QuikDel_allowsCloseBox(SBIcon<QuikDel> *_SBIcon) {
	if([_SBIcon __OriginalMethodPrefix_allowsCloseBox]) return YES;

	NSString *bundle = [_SBIcon displayIdentifier];
	if([bundle hasPrefix:@"com.apple."]) return NO;
	else if([bundle isEqualToString:@"com.saurik.Cydia"]) return NO;
	else return YES;
}

static void __$QuikDel_closeBoxClicked(SBIcon<QuikDel> *_SBIcon, id fp8) {

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
	id qd = [[QuikDel alloc] initWithIcon:_SBIcon path:path];
	[qd _closeBoxClicked];
	[qd autorelease];
}

extern "C" void QuikDelInitialize() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Class _$SBIcon = objc_getClass("SBIcon");
	MSHookMessage(_$SBIcon, @selector(allowsCloseBox), (IMP) &__$QuikDel_allowsCloseBox, "__OriginalMethodPrefix_");
	MSHookMessage(_$SBIcon, @selector(closeBoxClicked:), (IMP) &__$QuikDel_closeBoxClicked, "__OriginalMethodPrefix_");

	[pool release];
}
