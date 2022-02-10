//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <WebKit/WebKit.h>
#import "git2.h"
#import "RadBlockKit.h"
#import "RBFilterGroup.h"
#import "RBContentBlocker.h"
#import <Foundation/Foundation.h>

#if BEAM_WEBKIT_ENHANCEMENT_ENABLED
@interface WKPreferences ()
-(void)_setFullScreenEnabled:(BOOL)fullScreenEnabled;
-(void)_setAllowsPictureInPictureMediaPlayback:(BOOL)allowed;
@end

@interface WKWebView ()
- (void)_setAddsVisitedLinks:(BOOL)addsVisitedLinks;

-(CGFloat)_topContentInset;
-(void)_setTopContentInset:(CGFloat)inset;

-(BOOL)_automaticallyAdjustsContentInsets;
-(void)_setAutomaticallyAdjustsContentInsets:(BOOL)enabled;
@end

@protocol WKUIDelegatePrivate <WKUIDelegate>
- (void)_webView:(WKWebView *)webView getWindowFrameWithCompletionHandler:(void (^)(CGRect))completionHandler;
@end
#endif

// https://stackoverflow.com/questions/34956002/how-to-properly-handle-nsfilehandle-exceptions-in-swift-2-0/35003095#35003095
NS_INLINE NSException * _Nullable tryBlock(void(^_Nonnull tryBlock)(void)) {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        return exception;
    }
    return nil;
}
