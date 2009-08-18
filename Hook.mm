#import "Hook.h"
#import <mach/mach_host.h>

#define SpringBoard_ "/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"

static SBApplicationController *sharedSBApplicationController = nil;
static NSBundle *cyDelBundle = nil;
static NSDictionary *cyDelPrefs = nil;
static UIImage *safariCloseBox = nil;

#define SBLocalizedString(key) [[NSBundle mainBundle] localizedStringForKey:key value:@"None" table:@"SpringBoard"]
#define CDLocalizedString(key) [cyDelBundle localizedStringForKey:key value:key table:nil]

static void initTranslation() {
	cyDelBundle = [[NSBundle bundleWithPath:BUNDLE] retain];
}

static bool CDGetBoolPref(id key, bool value) {
	if(!cyDelPrefs) return value;
	id object = [cyDelPrefs objectForKey:key];
	if(!object) return value;
	else return [object boolValue];
}

// Thanks _BigBoss_!
static int getFreeMemory() {
	vm_size_t pageSize;
	host_page_size(mach_host_self(), &pageSize);
	struct vm_statistics vmStats;
	mach_msg_type_number_t infoCount = sizeof(vmStats);
	host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmStats, &infoCount);
	int availMem = vmStats.free_count + vmStats.inactive_count;
	return (availMem * pageSize) / 1024 / 1024;
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

- (id)initWithIcon:(SBIcon *)icon path:(NSString *)path {
	self = [super init];
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
	if(!_pkgName && !CDGetBoolPref(@"CDNonCydiaDelete", false)) {
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
		_cydiaManaged = (_pkgName != nil);
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
	id delView = [[[UIAlertView alloc]
			initWithTitle:title
			message:body
			delegate:[self retain]
			cancelButtonTitle:nil
			otherButtonTitles:nil]
		autorelease];
	[delView addButtonWithTitle:SBLocalizedString(@"UNINSTALL_ICON_CONFIRM")];
	[delView addButtonWithTitle:SBLocalizedString(@"UNINSTALL_ICON_CANCEL")];
	[delView setCancelButtonIndex:1];
	[delView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex == [alertView cancelButtonIndex]) {
		[self release];
		return;
	}
	[self _uninstall];
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
				[self removeFromMIList:bundle];
				[sharedSBApplicationController removeApplicationsFromModelWithBundleIdentifier:bundle];
				[sharedSBIconController uninstallIcon:curIcon animate:YES];
			}
		}

		[self killHUD];
	}

	[self autorelease];
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


HOOK(SBIcon, allowsCloseBox, BOOL) {
	if(CALL_ORIG(SBIcon, allowsCloseBox)) return YES;
	if (!safariCloseBox) safariCloseBox = [[UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/closebox.png"] retain];

	NSString *bundle = [self displayIdentifier];
	if(([bundle hasPrefix:@"com.apple."] && ![bundle hasPrefix:@"com.apple.samplecode."])
	|| ([bundle isEqualToString:@"com.saurik.Cydia"] && CDGetBoolPref(@"CDProtectCydia", true))
	|| [bundle hasPrefix:@"com.bigboss.categories."]
	|| ([bundle isEqualToString:@"com.ripdev.icy"] && CDGetBoolPref(@"CDProtectIcy", false))
	|| [bundle hasPrefix:@"jp.ashikase.springjumps."]
	|| [bundle hasPrefix:@"com.steventroughtonsmith.stack"])
		return NO;
	else return YES;
}

HOOK(SBIcon, closeBoxClicked$, void, id fp8) {
	Class $SBApplicationController = objc_getClass("SBApplicationController");
	sharedSBApplicationController = [$SBApplicationController sharedInstance];
	id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[self displayIdentifier]];

	if(!app || ![app isSystemApplication] || [[app path] isEqualToString:@"/Applications/Web.app"]) {
		CALL_ORIG(SBIcon, closeBoxClicked$, fp8);
		return;
	}
	if(getFreeMemory() < 20) {
		id memView = [[[UIAlertView alloc] initWithTitle:nil message:CDLocalizedString(@"NOT_ENOUGH_MEMORY")
						   delegate:nil cancelButtonTitle:CDLocalizedString(@"PACKAGE_FINISH_OKAY")
						   otherButtonTitles:nil] autorelease];
		[memView show];
		return;
	}
	id qd = [[CyDelete alloc] initWithIcon:self path:[app path]];
	[qd _closeBoxClicked];
	[qd release];
}

HOOK(SBApplication, deactivated, void) {
	if([[self displayIdentifier] isEqualToString:@"com.apple.Preferences"]) {
		CDUpdatePrefs();
	}
	CALL_ORIG(SBApplication, deactivated);
}

static void CDUpdatePrefs() {
	NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/net.howett.cydelete.plist"];
	if(!prefs) return;
	if(!cyDelPrefs || ![cyDelPrefs isEqualToDictionary:prefs]) {
		[cyDelPrefs release];
		cyDelPrefs = prefs;
	}
}

HOOK(SBIcon, setIsShowingCloseBox$, void, BOOL fp) {
	CALL_ORIG(SBIcon, setIsShowingCloseBox$, fp);
	if(fp == NO) return;

	UIPushButton *cb;
	object_getInstanceVariable(self, "_closeBox", reinterpret_cast<void**>(&cb));

	Class $SBApplicationController = objc_getClass("SBApplicationController");
	sharedSBApplicationController = [$SBApplicationController sharedInstance];
	id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[self displayIdentifier]];

        if([app isSystemApplication] && ![[app path] isEqualToString:@"/Applications/Web.app"]) {
		[cb setImage:safariCloseBox forState:0];
		[cb setImage:safariCloseBox forState:1];
	}
}

extern "C" void CyDeleteInitialize() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	GET_CLASS(SBIcon);
	HOOK_MESSAGE(SBIcon, allowsCloseBox);
	HOOK_MESSAGE_REPLACEMENT(SBIcon, closeBoxClicked:, closeBoxClicked$);
	HOOK_MESSAGE_REPLACEMENT(SBIcon, setIsShowingCloseBox:, setIsShowingCloseBox$);
	
	GET_CLASS(SBApplication);
	HOOK_MESSAGE(SBApplication, deactivated);

	initTranslation();
	CDUpdatePrefs();

	[pool release];
}
