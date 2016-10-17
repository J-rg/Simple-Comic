//
//  TSSTManagedGroup.m
//  SimpleComic
//
//  Created by Alexander Rauchfuss on 6/2/07.
//  Copyright 2007 Dancing Tortoise Software. All rights reserved.



#import "TSSTManagedGroup.h"
#import "TSSTManagedGroup+CoreDataProperties.h"
#import "SimpleComicAppDelegate.h"
#import <XADMaster/XADArchive.h>
#import <Quartz/Quartz.h>
#import "TSSTImageUtilities.h"
#import "TSSTPage.h"
#import "TSSTPage+CoreDataProperties.h"

@interface TSSTManagedArchive () <XADArchiveDelegate>
-(void)archiveNeedsPassword:(XADArchive *)archive;

@end

@implementation TSSTManagedGroup

- (void)awakeFromInsert
{
	[super awakeFromInsert];
    groupLock = [NSLock new];
    instance = nil;
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
    groupLock = [NSLock new];
    instance = nil;
}

- (void)willTurnIntoFault
{
	NSError * error = nil;
	if([self.nested boolValue])
	{
		if(![[NSFileManager defaultManager] removeItemAtPath: self.path error: &error])
		{
			NSLog(@"%@",[error localizedDescription]);
		}
	}
}

- (void)didTurnIntoFault
{	
	instance = nil;
	groupLock = nil;
}

- (void)setPath:(NSString *)newPath
{
    NSError * urlError = nil;
    NSURL * fileURL = [[NSURL alloc] initFileURLWithPath: newPath];
    NSData * bookmarkData = [fileURL bookmarkDataWithOptions: NSURLBookmarkCreationMinimalBookmark
                              includingResourceValuesForKeys: nil
                                               relativeToURL: nil
                                                       error: &urlError];
    if (bookmarkData == nil || urlError != nil) {
        bookmarkData = nil;
        [NSApp presentError: urlError];
    }
    self.pathData = bookmarkData;
}



- (NSString *)path
{
    NSError * urlError = nil;
    BOOL stale = NO;
    NSURL * fileURL = [NSURL URLByResolvingBookmarkData: self.pathData
                                                options: NSURLBookmarkResolutionWithoutUI
                                          relativeToURL: nil
                                    bookmarkDataIsStale: &stale
                                                  error: &urlError];
    
    
	NSString * hardPath = nil;
    
    if (fileURL == nil || urlError != nil) {
        fileURL = nil;
        [[self managedObjectContext] deleteObject: self];
        [NSApp presentError: urlError];
    }
    else {
        hardPath = [fileURL path];
    }
	
	return hardPath;
}


- (id)instance
{
    return nil;
}

- (NSData *)dataForPageIndex:(NSInteger)index
{
    return nil;
}

- (NSData *)dataForPageName:(NSString *)name
{
    
    return nil;
}

- (NSManagedObject *)topLevelGroup
{
	return self;
}

/**
 Goes through various files like pdfs, images, text files
 from the path folder and it's subfolders and add these
 to the Core Data for the managedObjectContext
 with the info needed to deal with the files.
 */
