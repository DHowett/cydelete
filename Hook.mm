#import <UIKit/UIProgressHUD.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplication.h>
#import <DHHookCommon.h>
#import <mach/mach_host.h>
#import <dirent.h>

__attribute__((unused)) static NSMutableString *outputForShellCommand(NSString *cmd);
static void removeBundleFromMIList(NSString *bundle);
static void CDUpdatePrefs();

DHLateClass(SBIcon);
DHLateClass(SBApplicationIcon);
DHLateClass(SBIconModel);
DHLateClass(SBIconController);
DHLateClass(SBApplication);
DHLateClass(SBApplicationController);

static NSBundle *cyDelBundle = nil;
static NSDictionary *cyDelPrefs = nil;
static CFMutableDictionaryRef iconPackagesDict;
static NSOperationQueue *uninstallQueue;
static UIImage *safariCloseBox = nil;

#define SBLocalizedString(key) [[NSBundle mainBundle] localizedStringForKey:key value:@"None" table:@"SpringBoard"]
#define CDLocalizedString(key) [cyDelBundle localizedStringForKey:key value:key table:nil]

@interface CDUninstallOperation : NSOperation {
	BOOL _executing;
	BOOL _finished;
}
@end

@interface CDUninstallDpkgOperation : CDUninstallOperation {
	NSString *_package;
}
@property (nonatomic, assign) NSString *package;
- (id)initWithPackage:(NSString *)package;
@end

