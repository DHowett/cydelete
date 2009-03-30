#import "CyDeleteSettings.h"

@implementation CyDeleteSettingsController

- (id)specifiers {
	return [self localizedSpecifiersForSpecifiers:[self loadSpecifiersFromPlistName:@"CyDelete" target:self]];
}

@end
