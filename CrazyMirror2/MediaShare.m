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

static NSString *fnPrefix = @"CrazyMirror2";
typedef enum { MediaTypePhoto, MediaTypeVideo } MyMediaType;

void clear_useless_video_files(void) {
	NSFileManager *fmn = NSFileManager.defaultManager;
	NSString *dir = fmn.currentDirectoryPath;
	for (NSString *path in [fmn contentsOfDirectoryAtPath:dir error:NULL])
		if ([path hasPrefix:fnPrefix])
			[fmn removeItemAtPath:[dir stringByAppendingPathComponent:path] error:NULL];
}
BOOL setup_input_device(AVCaptureSession *ses, AVCaptureDevice *dev, AVMediaType mediaType) {
	NSError *error;
	AVCaptureDeviceInput *devIn = [AVCaptureDeviceInput deviceInputWithDevice:dev error:&error];
	MyWarning(devIn, @"Cannot make a video device input. %@", error.localizedDescription);
	if (devIn == nil) return NO;
	AVCaptureDeviceInput *orgDevIn = nil;
	for (AVCaptureDeviceInput *input in ses.inputs)
		if ([input.device hasMediaType:mediaType]) { orgDevIn = input; break; }
	if (orgDevIn != nil) [ses removeInput:orgDevIn];
	BOOL canAddIt = [ses canAddInput:devIn];
	MyWarning(canAddIt, @"Cannot add input.",nil)
	if (canAddIt) {
		[ses addInput:devIn];
		return YES;
	} else {
		if (orgDevIn != nil) [ses addInput:orgDevIn];
		return NO;
	}
}
@implementation MyNotification
- (NSString *)windowNibName { return @"MyNotification"; }
- (void)setupType:(MyMediaType)type URL:(NSURL *)url {
	msgTxt.stringValue = NSLocalizedString(
		(type == MediaTypePhoto)? @"Took a photo." : @"Recorded a video.", nil);
	lookupBtn.image = ((URL = url) == nil)? photos_app_icon() :
		[NSImage imageWithSystemSymbolName:
			(type == MediaTypePhoto)? @"camera" : @"video" accessibilityDescription:nil];
	infoTxt.stringValue = NSLocalizedString(
		(URL == nil)? @"It was saved in your Photos library." :
		(type == MediaTypePhoto)? @"It was saved in your Pictures folder." :
			@"It was saved in your Movies folder.", nil);
}
- (IBAction)ok:(id)sender {
	[timer invalidate];
	[self.window orderOut:nil];
}
- (IBAction)lookItUp:(id)sender {
	NSWorkspace *wkspc = NSWorkspace.sharedWorkspace;
	if (URL == nil) {
		NSWorkspaceOpenConfiguration *config = NSWorkspaceOpenConfiguration.configuration;
		config.activates = YES;
		[wkspc openApplicationAtURL:photos_URL(wkspc) configuration:config completionHandler:nil];
	} else [wkspc selectFile:URL.absoluteURL.path inFileViewerRootedAtPath:@""];
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
static void show_notification(MyMediaType mediaType, NSURL *dstURL, NSView *view) {
	in_main_thread( ^{
		if (myNotification == nil) myNotification = [MyNotification.alloc initWithWindow:nil];
		NSWindow *myWin = myNotification.window;
		[myNotification setupType:mediaType URL:dstURL];
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
	return [NSString stringWithFormat:@"%@Photo_%05ld.%@", fnPrefix,
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
				show_notification(MediaTypePhoto, nil, view);
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
			else {
				NSURL *url = [urls[0] URLByAppendingPathComponent:photo_path(@"jpeg")];
				save_photo_as_file(imgRep, url, handler);
				show_notification(MediaTypePhoto, url, view);
			}
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
			show_notification(MediaTypeVideo, nil, view);
		}
	}]; });
}
static void save_movie_in_file(NSURL *srcURL, NSURL *dstURL, void (^handler)(void)) {
	NSError *error;
	if ([NSFileManager.defaultManager moveItemAtURL:srcURL toURL:dstURL error:&error])
		handler();
	else err_msg(error, NO);
}
#if defined DEBUG || defined DEBUG_I
static int logCNT = 0;
#endif
#ifdef DEBUG_I
static FILE *logFD = NULL;
static void MyLog(char *fmt, ...) {
	time_t sec;
	time(&sec);
	struct tm *t = localtime(&sec);
	fprintf(logFD, "%02d:%02d:%02d ", t->tm_hour, t->tm_min, t->tm_sec);
	va_list aList;
	va_start(aList, fmt);
	vfprintf(logFD, fmt, aList);
	fputs("\n", logFD);
	fflush(logFD);
	va_end(aList);
}
#endif

