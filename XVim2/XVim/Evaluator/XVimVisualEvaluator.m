//
//  Created by Shuichiro Suzuki on 2/19/12.
//  Copyright (c) 2012 JugglerShu.Net. All rights reserved.
//

#import "XVimVisualEvaluator.h"
#import "Logger.h"
#import "NSTextStorage+VimOperation.h"
#import "SourceEditorViewProtocol.h"
#import "XVim.h"
#import "XVimCommandLineEvaluator.h"
#import "XVimDeleteEvaluator.h"
#import "XVimEqualEvaluator.h"
#import "XVimExCommand.h"
#import "XVimGVisualEvaluator.h"
#import "XVimInsertEvaluator.h"
#import "XVimJoinEvaluator.h"
#import "XVimKeyStroke.h"
#import "XVimKeymapProvider.h"
#import "XVimLowercaseEvaluator.h"
#import "XVimMarkSetEvaluator.h"
#import "XVimOptions.h"
#import "XVimRegisterManager.h"
#import "XVimRegisterEvaluator.h"
#import "XVimReplacePromptEvaluator.h"
#import "XVimSearch.h"
#import "XVimShiftEvaluator.h"
#import "XVimTextObjectEvaluator.h"
#import "XVimTildeEvaluator.h"
#import "XVimUppercaseEvaluator.h"
#import "XVimWindow.h"
#import "XVimYankEvaluator.h"
#import "XVim2-Swift.h"

static NSString* MODE_STRINGS[] = { @"", @"-- VISUAL --", @"-- VISUAL LINE --", @"-- VISUAL BLOCK --" };

@interface XVimVisualEvaluator () {
    BOOL _waitForArgument;
    NSRange _operationRange;
    XVIM_VISUAL_MODE _visual_mode;
    XVimLocation _initialFromLocation;
    XVimLocation _initialToLocation;
    BOOL _initialToEOL;
}
@end

@implementation XVimVisualEvaluator
- (id)initWithLastVisualStateWithWindow:(XVimWindow*)window
{
    if (self = [self initWithWindow:window mode:XVim.instance.lastVisualMode]) {
        _initialFromLocation = XVim.instance.lastVisualSelectionBeginLocation;
        _initialToLocation = XVim.instance.lastVisualLocation;
        _initialToEOL = XVim.instance.lastVisualSelectionToEOL;
    }
    return self;
}

- (id)initWithWindow:(XVimWindow*)window mode:(XVIM_VISUAL_MODE)mode
{
    if (self = [self initWithWindow:window]) {
        _waitForArgument = NO;
        _visual_mode = mode;
        let ranges = window.sourceView.selectedRanges;
        if (ranges.count == 1) {
            let range = window.sourceView.selectedRange;
            if (range.length == 0) {
                NSUInteger start = window.sourceView.selectedRange.location;
                _initialFromLocation = XVimMakeLocation([window.sourceView.textStorage xvim_lineNumberAtIndex:start],
                                                       [window.sourceView.textStorage xvim_columnOfIndex:start]);
                _initialToLocation = XVimMakeLocation([window.sourceView.textStorage xvim_lineNumberAtIndex:start],
                                                     [window.sourceView.textStorage xvim_columnOfIndex:start]);
            }
            else {
                NSUInteger start = window.sourceView.selectedRange.location;
                NSUInteger end = window.sourceView.selectedRange.location
                               + window.sourceView.selectedRange.length - 1;
                _initialFromLocation = XVimMakeLocation([window.sourceView.textStorage xvim_lineNumberAtIndex:start],
                                                       [window.sourceView.textStorage xvim_columnOfIndex:start]);
                _initialToLocation = XVimMakeLocation([window.sourceView.textStorage xvim_lineNumberAtIndex:end],
                                                     [window.sourceView.textStorage xvim_columnOfIndex:end]);
            }
        }
        else {
            // Treat it as block selection
            _visual_mode = XVIM_VISUAL_BLOCK;
            NSUInteger start = window.sourceView.selectedRanges.firstObject.rangeValue.location;
            NSUInteger end = window.sourceView.selectedRanges.lastObject.rangeValue.location
                           + window.sourceView.selectedRanges.lastObject.rangeValue.length - 1;
            _initialFromLocation = XVimMakeLocation([window.sourceView.textStorage xvim_lineNumberAtIndex:start],
                                                   [window.sourceView.textStorage xvim_columnOfIndex:start]);
            _initialToLocation = XVimMakeLocation([window.sourceView.textStorage xvim_lineNumberAtIndex:end],
                                                 [window.sourceView.textStorage xvim_columnOfIndex:end]);
        }
    }
    return self;
}

