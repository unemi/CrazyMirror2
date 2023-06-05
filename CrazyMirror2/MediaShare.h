//
//  MediaShare.h
//  Crazy Mirror 2
//
//  Created by Tatsuo Unemi on 2023/05/13.
//

@import Cocoa;
@import AVFoundation;
@import Photos;
@import simd;

NS_ASSUME_NONNULL_BEGIN

extern void clear_useless_video_files(void);
extern BOOL setup_input_device(AVCaptureSession *ses, AVCaptureDevice *dev, AVMediaType mediaType);
extern void save_photo_image(NSBitmapImageRep *imgRep, NSView *view, void (^handler)(void));

@interface MediaShare : NSObject <AVCaptureFileOutputRecordingDelegate>
- (instancetype)initWithImgRep:(NSBitmapImageRep *)imgRep view:(NSView *)v
	session:(AVCaptureSession *)ses;
- (BOOL)addFrameImgRep:(NSBitmapImageRep *)imgRep;
- (void)finishWithHandler:(void (^)(void))handler;
@end

@interface MyNotification : NSWindowController <NSWindowDelegate> {
	IBOutlet NSTextField *msgTxt, *infoTxt, *timeDgt;
	IBOutlet NSButton *lookupBtn;
	NSURL *URL;
	NSTimer *timer;
}
@end

@interface VideoRecordingView : NSControl {
	CGFloat cycleTime;
	NSTimer *timer;
	SEL action;
	NSObject *target;
}
- (instancetype)initWithItem:(NSToolbarItem *)item;
- (void)startAnimation;
- (void)stopAnimation;
@end

//#define DEBUG_I
#ifndef DEBUG_I
#ifndef DEBUG
#define MyLog(...)
#else
#define MyLog(...) NSLog(@__VA_ARGS__)
#endif
#endif

NS_ASSUME_NONNULL_END
