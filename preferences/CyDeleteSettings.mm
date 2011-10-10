#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListController.h>

static CFNotificationCenterRef darwinNotifyCenter = CFNotificationCenterGetDarwinNotifyCenter();

@interface UIDevice (wc)
- (BOOL)isWildcat;
@end

@interface CyDeleteSettingsController : PSListController
- (id)specifiers;
- (void)donationButton:(id)arg;
- (void)setPreferenceValue:(id)value specifier:(id)specifier;
@end

@implementation CyDeleteSettingsController

- (id)navigationTitle {
	return [[self bundle] localizedStringForKey:[super navigationTitle] value:[super navigationTitle] table:nil];
}

- (id)localizedSpecifiersWithSpecifiers:(NSArray *)specifiers {
	for(PSSpecifier *curSpec in specifiers) {
		NSString *name = [curSpec name];
		if(name) {
			[curSpec setName:[[self bundle] localizedStringForKey:name value:name table:nil]];
		}
		NSString *footerText = [curSpec propertyForKey:@"footerText"];
		if(footerText)
			[curSpec setProperty:[[self bundle] localizedStringForKey:footerText value:footerText table:nil] forKey:@"footerText"];
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
	if(!_specifiers) {
		_specifiers = [[self localizedSpecifiersWithSpecifiers:[self loadSpecifiersFromPlistName:@"CyDelete" target:self]] retain];
	}
	return _specifiers;
}

- (void)donationButton:(id)arg {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4275311"]];
}

- (void)setPreferenceValue:(id)value specifier:(id)specifier {
	[super setPreferenceValue:value specifier:specifier];
	// Post a notification.
	NSString *notification = [specifier propertyForKey:@"postNotification"];
	if(notification)
		CFNotificationCenterPostNotification(darwinNotifyCenter, (CFStringRef)notification, NULL, NULL, true);
}

@end
