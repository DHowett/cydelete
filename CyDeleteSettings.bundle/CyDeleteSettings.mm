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
	NSArray *s = [self loadSpecifiersFromPlistName:@"CyDelete" target:self];
	int i;
	for(i=0; i<[s count]; i++) {
		id curObj = [s objectAtIndex:i];
		id name = [curObj name];
		if(name) {
			[curObj setName:[[self bundle] localizedStringForKey:name value:name table:nil]];
		}
		id titleDict = [curObj titleDictionary];
		if(titleDict) {
			NSMutableDictionary *newTitles = [[NSMutableDictionary alloc] init];
			for(NSString *key in titleDict) {
				[newTitles setObject: [[self bundle] localizedStringForKey:[titleDict objectForKey:key] value:[titleDict objectForKey:key] table:nil] forKey: key];
			}
			[curObj setTitleDictionary: [newTitles autorelease]];
		}
	}
	return s;
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
