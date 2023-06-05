//
//  AppDelegate.h
//  CrazyMirror2
//
//  Created by Tatsuo Unemi on 2023/05/04.
//

@import Cocoa;
@import AVFoundation;
@import MetalKit;
@import simd;

#import "VecTypes.h"

extern void in_main_thread(void (^block)(void));
extern void err_msg(NSObject *object, BOOL fatal);

@interface AppDelegate : NSObject
	<NSApplicationDelegate, NSWindowDelegate>
@end

@class MediaShare, VideoRecordingView;
@interface CrazyMirror : MTKView
	<AVCaptureVideoDataOutputSampleBufferDelegate, NSMenuItemValidation> {
	NSArray<AVCaptureDevice *> *cameras;
	AVCaptureDeviceDiscoverySession *camSearch;
	AVCaptureDevice *camera;
	AVCaptureSession *ses;
	MTLRenderPipelineDescriptor *pplnStDesc;
	id<MTLLibrary> dfltLib;
	id<MTLCommandQueue> commandQueue;
	id<MTLComputePipelineState> pl4Blur, pl4Difs, pl4Copy;
	id<MTLRenderPipelineState> pipeLine;
	id<MTLBuffer> frmsBuffer, lrndBuffer,
		avrgImgBuffer, blurImgBuffer, difsImgBuffer;
	NSLock *frmsBufLock;
	simd_uint3 blurInfo;
	uint intInfo[N_INT_INFOS];
	simd_float3 floatInfo;
	BOOL isARM;
//
	IBOutlet NSToolbarItem *photoItem, *videoItem, *autoItem;
	IBOutlet NSPopUpButton *cameraPopUp, *efctPopUp;
	IBOutlet NSSwitch *autoSwitch;
	IBOutlet NSTextField *fullScrMsg;
	IBOutlet NSMenu *fullScrMenu;
	NSTimer *alternator, *fullScrMsgTimer, *cursorHidingTimer;
	CGFloat fullScrMsgClock;
	NSSound *cameraShutterSnd;
	BOOL takePhoto, recVideo, recInPortraitMode;
	NSImage *videoItemImg;
	MediaShare *mediaShare;
	VideoRecordingView *recIndicator;
}
- (IBAction)chooseEffect:(NSPopUpButton *)sender;
- (IBAction)toggleAutoAlternate:(NSSwitch *)sender;
- (IBAction)chooseEffectByMenu:(NSMenuItem *)sender;
- (IBAction)toggleAutoAltByMenu:(NSMenuItem *)sender;
@end

#define MyErrMsg(f,test,fmt,...) if ((test)==0)\
 err_msg([NSString stringWithFormat:NSLocalizedString(fmt,nil),__VA_ARGS__],f);
#define MyAssert(test,fmt,...) MyErrMsg(YES,test,fmt,__VA_ARGS__)
#define MyWarning(test,fmt,...) MyErrMsg(NO,test,fmt,__VA_ARGS__)
