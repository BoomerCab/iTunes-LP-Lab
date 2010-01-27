//
//  APWriteManager.m
//  MetaZ
//
//  Created by Brian Olsen on 29/09/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import "APWriteManager.h"


@implementation APChapterWriteTask

+ (id)taskWithLaunchPath:(NSString *)path filePath:(NSString*)filePath chaptersFile:(NSString *)chaptersFile
{
    return [[[self alloc] initWithLaunchPath:path filePath:filePath chaptersFile:chaptersFile] autorelease];
}

- (id)initWithLaunchPath:(NSString *)path filePath:(NSString*)filePath chaptersFile:(NSString *)theChaptersFile
{
    self = [super init];
    if(self)
    {
        [self setLaunchPath:path];
        chaptersFile = [theChaptersFile retain];
        if([chaptersFile length] == 0)
            [self setArguments:[NSArray arrayWithObjects:@"-r", filePath, nil]];
        else
            [self setArguments:[NSArray arrayWithObjects:@"--import", chaptersFile, filePath, nil]];

    }
    return self;
}

- (void)taskTerminatedWithStatus:(int)status
{
    NSError* tempError = nil;
    NSFileManager* mgr = [NSFileManager defaultManager];
    if([chaptersFile length]>0)
    {
        if(![mgr removeItemAtPath:chaptersFile error:&tempError])
        {
            MZLoggerError(@"Failed to remove temp chapters file %@", [tempError localizedDescription]);
            tempError = nil;
        }
    }
    
    [self setErrorFromStatus:status];
    self.isExecuting = NO;
    self.isFinished = YES;
}

@end


@implementation APWriteManager
@synthesize provider;
@synthesize task;
@synthesize delegate;
@synthesize edits;
@synthesize isFinished;

+ (id)managerForProvider:(id<MZDataProvider>)provider
                    task:(NSTask *)task
                delegate:(id<MZDataWriteDelegate>)delegate
                   edits:(MetaEdits *)edits
             pictureFile:(NSString *)file
            chaptersFile:(NSString *)chapterFile
{
    return [[[self alloc] initForProvider:provider
                                     task:task
                                 delegate:delegate
                                    edits:edits                              
                              pictureFile:file
                             chaptersFile:chapterFile] autorelease];
}

- (id)initForProvider:(id<MZDataProvider>)theProvider
                 task:(NSTask *)theTask
             delegate:(id<MZDataWriteDelegate>)theDelegate
                edits:(MetaEdits *)theEdits
          pictureFile:(NSString *)file
         chaptersFile:(NSString *)theChapterFile
{
    self = [super init];
    if(self)
    {
        provider = [theProvider retain];
        task = [theTask retain];
        delegate = [theDelegate retain];
        edits = [theEdits retain];
        pictureFile = [file retain];
        chaptersFile = [theChapterFile retain];
        NSPipe* out = [NSPipe pipe];
        [task setStandardOutput:out];
    }
    return self;
}

- (void)dealloc
{
    if([task isRunning])
        [task terminate];
    [provider release];
    [task release];
    [delegate release];
    [edits release];
    [pictureFile release];
    [err release];
    [super dealloc];
}

- (void)start
{
    if([self isCancelled])
        return;
    [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(handlerGotData:)
                   name:NSFileHandleReadCompletionNotification
                 object:[[task standardOutput] fileHandleForReading]];
    [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(taskTerminated:)
                   name:NSTaskDidTerminateNotification
                 object:task];
    MZLoggerDebug(@"Starting write %@", [[task arguments] componentsJoinedByString:@" "]);
    err = [[NSPipe alloc] init];
    [task setStandardError:err];
    [[[task standardOutput] fileHandleForReading] readInBackgroundAndNotify];
    [task launch];
    if([delegate respondsToSelector:@selector(dataProvider:controller:writeStartedForEdits:)])
        [delegate dataProvider:provider controller:self writeStartedForEdits:edits];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return [task isRunning];
}

/*
- (BOOL)isFinished
{
    return self.isFinished;
}
*/

- (void)cancel
{
    [super cancel];
    if([task isRunning])
        [task terminate];
}

