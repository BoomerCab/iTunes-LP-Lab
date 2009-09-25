//
//  MyTableView.m
//  MetaZ
//
//  Created by Brian Olsen on 02/09/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import "FilesTableView.h"
#import "MZMetaLoader.h"
#import "NSArray-Mapping.h"

#define MZFilesTableRows @"MZFilesTableRows"

@implementation FilesTableView
@synthesize undoController;
@synthesize filesController;

+ (void)initialize
{
    static BOOL initialized = NO;
    /* Make sure code only gets executed once. */
    if (initialized == YES) return;
    initialized = YES;
 
    NSArray* sendTypes = [NSArray arrayWithObjects:NSFilenamesPboardType,
                                NSStringPboardType, nil];
    NSArray* returnTypes = [NSArray arrayWithObjects:NSFilenamesPboardType,
                                NSStringPboardType, nil];
    [NSApp registerServicesMenuSendTypes:sendTypes
                    returnTypes:returnTypes];
    
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        [self registerForDraggedTypes:
                [NSArray arrayWithObjects:MZFilesTableRows,
                    MZMetaEditsDataType, NSFilenamesPboardType,
                    NSStringPboardType, nil] ];
        [self setDataSource:self];
    }
    return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    if(self)
    {
        [self registerForDraggedTypes:
                [NSArray arrayWithObjects:MZFilesTableRows,
                    MZMetaEditsDataType, NSFilenamesPboardType,
                    NSStringPboardType, nil] ];
        [self setDataSource:self];
    }
    return self;
}

-(void)dealloc {
    [undoController release];
    [filesController release];
    [super dealloc];
}

#pragma mark - actions
-(IBAction)delete:(id)sender {
    [filesController remove:sender];
}

-(IBAction)beginEnterEdit:(id)sender {
    NSInteger row = [self selectedRow];
    [self editColumn:0 row:row withEvent:nil select:YES];
}

-(IBAction)paste:(id)sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [NSArray arrayWithObjects:MZFilesTableRows,
            MZMetaEditsDataType, NSFilenamesPboardType,
            NSStringPboardType, nil];
    NSString *bestType = [pb availableTypeFromArray:types];
    if (bestType != nil)
    {
        if([bestType isEqualToString:MZFilesTableRows])
        {
            NSData* data = [pb dataForType:MZFilesTableRows];
            NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            // TODO Support rowIndex paste??
        }
        if([bestType isEqualToString:MZMetaEditsDataType])
        {
            NSData* data = [pb dataForType:MZMetaEditsDataType];
            NSArray* edits = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            // TODO Support Meta edits paste here??
        }
        if([bestType isEqualToString:NSFilenamesPboardType])
        {
            NSArray* filenames = [pb propertyListForType:NSFilenamesPboardType];
            [[MZMetaLoader sharedLoader] loadFromFiles:filenames];
        }
        if([bestType isEqualToString:NSStringPboardType])
        {
            NSString* filename = [pb stringForType:NSStringPboardType];
            NSFileManager* mgr = [NSFileManager defaultManager];
            BOOL dir = NO;
            if([mgr fileExistsAtPath:[filename stringByExpandingTildeInPath]
                        isDirectory:&dir] && !dir)
                [[MZMetaLoader sharedLoader] loadFromFile:filename];
        }
    }
}

- (BOOL)pasteboardHasTypes {
    // has the pasteboard got an expense?
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [NSArray arrayWithObjects:MZFilesTableRows,
            MZMetaEditsDataType, NSFilenamesPboardType,
            NSStringPboardType, nil];
    NSString *bestType = [pb availableTypeFromArray:types];
    if(bestType != nil && [bestType isEqualToString:NSStringPboardType])
    {
        NSString* str = [pb stringForType:NSStringPboardType];
        NSFileManager* mgr = [NSFileManager defaultManager];
        BOOL dir = NO;
        return [mgr fileExistsAtPath:[str stringByExpandingTildeInPath] isDirectory:&dir] && !dir;
    }
    return bestType != nil;
}

#pragma mark - user interface validation
- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
    SEL action = [anItem action];
    if(action == @selector(delete:))
        return [self numberOfSelectedRows] > 0;
    if(action == @selector(paste:))
        return [self pasteboardHasTypes];
    return [super validateUserInterfaceItem:anItem];
}

