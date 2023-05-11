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

@interface AppDelegate : NSObject
	<NSApplicationDelegate, NSWindowDelegate>
@end

@interface CrazyMirror : MTKView
	<AVCaptureVideoDataOutputSampleBufferDelegate, NSMenuItemValidation> {
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
	IBOutlet NSPopUpButton *efctPopUp;
	IBOutlet NSSwitch *autoSwitch;
	IBOutlet NSTextField *intervalDgt;
	IBOutlet NSTextField *fullScrMsg;
	NSTimer *alternator, *fullScrMsgTimer;
}
- (IBAction)chooseEffect:(NSPopUpButton *)sender;
- (IBAction)toggleAutoAlternate:(NSSwitch *)sender;
- (IBAction)chooseEffectMyMenu:(NSMenuItem *)sender;
- (IBAction)toggleAutoAltByMenu:(NSMenuItem *)sender;
@end

#define MyAssert(test,...) if ((test)==0) err_msg([NSString stringWithFormat:__VA_ARGS__]);
