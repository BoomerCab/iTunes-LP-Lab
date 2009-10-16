//
//  AppController.m
//  MetaZ
//
//  Created by Brian Olsen on 06/09/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import "AppController.h"
#import "UndoTableView.h"
#import "MZMetaSearcher.h"
#import "FakeSearchResult.h"

#define MaxShortDescription 256

@interface AppController (Private)

- (void)updateSearchMenu;

@end


NSArray* MZUTIFilenameExtension(NSArray* utis)
{
    NSMutableArray* ret = [NSMutableArray arrayWithCapacity:utis.count];
    for(NSString* uti in utis)
    {
        NSDictionary* dict = (NSDictionary*)UTTypeCopyDeclaration((CFStringRef)uti);
        //[dict writeToFile:[NSString stringWithFormat:@"/Users/bro/Documents/Maven-Group/MetaZ/%@.plist", uti] atomically:NO];
        NSDictionary* tags = [dict objectForKey:(NSString*)kUTTypeTagSpecificationKey];
        NSArray* extensions = [tags objectForKey:(NSString*)kUTTagClassFilenameExtension];
        [ret addObjectsFromArray:extensions];
    }
    return ret;
}


NSResponder* findResponder(NSWindow* window) {
    NSResponder* oldResponder =  [window firstResponder];
    if([oldResponder isKindOfClass:[NSTextView class]] && [window fieldEditor:NO forObject:nil] != nil)
    {
        NSResponder* delegate = [((NSTextView*)oldResponder) delegate];
        if([delegate isKindOfClass:[NSTextField class]])
            oldResponder = delegate;
    }
    return oldResponder;
}

NSDictionary* findBinding(NSWindow* window) {
    NSResponder* oldResponder = findResponder(window);
    NSDictionary* dict = [oldResponder infoForBinding:NSValueBinding];
    if(dict == nil)
        dict = [oldResponder infoForBinding:NSDataBinding];
    return dict;
}


@implementation AppController
@synthesize window;
@synthesize tabView;
@synthesize episodeFormatter;
@synthesize seasonFormatter;
@synthesize dateFormatter;
@synthesize purchaseDateFormatter;
@synthesize filesSegmentControl;
@synthesize filesController;
@synthesize undoController;
@synthesize resizeController;
@synthesize shortDescription;
@synthesize longDescription;
@synthesize imageView;
@synthesize searchIndicator;
@synthesize searchController;
@synthesize searchField;
@synthesize remainingInShortDescription;

#pragma mark - initialization

+ (void)initialize
{
    static BOOL initialized = NO;
    /* Make sure code only gets executed once. */
    if (initialized == YES) return;
    initialized = YES;
 
    NSArray* sendTypes = [NSArray arrayWithObjects:NSTIFFPboardType, nil];
    NSArray* returnTypes = [NSArray arrayWithObjects:NSTIFFPboardType, nil];
    [NSApp registerServicesMenuSendTypes:sendTypes
                    returnTypes:returnTypes];
    
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* dictPath;
    if (dictPath = [bundle pathForResource:@"FactorySettings" ofType:@"plist"])  {
        NSDictionary* dict = [[NSDictionary alloc] initWithContentsOfFile:dictPath];
        [[NSUserDefaults standardUserDefaults] registerDefaults:dict];
        [dict release];
    }
}
- (id)init
{
    self = [super init];
    if(self)
    {
        remainingInShortDescription = MaxShortDescription;
        activeProfile = [[SearchProfile unknownTypeProfile] retain];
    }
    return self;
}

