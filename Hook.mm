#import "Hook.h"

#define SpringBoard_ "/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"

static SBApplicationController *sharedSBApplicationController = nil;
static NSBundle *cyDelBundle = nil;

static NSString *SBLocalizedString(NSString *key) {
	return [[NSBundle mainBundle] localizedStringForKey:key value:@"None" table:@"SpringBoard"];
}

static void initTranslation() {
	cyDelBundle = [[NSBundle bundleWithPath:BUNDLE] retain];
}

static inline NSString *CDLocalizedString(NSString *key) {
	return [cyDelBundle localizedStringForKey:key value:key table:nil];
}

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

- (void)removeFromMIList:(NSString *)bundle {
	NSString *path([NSString stringWithFormat:@"%@/Library/Caches/com.apple.mobile.installation.plist", NSHomeDirectory()]);
	NSMutableDictionary *cache = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
	[cache autorelease];
	[[cache objectForKey:@"System"] removeObjectForKey:bundle];
	[cache writeToFile:path atomically:YES];
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
			return CDLocalizedString(@"PACKAGE_FINISH_OKAY");
		case 2:
			return CDLocalizedString(@"PACKAGE_FINISH_RESTART");
		case 3:
			//return CDLocalizedString(@"PACKAGE_FINISH_RELOAD");
		case 4:
			return CDLocalizedString(@"PACKAGE_FINISH_REBOOT");
	}
}

- (id)initWithIcon:(SBIcon *)icon path:(NSString *)path {
	self = [super init];
	_finish = -1;
	_SBIcon = [icon retain];
	_path = [path retain];
	_win = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	_hud = [[UIProgressHUD alloc] initWithWindow:_win];
	return self;
}

- (void)_closeBoxClicked {
	id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]];
	NSString *bundle = [[app bundle] bundleIdentifier];
	if([bundle isEqualToString:@"com.ripdev.Installer"]
	   || [bundle isEqualToString:@"com.ripdev.install"]) {
		// If we're dealing with Installer, short circuit over the package search. 
		_cydiaManaged = false;
		[self askDelete];
		return;
	}
	[self startHUD:CDLocalizedString(@"PACKAGE_SEARCHING")];
	[NSThread detachNewThreadSelector:@selector(closeBoxClicked_thread:) toTarget:self withObject:[NSThread currentThread]];
}

- (void)closeBoxClicked_thread:(id)callingThread {
	id pool = [[NSAutoreleasePool alloc] init];
	id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]];
	NSString *bundle = [[app bundle] bundleIdentifier];
	NSString *title = [app displayName];
	NSString *dpkgCmd = [NSString stringWithFormat:@"/usr/libexec/cydelete/owner.sh \"%@\" \"%@\" \"%@/Info.plist\"", bundle, title, _path];
	NSMutableString *dpkgOutput =  __CyDelete_outputForShellCommand(dpkgCmd);
	[self killHUD];
	_pkgName = [dpkgOutput copy];
	[self performSelector:@selector(closeBoxClicked_finish) onThread:callingThread withObject:nil waitUntilDone:YES];
	[pool drain];
}

- (void)closeBoxClicked_finish {
	if(!_pkgName) {

		// Specialcase Icy if installed outside Cydia.
		id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]];
		NSString *bundle = [[app bundle] bundleIdentifier];
		if([bundle isEqualToString:@"com.ripdev.icy"]) {
			_cydiaManaged = false;
			[self askDelete];
			return;
		}

		NSString *body = [[NSString alloc] initWithFormat:CDLocalizedString(@"PACKAGE_NOT_CYDIA_BODY"), [_SBIcon displayName]];
		UIAlertView *alertUnknown = [[UIAlertView alloc] initWithTitle:CDLocalizedString(@"PACKAGE_NOT_CYDIA_TITLE")
								message:body
								delegate:nil
								cancelButtonTitle:@"OK"
								otherButtonTitles:nil];
		[body release];
		[alertUnknown show];
		[alertUnknown release];
		return;
	} else {
		_cydiaManaged = true;
		[self askDelete];
		return;
	}
}

