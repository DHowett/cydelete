#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListController.h>

static CFNotificationCenterRef darwinNotifyCenter = CFNotificationCenterGetDarwinNotifyCenter();

@interface CyDeleteSettingsController : PSListController {
	bool _cydiaPresent;
	bool _icyPresent;
}
- (id)specifiers;
- (void)donationButton:(id)arg;
- (void)setPreferenceValue:(id)value specifier:(id)specifier;
@end

@implementation CyDeleteSettingsController

/*
- (void)viewDidBecomeVisible {
	NSFileManager *manager = [NSFileManager defaultManager];
	_cydiaPresent = [manager fileExistsAtPath:@"/Applications/Cydia.app/Info.plist"];
	_icyPresent = [manager fileExistsAtPath:@"/Applications/Icy.app/Info.plist"];
//	if(!_cydiaPresent) [self removeSpecifier:[_specifiers objectAtIndex:5] animated:YES];
//	if(!_icyPresent) [self removeSpecifier:[_specifiers objectAtIndex:6] animated:YES];
}
*/

- (id)navigationTitle {
	return [[self bundle] localizedStringForKey:[super navigationTitle] value:[super navigationTitle] table:nil];
}

- (id)localizedSpecifiersWithSpecifiers:(NSArray *)specifiers {
	for(PSSpecifier *curSpec in specifiers) {
		NSString *name = [curSpec name];
		if(name) {
			[curSpec setName:[[self bundle] localizedStringForKey:name value:name table:nil]];
		}
		id titleDict = [curSpec titleDictionary];
		if(titleDict) {
			NSMutableDictionary *newTitles = [[NSMutableDictionary alloc] init];
			for(NSString *key in titleDict) {
				NSString *value = [titleDict objectForKey:key];
				[newTitles setObject:[[self bundle] localizedStringForKey:value value:value table:nil] forKey: key];
			}
			[curSpec setTitleDictionary: [newTitles autorelease]];
		}
	}
	return specifiers;
}

- (id)specifiers {
	return [self localizedSpecifiersWithSpecifiers:[self loadSpecifiersFromPlistName:@"CyDelete" target:self]];
}

- (void)donationButton:(id)arg {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4275311"]];
}

- (void)setPreferenceValue:(id)value specifier:(id)specifier {
	[super setPreferenceValue:value specifier:specifier];
	// Post a notification.
	NSString *notification = [specifier propertyForKey:@"postNotification"];
	CFNotificationCenterPostNotification(darwinNotifyCenter, (CFStringRef)notification, NULL, NULL, true);
}

/*
- (id)setCydiaProtection:(CFBooleanRef)value specifier:(id)specifier {
	if(value == kCFBooleanFalse) {
		if(!_icyPresent) value = kCFBooleanTrue;
	}
	[self setPreferenceValue:(id)value specifier:specifier];
	[[NSUserDefaults standardUserDefaults] synchronize];
}
*/

@end