-(void)awakeFromNib
{
    [[MZPluginController sharedInstance] setDelegate:self];
    [[MZMetaSearcher sharedSearcher] setFakeResult:[FakeSearchResult resultWithController:filesController]];
    [self updateSearchMenu];

    undoManager = [[NSUndoManager alloc] init];

    [seasonFormatter setNilSymbol:@""];
    [episodeFormatter setNilSymbol:@""];
    [dateFormatter setLenient:YES];
    [purchaseDateFormatter setLenient:YES];
    [dateFormatter setDefaultDate:nil];
    [purchaseDateFormatter setDefaultDate:nil];

    [filesController addObserver:self
                      forKeyPath:@"selection.title"
                         options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial
                         context:nil];
    [filesController addObserver:self
                      forKeyPath:@"selection.pure.videoType"
                         options:0
                         context:nil];
    [filesController addObserver:self
                      forKeyPath:@"selection.shortDescription"
                         options:0
                         context:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(finishedSearch:)
               name:MZSearchFinishedNotification
             object:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [filesController removeObserver:self forKeyPath:@"selection.title"];
    [filesController removeObserver:self forKeyPath:@"selection.pure.videoType"];
    [window release];
    [tabView release];
    [episodeFormatter release];
    [seasonFormatter release];
    [dateFormatter release];
    [purchaseDateFormatter release];
    [filesSegmentControl release];
    [filesController release];
    [resizeController release];
    [undoController release];
    [shortDescription release];
    [longDescription release];
    [undoManager release];
    [imageView release];
    [imageEditController release];
    [prefController release];
    [searchIndicator release];
    [searchController release];
    [searchField release];
    [activeProfile release];
    [super dealloc];
}
#pragma mark - private

- (void)updateSearchMenu
{
    SearchProfile* profile;
    
    id videoType = [filesController protectedValueForKeyPath:@"selection.pure.videoType"];
    MZVideoType vt;
    MZTag* tag = [MZTag tagForIdentifier:MZVideoTypeTagIdent];
    [tag convertObject:videoType toValue:&vt];
    switch (vt) {
        case MZMovieVideoType:
            profile = [SearchProfile movieProfile];
            break;
        case MZTVShowVideoType:
            profile = [SearchProfile tvShowProfile];
            break;
        default:
            profile = [SearchProfile unknownTypeProfile];
            break;
    }
    /*
    if([activeProfile.identifier isEqual:profile.identifier])
        return;
    */
    [activeProfile release];
    activeProfile = [profile retain];
    [activeProfile setCheckObject:filesController withPrefix:@"selection.pure."];

    NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Search menu"];
    NSInteger i = 0;
    for(NSString* tagId in [profile tags])
    {
        if(![tagId isEqual:MZVideoTypeTagIdent])
        {
            MZTag* tag = [MZTag tagForIdentifier:tagId];
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:[tag localizedName] action:NULL keyEquivalent:@""];
            [item setTarget:profile];
            [item setAction:@selector(switchItem:)];
            [item setTag:i];
            [item setState:NSOnState];
            [menu addItem:item];
            [item release];
        }
        i++;
    }
    id searchCell = [searchField cell];
    [searchCell setSearchMenuTemplate:menu];
    [menu release];
        
    NSString* prefix = @"selection.pure.";
    id mainValue = @"";
    if([profile mainTag])
    {
        mainValue = [filesController protectedValueForKeyPath:
            [prefix stringByAppendingString:[profile mainTag]]];
    
        if(mainValue == nil || mainValue == [NSNull null] || mainValue == NSMultipleValuesMarker ||
            mainValue == NSNoSelectionMarker || mainValue == NSNotApplicableMarker)
        {
            mainValue = @"";
        }
    }
    [searchField setStringValue:mainValue];
    [[MZMetaSearcher sharedSearcher] clearResults];
}

#pragma mark - as observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqual:@"selection.title"] && object == filesController)
    {
        id value = [object valueForKeyPath:keyPath];
        if(value == NSMultipleValuesMarker ||
           value == NSNotApplicableMarker ||
           value == NSNoSelectionMarker ||
           value == [NSNull null] ||
           value == nil)
        {
            [window setTitle:@"MetaZ"];
        }
        else
        {
            [window setTitle:[NSString stringWithFormat:@"MetaZ - %@", value]];
        }

        if(value == NSNoSelectionMarker)
            [filesSegmentControl setEnabled:NO forSegment:1];
        else
            [filesSegmentControl setEnabled:YES forSegment:1];
    }
    if([keyPath isEqual:@"selection.pure.videoType"] && object == filesController)
    {
        [self updateSearchMenu];
    }
    if([keyPath isEqual:@"selection.shortDescription"] && object == filesController)
    {
        NSInteger newRemain = 0;
        id length = [filesController valueForKeyPath:@"selection.shortDescription.length"];
        if([length respondsToSelector:@selector(integerValue)])
            newRemain = [length integerValue];
        [self willChangeValueForKey:@"remainingInShortDescription"];
        remainingInShortDescription = MaxShortDescription-newRemain;
        [self didChangeValueForKey:@"remainingInShortDescription"];
    }
}


#pragma mark - as MZPluginControllerDelegate

- (id<MetaData>)pluginController:(MZPluginController *)controller
        extraMetaDataForProvider:(id<MZDataProvider>)provider
                          loaded:(MetaLoaded*)loaded
{
    return [[[SearchMeta alloc] initWithProvider:loaded controller:searchController] autorelease];
}


#pragma mark - actions

- (IBAction)showAdvancedTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"advanced"];    
}

- (IBAction)showChapterTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"chapters"];    
}

- (IBAction)showInfoTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"info"];
}

- (IBAction)showSortTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"sorting"];
}

- (IBAction)showVideoTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"video"];    
}

- (IBAction)startSearch:(id)sender;
{
    NSString* term = [sender stringValue];
    NSMutableDictionary* dict = [activeProfile searchTerms];
    [dict setObject:term forKey:[activeProfile mainTag]];
    [searchIndicator startAnimation:sender];
    [searchController setSortDescriptors:nil];
    [[MZMetaSearcher sharedSearcher] startSearchWithData:dict];
}

- (IBAction)segmentClicked:(id)sender {
    int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];

    if(clickedSegmentTag == 0)
        [self openDocument:sender];
    else
        [filesController remove:sender];
}