// The [self retain] here does NOT seem right.
- (void)askDelete {
	NSString *title = [NSString stringWithFormat:SBLocalizedString(@"UNINSTALL_ICON_TITLE"), [_SBIcon displayName]];
	NSString *body;
	if(_cydiaManaged)
		body = [NSString stringWithFormat:CDLocalizedString(@"PACKAGE_DELETE_BODY"), [_SBIcon displayName], _pkgName];
	else
		body = [NSString stringWithFormat:SBLocalizedString(@"DELETE_WIDGET_BODY"), [_SBIcon displayName]];
	id delSheet = [[[UIActionSheet alloc]
			initWithTitle:title
			buttons:[NSArray arrayWithObjects:SBLocalizedString(@"UNINSTALL_ICON_CONFIRM"), SBLocalizedString(@"UNINSTALL_ICON_CANCEL"), nil]
			defaultButtonIndex:2
			delegate:[self retain]
			context:@"askDelete"]
		autorelease];
	[delSheet setNumberOfRows:1];
	[delSheet setDestructiveButtonIndex:1];
	[delSheet setCancelButtonIndex:2];
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
	[self startHUD:CDLocalizedString(@"PACKAGE_UNINSTALLING")];
	[NSThread detachNewThreadSelector:(_cydiaManaged ? @selector(uninstall_thread_dpkg:) : @selector(uninstall_thread_nondpkg:))
		  toTarget:self
		  withObject:[NSThread currentThread]];
}

- (void)uninstall_thread_dpkg:(NSThread *)callingThread {
	id pool = [[NSAutoreleasePool alloc] init];
	NSString *command = [NSString stringWithFormat:@"/usr/libexec/cydelete/setuid /usr/libexec/cydelete/uninstall_dpkg.sh %@", _pkgName];
	NSString *body = __CyDelete_outputForShellCommand(command);
	[self performSelector:@selector(uninstalled:) onThread:callingThread withObject:body waitUntilDone:YES];
	[pool drain];
}

- (void)uninstall_thread_nondpkg:(NSThread *)callingThread {
	id pool = [[NSAutoreleasePool alloc] init];
	id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]];
	NSString *command = [NSString stringWithFormat:@"/usr/libexec/cydelete/setuid /usr/libexec/cydelete/uninstall_nondpkg.sh %@", [app path]];
	system([command UTF8String]);
	[self performSelector:@selector(uninstalled:) onThread:callingThread withObject:nil waitUntilDone:YES];
	[pool drain];
}

- (void)uninstalled:(NSString *)body {
	if(!body && _cydiaManaged) {
		[self killHUD];
		body = [[NSString alloc] initWithFormat:CDLocalizedString(@"PACKAGE_UNINSTALL_ERROR_BODY"), _pkgName];
		UIAlertView *delView = [[UIAlertView alloc] initWithTitle:CDLocalizedString(@"PACKAGE_UNINSTALL_ERROR_TITLE") message:body delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
		[delView show];
		[delView release];
		[body release];
	} else {
		/* Remove the Application from the ApplicationController */
		id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]];
		NSString *bundle = [[app bundle] bundleIdentifier];
		[sharedSBApplicationController removeApplicationsFromModelWithBundleIdentifier:bundle];

		/* Uninstall the icon with the cool "winking out of existence" animation! */
		Class $SBIconController = objc_getClass("SBIconController");
		id sharedSBIconController = [$SBIconController sharedInstance];
		[sharedSBIconController uninstallIcon:_SBIcon animate:YES];

		[self removeFromMIList:bundle];

		if([bundle isEqualToString:@"jp.ashikase.springjumps"]) {
			Class $SBIconModel = objc_getClass("SBIconModel");
			id sharedSBIconModel = [$SBIconModel sharedInstance];

			NSArray *allBundles = [sharedSBApplicationController allApplications];
			int i = 0;
			int count = [allBundles count];
			for(i = 0; i < count; i++) {
				SBApplication *curApp = [allBundles objectAtIndex:i];
				NSString *bundle = [curApp bundleIdentifier];
				if(![bundle hasPrefix:@"jp.ashikase.springjumps."])
					continue;
				SBIcon *curIcon = [sharedSBIconModel iconForDisplayIdentifier:[curApp displayIdentifier]];
				if(!curIcon) continue;
				[sharedSBApplicationController removeApplicationsFromModelWithBundleIdentifier:bundle];
				[sharedSBIconController uninstallIcon:curIcon animate:YES];
			}
		}

		[self killHUD];

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
	NSString *body = [NSString stringWithFormat:CDLocalizedString(@"PACKAGE_FINISH_BODY"), [_SBIcon displayName], [CyDelete getFinishString:_finish]];
	id finishSheet = [[[UIActionSheet alloc]
			initWithTitle:CDLocalizedString(@"PACKAGE_FINISH_TITLE")
			buttons:[NSArray arrayWithObjects:[CyDelete getFinishString:_finish], nil]
			defaultButtonIndex:1
			delegate:self
			context:@"finish"]
		autorelease];
	[finishSheet setBodyText:body];
	[finishSheet popupAlertAnimated:YES];
}

