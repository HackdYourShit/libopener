#import "HBLOHandlerController.h"
#import "HBLOOpenOperation.h"
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import <version.h>
#include <dlfcn.h>

static BOOL isOverriding = NO;

// TODO: SBSOpenSensitiveURLAndUnlock() late loads MobileCoreServices. not sure if it's worth
// supporting such situations… use case: sbopenurl

@interface LSApplicationWorkspace ()

- (NSURL *)_opener_URLOverrideForURL:(NSURL *)url;

@end

%hook LSApplicationWorkspace

%new - (NSURL *)_opener_URLOverrideForURL:(NSURL *)url {
	NSArray <HBLOOpenOperation *> *result = [[HBLOHandlerController sharedInstance] getReplacementsForOpenOperation:[HBLOOpenOperation openOperationWithURL:url sender:[NSBundle mainBundle].bundleIdentifier]];

	// none? fair enough, just return the original url
	if (!result) {
		return nil;
	}

	// well, looks like we're getting newURL[0]! how, uh, boring
	return result[0].URL;
}

- (NSURL *)URLOverrideForURL:(NSURL *)url {
	// if we're currently trying to find replacements, we don't want to replace the replacements
	if (isOverriding) {
		return %orig;
	}

	// consult with HBLOHandlerController to see if there's any possible URL replacements
	isOverriding = YES;
	NSURL *newURL = [self _opener_URLOverrideForURL:url];
	isOverriding = NO;

	// if we got a url, return that. if not, well, we tried… call the original function
	return newURL ?: %orig;
}

- (BOOL)openURL:(NSURL *)url withOptions:(NSDictionary *)options {
	// need to make sure all openURL: requests go through URLOverrideForURL:
	return %orig([self _opener_URLOverrideForURL:url] ?: url, options);
}

%end

#pragma mark - Constructor

%ctor {
	// only use these hooks if we aren’t using app links
	if (!IS_IOS_OR_NEWER(iOS_9_0)) {
		%init;
	}
}
