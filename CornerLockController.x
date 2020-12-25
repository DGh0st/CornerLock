#import "CornerLockController.h"
#import "CornerLockWindow.h"
#import "SBScreenEdgePanGestureRecognizer.h"

@interface FBSystemGestureManager : NSObject // iOS 9 - 12
+(id)sharedInstance; // iOS 9 - 12
// -(void)addGestureRecognizer:(id)gestureRecognizer toDisplay:(id)display; // iOS 9 - 12
// -(void)removeGestureRecognizer:(id)gestureRecognizer fromDisplay:(id)display; // iOS 9 - 12
-(void)addGestureRecognizer:(id)gestureRecognizer toDisplayWithIdentity:(id)displayIdentity; // iOS 11 - 12
-(void)removeGestureRecognizer:(id)gestureRecognizer fromDisplayWithIdentity:(id)displayIdentity; // iOS 11 - 12
@end

@interface _UISystemGestureManager : NSObject // iOS 13
+(instancetype)sharedInstance; // iOS 13
-(void)addGestureRecognizer:(id)gestureRecognizer toDisplayWithIdentity:(id)displayIdentity; // iOS 13
@end

@interface SBSystemGestureManager : NSObject { // iOS 9 - 13
	// FBSDisplayIdentity* _displayIdentity; // iOS 11 - 13
}
+(instancetype)mainDisplayManager; // iOS 9 - 13
-(id)display; // iOS 9 - 10
@end

@interface UIStatusBar : UIView // iOS 3 - 13
-(CGRect)frameForPartWithIdentifier:(id)identifier; // iOS 11.0.1 - 13
-(CGRect)frameForRegionWithIdentifier:(id)identifier; // iOS 11 - 11.0.1
@end

@interface SpringBoard : UIApplication // iOS 4 - 13
+(instancetype)sharedApplication; // iOS 4 - 13
-(UIInterfaceOrientation)activeInterfaceOrientation; // iOS 4 - 13
-(UIStatusBar *)statusBar; // iOS 4 - 13
@end

@interface SBLockScreenManager : NSObject // iOS 7 - 13
+(instancetype)sharedInstance; // ioS 7 - 13
-(BOOL)isUILocked; // iOS 7 - 13
-(void)lockUIFromSource:(NSInteger)source withOptions:(id)options; // iOS 7 - 13
-(id)lockScreenViewController; // iOS 7 - 12
@end

@interface SBReachabilityManager : NSObject // iOS 8 - 13
+(instancetype)sharedInstance; // iOS 8 - 13
-(void)deactivateReachability; // iOS 12 - 13
-(void)deactivateReachabilityModeForObserver:(id)observer; // iOS 8 - 11
-(void)ignoreWindowForReachability:(id)window; // iOS 12 - 13
@end

@interface SBScreenWakeAnimationController : NSObject // iOS 11 - 13
+(instancetype)sharedInstance; // iOS 11 - 13
-(void)sleepForSource:(NSInteger)source target:(id)target completion:(id)completion; // iOS 11 - 13
-(BOOL)isWakeAnimationInProgress; // iOS 11 - 13
@end

FOUNDATION_EXTERN NSString *_UIStatusBarPartIdentifierFittingLeading; // iOS 11 - 13 (UIKit)
FOUNDATION_EXTERN CGFloat SBLayoutDefaultSideLayoutElementWidth(); // iOS 9 - 13 (SpringBoardUIServices)
FOUNDATION_EXTERN CGPoint _UIWindowConvertPointFromOrientationToOrientation(CGPoint point, UIInterfaceOrientation fromOrientation, UIInterfaceOrientation toOrientation); // iOS 9 - 13 (UIKit)
FOUNDATION_EXTERN void BKSHIDServicesSetBacklightFactorWithFadeDuration(float factor, float duration, bool disableActions); // iOS 9 - 13 (BackBoardServices)

#define CORNER_LOCK_PORTRAIT_MULTIPLIER 0.25
#define CORNER_LOCK_LANDSCAPE_MULTIPLIER 0.172
#define CORNER_LOCK_ANIMATION_DURATION 0.33

static inline CGFloat PercentageForDistance(CGFloat distance, CGFloat maxDistance) {
	if (distance >= 20.0) // skip status bar height
		return (distance - 20.0) / maxDistance;
	return 0.0;
}

@implementation CornerLockController
+(instancetype)sharedInstance {
	static CornerLockController *_sharedController = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedController = [[CornerLockController alloc] init];
	});
	return _sharedController;
}

