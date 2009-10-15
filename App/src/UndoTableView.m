//
//  UndoTableView.m
//  MetaZ
//
//  Created by Brian Olsen on 11/10/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import "UndoTableView.h"


@implementation UndoTableView

-(IBAction)beginEnterEdit:(id)sender {
    NSInteger row = [self selectedRow];
    NSArray* columns = [self tableColumns];
    int i = 0;
    for(NSTableColumn* column in columns)
    {
        if([column isEditable])
        {
            [self editColumn:i row:row withEvent:nil select:YES];
            return;
        }
        i++;
    }
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString* ns = [theEvent charactersIgnoringModifiers];
    if([ns length] == 1)
    {
        unichar ch = [ns characterAtIndex:0];
        //NSLog(@"keyDown %x %x", ch, NSNewlineCharacter);
        switch(ch) {
            case NSNewlineCharacter:
                //NSLog(@"Caught NL");
            case NSCarriageReturnCharacter:
                //NSLog(@"Caught CR");
            case NSEnterCharacter:
                //NSLog(@"Caught Enter");
                if([self numberOfSelectedRows] == 1) {
                    [self beginEnterEdit:self];
                    return;
                }
                break;
        }
    }
    [super keyDown:theEvent];
}

- (BOOL)resignFirstResponder
{
    return [super resignFirstResponder];
}

@end
