/*	
	Copyright (c) 2006-2009 Dancing Tortoise Software
 
	Permission is hereby granted, free of charge, to any person 
	obtaining a copy of this software and associated documentation
	files (the "Software"), to deal in the Software without 
	restriction, including without limitation the rights to use, 
	copy, modify, merge, publish, distribute, sublicense, and/or 
	sell copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following 
	conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
	OTHER DEALINGS IN THE SOFTWARE.
	
	Simple Comic
	SimpleComicAppDelegate.m
*/


#import "SimpleComicAppDelegate.h"
#import <XADMaster/XADArchive.h>
#import "TSSTSessionWindowController.h"
#import "TSSTSortDescriptor.h"
#import "TSSTManagedGroup.h"
#import "TSSTManagedSession.h"
#import "TSSTCustomValueTransformers.h"
#import "DTPreferencesController.h"
#import "Simple_Comic-Swift.h"
#import "TSSTManagedSession+CoreDataProperties.h"


@interface SimpleComicAppDelegate () <XADArchiveDelegate>

@end

NSString *const TSSTPageOrder =         @"pageOrder";
NSString *const TSSTPageZoomRate =      @"pageZoomRate";
NSString *const TSSTFullscreen =        @"fullscreen";
NSString *const TSSTSavedSelection =    @"savedSelection";
NSString *const TSSTThumbnailSize =     @"thumbnailSize";
NSString *const TSSTTwoPageSpread =     @"twoPageSpread";
NSString *const TSSTPageScaleOptions =  @"scaleOptions";
NSString *const TSSTIgnoreDonation =    @"ignoreDonation";
NSString *const TSSTScrollPosition =    @"scrollPosition";
NSString *const TSSTConstrainScale =    @"constrainScale";
NSString *const TSSTZoomLevel =         @"zoomLevel";
NSString *const TSSTViewRotation =      @"rotation";
NSString *const TSSTBackgroundColor =   @"pageBackgroundColor";
NSString *const TSSTSessionRestore =    @"sessionRestore";
NSString *const TSSTScrollersVisible =  @"scrollersVisible";
NSString *const TSSTAutoPageTurn =      @"autoPageTurn";
NSString *const TSSTWindowAutoResize =  @"windowAutoResize";
NSString *const TSSTLoupeDiameter =     @"loupeDiameter";
NSString *const TSSTLoupePower =		   @"loupePower";
NSString *const TSSTStatusbarVisible =  @"statusBarVisisble";
NSString *const TSSTLonelyFirstPage =   @"lonelyFirstPage";
NSString *const TSSTNestedArchives =	   @"nestedArchives";
NSString *const TSSTUpdateSelection =   @"updateSelection";
NSString *const SSDEnableSwipe = @"enableSwipe";

NSString *const TSSTSessionEndNotification = @"sessionEnd";


#pragma mark - String Encoding Functions



