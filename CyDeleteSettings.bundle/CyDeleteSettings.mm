#import "CyDeleteSettings.h"

@implementation CyDeleteSettingsController

- (id)specifiers {
	return [self localizedSpecifiersForSpecifiers:[self loadSpecifiersFromPlistName:@"CyDelete" target:self]];
}

- (id)donationButton:(id)arg {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4275311"]];
}

@end
