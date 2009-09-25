//
//  MZWriteQueue.m
//  MetaZ
//
//  Created by Brian Olsen on 07/09/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import "MZWriteQueue.h"

@implementation MZWriteQueue
@synthesize queueItems;
@synthesize status;

static MZWriteQueue* sharedQueue = nil;

+(MZWriteQueue *)sharedQueue {
    if(!sharedQueue)
        [[[MZWriteQueue alloc] init] release];
    return sharedQueue;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    return !([key isEqual:@"queueItems"] || [key isEqual:@"status"]);
}

-(id)init
{
    self = [super init];

    if(sharedQueue)
    {
        [self release];
        self = [sharedQueue retain];
    } else if(self)
    {
        status = QueueStopped;
        fileName = [[@"MetaZ" stringByAppendingPathComponent:@"Write.queue"] retain];
        queueItems = [[NSMutableArray alloc] init];
        //[self loadQueueWithError:NULL];
        sharedQueue = [self retain];
    }
    return self;
}

-(void)dealloc
{
    [fileName release];
    [queueItems release];
    [super dealloc];
}

-(BOOL)started
{
    return status > QueueStopped;
}

-(BOOL)paused
{
    return status == QueuePaused;
}

-(void)start
{
    if(status == QueueStopped)
    {
        [self willChangeValueForKey:@"status"];
        status = QueueRunning;
        [self didChangeValueForKey:@"status"];
    }
}

-(void)pause
{
    if(status == QueueRunning)
    {
        [self willChangeValueForKey:@"status"];
        status = QueuePaused;
        [self didChangeValueForKey:@"status"];
    }
}

-(void)resume
{
    if(status == QueuePaused)
    {
        [self willChangeValueForKey:@"status"];
        status = QueueRunning;
        [self didChangeValueForKey:@"status"];
    }
}

-(void)stop
{
    if(status != QueueStopped)
    {
        [self willChangeValueForKey:@"status"];
        status = QueueStopped;
        [self didChangeValueForKey:@"status"];
    }
}

-(BOOL)loadQueueWithError:(NSError **)error
{
    NSFileManager *mgr = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    for(NSString * path in paths)
    {
        NSString *destinationPath = [path stringByAppendingPathComponent: fileName];
        if([mgr fileExistsAtPath:destinationPath])
        {
            id ret = [NSKeyedUnarchiver unarchiveObjectWithFile:destinationPath];
            if(!ret)
            {
                // Make NSError;
                return NO;
            }
            [self willChangeValueForKey:@"queueItems"];
            [queueItems addObjectsFromArray: ret];
            [self didChangeValueForKey:@"queueItems"];
            return YES;
        }
    }
    if ([paths count] == 0)
    {
        //Make NSError;
        return NO;
    }
    return YES;
}

-(BOOL)saveQueueWithError:(NSError **)error
{
    NSFileManager *mgr = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if([queueItems count] > 0)
    {
        if ([paths count] > 0)
        {
            NSString *destinationDir = [[paths objectAtIndex:0]
                        stringByAppendingPathComponent: @"MetaZ"];
            BOOL isDir;
            if([mgr fileExistsAtPath:destinationDir isDirectory:&isDir])
            {
                if(!isDir)
                {
                    [mgr removeItemAtPath:destinationDir error:error];
                    [mgr createDirectoryAtPath:destinationDir withIntermediateDirectories:YES attributes:nil error:error];
                }
            }
            else
                [mgr createDirectoryAtPath:destinationDir withIntermediateDirectories:YES attributes:nil error:error];
            
            NSString *destinationPath = [[paths objectAtIndex:0]
                        stringByAppendingPathComponent: fileName];
            if(![NSKeyedArchiver archiveRootObject:queueItems toFile:destinationPath])
            {
                //Make NSError;
                return NO;
            }
        }
        else
        {
            // Make NSError;
            return NO;
        }
    }
    else
    {
        for(NSString * path in paths)
        {
            NSString *destinationPath = [path stringByAppendingPathComponent: fileName];
            if([mgr fileExistsAtPath:destinationPath] && ![mgr removeItemAtPath:destinationPath error:error])
                return NO;
        }
    }
    return YES;
}

-(void)removeAllQueueItems
{
    [self willChangeValueForKey:@"queueItems"];
    [queueItems removeAllObjects];
    [self saveQueueWithError:NULL];
    [self didChangeValueForKey:@"queueItems"];
}

-(void)removeObjectFromQueueItemsAtIndex:(NSUInteger)index
{
    [self willChangeValueForKey:@"queueItems"];
    [queueItems removeObjectAtIndex:index];
    [self saveQueueWithError:NULL];
    [self didChangeValueForKey:@"queueItems"];
}

-(void)removeQueueItemsAtIndexes:(NSIndexSet *)indexes
{
    [self willChangeValueForKey:@"queueItems"];
    [queueItems removeObjectsAtIndexes:indexes];
    [self saveQueueWithError:NULL];
    [self didChangeValueForKey:@"queueItems"];
}

-(void)insertObject:(MetaEdits *)anEdit inQueueItemsAtIndex:(NSUInteger)index
{
    NSAssert(anEdit, @"A value argument");
    [self willChangeValueForKey:@"queueItems"];
    [queueItems insertObject:[anEdit copy] atIndex:index];
    [self saveQueueWithError:NULL];
    [self didChangeValueForKey:@"queueItems"];
}

-(void)insertQueueItems:(NSArray *)edits atIndexes:(NSIndexSet *)indexes;
{
    NSUInteger currentIndex = [indexes firstIndex];
    NSUInteger i, count = [indexes count];
    NSAssert([edits count] == count, @"Array and indexes must contain same count");
 
    [self willChangeValueForKey:@"queueItems"];
    for (i = 0; i < count; i++)
    {
        MetaEdits* edit = [edits objectAtIndex:i];
        [queueItems insertObject:[edit copy] atIndex:currentIndex];
        currentIndex = [indexes indexGreaterThanIndex:currentIndex];
    }
    [self saveQueueWithError:NULL];
    [self didChangeValueForKey:@"queueItems"];
}

-(void)addQueueItems:(NSArray *)anArray
{
    NSAssert(anArray, @"An array argument");
    if([anArray count] == 0)
        return;
    [self willChangeValueForKey:@"queueItems"];
    for(MetaEdits* edit in anArray)
        [queueItems addObject:[edit copy]];
    [self saveQueueWithError:NULL];
    [self didChangeValueForKey:@"queueItems"];
}

-(void)addQueueItemsObject:(MetaEdits *)anEdit
{
    NSAssert(anEdit, @"A value argument");
    [self willChangeValueForKey:@"queueItems"];
    [queueItems addObject:[anEdit copy]];
    [self saveQueueWithError:NULL];
    [self didChangeValueForKey:@"queueItems"];
}

@end