- (NSString*)modeString { return MODE_STRINGS[_visual_mode]; }

- (XVIM_MODE)mode { return XVIM_MODE_VISUAL; }

- (NSUInteger)initialNumberOfColumns {
    return labs((NSInteger)_initialToLocation.column - (NSInteger)_initialFromLocation.column);
}
- (NSUInteger)initialNumberOfLines {
    return labs((NSInteger)_initialToLocation.line - (NSInteger)_initialFromLocation.line);
}

- (void)becameHandler
{
    [super becameHandler];
    if (_initialToLocation.line != NSNotFound) {
        if (XVim.instance.isProcessingDOT) {
            [self.sourceView xvim_changeSelectionMode:_visual_mode];
            // When repeating we have to set initial selected range
            if (_visual_mode == XVIM_VISUAL_CHARACTER) {
                if (_initialFromLocation.line == _initialToLocation.line) {
                    // Same number of character if in one line
                    [self.sourceView xvim_moveToLocation:
                         XVimMakeLocation(self.sourceView.insertionLine,
                                          self.sourceView.insertionColumn + self.initialNumberOfColumns)];
                }
                else {
                    [self.sourceView xvim_moveToLocation:
                         XVimMakeLocation(self.sourceView.insertionLine + self.initialNumberOfLines,
                                          _initialToLocation.column)];
                    
                }
            }
            else if (_visual_mode == XVIM_VISUAL_LINE) {
                // Same number of lines
                [self.sourceView xvim_moveToLocation:
                    XVimMakeLocation(self.sourceView.insertionLine + self.initialNumberOfLines,
                                     self.sourceView.insertionColumn)];
            }
            else if (_visual_mode == XVIM_VISUAL_BLOCK) {
                // Use same number of lines/colums
                [self.sourceView xvim_moveToLocation:
                    XVimMakeLocation(self.sourceView.insertionLine + self.initialNumberOfLines,
                                     self.sourceView.insertionColumn + self.initialNumberOfColumns)];
            }
        }
        else {
//            [self.sourceView xvim_moveToLocation:_initialFromLocation];
			[self.sourceView xvim_changeSelectionMode:_visual_mode];
//            [self.sourceView xvim_moveToLocation:_initialToLocation];
        }
    }
    else {
        [self.sourceView xvim_changeSelectionMode:_visual_mode];
    }
    if (_initialToEOL) {
        [self performSelector:@selector(DOLLAR)];
    }
}

- (void)didEndHandler
{
    if (!_waitForArgument) {
        [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_NONE];
        [self endUndoGrouping];
        // TODO:
        //[[[XVim instance] repeatRegister] setVisualMode:_mode withRange:_operationRange];
    }
    [super didEndHandler];
}

- (XVimKeymap*)selectKeymapWithProvider:(id<XVimKeymapProvider>)keymapProvider
{
    return [keymapProvider keymapForMode:XVIM_MODE_VISUAL];
}

- (XVimEvaluator*)eval:(XVimKeyStroke*)keyStroke
{
    XVim.instance.lastVisualMode = self.sourceView.selectionMode;
    XVim.instance.lastVisualLocation = self.sourceView.insertionLocation;
    XVim.instance.lastVisualSelectionBeginLocation = self.sourceView.selectionBeginLocation;
    XVim.instance.lastVisualSelectionToEOL = self.sourceView.selectionToEOL;

    let nextEvaluator = [super eval:keyStroke];
    if (nextEvaluator != XVimEvaluator.invalidEvaluator) {
        return nextEvaluator;
    }
    return self;
}

