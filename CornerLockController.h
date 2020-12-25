#import "SBSystemGestureRecognizerDelegate.h"

@class CornerLockWindow, SBScreenEdgePanGestureRecognizer;

@interface CornerLockController : NSObject <SBSystemGestureRecognizerDelegate>
@property (nonatomic, retain) SBScreenEdgePanGestureRecognizer *cornerLockPanGestureRecognizer;
@property (nonatomic, retain) CornerLockWindow *window;
+(instancetype)sharedInstance;
@end