static NSArray<NSNumber*> * allAvailableStringEncodings(void)
{
	const CFStringEncoding encodings[] = {
        kCFStringEncodingMacRoman,
        kCFStringEncodingISOLatin1,
        kCFStringEncodingASCII,
        101,
        kCFStringEncodingWindowsLatin2,
        kCFStringEncodingMacCentralEurRoman,
        kCFStringEncodingDOSLatin2,
        101,
        kCFStringEncodingDOSJapanese,
        kCFStringEncodingMacJapanese,
        kCFStringEncodingShiftJIS_X0213_00,
        kCFStringEncodingISO_2022_JP,
        kCFStringEncodingEUC_JP,
        101,
        kCFStringEncodingGBK_95,
        kCFStringEncodingGB_18030_2000,
        101,
        kCFStringEncodingDOSChineseSimplif,
        kCFStringEncodingVISCII,
        kCFStringEncodingHZ_GB_2312,
        kCFStringEncodingEUC_CN,
        kCFStringEncodingGB_2312_80,
        101,
        kCFStringEncodingDOSChineseTrad,
        kCFStringEncodingBig5_HKSCS_1999,
        kCFStringEncodingBig5,
        101,
        kCFStringEncodingDOSKorean,
        kCFStringEncodingEUC_KR,
        kCFStringEncodingKSC_5601_87,
        kCFStringEncodingWindowsKoreanJohab,
        101,
        kCFStringEncodingWindowsCyrillic,
        kCFStringEncodingDOSCyrillic,
        kCFStringEncodingDOSRussian,
        kCFStringEncodingKOI8_R,
        kCFStringEncodingKOI8_U,
        101,
        kCFStringEncodingWindowsArabic,
        kCFStringEncodingISOLatinArabic,
        101,
        kCFStringEncodingISOLatinHebrew,
        kCFStringEncodingWindowsHebrew,
        101,
        kCFStringEncodingISOLatinGreek,
        kCFStringEncodingWindowsGreek,
        101,
        kCFStringEncodingISOLatin5,
        kCFStringEncodingWindowsLatin5,
        101,
        kCFStringEncodingISOLatinThai,
        kCFStringEncodingDOSThai,
        101,
        kCFStringEncodingWindowsVietnamese,
        kCFStringEncodingDOSPortuguese,
        kCFStringEncodingWindowsBalticRim,
        UINT_MAX
    };
    
    NSMutableArray * codeNumbers = [NSMutableArray arrayWithCapacity:sizeof(encodings) / sizeof(encodings[0]) - 1]; //We don't store the UINT_MAX value in the NSArray
    size_t counter = 0;
    NSStringEncoding encoding;
    while (encodings[counter] != UINT_MAX) {
        if (encodings[counter] != 101) {
            encoding = CFStringConvertEncodingToNSStringEncoding(encodings[counter]);
        } else {
            encoding = 101;
        }
		
        [codeNumbers addObject: @(encoding)];
        ++counter;
    }
    
    return codeNumbers;
}



@implementation SimpleComicAppDelegate
{
	/*  This panel appears when the text encoding auto-detection fails */
	NSData					   * encodingTestData;
	NSInteger					 encodingSelection;
	
	/*  Core Data stuff. */
	NSManagedObjectModel		 * managedObjectModel;
	NSManagedObjectContext		 * managedObjectContext;
	NSPersistentStoreCoordinator * persistentStoreCoordinator;
	
	/* Auto-save timer */
	NSTimer * autoSave;
	
	/*  Window controller for preferences. */
	DTPreferencesController      * preferences;
	
	/*  This is the array that maintains all of the session window managers. */
	NSMutableArray<TSSTSessionWindowController*> * sessions;
	
	/*	Vars to delay the loading of files from an app launch until the core data store
	 has finished initializing */
	BOOL      launchInProgress;
	BOOL	  optionHeldAtlaunch;
	NSArray<NSString*>	*launchFiles;
}


@synthesize encodingSelection;
@synthesize passwordPanel;
@synthesize passwordField;
@synthesize encodingPanel;
@synthesize encodingTestField;
@synthesize encodingPopup;
@synthesize donationPanel;
@synthesize launchPanel;


/*  Convenience method for adding metadata to the core data store.
    Used by Simple Comic to keep track of store versioning. */
+ (void)setMetadata:(NSString *)value forKey:(NSString *)key onStoreWithURL:(NSURL *)url managedBy:(NSPersistentStoreCoordinator *)coordinator
{
    NSPersistentStore * store = [coordinator persistentStoreForURL: url];
    NSMutableDictionary * metadata = [[coordinator metadataForPersistentStore: store] mutableCopy];
    [metadata setValue: value forKey: key];
    [coordinator setMetadata: metadata forPersistentStore: store];
}



/*  Sets up the user defaults and arrays of compatible file types. */
+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSDictionary* standardDefaults =
		@{
		  TSSTPageOrder: @NO,
		  TSSTPageZoomRate: @0.1f,
		  TSSTPageScaleOptions: @1,
		  TSSTThumbnailSize: @100,
		  TSSTTwoPageSpread: @YES,
		  TSSTIgnoreDonation: @NO,
		  TSSTConstrainScale: @YES,
		  TSSTScrollersVisible: @YES,
		  TSSTSessionRestore: @YES,
		  TSSTAutoPageTurn: @YES,
		  TSSTBackgroundColor: [NSArchiver archivedDataWithRootObject: [NSColor whiteColor]],
		  TSSTWindowAutoResize: @YES,
		  TSSTLoupeDiameter: @500,
		  TSSTLoupePower: @2.0f,
		  TSSTStatusbarVisible: @YES,
		  TSSTLonelyFirstPage: @YES,
		  TSSTNestedArchives: @YES,
		  TSSTUpdateSelection: @0,
		  SSDEnableSwipe: @NO,
		  };
		
		NSUserDefaultsController * sharedDefaultsController = [NSUserDefaultsController sharedUserDefaultsController];
		[sharedDefaultsController setInitialValues: standardDefaults];
		NSUserDefaults * defaults = [sharedDefaultsController defaults];
		[defaults registerDefaults: standardDefaults];
		
		id transformer = [TSSTLastPathComponent new];
		[NSValueTransformer setValueTransformer: transformer forName: @"TSSTLastPathComponent"];
	});
}