- (IBAction)selectNextFile:(id)sender {
    NSResponder* oldResponder = findResponder(window);
    if([filesController commitEditing])
    {
        NSResponder* currentResponder =  findResponder(window);
        if(oldResponder != currentResponder)
            [window makeFirstResponder:oldResponder];
    }
    [filesController selectNext:sender];
}

- (IBAction)selectPreviousFile:(id)sender {
    NSResponder* oldResponder = findResponder(window);
    if([filesController commitEditing])
    {
        NSResponder* currentResponder =  findResponder(window);
        if(oldResponder != currentResponder)
            [window makeFirstResponder:oldResponder];
    }
    [filesController selectPrevious:sender];
}

- (IBAction)revertChanges:(id)sender {
    NSDictionary* dict = findBinding(window);
    if(dict == nil)
    {
        NSLog(@"Could not find binding for revert.");
        return;
    }
    id observed = [dict objectForKey:NSObservedObjectKey];
    NSString* keyPath = [dict objectForKey:NSObservedKeyPathKey];
    [observed setValue:[NSNumber numberWithBool:NO] forKeyPath:[keyPath stringByAppendingString:@"Changed"]];
}

- (IBAction)showImageEditor:(id)sender
{
    if(!imageEditController)
        imageEditController = [[ImageWindowController alloc] initWithImageView:imageView];
    [[NSNotificationCenter defaultCenter] 
                addObserver:self 
                 selector:@selector(imageEditorDidClose:)
                     name:NSWindowWillCloseNotification
                   object:[imageEditController window]];
    [imageEditController showWindow:self];
}

- (IBAction)showPreferences:(id)sender
{
    if(!prefController)
    {
        prefController = [[PreferencesWindowController alloc] init];
        [[NSNotificationCenter defaultCenter] 
                addObserver:self 
                 selector:@selector(preferencesDidClose:)
                     name:NSWindowWillCloseNotification
                   object:[prefController window]];
    }
    [prefController showWindow:self];
}

- (IBAction)openDocument:(id)sender {
    NSArray *fileTypes = [[MZMetaLoader sharedLoader] types];

    NSArray* utis = MZUTIFilenameExtension(fileTypes);
    for(NSString* uti in utis)
    {
        NSLog(@"Found UTI %@", uti);
    }
    
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory: nil
                              file: nil
                             types: fileTypes
                    modalForWindow: window
                     modalDelegate: self
                    didEndSelector: @selector(openPanelDidEnd:returnCode:contextInfo:) 
                       contextInfo: nil];
}

#pragma mark - user interface validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
    SEL action = [anItem action];
    if(action == @selector(selectNextFile:))
        return [filesController canSelectNext];
    if(action == @selector(selectPreviousFile:))
        return [filesController canSelectPrevious];
    if(action == @selector(revertChanges:))
    {
        NSDictionary* dict = findBinding(window);
        if([[filesController selectedObjects] count] >= 1 && dict != nil)
        {
            id observed = [dict objectForKey:NSObservedObjectKey];
            NSString* keyPath = [dict objectForKey:NSObservedKeyPathKey];
            BOOL changed = [[observed valueForKeyPath:[keyPath stringByAppendingString:@"Changed"]] boolValue];
            return changed;
        }
        else 
            return NO;
    }
    return YES;
}

#pragma mark - callbacks

- (void)finishedSearch:(NSNotification *)note
{
    NSLog(@"Finished search");
    [searchIndicator stopAnimation:self];
}

- (void)imageEditorDidClose:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] 
           removeObserver:self 
                     name:NSWindowWillCloseNotification
                   object:[note object]];
    [imageEditController release];
    imageEditController = nil;
}

- (void)preferencesDidClose:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] 
           removeObserver:self 
                     name:NSWindowWillCloseNotification
                   object:[note object]];
    [prefController release];
    prefController = nil;
}

- (void)openPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo {
    if (returnCode == NSOKButton)
        [[MZMetaLoader sharedLoader] loadFromFiles: [oPanel filenames]];
}

#pragma mark - as window delegate

- (NSSize)windowWillResize:(NSWindow *)aWindow toSize:(NSSize)proposedFrameSize {
    return [resizeController windowWillResize:aWindow toSize:proposedFrameSize];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)aWindow {
    NSResponder* responder = [aWindow firstResponder];
    if(responder == shortDescription || 
        responder == longDescription ||
        [responder isKindOfClass:[UndoTableView class]])
    {
        NSUndoManager * man = [undoController undoManager];
        if(man != nil)
            return man;
    }
    return undoManager;
}

#pragma mark - as text delegate
- (void)textDidChange:(NSNotification *)aNotification
{
    [self willChangeValueForKey:@"remainingInShortDescription"];
    remainingInShortDescription = MaxShortDescription-[[shortDescription string] length];
    [self didChangeValueForKey:@"remainingInShortDescription"];
}

#pragma mark - as application delegate

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    return [[MZMetaLoader sharedLoader] loadFromFile:filename];
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    if([[MZMetaLoader sharedLoader] loadFromFiles: filenames])
        [sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
    else
        [sender replyToOpenOrPrint:NSApplicationDelegateReplyCancel];
}


@end