@interface CDUninstallDeleteOperation : CDUninstallOperation {
	NSString *_path;
}
@property (nonatomic, assign) NSString *path;
- (id)initWithPath:(NSString *)path;
@end

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
__attribute__((unused)) static int getFreeMemory() {
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

@implementation CDUninstallOperation
- (id)init {
	if((self = [super init]) != nil) {
		_executing = NO;
		_finished = NO;
	}
	return self;
}

- (BOOL)isConcurrent { return YES; }
- (BOOL)isExecuting { return _executing; }
- (BOOL)isFinished { return _finished; }

- (void)start {
	if([self isCancelled]) {
		[self willChangeValueForKey:@"isFinished"];
		_finished = YES;
		[self didChangeValueForKey:@"isFinished"];
		return;
	}
	[self willChangeValueForKey:@"isExecuting"];
	[NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
	_executing = YES;
	[self didChangeValueForKey:@"isExecuting"];
}

- (void)completeOperation {
	[self willChangeValueForKey:@"isFinished"];
	[self willChangeValueForKey:@"isExecuting"];
	_executing = NO;
	_finished = YES;
	[self didChangeValueForKey:@"isExecuting"];
	[self didChangeValueForKey:@"isFinished"];
}

- (void)main {
}
@end

@implementation CDUninstallDeleteOperation
@synthesize path = _path;
- (id)initWithPath:(NSString *)path {
	if((self = [super init]) != nil) {
		self.path = path;
	}
	return self;
}

- (void)main {
	DHScopedAutoreleasePool();
	NSString *command = [NSString stringWithFormat:@"/usr/libexec/cydelete/setuid /usr/libexec/cydelete/uninstall_nondpkg.sh %@", _path];
	system([command UTF8String]);
	[self completeOperation];
}

- (void)dealloc { [_path release]; [super dealloc]; }
@end

@implementation CDUninstallDpkgOperation
@synthesize package = _package;
- (id)initWithPackage:(NSString *)package {
	if((self = [super init]) != nil) {
		self.package = package;
	}
	return self;
}

- (void)displayError {
	NSString *body = [NSString stringWithFormat:CDLocalizedString(@"PACKAGE_UNINSTALL_ERROR_BODY"), _package];
	UIAlertView *delView = [[UIAlertView alloc] initWithTitle:CDLocalizedString(@"PACKAGE_UNINSTALL_ERROR_TITLE") message:body delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
	[delView show];
	[delView release];
}

- (void)main {
	DHScopedAutoreleasePool();
	NSString *command = [NSString stringWithFormat:@"/usr/libexec/cydelete/setuid /usr/libexec/cydelete/uninstall_dpkg.sh %@", _package];
	NSString *output = outputForShellCommand(command);
	if(!output) [self performSelectorOnMainThread:@selector(displayError) withObject:nil waitUntilDone:NO];
	[self completeOperation];
}

- (void)dealloc { [_package release]; [super dealloc]; }
@end

static void removeBundleFromMIList(NSString *bundle) {
	NSString *path([NSString stringWithFormat:@"%@/Library/Caches/com.apple.mobile.installation.plist", NSHomeDirectory()]);
	NSMutableDictionary *cache = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
	[cache autorelease];
	[[cache objectForKey:@"System"] removeObjectForKey:bundle];
	[cache writeToFile:path atomically:YES];
}

__attribute__((unused)) static NSMutableString *outputForShellCommand(NSString *cmd) {
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

static void CDUpdatePrefs() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/net.howett.cydelete.plist"];
	if(!prefs) return;
	if(!cyDelPrefs || ![cyDelPrefs isEqualToDictionary:prefs]) {
		[cyDelPrefs release];
		cyDelPrefs = [prefs retain];
	}
}

HOOK(SBApplicationController, uninstallApplication$, void, id application) {
	if(![application isSystemApplication]) {
		CALL_ORIG(SBApplicationController, uninstallApplication$, application);
		return;
	}

	NSString *package = (NSString *)CFDictionaryGetValue(iconPackagesDict, [[$SBIconModel sharedInstance] iconForDisplayIdentifier:[application displayIdentifier]]);
	NSString *path = [application path];
	CDUninstallOperation *op;
	if(!package)
		op = [[CDUninstallDeleteOperation alloc] initWithPath:path];
	else
		op = [[CDUninstallDpkgOperation alloc] initWithPackage:package];
	[uninstallQueue addOperation:op];
	[op release];
	removeBundleFromMIList([application bundleIdentifier]);
	if([[application bundleIdentifier] isEqualToString:@"jp.ashikase.springjumps"]) {
		NSArray *allBundles = [self allApplications];
		int i = 0;
		int count = [allBundles count];
		for(i = 0; i < count; i++) {
			SBApplication *curApp = [allBundles objectAtIndex:i];
			NSString *bundle = [curApp bundleIdentifier];
			if(![bundle hasPrefix:@"jp.ashikase.springjumps."])
				continue;
			SBIcon *curIcon = [[$SBIconModel sharedInstance] iconForDisplayIdentifier:[curApp displayIdentifier]];
			if(!curIcon) continue;
			removeBundleFromMIList(bundle);
			[self removeApplicationsFromModelWithBundleIdentifier:bundle];
			[[$SBIconController sharedInstance] removeIcon:curIcon animate:YES];
		}
	}
}

IMPLEMENTATION(SBApplicationIcon, allowsCloseBox, BOOL) {
	NSString *bundle = [self displayIdentifier];
	if(([bundle hasPrefix:@"com.apple."] && ![bundle hasPrefix:@"com.apple.samplecode."])
	|| ([bundle isEqualToString:@"com.saurik.Cydia"] && CDGetBoolPref(@"CDProtectCydia", true))
	|| [bundle hasPrefix:@"com.bigboss.categories."]
	|| ([bundle isEqualToString:@"com.ripdev.icy"] && CDGetBoolPref(@"CDProtectIcy", false))
	|| [bundle hasPrefix:@"jp.ashikase.springjumps."]
	|| [bundle hasPrefix:@"com.steventroughtonsmith.stack"])
		return NO;
	if(getFreeMemory() < 20) return NO;
	else return YES;
}

IMPLEMENTATION(SBApplicationIcon, closeBoxClicked$, void, id event) {
	if(!CFDictionaryContainsKey(iconPackagesDict, self)) {
		SBApplication *app = [self application];
		NSString *bundle = [app bundleIdentifier];
		NSString *title = [self displayName];
		NSString *plistPath = [NSString stringWithFormat:@"%@/Info.plist", [app path]];
		NSString *_pkgName;
		if([bundle isEqualToString:@"com.ripdev.Installer"]
		   || [bundle isEqualToString:@"com.ripdev.install"]) {
			// If we're dealing with Installer, short circuit over the package search. 
			_pkgName = nil;
		} else {
			char *pkgNameC = owner([bundle UTF8String], [title UTF8String], [plistPath UTF8String]);
			_pkgName = pkgNameC ? [[NSString stringWithUTF8String:pkgNameC] retain] : nil;
		}
		CFDictionaryAddValue(iconPackagesDict, self, _pkgName);
	}

	struct objc_super superclass = {self, $SBIcon};
	objc_msgSendSuper(&superclass, sel);
}

IMPLEMENTATION(SBApplicationIcon, setIsShowingCloseBox$, void, BOOL isShowingCloseBox) {
	struct objc_super superclass = {self, $SBIcon};
	objc_msgSendSuper(&superclass, sel, isShowingCloseBox);
	if(!isShowingCloseBox) return;
	if(![[self application] isSystemApplication]) return;

	UIPushButton *cb;
	cb = MSHookIvar<UIPushButton *>(self, "_closeBox");

	if(!safariCloseBox) safariCloseBox = [[UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/closebox.png"] retain];

	[cb setImage:safariCloseBox forState:0];
	[cb setImage:safariCloseBox forState:1];

}

IMPLEMENTATION(SBApplicationIcon, completeUninstall, void) {
	[[$SBIconModel sharedInstance] uninstallApplicationIcon:self];
}

IMPLEMENTATION(SBApplicationIcon, uninstallAlertTitle, NSString *) {
	return [NSString stringWithFormat:SBLocalizedString(@"UNINSTALL_ICON_TITLE"),
					[self displayName]];
}

IMPLEMENTATION(SBApplicationIcon, uninstallAlertBody, NSString *) {
	NSString *package = (NSString *)CFDictionaryGetValue(iconPackagesDict, self);
	NSString *body;
	if(package)
		body = [NSString stringWithFormat:CDLocalizedString(@"PACKAGE_DELETE_BODY"),
						[self displayName], package];
	else
		body = [NSString stringWithFormat:SBLocalizedString(@"DELETE_WIDGET_BODY"),
						[self displayName]];
	return body;
}

IMPLEMENTATION(SBApplicationIcon, uninstallAlertConfirmTitle, NSString *) {
	return SBLocalizedString(@"UNINSTALL_ICON_CONFIRM");
}

IMPLEMENTATION(SBApplicationIcon, uninstallAlertCancelTitle, NSString *) {
	return SBLocalizedString(@"UNINSTALL_ICON_CANCEL");
}

static void reloadPrefsNotification(CFNotificationCenterRef center,
					void *observer,
					CFStringRef name,
					const void *object,
					CFDictionaryRef userInfo) {
	CDUpdatePrefs();
}

static _Constructor void CyDeleteInitialize() {
	DHScopedAutoreleasePool();

	HOOK_MESSAGE_REPLACEMENT(SBApplicationController, uninstallApplication:, uninstallApplication$);

	ADD_MESSAGE(SBApplicationIcon, allowsCloseBox);
	ADD_MESSAGE_REPLACEMENT(SBApplicationIcon, closeBoxClicked:, closeBoxClicked$);
	ADD_MESSAGE_REPLACEMENT(SBApplicationIcon, setIsShowingCloseBox:, setIsShowingCloseBox$);
	ADD_MESSAGE(SBApplicationIcon, completeUninstall);
	ADD_MESSAGE(SBApplicationIcon, uninstallAlertTitle);
	ADD_MESSAGE(SBApplicationIcon, uninstallAlertBody);
	ADD_MESSAGE(SBApplicationIcon, uninstallAlertConfirmTitle);
	ADD_MESSAGE(SBApplicationIcon, uninstallAlertCancelTitle);

	initTranslation();
	CDUpdatePrefs();
	iconPackagesDict = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
	uninstallQueue = [[NSOperationQueue alloc] init];
	[uninstallQueue setMaxConcurrentOperationCount:1];

	CFNotificationCenterRef r = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(r, NULL, &reloadPrefsNotification,
					CFSTR("net.howett.cydelete/ReloadPrefs"), NULL, 0);
}
