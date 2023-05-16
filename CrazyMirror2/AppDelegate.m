//
//  AppDelegate.m
//  CrazyMirror2
//
//  Created by Tatsuo Unemi on 2023/05/04.
//

#import "AppDelegate.h"
#import "MediaShare.h"
#include <sys/time.h>
#include <sys/sysctl.h>

static unsigned long current_time_ms(void) {
// returns elapsed time in millisecond since the first call
	static time_t startSec = 0;
	struct timeval tm;
	gettimeofday(&tm, NULL);
	if (startSec == 0) startSec = tm.tv_sec;
	return (tm.tv_sec - startSec) * 1000 + tm.tv_usec / 1000;
}
void err_msg(NSString *msg, BOOL fatal) {
	void (^block)(void) = ^{
		NSAlert *alt = NSAlert.new;
		alt.alertStyle = NSAlertStyleCritical;
		alt.messageText = msg;
		[alt runModal];
		if (fatal) [NSApp terminate:nil];
	};
	if (NSThread.isMainThread) block();
	else dispatch_async(dispatch_get_main_queue(), block);
}
static BOOL check_hw_arch(void) {
	int mib[2] = { CTL_HW, HW_MACHINE };
	size_t dataSize = 128;
	char archName[128];
	memset(archName, 0, 128);
	if (sysctl(mib, 2, archName, &dataSize, NULL, 0) < 0)
		err_msg(@"Couldn't get architecture type.", YES);
	return strcmp(archName, "x86_64") != 0;
}
struct {
	NSString *name;
	uint argMask;
} Effects[] = {
	{@"hnalalaa", 0},
	{@"howawaan", ArgAvrgMask},
	{@"zjvdgycboo", ArgAvrgMask | ArgBlurMask},
	{@"hnolelee", ArgAvrgMask | ArgBlurMask},
	{@"shavazzz", ArgLRndMask},
	{@"hahehohu", ArgAvrgMask | ArgBlurMask | ArgDifsMask}
};
static NSString *keyPhotoCount = @"PhotoCount", *keyVideoCount = @"VideoCount";

@implementation NSMenu (MyExtension)
- (void)addItemWithToolbarItem:(NSToolbarItem *)tbItem {
	NSMenuItem *newItem = [self addItemWithTitle:tbItem.label
		action:tbItem.action keyEquivalent:@""];
	newItem.target = tbItem.target;
	newItem.image = tbItem.image;
}
@end

