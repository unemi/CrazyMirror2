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
extern void share_as_photo(NSBitmapImageRep *imgRep,
	NSInteger ID, NSWindow *parent, void (^handler)(void));

@interface MediaShare : NSObject
@property (readonly) NSInteger ID;
- (instancetype)initWithImgRep:(NSBitmapImageRep *)imgRep
	ID:(NSInteger)ID parent:(NSWindow *)pwin;
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
- (void)stopAnimation;
@end

NS_ASSUME_NONNULL_END