- (void) dealloc
{
	[[NSUserDefaults standardUserDefaults] removeObserver: self forKeyPath: TSSTUpdateSelection];
	[[NSUserDefaults standardUserDefaults] removeObserver: self forKeyPath: TSSTSessionRestore];

}


#pragma mark - Application Delegate Methods


/*	Stores any files that were opened on launch till applicationDidFinishLaunching:
	is called. */
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	autoSave = nil;
	launchFiles = nil;
	launchInProgress = YES;
	preferences = nil;
	optionHeldAtlaunch = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endSession:) name: TSSTSessionEndNotification object: nil];
	[[NSUserDefaults standardUserDefaults] addObserver: self forKeyPath: TSSTUpdateSelection options: 0 context: nil];
	[[NSUserDefaults standardUserDefaults] addObserver: self forKeyPath: TSSTSessionRestore options: 0 context: nil];
}



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
	[self generateEncodingMenu];
	
	/* Starts the auto save timer */
	if([userDefaults boolForKey: TSSTSessionRestore])
	{
		autoSave = [NSTimer scheduledTimerWithTimeInterval: 30.0 target: self selector: @selector(saveContext) userInfo: nil repeats: YES];
	}
    sessions = [NSMutableArray new];
	[self sessionRelaunch];
	launchInProgress = NO;

	if (launchFiles) {
		TSSTManagedSession * session;
//		if (optionHeldAtlaunch)
//		{
//			NSMutableArray * looseImages = [NSMutableArray array];
//			for(NSString * path in launchFiles)
//			{
//				if([[TSSTManagedArchive archiveExtensions] containsObject: [[path pathExtension] lowercaseString]])
//				{
//					session = [self newSessionWithFiles: [NSArray arrayWithObject: path]];
//					[self windowForSession: session];
//				}
//				else {
//					[looseImages addObject: path];
//				}
//				
//				if ([looseImages count]> 0) {
//					session = [self newSessionWithFiles: looseImages];
//					[self windowForSession: session];
//				}
//				
//			}
//		}
//		else
//		{
			session = [self newSessionWithFiles: launchFiles];
			[self windowForSession: session];
//		}
		
		launchFiles = nil;
	}
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{	
	NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
	
	if(![userDefaults boolForKey: TSSTSessionRestore])
	{
		/* Goes through and deletes all active sessions if the user has auto save turned off */
		for(TSSTSessionWindowController * sessionWindow in sessions)
		{
			[[sessionWindow window] performClose: self];
		}
	}
	
    NSApplicationTerminateReply reply = NSTerminateNow;
	/* TODO: some day I really need to add the fallback error handling */
    if(![self saveContext])
    {
        // Error handling wasn't implemented. Fall back to displaying a "quit anyway" panel.
		NSAlert *alert = [NSAlert new];
		alert.messageText = @"Quit";
		alert.informativeText = @"Could not save changes while quitting. Quit anyway?";
		[alert addButtonWithTitle:@"Quit anyway"];
		[alert addButtonWithTitle:@"Cancel"];
		NSInteger alertReturn = [alert runModal];
        if (alertReturn == NSAlertSecondButtonReturn)
        {
            reply = NSTerminateCancel;	
        }
    }
	
	return reply;
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}


/* Used to watch and react to pref changes */
- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object 
						change:(NSDictionary *)change 
					   context:(void *)context
{
	NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];

	if([keyPath isEqualToString: TSSTSessionRestore])
	{
		[autoSave invalidate];
		autoSave = nil;
		if([userDefaults boolForKey: TSSTSessionRestore])
		{
			autoSave = [NSTimer scheduledTimerWithTimeInterval: 30.0 target: self selector: @selector(saveContext) userInfo: nil repeats: YES];
		}
	}
}



- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{	
	if(!launchInProgress)
	{
		TSSTManagedSession * session;
		session = [self newSessionWithFiles: filenames];
		[self windowForSession: session];
	}
	else
	{
		launchFiles = filenames;
	}
}



//- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
//{	
//	if(!launchInProgress)
//	{
//		TSSTManagedSession * session;
//		session = [self newSessionWithFiles: [NSArray arrayWithObject: filename]];
//		[self windowForSession: session];
//		return YES;
//
//	}
//	
//	return NO;
//
////	else
////	{
////		launchFiles = [filenames retain];
////	}
//}


//- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
//{	
//	BOOL option = (GetCurrentKeyModifiers()&(optionKey) != 0);
//	if(!launchInProgress)
//	{
//		TSSTManagedSession * session;
//		if (option)
//		{
//			NSMutableArray * looseImages = [NSMutableArray array];
//			for(NSString * path in filenames)
//			{
//				if([[TSSTManagedArchive archiveExtensions] containsObject: [[path pathExtension] lowercaseString]])
//				{
//					session = [self newSessionWithFiles: [NSArray arrayWithObject: path]];
//					[self windowForSession: session];
//				}
//				else
//				{
//					[looseImages addObject: path];
//				}
//				
//				if ([looseImages count]> 0) {
//					session = [self newSessionWithFiles: looseImages];
//					[self windowForSession: session];
//				}
//				
//			}
//		}
//		else
//		{
//			session = [self newSessionWithFiles: filenames];
//			[self windowForSession: session];
//		}
//	}
//	else
//	{
//		launchFiles = [filenames retain];
//		optionHeldAtlaunch = option;
//	}
//}



#pragma mark - Core Data



- (NSManagedObjectModel *)managedObjectModel
{
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
    managedObjectModel = [NSManagedObjectModel mergedModelFromBundles: nil];    
    return managedObjectModel;
}


/*	Returns the persistent store coordinator for the application.  This 
	implementation will create and return a coordinator, having added the 
	store for the application to it.  (The folder for the store is created, 
	if necessary.) */
- (NSPersistentStoreCoordinator *) persistentStoreCoordinator
{	
    if (persistentStoreCoordinator != nil)
	{
        return persistentStoreCoordinator;
    }
	
    NSURL * url;
    NSError * error = nil;
    
	NSFileManager * fileManager = [NSFileManager defaultManager];
    NSString * applicationSupportFolder = [self applicationSupportFolder];
    if (![fileManager fileExistsAtPath: applicationSupportFolder isDirectory: NULL] )
	{
		if(![fileManager createDirectoryAtPath: applicationSupportFolder withIntermediateDirectories: YES attributes: nil error: &error])
		{
			NSLog(@"%@",[error localizedDescription]);
		}
    }
	
	NSDictionary * storeOptions = @{NSMigratePersistentStoresAutomaticallyOption: @YES};
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: @"SimpleComic.sql"]];
	
	error = nil;
	NSDictionary * storeInfo = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType: NSSQLiteStoreType URL: url error: &error];
	if(error)
	{
		NSLog(@"%@",[error localizedDescription]);
	}    

	if(![[storeInfo valueForKey: @"viewVersion"] isEqualToString: @"Version 1708"])
	{
		if(![fileManager removeItemAtURL: url error: &error])
		{
			NSLog(@"%@",[error localizedDescription]);
		}
	}
	
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	
    if (![persistentStoreCoordinator addPersistentStoreWithType: NSSQLiteStoreType configuration: nil URL: url options: storeOptions error: &error])
	{
        [[NSApplication sharedApplication] presentError: error];
    }    
	
	[SimpleComicAppDelegate setMetadata: @"Version 1708" forKey: @"viewVersion" onStoreWithURL: url managedBy: persistentStoreCoordinator];

    return persistentStoreCoordinator;
}