#pragma mark - services support 
- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{
    if((sendType && [self selectedRow] >= 0) &&
        ([sendType isEqual:NSStringPboardType] ||
            [sendType isEqual:NSFilenamesPboardType]))
    {
            return self;
    }
    if(returnType &&
        ([returnType isEqual:NSStringPboardType] ||
            [returnType isEqual:NSFilenamesPboardType]))
    {
            return self;
    }
    return [super validRequestorForSendType:sendType
                                 returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
    if(![types containsObject:NSStringPboardType] &&
        ![types containsObject:NSFilenamesPboardType])
    {
        return NO;
    }
    if([self selectedRow] < 0)
        return NO;


    NSArray* returnTypes = [NSArray arrayWithObjects:NSFilenamesPboardType,
                                NSStringPboardType, nil];
    [pboard declareTypes:returnTypes owner:nil];

    if([types containsObject:NSStringPboardType])
    {
        MetaEdits* selection = [[filesController arrangedObjects] objectAtIndex:[self selectedRow]];
        if(![pboard setString:[selection loadedFileName] forType:NSStringPboardType])
            return NO;
    }
    if([types containsObject:NSFilenamesPboardType])
    {
        NSArray* selection = [[filesController arrangedObjects] objectsAtIndexes:[self selectedRowIndexes]];
        selection = [selection arrayByPerformingSelector:@selector(loadedFileName)];
        if(![pboard setPropertyList:selection forType:NSFilenamesPboardType])
            return NO;
    }
    
    return YES;
}

#pragma mark - drag'n'drop support
- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard*)pboard
{
    [pboard declareTypes:[NSArray arrayWithObjects:MZFilesTableRows,
            MZMetaEditsDataType, NSFilenamesPboardType,
            NSStringPboardType,nil] owner:nil];

    NSData *rowdata = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    if(![pboard setData:rowdata forType:MZFilesTableRows])
        return NO;

    NSArray* edits = [[filesController arrangedObjects] objectsAtIndexes:rowIndexes];
    NSData *editsdata = [NSKeyedArchiver archivedDataWithRootObject:edits];
    if(![pboard setData:editsdata forType:MZMetaEditsDataType])
        return NO;

    NSArray* filenames = [edits arrayByPerformingSelector:@selector(loadedFileName)];
    if(![pboard setPropertyList:filenames forType:NSFilenamesPboardType])
        return NO;
    if(![pboard setString:[filenames objectAtIndex:0] forType:NSStringPboardType])
        return NO;
    return YES;
}


- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    if(op==NSTableViewDropOn)
        [self setDropRow:row dropOperation:NSTableViewDropAbove];

    NSPasteboard* pboard = [info draggingPasteboard];
    NSArray *types = [NSArray arrayWithObjects:MZFilesTableRows,
            MZMetaEditsDataType, NSFilenamesPboardType,
            NSStringPboardType, nil];
    NSString *bestType = [pboard availableTypeFromArray:types];
    if(bestType != nil)
    {
        if([bestType isEqualToString:NSStringPboardType])
        {
            NSString* str = [pboard stringForType:NSStringPboardType];
            NSFileManager* mgr = [NSFileManager defaultManager];
            BOOL dir = NO;
            if([mgr fileExistsAtPath:[str stringByExpandingTildeInPath] isDirectory:&dir] && !dir )
                return NSDragOperationMove | NSDragOperationDelete;
            return NSDragOperationNone;
        }
        return NSDragOperationMove | NSDragOperationDelete;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
            row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSArray *types = [NSArray arrayWithObjects:MZFilesTableRows,
            MZMetaEditsDataType, NSFilenamesPboardType,
            NSStringPboardType, nil];
    NSString *bestType = [pboard availableTypeFromArray:types];
    if (bestType != nil)
    {
        if([bestType isEqualToString:MZFilesTableRows])
        {
            NSData* data = [pboard dataForType:MZFilesTableRows];
            NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSArray* edits = [[filesController arrangedObjects] objectsAtIndexes:rowIndexes];
            [filesController setSortDescriptors:nil];
            [[MZMetaLoader sharedLoader] moveObjects:edits toIndex:row];
            return YES;
        }
        /*
        if([bestType isEqualToString:MZMetaEditsDataType])
        {
            NSData* data = [pb dataForType:MZMetaEditsDataType];
            NSArray* edits = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        */
        if([bestType isEqualToString:NSFilenamesPboardType])
        {
            NSArray* filenames = [pboard propertyListForType:NSFilenamesPboardType];
            [[MZMetaLoader sharedLoader] loadFromFiles:filenames];
            return YES;
        }
        if([bestType isEqualToString:NSStringPboardType])
        {
            NSString* filename = [pboard stringForType:NSStringPboardType];
            NSFileManager* mgr = [NSFileManager defaultManager];
            BOOL dir = NO;
            if([mgr fileExistsAtPath:[filename stringByExpandingTildeInPath]
                        isDirectory:&dir] && !dir)
            {
                [[MZMetaLoader sharedLoader] loadFromFile:filename];
                return YES;
            }
        }
    }
    return NO;
}

#pragma mark - general
- (void)keyDown:(NSEvent *)theEvent {
    NSString* ns = [theEvent charactersIgnoringModifiers];
    NSUInteger modifierFlags = [theEvent modifierFlags]; 
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
            case NSBackspaceCharacter:
            case NSDeleteCharacter:
                if([self numberOfSelectedRows] > 0 && (modifierFlags & NSCommandKeyMask) == NSCommandKeyMask )
                {
                    //NSLog(@"Caught Cmd-Backspace");
                    [self delete:self];
                    return;
                }
        }
    }
    [super keyDown:theEvent];
}

-(NSUndoManager *)undoManager {
    NSUndoManager* man = [undoController undoManager];
    if(man != nil)
        return man;
    return [super undoManager];
}

@end
