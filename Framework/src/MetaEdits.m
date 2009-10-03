//
//  MetaEdits.m
//  MetaZ
//
//  Created by Brian Olsen on 24/08/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import <MetaZKit/MetaEdits.h>
#import <MetaZKit/MZMethodData.h>
#import <MetaZKit/MZConstants.h>
#import <MetaZKit/MZTag.h>
//#import <MetaZKit/MetaChangeNotification.h>


@implementation MetaEdits
@synthesize undoManager;
@synthesize multiUndoManager;
@synthesize changes;

#pragma mark - initialization

- (id)initWithProvider:(id<MetaData>)aProvider {
    self = [super init];
    //undoManager = [[ProxyUndoManager alloc] initWithUndoManager:[[NSUndoManager alloc] init] andType:2];
    undoManager = [[NSUndoManager alloc] init];
    multiUndoManager = nil;
    provider = [aProvider retain];
    changes = [[NSMutableDictionary alloc] init];

    NSArray* tags = [aProvider providedTags];
    for(MZTag* tag in tags)
    {
        NSString* key = [tag identifier];
        [provider addObserver: self 
                   forKeyPath: key
                      options: NSKeyValueObservingOptionPrior|NSKeyValueObservingOptionOld
                      context: nil];
        NSString* changedKey = [key stringByAppendingString:@"Changed"];
        [self addMethodGetterForKey:key ofType:1 withObjCType:@encode(id)];
        [self addMethodGetterForKey:changedKey withRealKey:key ofType:2 withObjCType:@encode(BOOL)];
        [self addMethodSetterForKey:key ofType:3 withObjCType:@encode(id)];
        [self addMethodSetterForKey:changedKey withRealKey:key ofType:4 withObjCType:@encode(BOOL)];
    }

    return self;
}

- (void)dealloc {
    NSArray* tags = [provider providedTags];
    for(MZTag *tag in tags)
        [provider removeObserver:self forKeyPath: [tag identifier]];
    [changes release];
    [provider release];
    [undoManager release];
    [multiUndoManager release];
    [super dealloc];
}

- (id)owner
{
    return [provider owner];
}

- (NSArray *)providedTags {
    return [provider providedTags];
}

- (NSString *)loadedFileName {
    return [provider loadedFileName];
}

