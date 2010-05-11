//
//  AmazonSearch.h
//  MetaZ
//
//  Created by Brian Olsen on 20/11/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MetaZKit/MetaZKit.h>
#import "AmazonPlugin.h"

@interface AmazonSearch : MZRESTSearch
{
    NSDictionary* mapping;
    NSDictionary* ratingsMap;
}

+ (id)searchWithProvider:(id)provider delegate:(id<MZSearchProviderDelegate>)delegate url:(NSURL *)url parameters:(NSDictionary *)params;
- (id)initWithProvider:(id)provider delegate:(id<MZSearchProviderDelegate>)delegate url:(NSURL *)url parameters:(NSDictionary *)params;

@end