- (void)nestedFolderContents
{
	NSString * folderPath = self.path;
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSManagedObject * nestedDescription;
	NSError * error = nil;
	NSArray<NSString*> * nestedFiles = [fileManager contentsOfDirectoryAtPath: folderPath error: &error];
	if (error) {
		NSLog(@"%@",[error localizedDescription]);
	}
	NSString * path, * fileExtension, * fullPath;
	BOOL isDirectory, exists;
	
	for (path in nestedFiles)
	{
		nestedDescription = nil;
		fileExtension = [[path pathExtension] lowercaseString];
		fullPath = [folderPath stringByAppendingPathComponent: path];
		exists = [fileManager fileExistsAtPath: fullPath isDirectory: &isDirectory];
		if(exists && ![[[path lastPathComponent] substringToIndex: 1] isEqualToString: @"."])
		{
			if(isDirectory)
			{
				nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"ImageGroup" inManagedObjectContext: [self managedObjectContext]];
			 	[nestedDescription setValue: fullPath forKey: @"path"];
		 		[nestedDescription setValue: path forKey: @"name"];
	 			[(TSSTManagedGroup *)nestedDescription nestedFolderContents];
			}
			else if([[TSSTManagedArchive archiveExtensions] containsObject: fileExtension])
			{
				nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Archive" inManagedObjectContext: [self managedObjectContext]];
				[nestedDescription setValue: fullPath forKey: @"path"];
				[nestedDescription setValue: path forKey: @"name"];
				[(TSSTManagedArchive *)nestedDescription nestedArchiveContents];
			}
			else if([fileExtension isEqualToString: @"pdf"])
 			{
				nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"PDF" inManagedObjectContext: [self managedObjectContext]];
				[nestedDescription setValue: fullPath forKey: @"path"];
				[nestedDescription setValue: path forKey: @"name"];
				[(TSSTManagedPDF *)nestedDescription pdfContents];
			}
			else if([[TSSTPage imageExtensions] containsObject: fileExtension])
			{
				nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Image" inManagedObjectContext: [self managedObjectContext]];
				[nestedDescription setValue: fullPath forKey: @"imagePath"];
			}
			else if ([[TSSTPage textExtensions] containsObject: fileExtension])
			{
				nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Image" inManagedObjectContext: [self managedObjectContext]];
				[nestedDescription setValue: fullPath forKey: @"imagePath"];
				[nestedDescription setValue: @YES forKey: @"text"];
			}
            
			if(nestedDescription)
			{
				[nestedDescription setValue: self forKey: @"group"];
			}
		}
	}
}

/**
 Returns a set with all the images found in the key in union with the ones from other groups.
 
 @return NSSet with all images found in context.
*/
- (NSSet *)nestedImages
{
	NSMutableSet * allImages = [self.images mutableCopy];
	NSSet * groups = self.groups;
	for(TSSTManagedGroup * group in groups)
	{
		[allImages unionSet: group.nestedImages];
	}
	
	return allImages;
}

@end


@implementation TSSTManagedArchive

/**
 * @returns NSArray with archieve extions which the software supports.
 */
+ (NSArray *)archiveExtensions
{
	static NSArray * extensions = nil;
	if(!extensions)
	{
		extensions = @[@"rar", @"cbr", @"zip", @"cbz", @"7z", @"cb7", @"lha", @"lzh", @"cbt", @"tar"];
	}
	
	return extensions;
}

/**
 @return NSArray with file extensions for which software support QuickLook for.
 */
+ (NSArray *)quicklookExtensions
{
	static NSArray * extensions = nil;

	if(!extensions)
	{
		extensions = @[@"cbr", @"cbz", @"cbt"];
	}
	
	return extensions;
}

- (void)willTurnIntoFault
{
	NSError * error;
	if([self.nested boolValue])
	{
		if(![[NSFileManager defaultManager] removeItemAtPath: self.path error: &error])
		{
			NSLog(@"%@",[error localizedDescription]);
		}
	}
	
	NSString * solid  = self.solidDirectory;
	if(solid)
	{
		if(![[NSFileManager defaultManager] removeItemAtPath: solid error: &error])
		{
			NSLog(@"%@",[error localizedDescription]);
		}
	}
}

- (id)instance
{
    if (!instance)
    {
        NSFileManager * manager = [NSFileManager defaultManager];
        if([manager fileExistsAtPath: self.path])
        {
            instance = [[XADArchive alloc] initWithFile: self.path delegate: self error:NULL];

            // Set the archive delegate so that password and encoding queries can have a modal pop up.
			
            if(self.password)
            {
                [instance setPassword: self.password];
            }
        }
    }
	
    return instance;
}