@interface MediaShare () {
	NSView *view;
	NSURL *URL, *audioURL;
	AVAssetWriter *writer;
	AVAssetWriterInput *imageInput;
	AVAssetWriterInputPixelBufferAdaptor *pxBufAdaptor;
	struct timeval startTime;
	NSMutableArray *frameQue;
	NSConditionLock *queLock;
	AVCaptureAudioFileOutput *audioOut;
}
@end

@implementation MediaShare
- (void)captureOutput:(AVCaptureFileOutput *)output
	didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
	fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error {
	NSLog(@"captureOutput:didFinishRecordingToOutputFileAtURL:");
}
- (void)setupAudioIOIfNeeded:(AVCaptureSession *)ses {
	if (preferences.recAudioFrom == nil) return;
	MyLog("recAudioFrom %s", preferences.recAudioFrom.UTF8String);
	@try {
		AVCaptureDevice *mic = nil;
		for (AVCaptureDevice *dev in get_microphones())
			if ([dev.localizedName isEqualToString:preferences.recAudioFrom])
				{ mic = dev; break; }
		if (mic == nil) mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
		if (mic == nil) @throw @"No audio input available.";
		if (!setup_input_device(ses, mic, AVMediaTypeAudio)) @throw @"Cannot setup audio input";
		audioOut = AVCaptureAudioFileOutput.new;
		if (![ses canAddOutput:audioOut]) @throw @"Cannot add audio output to the session.";
		[ses addOutput:audioOut];
		NSString *path = [NSString stringWithFormat:
			@"%@Sound%05ld.m4a", fnPrefix, preferences.videoCount];
		NSFileManager *fmn = NSFileManager.defaultManager;
		if ([fmn fileExistsAtPath:path]) [fmn removeItemAtPath:path error:NULL];
		audioURL = [NSURL fileURLWithPath:path];
		[audioOut startRecordingToOutputFileURL:audioURL
			outputFileType:AVFileTypeAppleM4A recordingDelegate:self];
	} @catch (NSObject *obj) { err_msg(obj, NO); }
}
static void insert_track(AVMutableComposition *compo, NSURL *url) {
	AVAsset *asset = [AVAsset assetWithURL:url];
	NSArray<AVAssetTrack *> *trks = asset.tracks;
	if (trks == nil || trks.count <= 0)
		@throw [NSString stringWithFormat:@"%@ has no track.", url.lastPathComponent];
	AVAssetTrack *trk = trks[0];
	NSError *error;
	CMTimeRange tmRange = trk.timeRange;
#ifdef DEBUG
	NSLog(@"%lld, %lld/%d %@", tmRange.start.value, tmRange.duration.value,
		tmRange.duration.timescale, url.lastPathComponent);
#endif
	AVMutableCompositionTrack *cTrack = [compo addMutableTrackWithMediaType:
		trk.mediaType preferredTrackID:kCMPersistentTrackID_Invalid];
	BOOL result = [cTrack insertTimeRange:tmRange ofTrack:trk atTime:kCMTimeZero error:&error];
	if (!result) @throw error;
}
- (void)saveVideoMovieWithHandler:(void (^)(void))handler {
	if (audioURL != nil) { @try {
		AVMutableComposition *compo = AVMutableComposition.composition;
		insert_track(compo, URL);
		insert_track(compo, audioURL);
		AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:compo
			presetName:AVAssetExportPresetPassthrough];
		exporter.outputURL = [NSURL fileURLWithPath:
			[NSString stringWithFormat:@"%@_tmp.MOV", URL.path.stringByDeletingPathExtension]];
		exporter.outputFileType = AVFileTypeQuickTimeMovie;
		NSCondition *cond = NSCondition.new; [cond lock];
		[exporter exportAsynchronouslyWithCompletionHandler:^{ [cond signal]; }];
		[cond wait]; [cond unlock];
		if (exporter.status != AVAssetExportSessionStatusCompleted)
			@throw @"AVAssetExportSession could not completed.";
		NSFileManager *fmn = NSFileManager.defaultManager;
		NSError *error;
		if (![fmn removeItemAtURL:URL error:&error]) @throw error;
		if (![fmn removeItemAtURL:audioURL error:&error]) @throw error;
		if (![fmn moveItemAtURL:exporter.outputURL toURL:URL error:&error]) @throw error;
	} @catch (NSObject *obj) { err_msg(obj, NO); }}
	switch (preferences.svVideo) {
		case SvVidInPhotosLib: share_movie_in_photosLib(URL, view, handler); break;
		case SvVidInMovieFolder: {
			NSArray<NSURL *> *urls = [NSFileManager.defaultManager
				URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask];
			if (urls == nil || urls.count < 1)
				err_msg(@"Cannot identify Movies folder.", NO);
			else {
				NSURL *url = [urls[0] URLByAppendingPathComponent:URL.lastPathComponent];
				save_movie_in_file(URL, url, handler);
				show_notification(MediaTypeVideo, url, view);
			}
		} break;
		case SvVidInUserFolder: in_main_thread(^{
			NSSavePanel *sp = NSSavePanel.new;
			sp.nameFieldStringValue = self->URL.lastPathComponent;
			sp.allowedFileTypes = @[(NSString *)kUTTypeQuickTimeMovie];
			[sp beginSheetModalForWindow:self->view.window completionHandler:^(NSModalResponse result) {
				if (result != NSModalResponseOK) return;
				save_movie_in_file(self->URL, sp.URL, handler);
			}];
		});
	}
}
static BOOL wait_for_input_ready(AVAssetWriterInput *input) {
	for (NSInteger i = 0; i < 2000; i ++) {
		if (input.readyForMoreMediaData) return YES;
		else usleep(1000);
	}
	return NO; 
}
- (void)recordingWithImg:(NSBitmapImageRep *)imgRep session:(AVCaptureSession *)ses {
	imageInput = [AVAssetWriterInput
		assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:
		@{AVVideoWidthKey:@(imgRep.pixelsWide), AVVideoHeightKey:@(imgRep.pixelsHigh),
		  AVVideoCodecKey:AVVideoCodecTypeHEVC}];
	imageInput.expectsMediaDataInRealTime = YES;
	pxBufAdaptor = [AVAssetWriterInputPixelBufferAdaptor
		assetWriterInputPixelBufferAdaptorWithAssetWriterInput:imageInput
		sourcePixelBufferAttributes:nil];
	[writer addInput:imageInput];
	[self setupAudioIOIfNeeded:ses];
	if (![writer startWriting]) @throw writer.error;
	[writer startSessionAtSourceTime:kCMTimeZero];
//
	void (^completionHandler)(void) = nil;
	MyLog("videoFrameLoop start");
	while (completionHandler == nil) { @try {
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
			if (!wait_for_input_ready(imageInput)) @throw @"Timeout to add frame image.";
			BOOL result = [pxBufAdaptor appendPixelBuffer:pixBuffer
				withPresentationTime:(CMTime){playTime, TIME_SCALE, 1, 0}];
#if defined DEBUG || defined DEBUG_I
	if (logCNT == 0) MyLog("appendPixelBuffer %d", result);
#endif
			usleep(1000);
			CFRelease(pixBuffer);
#if defined DEBUG || defined DEBUG_I
	if (logCNT == 0) MyLog("CFRelease PixelBuffer");
#endif
			if (!result) @throw @"Cannot append a frame image.";
		} else completionHandler = (void (^)(void))task;
#if defined DEBUG || defined DEBUG_I
	if (logCNT == 0) MyLog("back to loop head");
	logCNT ++;
#endif
	} @catch (NSString *msg) { err_msg(msg, NO); break; } }
	MyLog("videoFrameLoop end %d", logCNT);
	if (audioOut != nil) [audioOut stopRecording];
	[writer endSessionAtSourceTime:(CMTime){self.playTime, TIME_SCALE, 1, 0}];
	[writer finishWritingWithCompletionHandler:^{
		MyLog("Finalization completed");
		[self saveVideoMovieWithHandler:completionHandler];
	}];
}
- (instancetype)initWithImgRep:(NSBitmapImageRep *)imgRep view:(NSView *)v
	session:(AVCaptureSession *)ses {
	if (!(self = [super init])) return nil;
#ifdef DEBUG_I
	if (logFD == NULL) {
		logFD = fopen("tmp/CrazyMirror2.log", "w");
		MyAssert(logFD, @"Couldn't make logfile (%d).", errno)
	}
	MyLog("MediaShare was initialized.");
#endif
	view = v;
	frameQue = NSMutableArray.new;
	queLock = NSConditionLock.new;

	NSFileManager *fmn = NSFileManager.defaultManager;
	NSInteger ID = preferences.videoCount;
	while (URL == nil) {
		NSString *filePath = [NSString stringWithFormat:@"%@Video_%05ld.MOV", fnPrefix, ID];
		if ([fmn fileExistsAtPath:filePath]) ID ++;
		else if ((URL = [NSURL fileURLWithPath:filePath]) == nil)
			{ err_msg(@"Cannot make a file URL for video.", NO); return nil; }
	}
	preferences.videoCount = ID;
	NSError *error;
	writer = [AVAssetWriter assetWriterWithURL:URL fileType:AVFileTypeMPEG4 error:&error];
	if (writer == nil) { err_msg(error, NO); return nil; }	
	[NSThread detachNewThreadWithBlock:^{ [self recordingWithImg:imgRep session:ses]; }];
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
