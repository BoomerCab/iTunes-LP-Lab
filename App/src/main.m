//
//  main.m
//  MetaZ
//
//  Created by Brian Olsen on 20/08/09.
//  Copyright Maven-Group 2009. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <RubyCocoa/RBRuntime.h>
#import <MetaZKit/MZLogger.h>
#import <sys/stat.h>

int main(int argc, const char *argv[])
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    BOOL makeFileLog = YES;
    for(int i=0; i<argc; i++)
        if(strncmp(argv[i], "-l", 2)==0)
            makeFileLog = NO;
    
    if(makeFileLog)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        if([paths count] > 0)
        {
            NSString* path = [[[paths objectAtIndex:0] 
                stringByAppendingPathComponent:@"Logs"] 
                stringByAppendingPathComponent:@"MetaZ.log"];

            umask(022);
        
            // Send stderr to our file
            freopen([path fileSystemRepresentation], "a", stderr);
        }
    }

    GTMLogger *logger = [GTMLogger sharedLogger];
    [logger setFormatter:[[[MZLogStandardFormatter alloc] init] autorelease]];
    [logger setWriter:[MZNSLogWriter logWriter]];
    [logger setFilter:[[[GTMLogNoFilter alloc] init] autorelease]];
    
    //RBApplicationInit("rb_main.rb", argc, argv, nil);
    [pool release];
    return NSApplicationMain(argc,  argv);
}