- (XVimEvaluator*)a
{
    // FIXME: doesn't work properly, especially in block mode
    self.onChildCompleteHandler = @selector(onComplete_ai:);
    [self.argumentString appendString:@"a"];
    return [[XVimTextObjectEvaluator alloc] initWithWindow:self.window inner:NO];
}

- (XVimEvaluator*)A
{
    [self beginUndoGrouping];
    return [[XVimInsertEvaluator alloc] initWithWindow:self.window insertMode:XVIM_INSERT_APPEND];
}

- (XVimEvaluator*)i
{
    // FIXME: doesn't work properly, especially not in block mode
    self.onChildCompleteHandler = @selector(onComplete_ai:);
    [self.argumentString appendString:@"i"];
    return [[XVimTextObjectEvaluator alloc] initWithWindow:self.window inner:YES];
}

- (XVimEvaluator*)onComplete_ai:(XVimTextObjectEvaluator*)childEvaluator
{
    XVimMotion* m = childEvaluator.motion;

    self.onChildCompleteHandler = nil;
    if (m.style != MOTION_NONE) {
        return [self _motionFixed:m];
    }
    return self;
}

- (XVimEvaluator*)c
{
    if (self.sourceView.selectionMode == XVIM_VISUAL_BLOCK) {
        [self beginUndoGrouping];
        return [[XVimInsertEvaluator alloc] initWithWindow:self.window insertMode:XVIM_INSERT_BLOCK_KILL];
    }
    XVimDeleteEvaluator* eval = [[XVimDeleteEvaluator alloc] initWithWindow:self.window insertModeAtCompletion:YES];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_EXCLUSIVE count:1]];
}

- (XVimEvaluator*)C
{
    if (self.sourceView.selectionMode != XVIM_VISUAL_BLOCK) {
        [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_LINE];
        return [self c];
    }
    [self beginUndoGrouping];
    [self performSelector:@selector(DOLLAR)];
    return [[XVimInsertEvaluator alloc] initWithWindow:self.window insertMode:XVIM_INSERT_BLOCK_KILL];
}

- (XVimEvaluator*)C_b
{
    [[self sourceView] xvim_scrollPageBackward:[self numericArg]];
    return self;
}

- (XVimEvaluator*)C_d
{
    [[self sourceView] xvim_scrollHalfPageForward:[self numericArg]];
    return self;
}

- (XVimEvaluator*)d
{
    XVimDeleteEvaluator* eval = [[XVimDeleteEvaluator alloc] initWithWindow:self.window];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_INCLUSIVE count:0]];
}

- (XVimEvaluator*)DEL { return [self d]; }

- (XVimEvaluator*)D
{
    if (self.sourceView.selectionMode == XVIM_VISUAL_BLOCK) {
        [self performSelector:@selector(DOLLAR)];
    }
    else {
        [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_LINE];
    }

    return [self d];
}

- (XVimEvaluator*)C_e
{
    [self.sourceView xvim_scrollLineForward:self.numericArg];
    return self;
}

- (XVimEvaluator*)C_f
{
    [self.sourceView xvim_scrollPageForward:self.numericArg];
    return self;
}

- (XVimEvaluator*)g
{
    [self.argumentString appendString:@"g"];
    self.onChildCompleteHandler = @selector(g_completed:);
    return [[XVimGVisualEvaluator alloc] initWithWindow:self.window];
    return nil;
}

- (XVimEvaluator*)g_completed:(XVimEvaluator*)childEvaluator
{
    if (childEvaluator == [XVimEvaluator invalidEvaluator]) {
        [self.argumentString setString:@""];
        return self;
    }
    return nil;
}

