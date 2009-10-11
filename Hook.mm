#import <UIKit/UIProgressHUD.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplication.h>
#import <DHHookCommon.h>
#import <mach/mach_host.h>
#import <dirent.h>

NSMutableString *__CyDelete_outputForShellCommand(NSString *cmd);
static void CDUpdatePrefs();

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
- (void)closeBoxClicked_finish;
- (void)askDelete;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)_uninstall;
- (void)uninstall_thread_dpkg:(NSThread *)callingThread;
- (void)uninstall_thread_nondpkg:(NSThread *)callingThread;
- (void)uninstalled:(NSString *)body;
- (void)dealloc;
@end

#define SpringBoard_ "/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"

DHLateClass(SBIcon);
DHLateClass(SBIconModel);
DHLateClass(SBIconController);
DHLateClass(SBApplication);
DHLateClass(SBApplicationController);

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

#define fexists(n) access(n, F_OK)
static char *owner(const char *_bundle, const char *_title, const char *_path) {
	char bundle[1024], title[1024];
	static char pkgname[256];
	int pathlen = strlen(_path);

	snprintf(bundle, 1024, "/var/lib/dpkg/info/%s.list", _bundle);
	snprintf(title, 1024, "/var/lib/dpkg/info/%s.list", _title);
	if(fexists(bundle) == 0) {
		strcpy(pkgname, _bundle);
		return pkgname;
	} else if(fexists(title) == 0) {
		strcpy(pkgname, _title);
		return pkgname;
	}

	DIR *d = opendir("/var/lib/dpkg/info");
	struct dirent *ent;
	while((ent = readdir(d)) != NULL) {
		int namelen = strlen(ent->d_name);
		if(strcmp(ent->d_name + namelen - 5, ".list") != 0) continue;
		char curpath[1024];
		snprintf(curpath, 1024, "/var/lib/dpkg/info/%s", ent->d_name);
		FILE *fp = fopen(curpath, "r");
		char curfn[1024];
		while(fgets(curfn, 1024, fp) != NULL) {
			if(strncmp(_path, curfn, pathlen) == 0) {
				strncpy(pkgname, ent->d_name, namelen - 5);
				pkgname[namelen - 5] = '\0';
				fclose(fp);
				closedir(d);
				return pkgname;
			}
		}
		fclose(fp);
	}
	closedir(d);
	return NULL;
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
	//[self startHUD:CDLocalizedString(@"PACKAGE_SEARCHING")];
	//[NSThread detachNewThreadSelector:@selector(closeBoxClicked_thread:) toTarget:self withObject:[NSThread currentThread]];
	NSString *title = [app displayName];
	char *pkgNameC = owner([bundle UTF8String], [title UTF8String], [[NSString stringWithFormat:@"%@/Info.plist", _path] UTF8String]);
	_pkgName = pkgNameC ? [[NSString stringWithUTF8String:pkgNameC] retain] : nil;
	[self closeBoxClicked_finish];
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
		id sharedSBIconController = [DHClass(SBIconController) sharedInstance];
		[sharedSBIconController uninstallIcon:_SBIcon animate:YES];

		[self removeFromMIList:bundle];

		if([bundle isEqualToString:@"jp.ashikase.springjumps"]) {
			id sharedSBIconModel = [DHClass(SBIconModel) sharedInstance];

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

- (void)dealloc {
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
	sharedSBApplicationController = [DHClass(SBApplicationController) sharedInstance];
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
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/net.howett.cydelete.plist"];
	if(!prefs) return;
	if(!cyDelPrefs || ![cyDelPrefs isEqualToDictionary:prefs]) {
		[cyDelPrefs release];
		cyDelPrefs = [prefs retain];
	}
}

HOOK(SBIcon, setIsShowingCloseBox$, void, BOOL fp) {
	CALL_ORIG(SBIcon, setIsShowingCloseBox$, fp);
	if(fp == NO) return;

	UIPushButton *cb;
	cb = MSHookIvar<UIPushButton *>(self, "_closeBox");

	sharedSBApplicationController = [DHClass(SBApplicationController) sharedInstance];
	id app = [sharedSBApplicationController applicationWithDisplayIdentifier:[self displayIdentifier]];

        if([app isSystemApplication] && ![[app path] isEqualToString:@"/Applications/Web.app"]) {
		[cb setImage:safariCloseBox forState:0];
		[cb setImage:safariCloseBox forState:1];
	}
}

static _Constructor void CyDeleteInitialize() {
	DHScopedAutoreleasePool();

	HOOK_MESSAGE(SBIcon, allowsCloseBox);
	HOOK_MESSAGE_AUTO(SBIcon, closeBoxClicked$);
	HOOK_MESSAGE_AUTO(SBIcon, setIsShowingCloseBox$);
	HOOK_MESSAGE(SBApplication, deactivated);

	initTranslation();
	CDUpdatePrefs();
}