- (void)finishUninstall {
	//Class $SpringBoard = objc_getClass("SpringBoard");
	//SpringBoard *sharedSB = [$SpringBoard sharedInstance];
	switch(_finish) {
		default:
		case 0:
		case 1:
			return;
		case 2:
			system("/usr/libexec/cydelete/setuid /bin/launchctl stop com.apple.SpringBoard");
			break;
		case 3:
			//[sharedSB relaunchSpringBoard];
			//system("/usr/libexec/cydelete/setuid /bin/launchctl unload "SpringBoard_"; /usr/libexec/cydelete/setuid /bin/launchctl load "SpringBoard_);
			//break;
		case 4:
			//[sharedSB reboot];
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

	NSLog(@"CD: Calling %@.", cmd);
	fp = popen([cmd UTF8String], "r");
	if (fp == NULL) {
		return nil;
	}

	fgets(buf, 1024, fp);
	NSLog(@"CD: received %s", buf);
	finalRet = [NSString stringWithUTF8String:buf];
	NSLog(@"CD: Turned into %@", finalRet);

	if(pclose(fp) != 0) {
		return nil;
	}

	return finalRet;
}


static BOOL __$CyDelete_allowsCloseBox(SBIcon<CyDelete> *_SBIcon) {
	if([_SBIcon __CD_allowsCloseBox]) return YES;

	NSString *bundle = [_SBIcon displayIdentifier];
	if([bundle hasPrefix:@"com.apple."]
	|| [bundle isEqualToString:@"com.saurik.Cydia"]
	|| [bundle hasPrefix:@"com.bigboss.categories."]
	|| [bundle hasPrefix:@"jp.ashikase.springjumps."])
		return NO;
	else return YES;
}

static void __$CyDelete_closeBoxClicked(SBIcon<CyDelete> *_SBIcon, id fp8) {
	NSString *path;
	Class $SBApplicationController = objc_getClass("SBApplicationController");
	sharedSBApplicationController = [$SBApplicationController sharedInstance];
	path = [[sharedSBApplicationController applicationWithDisplayIdentifier:[_SBIcon displayIdentifier]] path];

	if([path isEqualToString:@"/Applications/Web.app"] ||
		   [path hasPrefix:@"/private/var/mobile"] ||
		   [path hasPrefix:@"/var/mobile"] || path == NULL) {
		[_SBIcon __CD_closeBoxClicked:fp8];
		return;
	}
	id qd = [[CyDelete alloc] initWithIcon:_SBIcon path:path];
	[qd _closeBoxClicked];
}

extern "C" void CyDeleteInitialize() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Class _$SBIcon = objc_getClass("SBIcon");
	MSHookMessage(_$SBIcon, @selector(allowsCloseBox), (IMP) &__$CyDelete_allowsCloseBox, "__CD_");
	MSHookMessage(_$SBIcon, @selector(closeBoxClicked:), (IMP) &__$CyDelete_closeBoxClicked, "__CD_");
	initTranslation();

	[pool release];
}
