//
//  SearchMeta.h
//  MetaZ
//
//  Created by Brian Olsen on 04/09/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MetaData.h"
#import "MZDynamicObject.h"

@interface SearchMeta : MZDynamicObject <MetaData> {
    id<MetaData> provider;
    IBOutlet NSArrayController* searchController;
}

-(id)initWithProvider:(id<MetaData>)aProvider andController:(NSArrayController *)aController;

@end
