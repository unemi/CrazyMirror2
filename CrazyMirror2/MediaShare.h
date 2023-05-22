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
extern void save_photo_image(NSBitmapImageRep *imgRep, NSView *view, void (^handler)(void));

@interface MediaShare : NSObject
- (instancetype)initWithImgRep:(NSBitmapImageRep *)imgRep view:(NSView *)v;
- (BOOL)addFrameImgRep:(NSBitmapImageRep *)imgRep;
- (void)finishWithHandler:(void (^)(void))handler;
@end

@interface MyNotification : NSWindowController <NSWindowDelegate> {
	IBOutlet NSTextField *msgTxt, *timeDgt;
	IBOutlet NSButton *openPhotosBtn;
	NSTimer *timer;
	NSString *message;
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
#define MyLog(...)
#endif

NS_ASSUME_NONNULL_END
