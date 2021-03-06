//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Jun  6 2019 20:12:56).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <DVTKit/NSObject-Protocol.h>

@class DVTFindPattern, DVTFindPatternAttachmentCell, NSArray, NSFont, NSMenu, NSString;
@protocol DVTFindPatternManager;

@protocol DVTFindPatternField <NSObject>
@property id <DVTFindPatternManager> findPatternManager;
- (NSFont *)font;
- (NSMenu *)menuForFindPatternAttachment:(DVTFindPatternAttachmentCell *)arg1;
- (NSString *)plainTextValue;
- (void)setFindPatternPropertyList:(id)arg1;
- (id)findPatternPropertyList;
- (BOOL)hasFindPattern;
- (NSString *)replacementExpression;
- (NSString *)regularExpression;
- (NSArray *)findPatternTokenArray;
- (void)setFindPatternArray:(NSArray *)arg1;
- (void)insertNewFindPattern:(DVTFindPattern *)arg1;
- (BOOL)removeFindPattern:(DVTFindPattern *)arg1;
@end

