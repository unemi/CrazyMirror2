//
//  Preferences.h
//  Crazy Mirror 2
//
//  Created by Tatsuo Unemi on 2023/05/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
	SvPhtInPhotosLib,
	SvPhtInPictFolder,
	SvPhtInUserFolder,
	SvPhtInPasteboard
} SaveModeForPhoto;

typedef enum {
	SvVidInPhotosLib,
	SvVidInMovieFolder,
	SvVidInUserFolder
} SaveModeForVideo;

extern NSString *noteIntervalChanged;
extern NSURL *photos_URL(NSWorkspace *wkspc);
extern NSImage *photos_app_icon(void);

@interface PreferenceData : NSObject
@property NSInteger photoCount, videoCount;
@property SaveModeForPhoto svPhoto;
@property SaveModeForVideo svVideo;
@property BOOL startFullScr, startAuto;
@property CGFloat interval;
- (void)incPhotoCount;
- (void)incVideoCount;
@end

@interface Preferences : NSWindowController <NSWindowDelegate>
@end

extern PreferenceData *preferences;

NS_ASSUME_NONNULL_END
