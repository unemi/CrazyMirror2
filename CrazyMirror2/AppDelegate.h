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
// interval of auto-alternation of effects in second.
#define AUTO_INTERVAL 10.

extern void err_msg(NSString *msg, BOOL fatal);

@interface AppDelegate : NSObject
	<NSApplicationDelegate, NSWindowDelegate>
@end

@class MediaShare;
@interface CrazyMirror : MTKView
	<AVCaptureVideoDataOutputSampleBufferDelegate, NSMenuItemValidation> {
	NSArray<AVCaptureDevice *> *cameras;
	AVCaptureDeviceDiscoverySession *devSearch;
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
	IBOutlet NSToolbarItem *photoItem, *videoItem;
	IBOutlet NSPopUpButton *cameraPopUp, *efctPopUp;
	IBOutlet NSSwitch *autoSwitch;
	IBOutlet NSTextField *intervalDgt;
	IBOutlet NSTextField *fullScrMsg;
	NSTimer *alternator, *fullScrMsgTimer;
	NSSound *cameraShutterSnd;
	BOOL takePhoto, recVideo;
	NSImage *videoItemImg;
	MediaShare *mediaShare;
}
- (IBAction)chooseEffect:(NSPopUpButton *)sender;
- (IBAction)toggleAutoAlternate:(NSSwitch *)sender;
- (IBAction)chooseEffectMyMenu:(NSMenuItem *)sender;
- (IBAction)toggleAutoAltByMenu:(NSMenuItem *)sender;
@end

#define MyErrMsg(f,test,fmt,...) if ((test)==0)\
 err_msg([NSString stringWithFormat:NSLocalizedString(fmt,nil),__VA_ARGS__],f);
#define MyAssert(test,fmt,...) MyErrMsg(YES,test,fmt,__VA_ARGS__)
#define MyWarning(test,fmt,...) MyErrMsg(NO,test,fmt,__VA_ARGS__)