-(instancetype)init {
	self = [super init];
	if (self != nil) {
		self.window = [[%c(CornerLockWindow) alloc] initWithDebugName:@"CornerLockWindow"];
		
		SBReachabilityManager *reachabilityManager = [%c(SBReachabilityManager) sharedInstance];
		if ([reachabilityManager respondsToSelector:@selector(ignoreWindowForReachability:)])
			[reachabilityManager ignoreWindowForReachability:self.window];

		self.window.rootViewController.view.backgroundColor = [UIColor blackColor];
		self.window.rootViewController.view.alpha = 0.0;

		// create gesture
		SBScreenEdgePanGestureRecognizer *edgePullGestureRecognizer = [%c(SBScreenEdgePanGestureRecognizer) alloc];
		if ([edgePullGestureRecognizer respondsToSelector:@selector(initWithTarget:action:type:)])
			edgePullGestureRecognizer = [edgePullGestureRecognizer initWithTarget:self action:@selector(_handleCornerPull:) type:1];
		else if ([edgePullGestureRecognizer respondsToSelector:@selector(initWithTarget:action:type:options:)])
			edgePullGestureRecognizer = [edgePullGestureRecognizer initWithTarget:self action:@selector(_handleCornerPull:) type:1 options:0]; // TODO: Find options value
		[edgePullGestureRecognizer setEdges:UIRectEdgeTop];
		if ([edgePullGestureRecognizer respondsToSelector:@selector(sb_setStylusTouchesAllowed:)])
			[edgePullGestureRecognizer sb_setStylusTouchesAllowed:NO];
		edgePullGestureRecognizer.delegate = self;
		self.cornerLockPanGestureRecognizer = edgePullGestureRecognizer;
		
		// add gesture to system
		id displayIdentity = [[%c(SBSystemGestureManager) mainDisplayManager] valueForKey:@"_displayIdentity"];
		Class SystemGestureManager = %c(FBSystemGestureManager) ?: %c(_UISystemGestureManager);
		[[SystemGestureManager sharedInstance] addGestureRecognizer:edgePullGestureRecognizer toDisplayWithIdentity:displayIdentity];
	}
	return self;
}

-(BOOL)gestureRecognizer:(SBScreenEdgePanGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	CGPoint location = [touch locationInView:nil];
	UIInterfaceOrientation currentOrientation = [[%c(SpringBoard) sharedApplication] activeInterfaceOrientation];

	CGFloat distanceX;
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	if (currentOrientation == UIInterfaceOrientationPortrait)
		distanceX = location.x;
	else if (currentOrientation == UIInterfaceOrientationPortraitUpsideDown)
		distanceX = screenSize.width - location.x;
	else if (currentOrientation == UIInterfaceOrientationLandscapeRight)
		distanceX = location.y;
	else if (currentOrientation == UIInterfaceOrientationLandscapeLeft)
		distanceX = screenSize.width - location.y;
	else
		return NO;
	return [self _isLocationXWithinLeadingStatusBarRegion:distanceX];
}

-(id)viewForSystemGestureRecognizer:(id)gestureRecognizer {
	return self.window;
}

-(void)_handleCornerPull:(SBScreenEdgePanGestureRecognizer *)gestureRecognizer {
	UIView *gestureView = gestureRecognizer.view;

	UIInterfaceOrientation currentOrientation = [[%c(SpringBoard) sharedApplication] activeInterfaceOrientation];
	CGPoint translation = [gestureRecognizer translationInView:nil];
	CGPoint velocity = [gestureRecognizer velocityInView:nil];
	
	CGFloat distanceY = _UIWindowConvertPointFromOrientationToOrientation(translation, UIInterfaceOrientationPortrait, currentOrientation).y;
	CGFloat velocityY = _UIWindowConvertPointFromOrientationToOrientation(velocity, UIInterfaceOrientationPortrait, currentOrientation).y;

	if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
		[self _gestureBeganForView:gestureView withDistance:distanceY andVelocity:velocityY];
	else if (gestureRecognizer.state == UIGestureRecognizerStateChanged)
		[self _gestureUpdatedForView:gestureView withDistance:distanceY andVelocity:velocityY];
	else if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateRecognized)
		[self _gestureEndedForView:gestureView withDistance:distanceY andVelocity:velocityY];
	else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled || gestureRecognizer.state == UIGestureRecognizerStateFailed)
		[self _gestureCancelledForView:gestureView withDistance:distanceY andVelocity:velocityY];
}

-(void)_gestureBeganForView:(UIView *)gestureView withDistance:(CGFloat)distance andVelocity:(CGFloat)velocity {
	[self _deactivateReachability];
}

-(void)_gestureUpdatedForView:(UIView *)gestureView withDistance:(CGFloat)distance andVelocity:(CGFloat)velocity {
	CGFloat maxDistance = (gestureView.bounds.size.height / 3.0);
	
	CGFloat percentage = PercentageForDistance(distance, maxDistance);
	self.window.rootViewController.view.alpha = percentage;
	
	if (percentage > 0.99)
		percentage = 0.99;
	else if (percentage < 0.0)
		percentage = 0.0;
	float backlightFactor = 1.0f - percentage;
	[self setBacklightLevel:backlightFactor withDuration:0.0];
}

