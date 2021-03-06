//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Jun  6 2019 20:42:15).
//
//  Copyright (C) 1997-2019 Steve Nygard.
//

#import <AppKit/NSBezierPath.h>

@interface NSBezierPath (DVTNSBezierPathAdditions)
+ (id)dvt_bezierPathWithCrossedRect:(struct CGRect)arg1;
+ (id)dvt_bezierPathWithRoundRectInRect:(struct CGRect)arg1 topLeftRadius:(double)arg2 topRightRadius:(double)arg3 bottomRightRadius:(double)arg4 bottomLeftRadius:(double)arg5;
+ (id)dvt_bezierPathWithRoundRectInRect:(struct CGRect)arg1 radius:(double)arg2;
+ (id)dvt_bezierPathWithLineFrom:(struct CGPoint)arg1 to:(struct CGPoint)arg2;
- (BOOL)_isPointValid:(struct CGPoint)arg1;
- (const struct CGPath *)dvt_CGPathShouldEnsurePathIsClosed:(BOOL)arg1;
- (const struct CGPath *)dvt_CGPath;
- (void)dvt_fillWithInnerShadow:(id)arg1;
- (id)dvt_bezierPathFromStrokedPath;
- (BOOL)dvt_isStrokeHitByPoint:(struct CGPoint)arg1;
- (void)dvt_applyPathToContext:(struct CGContext *)arg1;
- (void)dvt_fillWithLinearGradientFromPoint:(struct CGPoint)arg1 withColor:(id)arg2 toPoint:(struct CGPoint)arg3 withColor:(id)arg4;
- (void)dvt_fillWithLinearGradientFromPoint:(struct CGPoint)arg1 toPoint:(struct CGPoint)arg2 withColors:(id)arg3 atStops:(id)arg4;
@end