- (NSData *)dataForPageIndex:(NSInteger)index
{
	NSString * solidDirectory = self.solidDirectory;
	NSData * imageData;
	if(!solidDirectory)
	{
		[groupLock lock];
		imageData = [[self instance] contentsOfEntry: index];
		[groupLock unlock];
	}
	else
	{
		NSString * name = [[self instance] nameOfEntry: index];
		NSString * fileName = [NSString stringWithFormat:@"%li.%@", (long)index, [name pathExtension]];
		fileName = [solidDirectory stringByAppendingPathComponent: fileName];
		if(![[NSFileManager defaultManager] fileExistsAtPath: fileName])
		{
			[groupLock lock];
			imageData = [[self instance] contentsOfEntry: index];
			[groupLock unlock];
			[imageData writeToFile: fileName options: 0 error: nil];
		}
		else
		{
			imageData = [NSData dataWithContentsOfFile: fileName];
		}
	}

    return imageData;
}

- (NSData *)dataForPageName:(NSString *)name
{
    return nil;
}

- (NSManagedObject *)topLevelGroup
{
	NSManagedObject * group = self;
	NSManagedObject * parentGroup = group;
	
	while(group)
	{
		group = [group valueForKeyPath: @"group"];
		parentGroup = group && [group class] == [TSSTManagedArchive class] ? group : parentGroup;
	}
	
	return parentGroup;
}

- (void)nestedArchiveContents
{
    XADArchive * imageArchive = self.instance;
    
    NSFileManager * fileManager = [NSFileManager defaultManager];
	NSData * fileData;
	NSInteger collision = 0;
    NSString * archivePath = nil;
	NSInteger counter, archivedFilesCount = [imageArchive numberOfEntries];
	NSError * error;
	if([imageArchive isSolid])
	{
		do {
			archivePath = [NSString stringWithFormat: @"SC-images-%li", (long)collision];
			archivePath = [NSTemporaryDirectory() stringByAppendingPathComponent: archivePath];
			++collision;
		} while (![fileManager createDirectoryAtPath: archivePath withIntermediateDirectories: YES attributes: nil error: &error]);
		self.solidDirectory = archivePath;
	}
    
    for (counter = 0; counter < archivedFilesCount; ++counter)
    {
        NSString *fileName = [imageArchive nameOfEntry: counter];
        TSSTManagedGroup *nestedDescription = nil;
		
        if(!([fileName isEqualToString: @""] || [[[fileName lastPathComponent] substringToIndex: 1] isEqualToString: @"."]))
        {
            NSString *extension = [[fileName pathExtension] lowercaseString];
            if([[TSSTPage imageExtensions] containsObject: extension])
            {
                nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Image" inManagedObjectContext: [self managedObjectContext]];
				[nestedDescription setValue: fileName forKey: @"imagePath"];
				[nestedDescription setValue: @(counter) forKey: @"index"];
            }
            else if([[NSUserDefaults standardUserDefaults] boolForKey: TSSTNestedArchives] && [[TSSTManagedArchive archiveExtensions] containsObject: extension])
            {
                fileData = [imageArchive contentsOfEntry: counter];
                nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Archive" inManagedObjectContext: [self managedObjectContext]];
				nestedDescription.name = fileName;
				nestedDescription.nested = @YES;
				
                collision = 0;
                do {
                    archivePath = [NSString stringWithFormat: @"%li-%@", (long)collision, fileName];
                    archivePath = [NSTemporaryDirectory() stringByAppendingPathComponent: archivePath];
                    ++collision;
                } while ([fileManager fileExistsAtPath: archivePath]);

                [[NSFileManager defaultManager] createDirectoryAtPath: [archivePath stringByDeletingLastPathComponent] 
                                          withIntermediateDirectories: YES 
                                                           attributes: nil 
                                                                error: NULL];
                [[NSFileManager defaultManager] createFileAtPath: archivePath contents: fileData attributes: nil];

				nestedDescription.path = archivePath;
                [(TSSTManagedArchive *)nestedDescription nestedArchiveContents];
            }
			else if([[TSSTPage textExtensions] containsObject: extension])
			{
				nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Image" inManagedObjectContext: [self managedObjectContext]];
				[nestedDescription setValue: fileName forKey: @"imagePath"];
				[nestedDescription setValue: @(counter) forKey: @"index"];
				[nestedDescription setValue: @YES forKey: @"text"];
			}
            else if([extension isEqualToString: @"pdf"])
            {
                nestedDescription = [NSEntityDescription insertNewObjectForEntityForName: @"PDF" inManagedObjectContext: [self managedObjectContext]];
                archivePath = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
                NSInteger collision = 0;
                while([fileManager fileExistsAtPath: archivePath])
                {
                    ++collision;
                    fileName = [NSString stringWithFormat: @"%li-%@", (long)collision, fileName];
                    archivePath = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
                }
				fileData = [imageArchive contentsOfEntry: counter];
				[fileData writeToFile: archivePath atomically: YES];

				nestedDescription.path = archivePath;
				nestedDescription.nested = @YES;
				[(TSSTManagedPDF *)nestedDescription pdfContents];
            }
			
			if(nestedDescription)
			{
                nestedDescription.group = self;
			}
        }
    }
}