@implementation CrazyMirror
- (void)setupCamera:(AVCaptureDevice *)cam {
	NSError *error;
	AVCaptureDeviceInput *devIn = [AVCaptureDeviceInput deviceInputWithDevice:cam error:&error];
	MyWarning(devIn, @"Cannot make a video device input. %@", error);
	if (devIn == nil) return;
	AVCaptureDeviceInput *orgDevIn = nil;
	if (ses.inputs.count > 0) [ses removeInput:(orgDevIn = ses.inputs[0])];
	BOOL canAddIt = [ses canAddInput:devIn];
	MyWarning(canAddIt, @"Cannot add input.",nil)
	if (canAddIt) {
		[ses addInput:devIn];
		camera = cam;
	} else if (orgDevIn != nil) [ses addInput:orgDevIn];
}
- (void)setupCameraList:(NSArray<AVCaptureDevice *> *)camList {
	MyAssert(camList.count, @"No Camera available.",nil);
	[cameraPopUp removeAllItems];
	for (AVCaptureDevice *dev in camList)
		[cameraPopUp addItemWithTitle:dev.localizedName];
	if (camera != nil) {
		if (![camList containsObject:camera]) {
			[cameraPopUp selectItemAtIndex:0];
			[self setupCamera:camList[0]];
		} else [cameraPopUp selectItemWithTitle:camera.localizedName];
	} else [self setupCamera:camList[0]];
	cameras = camList;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
	change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
	if (object == devSearch) {
		[self setupCameraList:change[NSKeyValueChangeNewKey]];
	}
}
- (id<MTLComputePipelineState>)makeCompPL:(NSString *)name {
	id<MTLFunction> func = [dfltLib newFunctionWithName:name];
	MyAssert(func, @"Cannot make %@.", name);
	NSError *error;
	id<MTLComputePipelineState> pl =
		[self.device newComputePipelineStateWithFunction:func error:&error];
	MyAssert(pl, @"Cannot make ComputePipelineState for %@. %@", name, error);
	return pl;
}
- (void)checkHidingCursor:(id)object {
	if (!self.inFullScreenMode) return;
	if (cursorHidingTimer.isValid) [cursorHidingTimer invalidate];
	cursorHidingTimer = [NSTimer scheduledTimerWithTimeInterval:.5 repeats:NO block:
		^(NSTimer * _Nonnull timer) { [NSCursor setHiddenUntilMouseMoves:YES];}];
}
- (void)awakeFromNib {
	[super awakeFromNib];
	isARM = check_hw_arch();
	frmsBufLock = NSLock.new;
	intervalDgt.doubleValue = AUTO_INTERVAL;
//
//	Initialize capture session by default camera
	ses = AVCaptureSession.new;
	devSearch = [AVCaptureDeviceDiscoverySession
		discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera,
			AVCaptureDeviceTypeExternalUnknown]
			mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
	[self setupCameraList:devSearch.devices];
	[devSearch addObserver:self forKeyPath:@"devices"
		options:NSKeyValueObservingOptionNew context:nil];
	AVCaptureSessionPreset preset = AVCaptureSessionPreset1920x1080;
	MyAssert([ses canSetSessionPreset:preset], @"Cannot set session preset as %@.", preset);
	ses.sessionPreset = preset;
	AVCaptureVideoDataOutput *vOut = AVCaptureVideoDataOutput.new;
	MyAssert([ses canAddOutput:vOut], @"Cannot add output.",nil);
	[ses addOutput:vOut];
//	NSLog(@"%@", vOut.availableVideoCVPixelFormatTypes);
	vOut.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32ARGB)};
	dispatch_queue_t que = dispatch_queue_create("My capturing", DISPATCH_QUEUE_SERIAL);
	[vOut setSampleBufferDelegate:self queue:que];
	[ses startRunning];
//
	self.device = MTLCreateSystemDefaultDevice();
	pplnStDesc = MTLRenderPipelineDescriptor.new;
	dfltLib = self.device.newDefaultLibrary;
	pl4Blur = [self makeCompPL:@"blurFunction"];
	pl4Difs = [self makeCompPL:@"diffuseFunction"];
	pl4Copy = [self makeCompPL:@"copyImgFunction"];
	id<MTLFunction> func = [dfltLib newFunctionWithName:@"vertexShader"];
	MyAssert(func, @"Cannot make vertexShader",nil);
	pplnStDesc.vertexFunction = func;
	MTLRenderPipelineColorAttachmentDescriptor *colAttDesc = pplnStDesc.colorAttachments[0];
	colAttDesc.pixelFormat = self.colorPixelFormat;
	commandQueue = self.device.newCommandQueue;
//
	NSMenuItem *item = [fullScrMenu itemAtIndex:0];
	[fullScrMenu removeItemAtIndex:0];
	[fullScrMenu addItemWithToolbarItem:photoItem];
	[fullScrMenu addItemWithToolbarItem:videoItem];
	[fullScrMenu addItem:NSMenuItem.separatorItem];
	NSMenu *srcMenu = efctPopUp.menu;
	for (NSInteger i = 0; i < srcMenu.numberOfItems; i ++) {
		NSMenuItem *newItem = [fullScrMenu addItemWithTitle:[srcMenu itemAtIndex:i].title
			action:@selector(chooseEffectByMenu:) keyEquivalent:@""];
		newItem.tag = i;
		newItem.target = self;
	}
	[fullScrMenu addItem:NSMenuItem.separatorItem];
	NSMenuItem *aItem = [fullScrMenu addItemWithTitle:autoItem.label
		action:@selector(toggleAutoAltByMenu:) keyEquivalent:@""];
	aItem.target = self;
	[fullScrMenu addItem:NSMenuItem.separatorItem];
	[fullScrMenu addItem:item];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(checkHidingCursor:) name:NSMenuDidEndTrackingNotification object:fullScrMenu];
