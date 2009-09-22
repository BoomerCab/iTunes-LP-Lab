//
//  MGCollectionView.h
//  MetaZ
//
//  Created by Brian Olsen on 16/09/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MGCollectionViewItem;

@protocol MGCollectionViewTarget <NSObject>

- (NSDragOperation)dragOperationForFiles: (NSArray *)filePaths;
- (void)dragFiles:(NSArray *)filePaths toIndex:(NSUInteger)index;
- (void)dragItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)index;
- (BOOL)shouldRemoveItemsAtIndexes:(NSIndexSet *)indexes;
- (void)performDoubleClickActionForIndex:(NSUInteger)index;
- (void)onSelectionDidChange;
- (NSArray *)filePathsForIndexes:(NSIndexSet *)indexes;

@end

@interface MGCollectionView : NSView {
    IBOutlet id<MGCollectionViewTarget> target;
    NSMutableArray *items;
    BOOL needsLayout;
}

- (void)addItem:(MGCollectionViewItem *)item atIndex:(NSUInteger)index;
- (void)moveItem:(MGCollectionViewItem *)item toIndex:(NSUInteger)index;
- (void)removeObject:(MGCollectionViewItem *)item;
- (void)removeItemAtIndex:(NSUInteger)index;
- (void)removeAllItems;
- (int)numberOfItems;

- (NSIndexSet *)selectionIndexes;
//- (void)setSelectionIndexes:(NSIndexSet *)indexes;
- (void)selectIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend;
- (void)selectAll:(id)sender;
- (void)deselectAll:(id)sender;

@end

@interface MGCollectionViewItem : NSView
{
   BOOL isSelected;
   NSPoint mouseDownPos;
   int dragTargetType;
   NSMutableDictionary *cachedTextColors;
}
@end
