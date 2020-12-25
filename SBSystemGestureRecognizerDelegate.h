#import <UIKit/UIGestureRecognizer.h>

@protocol SBSystemGestureRecognizerDelegate <UIGestureRecognizerDelegate>
@required
-(id)viewForSystemGestureRecognizer:(id)gestureRecognizer;
@end