-(void)_gestureEndedForView:(UIView *)gestureView withDistance:(CGFloat)distance andVelocity:(CGFloat)velocity {
	CGFloat maxDistance = (gestureView.bounds.size.height / 3.0);
	CGFloat percentage = PercentageForDistance(distance, maxDistance);
	BOOL shouldLock;
	if (percentage < 0.1)
		shouldLock = NO;
	else if (percentage > 0.8)
		shouldLock = YES;
	else
		shouldLock = (velocity >= (maxDistance - distance));

	if (shouldLock) {
		SBLockScreenManager *lockScreenManager = [%c(SBLockScreenManager) sharedInstance];
		id targetViewController = nil;
		if ([lockScreenManager respondsToSelector:@selector(lockScreenViewController)])
			targetViewController = [lockScreenManager lockScreenViewController];

		UIView *dimView = self.window.rootViewController.view;
		[[%c(SBScreenWakeAnimationController) sharedInstance] sleepForSource:10 target:targetViewController completion:^{
			dimView.alpha = 0.0;
			if (![[%c(SBScreenWakeAnimationController) sharedInstance] isWakeAnimationInProgress])
				[lockScreenManager lockUIFromSource:8 withOptions:nil];
		}];
	} else {
		[self setBacklightLevel:1.0 withDuration:CORNER_LOCK_ANIMATION_DURATION];
		self.window.rootViewController.view.alpha = 0.0;
	}
}

-(void)_gestureCancelledForView:(UIView *)gestureView withDistance:(CGFloat)distance andVelocity:(CGFloat)velocity {
	[self _deactivateReachability];
	[self setBacklightLevel:1.0 withDuration:CORNER_LOCK_ANIMATION_DURATION];
	self.window.rootViewController.view.alpha = 0.0;
}

-(void)setBacklightLevel:(float)level withDuration:(float)duration {
	BKSHIDServicesSetBacklightFactorWithFadeDuration(level, duration, false);
}

-(void)_deactivateReachability {
	// deactivate reachability
	SBReachabilityManager *reachabilityManager = [%c(SBReachabilityManager) sharedInstance];
	if ([reachabilityManager respondsToSelector:@selector(deactivateReachability)])
		[reachabilityManager deactivateReachability];
	else if ([reachabilityManager respondsToSelector:@selector(deactivateReachabilityModeForObserver:)])
		[reachabilityManager deactivateReachabilityModeForObserver:nil];
}

-(BOOL)_isLocationXWithinLeadingStatusBarRegion:(CGFloat)locationX {
	SpringBoard *springBoard = [%c(SpringBoard) sharedApplication];
	CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
	BOOL isRTL = springBoard.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
	CGFloat statusBarXRegion = 0.0;
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		UIStatusBar *statusBar = [springBoard statusBar];
		CGRect leadingFrame = CGRectZero;
		if ([statusBar respondsToSelector:@selector(frameForRegionWithIdentifier:)])
			leadingFrame = [statusBar frameForRegionWithIdentifier:_UIStatusBarPartIdentifierFittingLeading];
		else if ([statusBar respondsToSelector:@selector(frameForPartWithIdentifier:)])
			leadingFrame = [statusBar frameForPartWithIdentifier:_UIStatusBarPartIdentifierFittingLeading];

		if (isRTL)
			statusBarXRegion = screenWidth - CGRectGetMinX(leadingFrame);
		else
			statusBarXRegion = CGRectGetMaxX(leadingFrame);

		CGFloat elementWidth = SBLayoutDefaultSideLayoutElementWidth() * 0.5;
		if (statusBarXRegion < elementWidth || statusBarXRegion > screenWidth)
			statusBarXRegion = elementWidth;
	} else {
		CGFloat multiplier = (UIInterfaceOrientationIsPortrait([springBoard activeInterfaceOrientation]) ? CORNER_LOCK_PORTRAIT_MULTIPLIER : CORNER_LOCK_LANDSCAPE_MULTIPLIER);
		statusBarXRegion = screenWidth * multiplier;
	}

	BOOL isLocationXWithinLeading = NO;
	if (isRTL)
		isLocationXWithinLeading = (screenWidth - statusBarXRegion < locationX);
	else
		isLocationXWithinLeading = (statusBarXRegion > locationX);
	return isLocationXWithinLeading;
}

-(void)dealloc {
	if (self.cornerLockPanGestureRecognizer != nil) {
		// remove gesture from system
		id displayIdentity = [[%c(SBSystemGestureManager) mainDisplayManager] valueForKey:@"_displayIdentity"];
		Class SystemGestureManager = %c(FBSystemGestureManager) ?: %c(_UISystemGestureManager);
		[[SystemGestureManager sharedInstance] removeGestureRecognizer:self.cornerLockPanGestureRecognizer fromDisplayWithIdentity:displayIdentity];

		[self.cornerLockPanGestureRecognizer release];
		self.cornerLockPanGestureRecognizer = nil;
	}

	[self.window release];
	self.window = nil;

	[super dealloc];
}
@end
