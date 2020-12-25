#import <UIKit/UIScreenEdgePanGestureRecognizer.h>

@protocol SBSystemGestureRecognizerDelegate;

@interface SBScreenEdgePanGestureRecognizer : UIScreenEdgePanGestureRecognizer // iOS 9 - 13
@property (nonatomic, assign, weak) id<SBSystemGestureRecognizerDelegate> delegate; // iOS 9 - 13
-(instancetype)initWithTarget:(id)target action:(SEL)action type:(NSInteger)type; // iOS 9 - 12
-(instancetype)initWithTarget:(id)target action:(SEL)action type:(NSInteger)type options:(NSUInteger)option; // iOS 13
-(void)sb_setStylusTouchesAllowed:(BOOL)allowed;
-(BOOL)isLocationWithinGrabberActiveZone; // iOS 9 - 13
-(void)setGrabberActiveZoneWidth:(CGFloat)width; // iOS 9 - 13
@end