#import "CornerLockWindow.h"

FOUNDATION_EXTERN CGFloat const UISpringBoardLockScreenWindowLevel; // iOS 9 - 13 (UIKit)

#define CORNER_LOCK_WINDOW_LEVEL (UISpringBoardLockScreenWindowLevel + 26.0) // 1 above control center window

%subclass CornerLockWindow : SBSecureMainScreenActiveInterfaceOrientationWindow
-(instancetype)initWithDebugName:(NSString *)name {
	self = %orig(name);
	if (self != nil) {
		self.windowLevel = CORNER_LOCK_WINDOW_LEVEL;
		self.hidden = NO;
	}
	return self;
}

-(BOOL)_ignoresHitTest {
	return YES;
}
%end
