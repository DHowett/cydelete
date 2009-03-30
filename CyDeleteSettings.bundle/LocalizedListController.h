#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>

@interface LocalizedListController : PSListController {
}
- (NSArray *)localizedSpecifiersForSpecifiers:(NSArray *)s;
- (id)navigationTitle;
@end

