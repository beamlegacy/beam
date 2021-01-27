//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <WebKit/WebKit.h>
#import "git2.h"

@interface WKPreferences ()
-(void)_setFullScreenEnabled:(BOOL)fullScreenEnabled;
@end
