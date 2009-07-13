#import "CyDeleteSettings.h"

@implementation CyDeleteSettingsController

- (id)navigationTitle {
	return [[self bundle] localizedStringForKey:_title value:_title table:nil];
}

- (void)viewDidBecomeVisible {
	NSFileManager *manager = [NSFileManager defaultManager];
	_cydiaPresent = [manager fileExistsAtPath:@"/Applications/Cydia.app/Info.plist"];
	_icyPresent = [manager fileExistsAtPath:@"/Applications/Icy.app/Info.plist"];
//	if(!_cydiaPresent) [self removeSpecifier:[_specifiers objectAtIndex:5] animated:YES];
//	if(!_icyPresent) [self removeSpecifier:[_specifiers objectAtIndex:6] animated:YES];
}

- (id)specifiers {
	NSArray *specifiers = [self loadSpecifiersFromPlistName:@"CyDelete" target:self];
	int i;
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

- (id)donationButton:(id)arg {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4275311"]];
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
