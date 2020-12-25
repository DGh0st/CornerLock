#import "CornerLockController.h"

static id applicationFinishLaunchingObserver = nil;

%ctor {
	void (^SetupCornerLock)(NSNotification *notification) = ^(NSNotification *notification) {
		// Setup corner lock shared instance which initializes the gesture
		[CornerLockController sharedInstance];
	};

	applicationFinishLaunchingObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:SetupCornerLock];
}

%dtor {
	[[NSNotificationCenter defaultCenter] removeObserver:applicationFinishLaunchingObserver];
}