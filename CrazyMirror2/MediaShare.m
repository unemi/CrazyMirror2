//
//  MediaShare.m
//  Crazy Mirror 2
//
//  Created by Tatsuo Unemi on 2023/05/13.
//

#import "MediaShare.h"
#import "AppDelegate.h"
#import "Preferences.h"
#define TIME_SCALE 600

void clear_useless_video_files(void) {
	NSFileManager *fmn = NSFileManager.defaultManager;
	NSString *dir = fmn.currentDirectoryPath;
	for (NSString *path in [fmn contentsOfDirectoryAtPath:dir error:NULL])
		if ([path hasPrefix:@"CrazyMirror2Video_"])
			[fmn removeItemAtPath:[dir stringByAppendingPathComponent:path] error:NULL];
}

@implementation MyNotification
- (NSString *)windowNibName { return @"MyNotification"; }
- (void)setMessage:(NSString *)msg {
	message = NSLocalizedString(msg, nil);
}
- (void)windowDidLoad {
	msgTxt.stringValue = message;
	openPhotosBtn.image = photos_app_icon();
}
- (IBAction)ok:(id)sender {
	[timer invalidate];
	[self.window orderOut:nil];
}
- (IBAction)openPhotos:(id)sender {
	NSWorkspaceOpenConfiguration *config = NSWorkspaceOpenConfiguration.configuration;
	config.activates = YES;
	NSWorkspace *wkspc = NSWorkspace.sharedWorkspace;
	[wkspc openApplicationAtURL:photos_URL(wkspc) configuration:config completionHandler:nil];
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
	timeDgt.integerValue = 5;
	timer = [NSTimer scheduledTimerWithTimeInterval:1. repeats:YES
		block:^(NSTimer * _Nonnull timer) {
		NSInteger tm = self->timeDgt.integerValue;
		if (tm <= 0) {
			[timer invalidate];
			[self.window orderOut:nil];
		} else self->timeDgt.integerValue = tm - 1;
	}];
}
@end
static void check_photo_lib_access(void (^block)(void)) {
	switch ([PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly]) {
		case PHAuthorizationStatusNotDetermined: {
		[PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
			handler:^(PHAuthorizationStatus status)
			{ if (status == PHAuthorizationStatusAuthorized) block(); }];
		} break;
		case PHAuthorizationStatusAuthorized: block(); break;
		default: break;
	}
}
static MyNotification *myNotification = nil;
static void show_notification(NSString *message, NSView *view) {
	in_main_thread( ^{
		if (myNotification == nil) myNotification = [MyNotification.alloc initWithWindow:nil];
		[myNotification setMessage:message];
		NSWindow *myWin = myNotification.window;
		NSRect rect = view.window.frame;
		NSSize size = myWin.frame.size;
		NSPoint origin = {rect.origin.x + (rect.size.width - size.width) / 2.,
			rect.origin.y + (rect.size.height - size.height) / 2. };
		[myWin setFrameOrigin:origin];
		myWin.level = view.window.level + 1;
		[myWin makeKeyAndOrderFront:nil];
	} );
}
static NSString *photo_path(NSString *fileExtension) {
	return [NSString stringWithFormat:@"CrazyMirror2Photo_%05ld.%@",
		preferences.photoCount, fileExtension];
}
static void share_image_in_photosLib(NSBitmapImageRep *imgRep,
	NSView *view, void (^handler)(void)) {
	check_photo_lib_access(^{
		[PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
			NSURL *fileURL = [NSURL fileURLWithPath:photo_path(@"HEIC")];
			CGImageDestinationRef dest = CGImageDestinationCreateWithURL(
				(CFURLRef)fileURL, (CFStringRef)@"public.heic", 1, NULL);
			CGImageDestinationAddImage(dest, imgRep.CGImage, (CFDictionaryRef)
				@{(NSString *)kCGImageDestinationLossyCompressionQuality:@(.75)});
			CGImageDestinationFinalize(dest);
			CFRelease(dest);
			PHAssetResourceCreationOptions *option = PHAssetResourceCreationOptions.new;
			option.shouldMoveFile = YES;
			[PHAssetCreationRequest.creationRequestForAsset
				addResourceWithType:PHAssetResourceTypePhoto fileURL:fileURL options:option];
		} completionHandler:^(BOOL success, NSError * _Nullable error) {
			if (success) {
				handler();
				[preferences incPhotoCount];
				show_notification(@"Took a photo.", view);
			} else err_msg(error, NO);
		}]; });
}
static void save_photo_as_file(NSBitmapImageRep *imgRep, NSURL *url, void (^handler)(void)) {
	NSData *data = [imgRep representationUsingType:NSBitmapImageFileTypeJPEG properties:@{}];
	[data writeToURL:url atomically:NO];
	handler();
	[preferences incPhotoCount];
}
static void copy_image(NSBitmapImageRep *imgRep, void (^handler)(void)) {
	NSPasteboard *pb = NSPasteboard.generalPasteboard;
	[pb declareTypes:@[NSPasteboardTypePNG] owner:NSApp];
	NSData *data = [imgRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	[pb setData:data forType:NSPasteboardTypePNG];
	handler();
}
void save_photo_image(NSBitmapImageRep *imgRep, NSView *view, void (^handler)(void)) {
	switch (preferences.svPhoto) {
		case SvPhtInPhotosLib: share_image_in_photosLib(imgRep, view, handler); break;
		case SvPhtInPictFolder: {
			NSArray<NSURL *> *urls = [NSFileManager.defaultManager
				URLsForDirectory:NSPicturesDirectory inDomains:NSUserDomainMask];
			if (urls == nil || urls.count < 1)
				err_msg(@"Cannot identify Pictures folder.", NO);
			else save_photo_as_file(imgRep,
				[urls[0] URLByAppendingPathComponent:photo_path(@"jpeg")], handler); 
			
		} break;
		case SvPhtInUserFolder: {
			NSSavePanel *sp = NSSavePanel.new;
			sp.nameFieldStringValue = photo_path(@"jpeg");
			sp.allowedFileTypes = @[(NSString *)kUTTypeJPEG];
			[sp beginSheetModalForWindow:view.window completionHandler:^(NSModalResponse result) {
				if (result != NSModalResponseOK) return;
				save_photo_as_file(imgRep, sp.URL, handler);
			}];
		} break;
		case SvPhtInPasteboard: copy_image(imgRep, handler);
	}
}
static void share_movie_in_photosLib(NSURL *srcURL, NSView *view, void (^handler)(void)) {
	check_photo_lib_access(^{
	[PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
		PHAssetResourceCreationOptions *option = PHAssetResourceCreationOptions.new;
		option.shouldMoveFile = YES;
		[PHAssetCreationRequest.creationRequestForAsset
			addResourceWithType:PHAssetResourceTypeVideo fileURL:srcURL options:option];
	} completionHandler:^(BOOL success, NSError * _Nullable error) {
		MyWarning(success, @"%@", error)
		else {
			handler();
			show_notification(@"Record a video.", view);
		}
	}]; });
}
static void save_movie_in_file(NSURL *srcURL, NSURL *dstURL, void (^handler)(void)) {
	NSError *error;
	if ([NSFileManager.defaultManager moveItemAtURL:srcURL toURL:dstURL error:&error])
		handler();
	else err_msg(error, NO);
}
static void save_video_movie(NSURL *srcURL, NSView *view, void (^handler)(void)) {
	switch (preferences.svVideo) {
		case SvVidInPhotosLib: share_movie_in_photosLib(srcURL, view, handler); break;
		case SvVidInMovieFolder: {
			NSArray<NSURL *> *urls = [NSFileManager.defaultManager
				URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask];
			if (urls == nil || urls.count < 1)
				err_msg(@"Cannot identify Movies folder.", NO);
			else save_movie_in_file(srcURL,
				[urls[0] URLByAppendingPathComponent:srcURL.lastPathComponent], handler);
		} break;
		case SvVidInUserFolder: in_main_thread(^{
			NSSavePanel *sp = NSSavePanel.new;
			sp.nameFieldStringValue = srcURL.lastPathComponent;
			sp.allowedFileTypes = @[(NSString *)kUTTypeQuickTimeMovie];
			[sp beginSheetModalForWindow:view.window completionHandler:^(NSModalResponse result) {
				if (result != NSModalResponseOK) return;
				save_movie_in_file(srcURL, sp.URL, handler);
			}];
		});
	}
}
#ifdef DEBUG_I
static FILE *logFD = NULL;
static int logCNT = 0;
static void MyLog(char *fmt, ...) {
	time_t sec;
	time(&sec);
	struct tm *t = localtime(&sec);
	fprintf(logFD, "%02d:%02d:%02d ", t->tm_hour, t->tm_min, t->tm_sec);
	va_list aList;
	va_start(aList, fmt);
	vfprintf(logFD, fmt, aList);
	fflush(logFD);
	va_end(aList);
}
#endif

