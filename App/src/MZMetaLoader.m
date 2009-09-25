//
//  MetaLoader.m
//  MetaZ
//
//  Created by Brian Olsen on 25/08/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import "MZMetaLoader.h"

@implementation MZMetaLoader
@synthesize files;

#pragma mark - initialization 

static MZMetaLoader* sharedLoader = nil;

+(MZMetaLoader *)sharedLoader {
    if(!sharedLoader)
        [[[MZMetaLoader alloc] init] release];
    return sharedLoader;
}

-(id)init {
    self = [super init];

    if(sharedLoader)
    {
        [self release];
        self = [sharedLoader retain];
    } else if(self)
    {
        files = [[NSMutableArray alloc] init];
        sharedLoader = [self retain];
    }
    return self;
}

-(void)dealloc {
    [files release];
    [super dealloc];
}


-(NSArray *)types {
    return [provider types];
}

-(NSArray *)extensions {
    NSArray* ret = [provider extensions];
    return ret;
}

-(void)removeAllObjects
{
    [self willChangeValueForKey:@"files"];
    [files removeAllObjects];
    [self didChangeValueForKey:@"files"];
}

-(void)fixTitle:(MetaEdits* )edits {
    NSString* title = [edits title];
    if(title == nil)
    {
        [[edits undoManager] disableUndoRegistration];
        NSString* loadedFileName = [edits fileName];
        NSAssert(loadedFileName != nil, @"Bad loaded file name");
        NSAssert( ((NSNull*)loadedFileName) != [NSNull null], @"Bad loaded file name" );
        NSString* newTitle = [loadedFileName substringToIndex:[loadedFileName length] - [[loadedFileName pathExtension] length] - 1];
        [edits setTitle:newTitle];
        [[edits undoManager] enableUndoRegistration];
    }
}

-(void)loadFromFile:(NSString *)fileName {
    [self willChangeValueForKey:@"files"];
    MetaLoaded* loaded = [provider loadFromFile:fileName];
    MetaEdits* edits = [[MetaEdits alloc] initWithProvider:loaded];
    [self fixTitle:edits];
    [files addObject:edits];
    [self didChangeValueForKey:@"files"];
}

-(void)loadFromFiles:(NSArray *)fileNames {
    [self willChangeValueForKey:@"files"];
    for ( NSString* fileName in fileNames )
    {
        MetaLoaded* loaded = [provider loadFromFile:fileName];
        MetaEdits* edits = [[MetaEdits alloc] initWithProvider:loaded];
        [self fixTitle:edits];
        [files addObject:edits];
    }
    [self didChangeValueForKey:@"files"];
}

- (void)moveObjects:(NSArray *)objects toIndex:(NSUInteger)index
{
    [self willChangeValueForKey:@"files"];
    NSMutableIndexSet* idx = [[[NSMutableIndexSet alloc] init] autorelease];
    for(MetaEdits* edit in objects)
    {
        for(int i=[files count]-1; i>=0; i--)
        {
            MetaEdits* ob = [files objectAtIndex:i];
            if(ob == edit)
                [idx addIndex:i];
        }
    }
    [files removeObjectsAtIndexes:idx];

    index -= [idx countOfIndexesInRange:NSMakeRange(0, index)];
    for(int i=[objects count]-1; i>=0; i--)
    {
        [files insertObject:[objects objectAtIndex:i] atIndex:index];
    }
    [self didChangeValueForKey:@"files"];
}

@end