- (XVimEvaluator*)I
{
    if (self.sourceView.selectionMode != XVIM_VISUAL_BLOCK) {
        return [[XVimInsertEvaluator alloc] initWithWindow:self.window insertMode:XVIM_INSERT_BEFORE_FIRST_NONBLANK];
    }
    [self beginUndoGrouping];
    return [[XVimInsertEvaluator alloc] initWithWindow:self.window insertMode:XVIM_INSERT_DEFAULT];
}

- (XVimEvaluator*)J
{
    XVimJoinEvaluator* eval = [[XVimJoinEvaluator alloc] initWithWindow:self.window addSpace:YES];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_EXCLUSIVE count: self.numericArg]];
}

- (XVimEvaluator*)m
{
    // 'm{letter}' sets a local mark.
    [self.argumentString appendString:@"m"];
    self.onChildCompleteHandler = @selector(m_completed:);
    return [[XVimMarkSetEvaluator alloc] initWithWindow:self.window];
    return nil;
}

- (XVimEvaluator*)m_completed:(XVimEvaluator*)childEvaluator
{
    // Vim does not escape from Visual mode after mark is set by m command
    self.onChildCompleteHandler = nil;
    return self;
}

- (XVimEvaluator*)o
{
#ifdef TODO
    [self.sourceView xvim_selectSwapEndsOnSameLine:NO];
#endif
    return self;
}

- (XVimEvaluator*)O
{
#ifdef TODO
    [self.sourceView xvim_selectSwapEndsOnSameLine:YES];
#endif
    return self;
}

- (XVimEvaluator*)p
{
    let view = [self sourceView];
    XVimRegister* reg = [XVim.instance.registerManager registerByName:self.yankRegister];
    [view xvim_put:reg.string type:reg.type afterCursor:YES count:self.numericArg];
    return nil;
}

- (XVimEvaluator*)P
{
    // Looks P works as p in Visual Mode.. right?
    return [self p];
}

- (XVimEvaluator*)r
{
    [self.window errorMessage:@"{Visual}r{char} not implemented yet" ringBell:NO];
    return self;
}

- (XVimEvaluator*)R { return [self S]; }

- (XVimEvaluator*)s
{
    // As far as I can tell this is equivalent to change
    return [self c];
}

- (XVimEvaluator*)S
{
    if (self.sourceView.selectionMode != XVIM_VISUAL_BLOCK) {
        [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_LINE];
    }
    [self.window errorMessage:@"{Visual}S not implemented yet" ringBell:NO];
    return self;
}

- (XVimEvaluator*)u
{
    [self beginUndoGrouping];
    XVimLowercaseEvaluator* eval = [[XVimLowercaseEvaluator alloc] initWithWindow:self.window];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_INCLUSIVE count:self.numericArg]];
}

- (XVimEvaluator*)U
{
    [self beginUndoGrouping];
    XVimUppercaseEvaluator* eval = [[XVimUppercaseEvaluator alloc] initWithWindow:self.window];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_INCLUSIVE count:self.numericArg]];
}

- (XVimEvaluator*)C_u
{
    [[self sourceView] xvim_scrollHalfPageBackward:self.numericArg];
    return self;
}

- (XVimEvaluator*)v
{
    let view = self.sourceView;
    if (view.selectionMode == XVIM_VISUAL_CHARACTER) {
        return [self ESC];
    }
    [view xvim_changeSelectionMode:XVIM_VISUAL_CHARACTER];
    return self;
}

- (XVimEvaluator*)V
{
    let view = self.sourceView;
    if (view.selectionMode == XVIM_VISUAL_LINE) {
        return [self ESC];
    }
    [view xvim_changeSelectionMode:XVIM_VISUAL_LINE];
    return self;
}

- (XVimEvaluator*)C_v
{
    let view = self.sourceView;
    if (view.selectionMode == XVIM_VISUAL_BLOCK) {
        return [self ESC];
    }
    [view xvim_changeSelectionMode:XVIM_VISUAL_BLOCK];
    return self;
}

- (XVimEvaluator*)x { return [self d]; }

- (XVimEvaluator*)X
{
    if (self.sourceView.selectionMode != XVIM_VISUAL_BLOCK) {
        [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_LINE];
    }
    return [self d];
}

