#import "Hook.h"

@implementation QuikDel

+ (id)showHUDonSpringBoard:(id)message {
	Class $SBIconController = objc_getClass("SBIconController");
	id sharedSBIconController = [$SBIconController sharedInstance];
	id aHUD = [[UIProgressHUD alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 240.0f)];
	[aHUD setText:[message copy]];
	[aHUD show:YES];
	[[sharedSBIconController contentView] addSubview:aHUD];
	return aHUD;
}

+ killHUD:(id)hud {
	Class $SBIconController = objc_getClass("SBIconController");
	id sharedSBIconController = [$SBIconController sharedInstance];
	[hud show:NO];
	//[[sharedSBIconController contentView] removeSubview:hud];
	[hud release];
}

- (id)initWithIcon:(SBIcon *)icon package:(NSString *)pkgName {
	self = [super init];
	_SBIcon = icon;
	_pkgName = [pkgName copy];
	return self;
}

- askDelete {
	NSString *title = [[NSString alloc] initWithFormat:@"Delete \"%@\"", [_SBIcon displayName]];
	NSString *body = [[NSString alloc] initWithFormat:@"Deleting \"%@\" will uninstall \"%@\"", [_SBIcon displayName], _pkgName];
	UIAlertView *delView = [[UIAlertView alloc] initWithTitle:title message:body delegate:self cancelButtonTitle:@"Delete" otherButtonTitles:@"Cancel", nil];
	[delView show];
	[title release];
	[body release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex == 1) {
		[self release];
		return;
	}

	NSString *command = [[NSString alloc] initWithFormat:@"/usr/libexec/quikdel/uninstall %@", _pkgName];

//	id hud = [QuikDel showHUDonSpringBoard:@"Oh God."];
	NSString *body = __QuikDel_outputForShellCommand(command);
//	[QuikDel killHUD:hud];
	if(!body) {
		body = [[NSString alloc] initWithFormat:@"%@ failed uninstall.", _pkgName];
		UIAlertView *delView = [[UIAlertView alloc] initWithTitle:@"Error Uninstalling" message:body delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
		[delView show];
		[delView release];
		[body release];
	} else {
		[body release];
		Class $SBIconController = objc_getClass("SBIconController");
		id sharedSBIconController = [$SBIconController sharedInstance];
		[sharedSBIconController uninstallIcon:_SBIcon animate:YES];
	}

	[self release];
}

- dealloc {
	[_pkgName release];
	[super dealloc];
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

	if([path hasPrefix:@"/private/var/mobile"]) {
		[_SBIcon __OriginalMethodPrefix_closeBoxClicked:fp8];
		return;
	}

	NSString *dpkgCmd = [[NSString alloc] initWithFormat:@"/usr/libexec/quikdel/owner.sh %@/Info.plist", path];
	id hud = [QuikDel showHUDonSpringBoard:@"Looking Up Package..."];
	NSMutableString *dpkgOutput =  __QuikDel_outputForShellCommand(dpkgCmd);
	[QuikDel killHUD:hud];
	[dpkgCmd release];

	if(!dpkgOutput) {
		UIAlertView *alertUnknown = [[UIAlertView alloc] initWithTitle:@"How Bizarre"
								message:@"NOT installed via Cydia.\nYou shouldn't see this."
								delegate:nil
								cancelButtonTitle:@"OK"
								otherButtonTitles:nil];
		[alertUnknown show];
		[alertUnknown release];
		return;
	} else {
		QuikDel *qd = [[QuikDel alloc] initWithIcon:_SBIcon package:dpkgOutput];
		[qd askDelete];
		[dpkgOutput release];
//		[_SBIcon completeUninstall];
//		[qd release];
	}
}

extern "C" void QuikDelInitialize() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Class _$SBIcon = objc_getClass("SBIcon");
	MSHookMessage(_$SBIcon, @selector(allowsCloseBox), (IMP) &__$QuikDel_allowsCloseBox, "__OriginalMethodPrefix_");
	MSHookMessage(_$SBIcon, @selector(closeBoxClicked:), (IMP) &__$QuikDel_closeBoxClicked, "__OriginalMethodPrefix_");

	[pool release];
}