- (void)taskTerminated:(NSNotification *)note
{
    [APDataProvider logFromProgram:@"AtomicParsley" pipe:err];
    NSError* error = nil;
    NSError* tempError = nil;
    
    int status = [task terminationStatus];
    if(status != 0)
    {
        MZLoggerError(@"Terminated bad %d", status);
        NSDictionary* dict = [NSDictionary dictionaryWithObject:
            [NSString stringWithFormat:
                NSLocalizedString(@"AtomicParsley failed with exit code %d", @"Write failed error"),
                status]
            forKey:NSLocalizedDescriptionKey];
        error = [NSError errorWithDomain:@"AtomicParsleyPlugin" code:status userInfo:dict];
    }

    NSFileManager* mgr = [NSFileManager defaultManager];
    if(pictureFile)
    {
        if(![mgr removeItemAtPath:pictureFile error:&tempError])
        {
            MZLoggerError(@"Failed to remove temp picture file %@", [tempError localizedDescription]);
            tempError = nil;
        }
    }
    if([self isCancelled] || error)
    {
        if(chaptersFile && [chaptersFile length]>0)
        {
            if(![mgr removeItemAtPath:chaptersFile error:&tempError])
            {
                MZLoggerError(@"Failed to remove temp chapters file %@", [tempError localizedDescription]);
                tempError = nil;
            }
        }
        if(![mgr removeItemAtPath:[edits savedTempFileName] error:&tempError])
        {
            MZLoggerError(@"Failed to remove temp write file %@", [tempError localizedDescription]);
            tempError = nil;
        }
        if([delegate respondsToSelector:@selector(dataProvider:controller:writeCanceledForEdits:error:)])
            [delegate dataProvider:provider controller:self writeCanceledForEdits:edits error:error];
    }
    else
    {
        NSString* fileName;
        BOOL isDir = NO;
        if([mgr fileExistsAtPath:[edits savedTempFileName] isDirectory:&isDir] && !isDir)
            fileName = [edits savedTempFileName];
        else
            fileName = [edits loadedFileName];

        status = [APDataProvider testReadFile:fileName];

        if(chaptersFile && status == 0)
        {
            if([chaptersFile isEqualToString:@""])
                status = [APDataProvider removeChaptersFromFile:fileName];
            else
            {
                status = [APDataProvider importChaptersFromFile:chaptersFile toFile:fileName];
                if(![mgr removeItemAtPath:chaptersFile error:&tempError])
                {
                    MZLoggerError(@"Failed to remove temp chapters file %@", [tempError localizedDescription]);
                    tempError = nil;
                }
            }
        }
        if(status != 0)
        {
            NSDictionary* dict = [NSDictionary dictionaryWithObject:
                [NSString stringWithFormat:
                    NSLocalizedString(@"mp4chaps failed with exit code %d", @"Write failed error"),
                    status]
                forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"AtomicParsleyPlugin" code:status userInfo:dict];
        }
        
        if(error)
        {
            if([delegate respondsToSelector:@selector(dataProvider:controller:writeCanceledForEdits:error:)])
                [delegate dataProvider:provider controller:self writeCanceledForEdits:edits error:error];
        }
        else
        {
            self.isFinished = YES;
            if([delegate respondsToSelector:@selector(dataProvider:controller:writeFinishedForEdits:)])
                [delegate dataProvider:provider controller:self writeFinishedForEdits:edits];
        }
    }
    self.isFinished = YES;
    [provider removeWriteManager:self];
}

- (void)handlerGotData:(NSNotification *)note
{
    if(self.isFinished)
        return;
    NSData* data = [[note userInfo]
            objectForKey:NSFileHandleNotificationDataItem];
    NSString* str = [[[NSString alloc]
            initWithData:data
                encoding:NSUTF8StringEncoding] autorelease];
    NSString* origStr = str;
    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if([str hasPrefix:@"Started writing to temp file."])
        str = [str substringFromIndex:29];
    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger percent = [str integerValue];
    MZLoggerDebug(@"Got data: %d '%@'", percent, origStr);
    if(percent > 0 && [delegate respondsToSelector:@selector(dataProvider:controller:writeFinishedForEdits:percent:)])
        [delegate dataProvider:provider controller:self writeFinishedForEdits:edits percent:percent];
        
    if([task isRunning])
    {
        [[[task standardOutput] fileHandleForReading]
            readInBackgroundAndNotify];
    }
}

@end