- (BOOL)quicklookCompatible
{	
	NSString * extension = [[self.name pathExtension] lowercaseString];
	return [TSSTManagedArchive.quicklookExtensions containsObject: extension];
}


/* Delegates */

/**  Called when Simple Comic encounters a password protected
 archive.  Brings a password dialog forward. */
-(void)archiveNeedsPassword:(XADArchive *)archive
{
    NSString * password = self.password;
    
    if(password)
    {
        archive.password = password;
        return;
    }
    
    password = [(SimpleComicAppDelegate*)[NSApp delegate] passwordForArchiveWithPath: self.path];
    archive.password = password;
    
    self.password = password;
}

@end


@implementation TSSTManagedPDF

- (id)instance
{
    if (!instance)
    {
        instance = [[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: self.path]];
    }
	
    return instance;
}

- (NSData *)dataForPageIndex:(NSInteger)index
{	
    [groupLock lock];
	PDFPage * page = [[self instance] pageAtIndex: index];
    [groupLock unlock];
	
	NSRect bounds = [page boundsForBox: kPDFDisplayBoxMediaBox];
	CGFloat dimension = 1400;
	CGFloat scale = 1 > (NSHeight(bounds) / NSWidth(bounds)) ? dimension / NSWidth(bounds) :  dimension / NSHeight(bounds);
	bounds.size = scaleSize(bounds.size, scale);
	
	NSImage * pageImage = [[NSImage alloc] initWithSize: bounds.size];
	[pageImage lockFocus];
		[[NSColor whiteColor] set];
		NSRectFill(bounds );
		NSAffineTransform * scaleTransform = [NSAffineTransform transform];
		[scaleTransform scaleBy: scale];
		[scaleTransform concat];
		[page drawWithBox: kPDFDisplayBoxMediaBox];
	[pageImage unlockFocus];
	
	NSData * imageData = [pageImage TIFFRepresentation];
	
    return imageData;
}

- (NSData *)dataForPageName:(NSString *)name
{
    
    return nil;
}

/**  Creates an image managedobject for every "page" in a pdf. */
- (void)pdfContents
{
    NSPDFImageRep * rep = [self instance];
    TSSTPage * imageDescription;
    NSMutableSet<TSSTPage*> * pageSet = [NSMutableSet set];
    NSInteger imageCount = [rep pageCount];
    for (NSInteger pageNumber = 0; pageNumber < imageCount; ++pageNumber)
    {
        imageDescription = [NSEntityDescription insertNewObjectForEntityForName: @"Image" inManagedObjectContext: [self managedObjectContext]];
		imageDescription.imagePath = [NSString stringWithFormat: @"%li", (long)(pageNumber + 1)];
		imageDescription.index = @(pageNumber);
        [pageSet addObject: imageDescription];
    }
    self.images = pageSet;
}

@end