- (NSManagedObjectContext *) managedObjectContext
{
    if (managedObjectContext != nil)
	{
        return managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
	{
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return managedObjectContext;
} 



/**  Method creates an application support directory for Simpl Comic if one
    is does not already exist.
    @return The absolute path to Simple Comic's application support directory 
	as a string.  */
- (NSString *)applicationSupportFolder
{
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString * basePath = ([paths count] > 0) ? paths[0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent: @"Simple Comic"];
}

- (BOOL)saveContext
{
    TSSTSessionWindowController * controller;
    for (controller in sessions)
    {
        [controller updateSessionObject];
    }
    
    NSError * error;
    NSManagedObjectContext * context = [self managedObjectContext];
	[context lock];
    BOOL saved = NO;
    if (context != nil)
	{
        if ([context commitEditing])
		{
            if (![context save: &error])
			{
				// This default error handling implementation should be changed to make sure the error presented includes application specific error recovery. 
				// For now, simply display 2 panels.
				[[NSApplication sharedApplication] presentError: error];
            }
            else 
            {
                saved = YES;
            }
        }
    }
	
	[context unlock];
    return saved;
}

#pragma mark -
#pragma mark Session Managment

- (void)windowForSession:(TSSTManagedSession *)settings
{
	NSArray * existingSessions = [sessions valueForKey: @"session"];
    if([settings.images count] > 0 && ![existingSessions containsObject: settings])
    {
        TSSTSessionWindowController * comicWindow = [[TSSTSessionWindowController alloc] initWithSession: settings];
        [sessions addObject: comicWindow];
        [comicWindow showWindow: self];
    }
}

- (void)endSession:(NSNotification *)notification
{
	TSSTSessionWindowController * controller = [notification object];
	TSSTManagedSession * sessionToRemove = [controller session];
	[sessions removeObject: controller];
	[[self managedObjectContext] deleteObject: sessionToRemove];
}

- (void)sessionRelaunch
{
    TSSTManagedSession * session;
	NSFetchRequest * sessionRequest = [NSFetchRequest new];
	[sessionRequest setEntity: [NSEntityDescription entityForName: @"Session" inManagedObjectContext: [self managedObjectContext]]];
	NSError * fetchError;
	NSArray * managedSessions = [[self managedObjectContext] executeFetchRequest: sessionRequest error: &fetchError];
	for(session in managedSessions)
	{
		if([session.groups count] <= 0)
		{
			[[self managedObjectContext] deleteObject: session];
		}
		else
		{
			
			[self windowForSession: session];
		}
	}
}

- (TSSTManagedSession *)newSessionWithFiles:(NSArray<NSString*> *)files
{
    TSSTManagedSession * sessionDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Session" inManagedObjectContext: [self managedObjectContext]];
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	sessionDescription.scaleOptions = [defaults valueForKey: TSSTPageScaleOptions];
	sessionDescription.pageOrder = [defaults valueForKey: TSSTPageOrder];
	sessionDescription.twoPageSpread = [defaults valueForKey: TSSTTwoPageSpread];
	
    [self addFiles: files toSession: sessionDescription];

	return sessionDescription;
}


- (void)addFiles:(NSArray<NSString*> *)paths toSession:(TSSTManagedSession *)session
{	
//	[[self managedObjectContext] retain];
//	[[self managedObjectContext] lock];
	NSFileManager * fileManager = [NSFileManager defaultManager];
	BOOL isDirectory;
    TSSTPage * fileDescription;
	NSMutableSet<TSSTPage *> * pageSet = [session.images mutableCopy];
	for (NSString *path in paths)
	{
		fileDescription = nil;
		NSString *fileExtension = [[path pathExtension] lowercaseString];
		BOOL exists = [fileManager fileExistsAtPath: path isDirectory: &isDirectory];
		if(exists && ![[[path lastPathComponent] substringToIndex: 1] isEqualToString: @"."])
		{
			if(isDirectory)
			{
				fileDescription = [NSEntityDescription insertNewObjectForEntityForName: @"ImageGroup" inManagedObjectContext: [self managedObjectContext]];
				[fileDescription setValue: path forKey: @"path"];
				[fileDescription setValue: [path lastPathComponent] forKey: @"name"];
				[(TSSTManagedGroup *)fileDescription nestedFolderContents];
			}
			else if([[TSSTManagedArchive archiveExtensions] containsObject: fileExtension])
			{
				fileDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Archive" inManagedObjectContext: [self managedObjectContext]];
				[fileDescription setValue: path forKey: @"path"];
				[fileDescription setValue: [path lastPathComponent] forKey: @"name"];
				[(TSSTManagedArchive *)fileDescription nestedArchiveContents];
			}
			else if([fileExtension compare:@"pdf" options:NSCaseInsensitiveSearch] == NSOrderedSame)
			{
				fileDescription = [NSEntityDescription insertNewObjectForEntityForName: @"PDF" inManagedObjectContext: [self managedObjectContext]];
				[fileDescription setValue: path forKey: @"path"];
				[fileDescription setValue: [path lastPathComponent] forKey: @"name"];
				[(TSSTManagedPDF *)fileDescription pdfContents];
			}
			else if([[TSSTPage imageExtensions] containsObject: fileExtension] || [[TSSTPage textExtensions] containsObject: fileExtension])
			{
				fileDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Image" inManagedObjectContext: [self managedObjectContext]];
				[fileDescription setValue: path forKey: @"imagePath"];
			}
			else if([fileExtension compare:@"savedsearch" options:NSCaseInsensitiveSearch] == NSOrderedSame)
			{
                
				//fileDescription = [NSEntityDescription insertNewObjectForEntityForName: @"SavedSearch" inManagedObjectContext: [self managedObjectContext]];
                fileDescription = [NSEntityDescription insertNewObjectForEntityForName: @"SmartFolder" inManagedObjectContext: [self managedObjectContext]];
				[fileDescription setValue: path forKey: @"path"];
				[fileDescription setValue: [path lastPathComponent] forKey: @"name"];
				[(ManagedSmartFolder*)fileDescription smartFolderContents];
            }
            
			if([fileDescription isKindOfClass:[TSSTManagedGroup class]])
			{
				[pageSet unionSet: [(TSSTManagedGroup *)fileDescription nestedImages]];
				[fileDescription setValue: session forKey: @"session"];
			}
			else if ([fileDescription isKindOfClass:[TSSTPage class]])
			{
				[pageSet addObject: fileDescription];
            }
            
			
			if(fileDescription)
			{
				[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: [NSURL fileURLWithPath: path]];
			}
		}
	}
	
	[session setValue: pageSet forKey: @"images"];
//	[[self managedObjectContext] unlock];
//	[[self managedObjectContext] release];
}

#pragma mark -
#pragma mark Actions

// Launches open modal.
- (IBAction)addPages:(id)sender
{
	// Creates a new modal.
	NSOpenPanel * addPagesModal = [NSOpenPanel openPanel];
	[addPagesModal setAllowsMultipleSelection: YES];
    [addPagesModal setCanChooseDirectories: YES];
	
	NSMutableArray * allAllowedFilesExtensions = [[TSSTManagedArchive archiveExtensions] mutableCopy];
	[allAllowedFilesExtensions addObjectsFromArray: [TSSTPage imageExtensions]];
#pragma TODO make a savedSearch constant?
    [allAllowedFilesExtensions addObject: @"savedSearch"];
    [addPagesModal setAllowedFileTypes:allAllowedFilesExtensions];

	if([addPagesModal runModal] !=  NSModalResponseCancel)
	{
		NSArray<NSURL*> *fileURLs = [addPagesModal URLs];
        NSMutableArray<NSString*> *filePaths = [[NSMutableArray alloc] initWithCapacity:fileURLs.count];
		NSString * filePath;

        for (NSURL *fileURL in fileURLs) {
            filePath = [fileURL path];
            [filePaths addObject:filePath];
        }
        
		TSSTManagedSession * session = [self newSessionWithFiles: filePaths];
		[self windowForSession: session];
	}
}

/*  Kills the password and encoding modals if the OK button was  clicked. */
- (IBAction)modalOK:(id)sender
{
    [NSApp stopModalWithCode: NSModalResponseOK];
}

/*  Kills the password and encoding modals if the Cancel button was clicked. */
- (IBAction)modalCancel:(id)sender
{
    [NSApp stopModalWithCode: NSModalResponseCancel];
}

- (IBAction)openPreferences:(id)sender
{
    if(!preferences)
    {
        preferences = [DTPreferencesController new];
	}
    [preferences showWindow: self];
}

#pragma mark - Archive Encoding Handling

- (IBAction)testEncodingMenu:(id)sender
{
	[NSApp runModalForWindow: encodingPanel];
}

- (void)generateEncodingMenu
{
	NSMenu * encodingMenu = [encodingPopup menu];
    NSArray * allEncodings = allAvailableStringEncodings();
	self.encodingSelection = 0;
	[encodingMenu setAutoenablesItems: NO];
	for (NSMenuItem * encodingMenuItem in [encodingMenu itemArray]) {
		[encodingMenu removeItem: encodingMenuItem];
	}
	
    for (NSNumber *encodingIdent in allEncodings) {
		NSStringEncoding stringEncoding = [encodingIdent unsignedIntegerValue];
        NSString * encodingName = [NSString localizedNameOfStringEncoding: stringEncoding];
        if (stringEncoding == 101) {
            [encodingMenu addItem: [NSMenuItem separatorItem]];
        } else if (encodingName && ![encodingName isEqualToString: @""]) {
            NSMenuItem * encodingMenuItem = [[NSMenuItem alloc] initWithTitle: encodingName action: nil keyEquivalent: @""];
            [encodingMenuItem setRepresentedObject: encodingIdent];
            [encodingMenu addItem: encodingMenuItem];
        }
    }
    [encodingPopup bind: @"selectedIndex" toObject: self withKeyPath: @"encodingSelection" options: nil];
}

- (void)updateEncodingMenuTestedAgainst:(NSData *)data
{
    for (NSMenuItem * encodingMenuItem in [[encodingPopup menu] itemArray]) {
        NSStringEncoding stringEncoding = [[encodingMenuItem representedObject] unsignedIntegerValue];
        [encodingMenuItem setEnabled: NO];
        if (![encodingMenuItem isSeparatorItem]) {
			NSString * testText = [[NSString alloc] initWithData: data encoding: stringEncoding];

			[encodingMenuItem setEnabled: testText ? YES : NO];
        }
    }
}

- (NSString*)passwordForArchiveWithPath:(NSString*)filename
{
    NSString* password = nil;
	[passwordField setStringValue: @""];
    if ([NSApp runModalForWindow: passwordPanel] != NSModalResponseCancel) {
        password = [passwordField stringValue];
    }
	
    [passwordPanel close];
    return password;
}

-(NSStringEncoding)archive:(XADArchive *)archive 
		   encodingForData:(NSData *)data 
					 guess:(NSStringEncoding)guess 
				confidence:(float)confidence
{
    NSString * testText = [[NSString alloc] initWithData: data encoding: guess];
    if (confidence < 0.8 || !testText) {
		NSMenu * encodingMenu = [encodingPopup menu];
        [self updateEncodingMenuTestedAgainst: data];
        NSArray * encodingIdentifiers = [[encodingMenu itemArray] valueForKey: @"representedObject"];
		
		NSUInteger index = [encodingIdentifiers indexOfObject: @(guess)];
		NSUInteger counter = 0;
//		NSStringEncoding encoding;
		NSNumber * encoding;
		while (!testText) {
			encoding = encodingIdentifiers[counter];
			if ([encoding class] != [NSNull class]) {
				testText = [[NSString alloc] initWithData: data encoding: [encoding unsignedIntegerValue]];
			}
			index = counter++;
		}

        if (index != NSNotFound) {
            self.encodingSelection = index;
        }
        
        encodingTestData = data;
		
        [self testEncoding: self];
		guess = NSNotFound;
        if ([NSApp runModalForWindow: encodingPanel] != NSModalResponseCancel) {
            guess = [[[encodingMenu itemAtIndex: encodingSelection] representedObject] unsignedIntegerValue];
        }
        [encodingPanel close];
        [archive setNameEncoding: guess];
    }
    
    return guess;
}

- (IBAction)testEncoding:(id)sender
{
    NSMenuItem * encodingMenuItem = [[encodingPopup menu] itemAtIndex: encodingSelection];
	NSString * testText = [[NSString alloc] initWithData: encodingTestData encoding: [[encodingMenuItem representedObject] unsignedIntegerValue]];
    
    if(!testText)
    {
        testText = @"invalid Selection";
    }
    
    [encodingTestField setStringValue: testText];
}

- (IBAction)actionStub:(id)sender
{
    
}

- (IBAction)endLaunchPanel:(id)sender
{
	[launchPanel close];
}

@end