- (NSString *)savedFileName
{
    return [[[self loadedFileName] stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:[self fileName]];
}

- (NSString *)savedTempFileName
{
    NSString* tempFile = [self savedFileName];
    NSString* ext = [tempFile pathExtension];
    tempFile = [[tempFile stringByDeletingPathExtension] stringByAppendingString:@"MetaZ"];
    if(ext && [ext length] > 0)
        return [tempFile stringByAppendingFormat:@".%@", ext];
    return tempFile;
}


- (NSUndoManager *)undoManager {
    return undoManager;
}

-(BOOL)changed {
    /*
    int count = [changes objectForKey:MZFileNameTag] != nil ? 1 : 0;
    return [changes count] > count;
    */
    return [changes count] > 0;
}

-(id)getterValueForKey:(NSString *)aKey {
    id ret = [changes objectForKey:aKey];
    if(ret != nil) // Not Changed
    {
        if(ret == [NSNull null])
            return nil;
        return ret;
    }
    return [provider performSelector:NSSelectorFromString(aKey)];
}

-(BOOL)getterChangedForKey:(NSString *)aKey {
    return [changes objectForKey:aKey] != nil;
}

-(void)setterChanged:(BOOL)aValue forKey:(NSString *)aKey {
    id oldValue = [changes objectForKey:aKey];
    if(!aValue && oldValue!=nil)
    {
        if([changes count] == 1)
            [self willChangeValueForKey:@"changed"];
        NSString* changedKey = [aKey stringByAppendingString:@"Changed"];
        [self willChangeValueForKey:changedKey];
        [self willChangeValueForKey:aKey];
        
        [[self undoManager] registerUndoWithTarget:self selector:[MZMethodData setterSelectorForKey:aKey] object:oldValue];
        MZTag* tag = [MZTag tagForIdentifier:aKey];
        NSString* actionKey = [tag localizedName];
        if(!actionKey)
            actionKey = aKey;
        if([[self undoManager] isUndoing])
            [[self undoManager] setActionName:[@"Set " stringByAppendingString:actionKey]];
        else
            [[self undoManager] setActionName:[@"Reverted " stringByAppendingString:actionKey]];
        if(multiUndoManager)
        {
            if([multiUndoManager isUndoing])
            {
                [[multiUndoManager prepareWithInvocationTarget:self] redo];
                [multiUndoManager setActionName:[@"Set " stringByAppendingString:actionKey]];
            }
            else
            {
                [[multiUndoManager prepareWithInvocationTarget:self] undo];
                [multiUndoManager setActionName:[@"Reverted " stringByAppendingString:actionKey]];
            }
        }
        
        [changes removeObjectForKey:aKey];
        [self didChangeValueForKey:aKey];
        [self didChangeValueForKey:changedKey];
        if([changes count] == 0)
            [self didChangeValueForKey:@"changed"];
    }
    else if(aValue && oldValue==nil)
    {
        if([changes count] == 0)
            [self willChangeValueForKey:@"changed"];
        NSString* changedKey = [aKey stringByAppendingString:@"Changed"];
        [self willChangeValueForKey:changedKey];
        [self willChangeValueForKey:aKey];
        
        [[[self undoManager] prepareWithInvocationTarget:self] setterChanged:NO forKey:aKey];
        MZTag* tag = [MZTag tagForIdentifier:aKey];
        NSString* actionKey = [tag localizedName];
        if(!actionKey)
            actionKey = aKey;
        [[self undoManager] setActionName:[@"Set " stringByAppendingString:actionKey]];
        if(multiUndoManager)
        {
            if([multiUndoManager isUndoing])
                [[multiUndoManager prepareWithInvocationTarget:self] redo];
            else
                [[multiUndoManager prepareWithInvocationTarget:self] undo];
            [multiUndoManager setActionName:[@"Set " stringByAppendingString:actionKey]];
        }
        
        [self willStoreValueForKey:aKey];
        oldValue = [self performSelector:NSSelectorFromString(aKey)];

        if(oldValue == nil)
            oldValue = [NSNull null];

        [changes setObject:oldValue forKey:aKey];
        [self didStoreValueForKey:aKey];
        [self didChangeValueForKey:aKey];
        [self didChangeValueForKey:changedKey];
        if([changes count] == 1)
            [self didChangeValueForKey:@"changed"];
    }
}

-(void)setterValue:(id)aValue forKey:(NSString *)aKey {
    id oldValue = [changes objectForKey:aKey];
    NSString* changedKey = [aKey stringByAppendingString:@"Changed"];
    if(aValue == nil)
        aValue = [NSNull null];
    if(oldValue == nil) {
        [self willChangeValueForKey:changedKey];
        if([changes count] == 0)
            [self willChangeValueForKey:@"changed"];
    }
    [self willChangeValueForKey:aKey];
    if(oldValue==nil)
    {
        [[[self undoManager] prepareWithInvocationTarget:self] setterChanged:NO forKey:aKey];
        MZTag* tag = [MZTag tagForIdentifier:aKey];
        NSString* actionKey = [tag localizedName];
        if(!actionKey)
            actionKey = aKey;
        [[self undoManager] setActionName:[@"Set " stringByAppendingString:actionKey]];
        if(multiUndoManager)
        {
            if([multiUndoManager isUndoing])
                [[multiUndoManager prepareWithInvocationTarget:self] redo];
            else
                [[multiUndoManager prepareWithInvocationTarget:self] undo];
            [multiUndoManager setActionName:[@"Set " stringByAppendingString:actionKey]];
        }
    } else
    {
        [[self undoManager] registerUndoWithTarget:self selector:[MZMethodData setterSelectorForKey:aKey] object:oldValue];
        MZTag* tag = [MZTag tagForIdentifier:aKey];
        NSString* actionKey = [tag localizedName];
        if(!actionKey)
            actionKey = aKey;
        [[self undoManager] setActionName:[@"Changed " stringByAppendingString:actionKey]];
        if(multiUndoManager)
        {
            if([multiUndoManager isUndoing])
                [[multiUndoManager prepareWithInvocationTarget:self] redo];
            else
                [[multiUndoManager prepareWithInvocationTarget:self] undo];
            [multiUndoManager setActionName:[@"Changed " stringByAppendingString:actionKey]];
        }
    }
    [changes setObject:aValue forKey:aKey];
    [self didChangeValueForKey:aKey];
    if(oldValue == nil) {
        [self didChangeValueForKey:changedKey];
        if([changes count] == 1)
            [self didChangeValueForKey:@"changed"];
    }
}


-(void)handleDataForKey:(NSString *)aKey ofType:(NSUInteger)aType forInvocation:(NSInvocation *)anInvocation {
    if(aType == 1) // Get value
    {
        id ret = [self getterValueForKey:aKey];
        [anInvocation setReturnObject:ret];
        return;
    }
    if( aType == 2) // Get Changed Value
    {
        BOOL ret = [self getterChangedForKey:aKey];
        [anInvocation setReturnValue: &ret];
        return;
    }
    if(aType == 3) // Set Value
    {
        id value = [anInvocation argumentObjectAtIndex:2];
        //[anInvocation getArgument:&value atIndex:2];
        [self setterValue:value forKey:aKey];
        return;
    }
    if(aType == 4) // Set Changed value
    {
        BOOL newChanged;
        [anInvocation getArgument:&newChanged atIndex:2];
        [self setterChanged:newChanged forKey:aKey];
        return;
    }
}

- (id)valueForUndefinedKey:(NSString *)key {
    if([self respondsToSelector:NSSelectorFromString(key)])
    {
        if([key hasSuffix:@"Changed"])
        {
            NSString* valueKey = [key substringToIndex:[key length]-7];
            BOOL ret = [self getterChangedForKey:valueKey];
            return [NSNumber numberWithBool:ret];
        }
        return [self getterValueForKey:key];
    }
    return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    if([self respondsToSelector:NSSelectorFromString(key)])
    {
        if([key hasSuffix:@"Changed"])
        {
            NSString* valueKey = [key substringToIndex:[key length]-7];
            BOOL newChanged = [value boolValue];
            [self setterChanged:newChanged forKey:valueKey];
            return;
        }
        [self setterValue:value forKey:key];
        return;
    }
    [super setValue:value forUndefinedKey:key];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(object == provider)
    {
        id value = [changes objectForKey:keyPath];
        if(value == nil)
        {
            NSNumber * prior = [change objectForKey:NSKeyValueChangeNotificationIsPriorKey];
            if([prior boolValue])
                [self willChangeValueForKey:keyPath];
            else
                [self didChangeValueForKey:keyPath];
        }
    }
    //[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (BOOL)isEqual:(id)other
{
    return [super isEqual:other];
}

#pragma mark - NSCoding implementation

- (id)initWithCoder:(NSCoder *)decoder
{
    id aProvider;
    if([decoder allowsKeyedCoding])
        aProvider = [decoder decodeObjectForKey:@"provider"];
    else
        aProvider = [decoder decodeObject];
        
    self = [self initWithProvider:aProvider];
    
    if([decoder allowsKeyedCoding])
        [changes addEntriesFromDictionary:[decoder decodeObjectForKey:@"changes"]];
    else
        [changes addEntriesFromDictionary:[decoder decodeObject]];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    if([encoder allowsKeyedCoding])
    {
        [encoder encodeObject:provider forKey:@"provider"];
        [encoder encodeObject:changes forKey:@"changes"];
    }
    else
    {
        [encoder encodeObject:provider];
        [encoder encodeObject:changes];
    }
}

#pragma mark - NSCopying implementation

- (id)copyWithZone:(NSZone *)zone
{
    id ret = [[provider copyWithZone:zone] autorelease];
    MetaEdits* copy = [[MetaEdits allocWithZone:zone] initWithProvider:ret];
    [copy->changes addEntriesFromDictionary:changes];
    return copy;
}

- (id<MetaData>)queueCopy
{
    id<MetaData> ret = [[provider copy] autorelease];
    MetaEdits* copy = [[MetaEdits alloc] initWithProvider:ret];
    [copy->changes addEntriesFromDictionary:changes];
    return copy;
}

/*
- (id)valueForUndefinedKey:(NSString *)key {
    if([key hasSuffix:@"Changed"])
    {
        NSString* valueKey = [key substringToIndex:[key length]-7];
        [provider valueForKey:valueKey]; // Fails when key not supported
        id value = [changes objectForKey:valueKey];
        return [NSNumber numberWithBool:(value!=nil)];
    }
    BOOL changed = [[self valueForKey:[key stringByAppendingString:@"Changed"]] boolValue];
    if(changed)
        return [changes objectForKey:key];
    if(provider)
        return [provider valueForKey:key];
    return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    if([key hasSuffix:@"Changed"])
    {
        BOOL newChanged = [value boolValue];
        NSString* valueKey = [key substringToIndex:[key length]-7];
        id oldValue = [changes objectForKey:valueKey];
        if(!newChanged && oldValue!=nil)
            [changes removeObjectForKey:valueKey];
        else if(newChanged && oldValue==nil)
        {
            oldValue = [self valueForKey:valueKey];
            [changes setObject:oldValue forKey:valueKey];
        }
        return;
    }

    BOOL changedUpdated = [changes objectForKey:key] == nil;
    NSString* changedKey = [key stringByAppendingString:@"Changed"];
    if(value == nil)
        value = [NSNull null];
    if(changedUpdated) [self willChangeValueForKey:changedKey];
    [changes setObject:value forKey:key];
    if(changedUpdated) [self didChangeValueForKey:changedKey];
}
*/

@end
