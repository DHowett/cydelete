#import "LocalizedListController.h"

@implementation LocalizedListController

- (NSArray *)localizedSpecifiersForSpecifiers:(NSArray *)s {
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
};

- (id)navigationTitle {
	return [[self bundle] localizedStringForKey:_title value:_title table:nil];
}

@end