- (XVimEvaluator*)y
{
    [self.sourceView xvim_yank:nil];
    return nil;
}

- (XVimEvaluator*)Y
{
    if (self.sourceView.selectionMode != XVIM_VISUAL_BLOCK) {
        [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_LINE];
    }
    return [self y];
}

- (XVimEvaluator*)C_y
{
    [self.sourceView xvim_scrollLineBackward:self.numericArg];
    return self;
}

- (XVimEvaluator*)DQUOTE
{
    [self.argumentString appendString:@"\""];
    self.onChildCompleteHandler = @selector(onComplete_DQUOTE:);
    _waitForArgument = YES;
    return [[XVimRegisterEvaluator alloc] initWithWindow:self.window];
}

- (XVimEvaluator*)onComplete_DQUOTE:(XVimRegisterEvaluator*)childEvaluator
{
    NSString* xregister = childEvaluator.reg;
    if ([XVim.instance.registerManager isValidForYank:xregister]) {
        self.yankRegister = xregister;
        [self.argumentString appendString:xregister];
        self.onChildCompleteHandler = @selector(onChildComplete:);
    }
    else {
        return XVimEvaluator.invalidEvaluator;
    }
    _waitForArgument = NO;
    return self;
}

/*
TODO: This block is from commit 42498.
      This is not merged. This is about percent register
- (XVimEvaluator*)DQUOTE:(XVimWindow*)window{
    XVimEvaluator* eval = [[XVimRegisterEvaluator alloc] initWithContext:[XVimEvaluatorContext
contextWithArgument:@"\""] parent:self completion:^ XVimEvaluator* (NSString* rname, XVimEvaluatorContext *context)
                           {
                               XVimRegister *xregister = [[XVim instance] findRegister:rname];
                               if (xregister.isReadOnly == NO || [xregister.displayName isEqualToString:@"%"] ){
                                   [context setYankRegister:xregister];
                                   [context appendArgument:rname];
                                   return [self withNewContext:context];
                               }

                               [[XVim instance] ringBell];
                               return nil;
                           }];
    return eval;
}
*/

- (XVimEvaluator*)EQUAL
{
    XVimEqualEvaluator* eval = [[XVimEqualEvaluator alloc] initWithWindow:self.window];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_EXCLUSIVE count:[self numericArg]]];
    return nil;
}

- (XVimEvaluator*)ESC
{
    [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_NONE];
    return nil;
}

- (XVimEvaluator*)C_c { return [self ESC]; }

- (XVimEvaluator*)C_LSQUAREBRACKET { return [self ESC]; }

- (XVimEvaluator*)C_RSQUAREBRACKET
{
    [self.window errorMessage:@"{Visual}CTRL-] not implemented yet" ringBell:NO];
    return self;
}

- (XVimEvaluator*)COLON
{
    __block XVimEvaluator* eval = [[XVimCommandLineEvaluator alloc]
                initWithWindow:self.window
                   firstLetter:@":'<,'>"
                       history:XVim.instance.exCommandHistory
                    completion:^XVimEvaluator*(NSString* command, XVimMotion** result) {
                        XVimExCommand* excmd = XVim.instance.excmd;
                        NSString* commandExecuted = [excmd executeCommand:command inWindow:self.window];

                        [self.sourceView xvim_changeSelectionMode:XVIM_VISUAL_NONE];

                        if ([commandExecuted isEqualToString:@"substitute"]) {
                            XVimSearch* searcher = XVim.instance.searcher;
                            if (searcher.confirmEach && searcher.lastFoundRange.location != NSNotFound) {
                                [eval didEndHandler];
                                return [[XVimReplacePromptEvaluator alloc]
                                               initWithWindow:self.window
                                            replacementString:searcher.lastReplacementString];
                            }
                        }

                        return nil;
                    }
                    onKeyPress:nil];

    return eval;
}

- (XVimEvaluator*)EXCLAMATION
{
    [self.window errorMessage:@"{Visual}!{filter} not implemented yet" ringBell:NO];
    return self;
}

