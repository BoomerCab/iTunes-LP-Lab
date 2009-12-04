//
//  MetaEditsUndoManager.h
//  MetaZ
//
//  Created by Brian Olsen on 18/11/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MetaEditsUndoManager : NSUndoManager
{
}

- (void)setActionName:(NSString *)actionName;

@end
