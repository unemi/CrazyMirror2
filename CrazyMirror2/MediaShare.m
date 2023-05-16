//
//  MediaShare.m
//  Crazy Mirror 2
//
//  Created by Tatsuo Unemi on 2023/05/13.
//

#import "MediaShare.h"
#import "AppDelegate.h"
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
static NSURL *photos_URL(NSWorkspace *wkspc) {
	return [wkspc URLForApplicationWithBundleIdentifier:@"com.apple.Photos"];
}
- (void)windowDidLoad {
	msgTxt.stringValue = message;
	NSWorkspace *wkspc = NSWorkspace.sharedWorkspace;
	openPhotosBtn.image = [wkspc iconForFile:photos_URL(wkspc).path];
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
static MyNotification *myNotification = nil;
static void show_notification(NSString *message, NSView *view) {
	void (^block)(void) = ^{
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
	};
	if (NSThread.isMainThread) block();
	else dispatch_async(dispatch_get_main_queue(), block);
}
void share_as_photo(NSBitmapImageRep *imgRep,
	NSInteger ID, NSView *view, void (^handler)(void)) {
	[PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
		NSURL *fileURL = [NSURL fileURLWithPath:
			[NSString stringWithFormat:@"CrazyMirror2Photo_%05ld.HEIC", ID]];
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
		MyWarning(success, @"Photo %@", error.localizedDescription)
		else {
			handler();
			show_notification(@"Took a photo.", view);
		}
	}];
}

#ifdef DEBUG_I
static FILE *logFD = NULL;
#endif

@interface MediaShare () {
	NSView *view;
	NSURL *URL;
	AVAssetWriter *writer;
	struct timeval startTime;
	NSMutableArray<NSArray *> *frameQue;
	NSConditionLock *queLock;
}
@end

@implementation MediaShare
- (void)thread:(NSBitmapImageRep *)imgRep {
	MyLog("Thread start\n");
	NSFileManager *fmn = NSFileManager.defaultManager;
	@try {
		while (URL == nil) {
			NSString *filePath = [NSString stringWithFormat:@"CrazyMirror2Video_%05ld.MOV", _ID];
			if ([fmn fileExistsAtPath:filePath]) _ID ++;
			else if ((URL = [NSURL fileURLWithPath:filePath]) == nil)
				@throw @"Cannot make a file URL.";
		}
		NSError *error;
		writer = [AVAssetWriter assetWriterWithURL:URL fileType:AVFileTypeMPEG4 error:&error];
		if (writer == nil) @throw error;
		AVAssetWriterInput *imageInput = [AVAssetWriterInput
			assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:
			@{AVVideoWidthKey:@(imgRep.pixelsWide), AVVideoHeightKey:@(imgRep.pixelsHigh),
			  AVVideoCodecKey:AVVideoCodecTypeHEVC}];
		imageInput.expectsMediaDataInRealTime = YES;
		AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
			assetWriterInputPixelBufferAdaptorWithAssetWriterInput:imageInput
			sourcePixelBufferAttributes:nil];
		[writer addInput:imageInput];
		if (![writer startWriting]) @throw error;
		[writer startSessionAtSourceTime:kCMTimeZero];
	MyLog("Loop start\n");
		while (imageInput.readyForMoreMediaData) {
			[queLock lockWhenCondition:YES];
			NSArray *task = nil; BOOL cond = NO;
			if (frameQue != nil && frameQue.count > 0) {
				task = frameQue[0];
				[frameQue removeObjectAtIndex:0];
				cond = frameQue.count > 0;
			}
			[queLock unlockWithCondition:cond];
			if (task == nil) break;
			NSBitmapImageRep *imgRep = task[0];
			CMTimeValue playTime = [task[1] integerValue];
			CVPixelBufferRef pixBuffer;
			OSStatus status = CVPixelBufferCreateWithBytes(NULL,
				imgRep.pixelsWide, imgRep.pixelsHigh, kCVPixelFormatType_32ARGB,
				imgRep.bitmapData, imgRep.bytesPerRow, NULL, NULL, NULL, &pixBuffer);
			if (status != noErr) @throw @"Cannot make CVPixelBuffer";
			BOOL result = [adaptor appendPixelBuffer:pixBuffer
				withPresentationTime:(CMTime){playTime, TIME_SCALE, 1, 0}];
			CFRelease(pixBuffer);
			if (!result) @throw @"Cannot append a frame image.";
		}
	MyLog("Loop end\n");
	} @catch (NSString *msg) {
		err_msg(msg, NO);
	} @catch (NSError *error) {
		err_msg(error.localizedDescription, NO);
	}
	[queLock lock];
	frameQue = nil;
	[queLock unlock];
	MyLog("Thread end\n");
}
- (instancetype)initWithImgRep:(NSBitmapImageRep *)imgRep
	ID:(NSInteger)ID view:(NSView *)v {
	if (!(self = [super init])) return nil;
#ifdef DEBUG_I
	if (logFD == NULL) {
		logFD = fopen("tmp/CrazzyMirror2.log", "w");
		MyAssert(logFD, @"Couldn't make logfile (%d).", errno)
	}
	MyLog("MediaShare was initialized.\n")
#endif
	_ID = ID;
	view = v;
	frameQue = NSMutableArray.new;
	queLock = NSConditionLock.new;
	[NSThread detachNewThreadSelector:@selector(thread:) toTarget:self withObject:imgRep];
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
	MyLog("Finalization start\n");
	[queLock lock];
	frameQue = nil;
	[queLock unlockWithCondition:YES];
	[writer endSessionAtSourceTime:(CMTime){self.playTime, TIME_SCALE, 1, 0}];
	NSURL *videoFileURL = URL;
	[writer finishWritingWithCompletionHandler:^{
	MyLog("Finalization completed\n");
		[PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
			PHAssetResourceCreationOptions *option = PHAssetResourceCreationOptions.new;
			option.shouldMoveFile = YES;
			[PHAssetCreationRequest.creationRequestForAsset
				addResourceWithType:PHAssetResourceTypeVideo fileURL:videoFileURL options:option];
		} completionHandler:^(BOOL success, NSError * _Nullable error) {
			MyWarning(success, @"%@", error)
			else {
				handler();
				show_notification(@"Record a video.", self->view);
			}
		}];
	}];
	MyLog("Finalization submitted\n");
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