- (XVimEvaluator*)GREATERTHAN
{
    XVimShiftEvaluator* eval = [[XVimShiftEvaluator alloc] initWithWindow:self.window unshift:NO];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_INCLUSIVE count:self.numericArg]];
}

- (XVimEvaluator*)LESSTHAN
{
    XVimShiftEvaluator* eval = [[XVimShiftEvaluator alloc] initWithWindow:self.window unshift:YES];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_INCLUSIVE count:self.numericArg]];
}

- (XVimEvaluator*)executeSearch:(XVimWindow*)window firstLetter:(NSString*)firstLetter
{
    /*1
XVimEvaluator *eval = [[XVimCommandLineEvaluator alloc] initWithContext:[[XVimEvaluatorContext alloc] init]
                                                                 parent:self
                                                           firstLetter:firstLetter
                                                               history:XVim.instance.searchHistory
                                                            completion:^ XVimEvaluator* (NSString *command)
                       {
                           XVimSearch *searcher = XVim.instance.searcher;
                           NSTextView *sourceView = window.sourceView;
                           NSRange found = [searcher executeSearch:command
                                                           display:[command substringFromIndex:1]
                                                              from:window.insertionPoint
                                                          inWindow:window];
                           //Move cursor and show the found string
                           if (found.location != NSNotFound) {
                               unichar firstChar = [command characterAtIndex:0];
                               if (firstChar == '?'){
                                   _insertion = found.location;
                               }else if (firstChar == '/'){
                                   _insertion = found.location + command.length - 1;
                               }
                               [self updateSelectionInWindow:window];
                               [sourceView scrollTo:window.insertionPoint];
                               [sourceView showFindIndicatorForRange:found];
                           } else {
                               [window errorMessage:[NSString stringWithFormat: @"Cannot find
'%@'",searcher.lastSearchDisplayString] ringBell:TRUE];
                           }
                           return self;
                       }
                                                            onKeyPress:^void(NSString *command)
                       {
                           XVimOptions *options = XVim.instance.options;
                           if (options.incsearch){
                               XVimSearch *searcher = [[XVim instance] searcher];
                               NSTextView *sourceView = window.sourceView;
                               NSRange found = [searcher executeSearch:command
                                                               display:[command substringFromIndex:1]
                                                                  from:window.insertionPoint
                                                              inWindow:window];
                               //Move cursor and show the found string
                               if (found.location != NSNotFound) {
                                   // Update the selection while preserving the current insertion point
                                   // The insertion point will be finalized if we complete a search
                                   NSUInteger prevInsertion = _insertion;
                                   unichar firstChar = [command characterAtIndex:0];
                                   if (firstChar == '?'){
                                       _insertion = found.location;
                                   }else if (firstChar == '/'){
                                       _insertion = found.location + command.length - 1;
                                   }
                                   [self updateSelectionInWindow:window];
                                   _insertion = prevInsertion;

                                   [sourceView scrollTo:found.location];
                                   [sourceView showFindIndicatorForRange:found];
                               }
                           }
                       }];
return eval;
 */
    return [self ESC]; // Temprarily this feture is turned off
}

- (XVimEvaluator*)QUESTION { return [self executeSearch:self.window firstLetter:@"?"]; }

- (XVimEvaluator*)SLASH { return [self executeSearch:self.window firstLetter:@"/"]; }

- (XVimEvaluator*)TILDE
{
    let eval = [[XVimTildeEvaluator alloc] initWithWindow:self.window];
    return [eval executeOperationWithMotion:[XVimMotion style:MOTION_NONE type:CHARWISE_EXCLUSIVE count:[self numericArg]]];
}

- (XVimEvaluator*)motionFixedCore:(XVimMotion*)motion
{
    if (!XVim.instance.isProcessingDOT) {
        [self.window preMotion:motion];
        [self.sourceView xvim_move:motion];
        [self resetNumericArg];
    }
    [self.argumentString setString:@""];
    return self;
}

@end