@interface MediaShare () {
	NSView *view;
	NSURL *URL;
	AVAssetWriter *writer;
	AVAssetWriterInput *imageInput;
	AVAssetWriterInputPixelBufferAdaptor *adaptor;
	struct timeval startTime;
	NSMutableArray *frameQue;
	NSConditionLock *queLock;
}
@end

@implementation MediaShare
- (void)videoFrameLoop {
	void (^completionHandler)(void) = nil;
	MyLog("videoFrameLoop start\n");
	@try {
		while (imageInput.readyForMoreMediaData) {
			[queLock lockWhenCondition:YES];
			id task = frameQue[0];
			[frameQue removeObjectAtIndex:0];
			[queLock unlockWithCondition:frameQue.count > 0];
			if ([task isKindOfClass:NSArray.class]) {
				NSBitmapImageRep *imgRep = ((NSArray *)task)[0];
				CMTimeValue playTime = [((NSArray *)task)[1] integerValue];
				CVPixelBufferRef pixBuffer;
				OSStatus status = CVPixelBufferCreateWithBytes(NULL,
					imgRep.pixelsWide, imgRep.pixelsHigh, kCVPixelFormatType_32ARGB,
					imgRep.bitmapData, imgRep.bytesPerRow, NULL, NULL, NULL, &pixBuffer);
				if (status != noErr) @throw @"Cannot make CVPixelBuffer";
				BOOL result = [adaptor appendPixelBuffer:pixBuffer
					withPresentationTime:(CMTime){playTime, TIME_SCALE, 1, 0}];
#ifdef DEBUG_I
	if (logCNT == 0) MyLog("appendPixelBuffer %d\n", result);
#endif
				usleep(1000);
				CFRelease(pixBuffer);
#ifdef DEBUG_I
	if (logCNT == 0) MyLog("CFRelease PixelBuffer\n");
#endif
				if (!result) @throw @"Cannot append a frame image.";
			} else { completionHandler = (void (^)(void))task; break; }
#ifdef DEBUG_I
	if (logCNT == 0) MyLog("back to loop head\n");
	 logCNT ++;
#endif
		}
	} @catch (NSString *msg) { err_msg(msg, NO); return; }
	MyLog("videoFrameLoop end %d\n", logCNT);
	[writer endSessionAtSourceTime:(CMTime){self.playTime, TIME_SCALE, 1, 0}];
	[writer finishWritingWithCompletionHandler:^{
		MyLog("Finalization completed\n");
		save_video_movie(self->URL, self->view, completionHandler);
	}];
}
- (void)videoThread:(NSBitmapImageRep *)imgRep {
	MyLog("videoThread start\n");
	NSThread.currentThread.name = @"video recording thread";
	NSFileManager *fmn = NSFileManager.defaultManager;
	NSInteger ID = preferences.videoCount;
	while (URL == nil) {
		NSString *filePath = [NSString stringWithFormat:@"CrazyMirror2Video_%05ld.MOV", ID];
		if ([fmn fileExistsAtPath:filePath]) ID ++;
		else if ((URL = [NSURL fileURLWithPath:filePath]) == nil)
			@throw @"Cannot make a file URL.";
	}
	preferences.videoCount = ID;
	NSError *error;
	writer = [AVAssetWriter assetWriterWithURL:URL fileType:AVFileTypeMPEG4 error:&error];
	if (writer == nil) @throw error;
	imageInput = [AVAssetWriterInput
		assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:
		@{AVVideoWidthKey:@(imgRep.pixelsWide), AVVideoHeightKey:@(imgRep.pixelsHigh),
		  AVVideoCodecKey:AVVideoCodecTypeHEVC}];
	imageInput.expectsMediaDataInRealTime = YES;
	adaptor = [AVAssetWriterInputPixelBufferAdaptor
		assetWriterInputPixelBufferAdaptorWithAssetWriterInput:imageInput
		sourcePixelBufferAttributes:nil];
	[writer addInput:imageInput];
	if (![writer startWriting]) @throw writer.error;
	[writer startSessionAtSourceTime:kCMTimeZero];
	[imageInput requestMediaDataWhenReadyOnQueue:
		dispatch_queue_create("Video frames feeder", DISPATCH_QUEUE_SERIAL)
		usingBlock:^{ [self videoFrameLoop]; }];
	MyLog("videoThread end\n");
}
- (instancetype)initWithImgRep:(NSBitmapImageRep *)imgRep view:(NSView *)v {
	if (!(self = [super init])) return nil;
#ifdef DEBUG_I
	if (logFD == NULL) {
		logFD = fopen("tmp/CrazzyMirror2.log", "w");
		MyAssert(logFD, @"Couldn't make logfile (%d).", errno)
	}
	MyLog("MediaShare was initialized.\n");
#endif
	view = v;
	frameQue = NSMutableArray.new;
	queLock = NSConditionLock.new;
	[NSThread detachNewThreadSelector:@selector(videoThread:) toTarget:self withObject:imgRep];
	return self;
}
- (CMTimeValue)playTime {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	if (startTime.tv_sec == 0) startTime = tv;
	return (tv.tv_usec > startTime.tv_usec)?
		(tv.tv_sec - startTime.tv_sec) * TIME_SCALE +
		(tv.tv_usec - startTime.tv_usec) * TIME_SCALE / 1000000 :
		(tv.tv_sec - startTime.tv_sec - 1) * TIME_SCALE +
		(1000000 + tv.tv_usec - startTime.tv_usec) * TIME_SCALE / 1000000;
}
- (BOOL)addFrameImgRep:(NSBitmapImageRep *)imgRep {
	if (frameQue == nil) return NO;
	[queLock lock];
	[frameQue addObject:@[imgRep, @(self.playTime)]];
	[queLock unlockWithCondition:YES];
	return YES;
}
- (void)finishWithHandler:(void (^)(void))handler {
	[queLock lock];
	[frameQue addObject:handler];
	[queLock unlockWithCondition:YES];
}
@end

@implementation VideoRecordingView
- (instancetype)initWithItem:(NSToolbarItem *)item {
	if (!(self = [super initWithFrame:(NSRect){0,0,20,20}])) return nil;
	action = item.action;
	target = item.target;
	return self;
}
- (void)startAnimation {
	timer = [NSTimer scheduledTimerWithTimeInterval:1./30.
		repeats:YES block:^(NSTimer * _Nonnull timer) {
		if ((self->cycleTime += 1./45.) > 1.) self->cycleTime --;
		self.needsDisplay = YES;
	}];
}
- (void)stopAnimation { [timer invalidate]; }
- (void)drawRect:(NSRect)rect {
	[NSColor.clearColor setFill];
	[NSBezierPath fillRect:self.bounds];
	[[NSColor colorWithRed:1. green:0. blue:0.
		alpha:(sin(cycleTime * M_PI * 2.) + 1.) / 2. * .8 + .2] setFill];
	NSRect rct = self.bounds;
	CGFloat d = rct.size.height / 4.;
	[[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(rct, d, d)] fill];
}
- (void)mouseDown:(NSEvent *)event {
	[self sendAction:action to:target];
}
@end
