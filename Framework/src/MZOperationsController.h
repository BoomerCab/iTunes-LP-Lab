//
//  MZOperationsController.h
//  MetaZ
//
//  Created by Brian Olsen on 19/01/10.
//  Copyright 2010 Maven-Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MetaZKit/MZDataProvider.h>

@interface MZOperationsController : NSObject <MZDataController>
{
    NSArray* operations;
    NSError* error;
    BOOL isFinished;
    BOOL isCancelled;
}
@property(readonly,copy) NSArray* operations;
@property(retain) NSError* error;
@property(assign) BOOL isFinished;
@property(assign) BOOL isCancelled;

- (void)addOperation:(NSOperation *)operation;
- (void)removeOperation:(NSOperation *)operation;

- (void)cancel;
- (void)addOperationsToQueue:(NSOperationQueue*)queue;

- (void)operationsFinished;

@end