//
	[self chooseEffect:efctPopUp];
	[self toggleAutoAlternate:autoSwitch];
//
	NSSize sz = self.frame.size;
	if (sz.height != sz.width * 9. / 16.) {
		NSRect winFrm = self.window.frame;
		CGFloat dH = sz.width * 9. / 16. - sz.height;
		winFrm.size.height += dH;
		winFrm.origin.y -= dH;
		[self.window setFrame:winFrm display:NO];
	}
}
//
- (id<MTLBuffer>)makeImgBufferWithSize:(NSInteger)size name:(NSString *)name {
	id<MTLBuffer> buf = [self.device newBufferWithLength:size
		options:MTLResourceStorageModePrivate];
	MyAssert(buf, @"Cannot allocate %@ image buffer of %ld bytes.", name, size);
	return buf;
}
- (void)setupBuffersWithBPR:(NSInteger)bpr width:(NSInteger)width height:(NSInteger)height {
	NSInteger bpf = bpr * height;
	FRM_IDX = FRM_NFRAMES = 0;
	FRM_BPF = (uint)bpf;	// bytes per frame
	FRM_BPR = (uint)bpr;	// bytes per row
	FRM_PPF = (uint)(width * height);
	floatInfo.x = blurInfo.x = (uint)width;
	floatInfo.y = blurInfo.y = (uint)height;
	blurInfo.z = 5;
	NSInteger size = bpf * MAX_ST_FRAMES;
	frmsBuffer = [self.device newBufferWithLength:size options:
		isARM? MTLResourceStorageModeShared : MTLResourceStorageModeManaged];
	MyAssert(frmsBuffer, @"Cannot allocate frames' buffer of %ld bytes.", size);
	size = sizeof(simd_float4) * width * height;
	avrgImgBuffer = [self makeImgBufferWithSize:size name:@"average"];
	blurImgBuffer = [self makeImgBufferWithSize:size name:@"blur"];
	difsImgBuffer = [self makeImgBufferWithSize:size*2 name:@"diffusion"];
	size = sizeof(long) * width * height;
	long *lrndMem = malloc(size);
	MyAssert(lrndMem, @"Cannot allocate memory for random integer of %ld bytes.", size);
	for (NSInteger i = 0; i < width * height; i ++) lrndMem[i] = lrand48();
	lrndBuffer = [self.device newBufferWithBytes:lrndMem
		length:size options:MTLResourceStorageModeManaged];
	MyAssert(lrndBuffer, @"Cannot allocate random integer buffer of %ld bytes.", size);
	free(lrndMem);
}
//
// AVCaptureVideoDataOutputSampleBufferDelegate
//
- (void)captureOutput:(AVCaptureOutput *)output
	didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	fromConnection:(AVCaptureConnection *)connection {
	CVImageBufferRef cvBuf = CMSampleBufferGetImageBuffer(sampleBuffer);
	NSInteger bpr = CVPixelBufferGetBytesPerRow(cvBuf),
		height = CVPixelBufferGetHeight(cvBuf), bpf = bpr * height;
	if (FRM_BPR != bpr || FRM_BPF != bpf)
		[self setupBuffersWithBPR:bpr width:CVPixelBufferGetWidth(cvBuf) height:height];
	CVPixelBufferLockBaseAddress(cvBuf, kCVPixelBufferLock_ReadOnly);
	char *baseAddr = CVPixelBufferGetBaseAddress(cvBuf);
	[frmsBufLock lock];
	if (FRM_NFRAMES > 0) FRM_IDX = (FRM_IDX + 1) % MAX_ST_FRAMES;
	memcpy((char *)frmsBuffer.contents + bpf * FRM_IDX, baseAddr, bpf);
	if (!isARM) [frmsBuffer didModifyRange:(NSRange){bpf * FRM_IDX, bpf}];
	if (FRM_NFRAMES < MAX_ST_FRAMES) FRM_NFRAMES ++;
	[frmsBufLock unlock];
	CVPixelBufferUnlockBaseAddress(cvBuf, kCVPixelBufferLock_ReadOnly);
}
//
- (void)dispatchThreads:(id<MTLComputeCommandEncoder>)cce pl:(id<MTLComputePipelineState>)pl {
	NSUInteger threadGrpSz = pl.maxTotalThreadsPerThreadgroup,
		nPixels = blurInfo.x * blurInfo.y;
	if (threadGrpSz > nPixels) threadGrpSz = nPixels;
	[cce dispatchThreads:MTLSizeMake(nPixels, 1, 1)
		threadsPerThreadgroup:MTLSizeMake(threadGrpSz, 1, 1)];
	[cce endEncoding];
}
- (void)encodeCompute:(id<MTLCommandBuffer>)cmdBuf pl:(id<MTLComputePipelineState>)pl
	arg0:(id<MTLBuffer>)arg0 ofst0:(NSInteger)ofst0
	arg1:(id<MTLBuffer>)arg1 ofst1:(NSInteger)ofst1 {
	NSInteger idx = 0;
	id<MTLComputeCommandEncoder> cce = cmdBuf.computeCommandEncoder;
	[cce setComputePipelineState:pl];
	[cce setBuffer:arg0 offset:ofst0 atIndex:idx ++];
	[cce setBuffer:arg1 offset:ofst1 atIndex:idx ++];
	[cce setBytes:&blurInfo length:sizeof(blurInfo) atIndex:idx ++];
	[self dispatchThreads:cce pl:pl];
}
static NSBitmapImageRep *make_bitmap_from_buffer(
	id<MTLBuffer> buf, NSInteger width, NSInteger height) {
	NSBitmapImageRep *imgRep = [NSBitmapImageRep.alloc initWithBitmapDataPlanes:NULL
		pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4
		hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
		bitmapFormat:NSBitmapFormatAlphaFirst
		bytesPerRow:width * 4 bitsPerPixel:32];
	simd_uchar4 *src = buf.contents, *dst = (simd_uchar4 *)imgRep.bitmapData;
	for (NSInteger i = 0; i < height; i ++)
		for (NSInteger j = 0; j < width; j ++)
			dst[(i + 1) * width - 1 - j] = src[i * width + j].wzyx;
	return imgRep;
}
- (void)stopVideoRecording {
	mediaShare = nil;
	recVideo = NO;
	self.framebufferOnly = YES;
}
- (void)drawRect:(NSRect)dirtyRect {
	if (frmsBuffer == nil) return;
	id<MTLCommandBuffer> cmdBuf = commandQueue.commandBuffer;
	NSInteger mask = Effects[EFCT_TYPE & EFCT_MASK].argMask, idx = 0,
		imgLength = blurInfo.x * blurInfo.y * sizeof(simd_float4);

	[frmsBufLock lock];
	if (mask & ArgBlurMask)
		[self encodeCompute:cmdBuf pl:pl4Blur
			arg0:frmsBuffer ofst0:FRM_IDX * FRM_BPF arg1:blurImgBuffer ofst1:0];
	if ((mask & ArgDifsMask) && (EFCT_TYPE & EFCT_CHANGED) == 0) {
		NSInteger of0 = 0, of1 = 0;
		if (EFCT_TYPE & DIFS_BACK) of0 = imgLength; else of1 = imgLength;
		[self encodeCompute:cmdBuf pl:pl4Difs
			arg0:difsImgBuffer ofst0:of0 arg1:difsImgBuffer ofst1:of1];
	}
	if ((EFCT_TYPE & EFCT_CHANGED) && (mask & (ArgAvrgMask | ArgDifsMask))) {
		id<MTLComputeCommandEncoder> cce = cmdBuf.computeCommandEncoder;
		[cce setComputePipelineState:pl4Copy];
		[cce setBytes:&mask length:sizeof(mask) atIndex:idx ++];
		[cce setBuffer:frmsBuffer offset:FRM_IDX * FRM_BPF atIndex:idx ++];
		[cce setBuffer:blurImgBuffer offset:0 atIndex:idx ++];
		[cce setBuffer:avrgImgBuffer offset:0 atIndex:idx ++];
		[cce setBuffer:difsImgBuffer offset:
			(EFCT_TYPE & DIFS_BACK)? 0 : imgLength atIndex:idx ++];
		[self dispatchThreads:cce pl:pl4Copy];
		idx = 0;
	}
	if (takePhoto && !recVideo) self.framebufferOnly = NO;
	id<MTLRenderCommandEncoder> rce =
		[cmdBuf renderCommandEncoderWithDescriptor:self.currentRenderPassDescriptor];
	NSSize viewSize = self.drawableSize;
	[rce setViewport:(MTLViewport){0., 0., viewSize.width, viewSize.height, 0., 1. }];
	[rce setRenderPipelineState:pipeLine];
	simd_float2 vertices[4] = {{-1, -1},{-1, 1},{1, -1},{1, 1}};
	[rce setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
	[rce setFragmentBytes:intInfo length:sizeof(intInfo) atIndex:idx ++];
	floatInfo.z = (current_time_ms() % 10000) / 10000.f;
	[rce setFragmentBytes:&floatInfo length:sizeof(floatInfo) atIndex:idx ++];
	[rce setFragmentBuffer:frmsBuffer offset:0 atIndex:idx ++];
	if (mask & ArgAvrgMask) [rce setFragmentBuffer:avrgImgBuffer offset:0 atIndex:idx ++];
	if (mask & ArgBlurMask) [rce setFragmentBuffer:blurImgBuffer offset:0 atIndex:idx ++];
	if (mask & ArgDifsMask) [rce setFragmentBuffer:difsImgBuffer
		offset:(EFCT_TYPE & DIFS_BACK)? 0 : imgLength atIndex:idx ++];
	if (mask & ArgLRndMask) [rce setFragmentBuffer:lrndBuffer offset:0 atIndex:idx ++];
	[rce drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
	[rce endEncoding];
	[cmdBuf presentDrawable:self.currentDrawable];

	id<MTLBuffer> frameImageBuf = nil;
	NSUInteger texW = 0, texH = 0;
	if (takePhoto || recVideo) {
		id<MTLTexture> tex = self.currentDrawable.texture;
		MyAssert(tex, @"Failed to get texture from MTKView.", nil);
		texW = tex.width; texH = tex.height;
		frameImageBuf = [tex.device newBufferWithLength:texW * texH * 4
			options:MTLResourceStorageModeShared];
		MyAssert(frameImageBuf, @"Failed to create buffer for %ld bytes.", texW * texH * 4);
		id<MTLBlitCommandEncoder> blitEnc = cmdBuf.blitCommandEncoder;
		[blitEnc copyFromTexture:tex sourceSlice:0 sourceLevel:0
			sourceOrigin:(MTLOrigin){0, 0, 0} sourceSize:(MTLSize){texW, texH, 1}
			toBuffer:frameImageBuf destinationOffset:0
			destinationBytesPerRow:texW * 4 destinationBytesPerImage:texW * texH * 4];
		[blitEnc endEncoding];
	}
	[cmdBuf commit];
	[cmdBuf waitUntilCompleted];
	[frmsBufLock unlock];
	EFCT_TYPE &= ~ EFCT_CHANGED;
	if (mask & ArgDifsMask) EFCT_TYPE ^= DIFS_BACK;
	if (takePhoto || recVideo) {
		NSBitmapImageRep *imgRep = make_bitmap_from_buffer(frameImageBuf, texW, texH);
		imgRep.size = self.bounds.size;
		if (takePhoto) {
			NSImage *orgImg = photoItem.image;
			photoItem.image = [NSImage imageWithSystemSymbolName:
				@"camera.fill" accessibilityDescription:nil];
			if (cameraShutterSnd == nil) cameraShutterSnd = [NSSound soundNamed:@"CameraShutter"];
			[cameraShutterSnd play];
			NSInteger photoCount = [NSUserDefaults.standardUserDefaults integerForKey:keyPhotoCount];
			share_as_photo(imgRep, photoCount, self, ^{
				self->photoItem.image = orgImg;
				[NSUserDefaults.standardUserDefaults
					setInteger:photoCount + 1 forKey:keyPhotoCount];});
			takePhoto = NO;
			if (!recVideo) self.framebufferOnly = YES;
		}
		if (recVideo) {
			if (mediaShare == nil) mediaShare = [MediaShare.alloc initWithImgRep:imgRep
				ID:[NSUserDefaults.standardUserDefaults integerForKey:keyVideoCount] view:self];
			if (![mediaShare addFrameImgRep:imgRep]) [self stopVideoRecording];
		}
	}
}
//
- (void)showFullScrMessage {
	if (fullScrMsgTimer.isValid) [fullScrMsgTimer invalidate];
	else {
		[fullScrMsg sizeToFit];
		NSRect msgRct = fullScrMsg.frame, scrBnds = self.bounds;
		msgRct.origin = (NSPoint){
			scrBnds.origin.x + (scrBnds.size.width - msgRct.size.width) / 2.,
			scrBnds.origin.y + (scrBnds.size.height - msgRct.size.height) / 2
		};
		[fullScrMsg setFrameOrigin:msgRct.origin];
		[self addSubview:fullScrMsg];
	}
	fullScrMsgClock = 0.;
	fullScrMsgTimer = [NSTimer scheduledTimerWithTimeInterval:1/30. repeats:YES
		block:^(NSTimer * _Nonnull timer) {
		if ((self->fullScrMsgClock += 1/90.) >= 1.) {
			[self->fullScrMsg removeFromSuperview];
			[timer invalidate];
		}
		self->fullScrMsg.alphaValue = (1. - pow(self->fullScrMsgClock, 2.)) * .6;
	}];
}
- (void)setupRecordingIndicator {
	if (recIndicator == nil) {
		recIndicator = [VideoRecordingView.alloc initWithItem:videoItem];
		videoItemImg = videoItem.image;
	}
	if (self.inFullScreenMode) {
		[recIndicator setFrameOrigin:(NSPoint){10, NSMaxY(self.bounds) - 30}];
		[self addSubview:recIndicator];
	} else {
		videoItem.image = nil;
		videoItem.view = recIndicator;
	}
	[recIndicator startAnimation];
}
- (void)resignRecordingIndicator {
	[recIndicator stopAnimation];
	if (self.inFullScreenMode) {
		[recIndicator removeFromSuperview];
	} else {
		videoItem.view = nil;
		videoItem.image = videoItemImg;
		videoItem.target = self;
		videoItem.action = @selector(recordVideo:);
	}
}
- (void)stopFullScreen {
	if (fullScrMsgTimer.isValid) {
		fullScrMsgClock = 1.;
		[fullScrMsgTimer fire];
	}
	if (recVideo) [self resignRecordingIndicator];
	for (NSView *view in self.subviews) {
		[view removeFromSuperview];
		if ([view isKindOfClass:VideoRecordingView.class])
			videoItem.view = view;
	}
	[self exitFullScreenModeWithOptions:nil];
	[NSCursor setHiddenUntilMouseMoves:NO];
	self.menu = nil;
	if (recVideo) [self setupRecordingIndicator];
}
- (void)keyDown:(NSEvent *)event {
	// ESC key stops full screen
	if (self.inFullScreenMode) {
		if (event.keyCode == 53) [self stopFullScreen];
		else if ((event.modifierFlags & (NSEventModifierFlagOption|NSEventModifierFlagCommand)) == 0)
			[self showFullScrMessage];
		else [super keyDown:event];
	} else [super keyDown:event];
}
//
- (IBAction)chooseCamera:(id)sender {
	AVCaptureDevice *newCam = cameras[cameraPopUp.indexOfSelectedItem];
	if (newCam != camera) [self setupCamera:newCam];
}
- (IBAction)takePhoto:(id)sender {
	takePhoto = YES;
}
- (IBAction)recordVideo:(id)sender {
	if (recVideo) {
		NSInteger ID = mediaShare.ID;
		[mediaShare finishWithHandler:^{
			[NSUserDefaults.standardUserDefaults setInteger:ID + 1 forKey:keyVideoCount];
		}];
		[self stopVideoRecording];
		[self resignRecordingIndicator];
	} else {
		recVideo = YES;
		self.framebufferOnly = NO;
		[self setupRecordingIndicator];
	}
}
- (IBAction)resizeWindow:(NSMenuItem *)item {
	if (self.inFullScreenMode) return;
	NSSize size, vSize = self.frame.size;
	sscanf(item.title.UTF8String, "%lf x %lf", &size.width, &size.height);
	NSRect winFrm = self.window.frame;
	winFrm.size.width += size.width - vSize.width;
	winFrm.size.height += size.height - vSize.height;
	winFrm.origin.x -= (size.width - vSize.width) / 2.;
	winFrm.origin.y -= size.height - vSize.height;
	[self.window setFrame:winFrm display:YES animate:YES];
}
- (IBAction)fullscreen:(id)sender {	// for Tool bar button
	if (recVideo) [self resignRecordingIndicator];
	[self enterFullScreenMode:self.window.screen withOptions:
		@{NSFullScreenModeAllScreens:@NO}];
	[NSCursor setHiddenUntilMouseMoves:YES];
	self.menu = fullScrMenu;
	[self showFullScrMessage];
	if (recVideo) [self setupRecordingIndicator];
}
- (IBAction)toggleFullScreen:(id)sender { // for Menu bar menu item
	if (self.inFullScreenMode) [self stopFullScreen];
	else [self fullscreen:sender];
}
- (IBAction)chooseEffect:(NSPopUpButton *)sender {
	NSInteger efctType = (uint)sender.indexOfSelectedItem;
	NSString *shaderName = Effects[efctType].name;
	id<MTLFunction> func = [dfltLib newFunctionWithName:shaderName];
	MyAssert(func, @"Cannot make shader function for %@.", shaderName);
	pplnStDesc.fragmentFunction = func;
	NSError *error;
	pipeLine = [self.device newRenderPipelineStateWithDescriptor:pplnStDesc error:&error];
	MyAssert(pipeLine, @"Cannot make RenderPipelineState. %@", error);
	EFCT_TYPE = (uint)efctType | EFCT_CHANGED;
}
- (void)alternateEffect:(NSTimer *)timer {
	NSInteger efctType = ((EFCT_TYPE & EFCT_MASK) + 1) % efctPopUp.numberOfItems;
	[efctPopUp selectItemAtIndex:efctType];
	[self chooseEffect:efctPopUp];
}
- (IBAction)toggleAutoAlternate:(NSSwitch *)sender {
	if (sender.state) {
		if (alternator == nil) alternator =
			[NSTimer scheduledTimerWithTimeInterval:intervalDgt.doubleValue
				target:self selector:@selector(alternateEffect:)
				userInfo:nil repeats:YES];
	} else if (alternator != nil) {
		[alternator invalidate]; alternator = nil;
	}
}
- (IBAction)chooseEffectByMenu:(NSMenuItem *)sender {
	[efctPopUp selectItemAtIndex:sender.tag];
	[self chooseEffect:efctPopUp];
}
- (IBAction)toggleAutoAltByMenu:(NSMenuItem *)sender {
	[autoSwitch performClick:nil];
}
- (IBAction)changeInteral:(NSTextField *)sender {
	CGFloat newValue = sender.doubleValue;
	if (alternator != nil) {
		[alternator invalidate];
		alternator = [NSTimer scheduledTimerWithTimeInterval:newValue
			target:self selector:@selector(alternateEffect:)
			userInfo:nil repeats:YES];
	}
}
- (IBAction)toggleToolbarShown:(id)sender {
	[self.window toggleToolbarShown:sender];
}
//
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	SEL action = menuItem.action;
	if (action == @selector(chooseEffectByMenu:))
		menuItem.state = (EFCT_TYPE & EFCT_MASK) == menuItem.tag;
	else if (action == @selector(toggleAutoAltByMenu:))
		menuItem.state = alternator != nil;
	else if (action == @selector(toggleToolbarShown:))
		menuItem.title = NSLocalizedString(
			self.window.toolbar.visible? @"Hide Toolbar" : @"Show Toolbar", nil);
	else if (action == @selector(recordVideo:))
		menuItem.state = recVideo;
	else if (action == @selector(resizeWindow:))
		return !self.inFullScreenMode;
	return YES;
}
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	clear_useless_video_files();
}
//- (void)applicationWillTerminate:(NSNotification *)aNotification {
//}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
	return YES;
}
- (void)windowWillClose:(NSNotification *)notification {
	[NSApp terminate:nil];
}
@end
