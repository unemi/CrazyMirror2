//
//  Preferences.m
//  Crazy Mirror 2
//
//  Created by Tatsuo Unemi on 2023/05/21.
//

#import "Preferences.h"

static NSString *keyStartWithFullScr = @"StartWithFullScreen",
	*keyStartWithAuto = @"StartWithAuto", *keyAutoInterval = @"AutoInterval",
	*keySaveModeForPhoto = @"SaveModeForPhoto", *keySaveModeForVideo = @"SaveModeForVideo";
static NSString *keyPhotoCount = @"PhotoCount", *keyVideoCount = @"VideoCount";
NSString *noteIntervalChanged = @"IntervalDidChange";

PreferenceData *preferences;

NSURL *photos_URL(NSWorkspace *wkspc) {
	return [wkspc URLForApplicationWithBundleIdentifier:@"com.apple.Photos"];
}
NSImage *photos_app_icon(void) {
	NSWorkspace *wkspc = NSWorkspace.sharedWorkspace;
	return [wkspc iconForFile:photos_URL(wkspc).path];
}

@implementation PreferenceData
- (instancetype)init {
	if ((self = [super init]) == nil) return nil;
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	NSNumber *num;
	if ((num = [ud objectForKey:keyStartWithFullScr])) _startFullScr = num.boolValue;
	if ((num = [ud objectForKey:keyStartWithAuto])) _startAuto = num.boolValue;
	if ((num = [ud objectForKey:keySaveModeForPhoto])) _svPhoto = num.intValue;
	if ((num = [ud objectForKey:keySaveModeForVideo])) _svVideo = num.intValue;
	if ((num = [ud objectForKey:keyPhotoCount])) _photoCount = num.integerValue;
	if ((num = [ud objectForKey:keyVideoCount])) _videoCount = num.integerValue;
	if ((num = [ud objectForKey:keyAutoInterval])) _interval = num.doubleValue;
	else _interval = 10.; // factory default
	return self;
}
- (void)save {
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	[ud setBool:_startFullScr forKey:keyStartWithFullScr];
	[ud setBool:_startAuto forKey:keyStartWithAuto];
	[ud setInteger:_svPhoto forKey:keySaveModeForPhoto];
	[ud setInteger:_svVideo forKey:keySaveModeForVideo];
	[ud setDouble:_interval forKey:keyAutoInterval];
}
- (void)incPhotoCount {
	[NSUserDefaults.standardUserDefaults setInteger:(++ _photoCount) forKey:keyPhotoCount];
}
- (void)incVideoCount {
	[NSUserDefaults.standardUserDefaults setInteger:(++ _videoCount) forKey:keyVideoCount];
}
@end

@interface Preferences () {
	IBOutlet NSButton *startFullScrCBox, *startAutoCBox;
	IBOutlet NSPopUpButton *svPhotoPopUp, *svVideoPopUp;
	IBOutlet NSTextField *intervalDgt;
}
@end
@implementation Preferences
- (NSString *)windowNibName { return @"Preferences"; }
- (void)windowDidLoad {
    [super windowDidLoad];
	NSString *path = NSBundle.mainBundle.resourcePath;
	do { path = [path stringByDeletingLastPathComponent]; }
	while ( ![path hasSuffix:@".app"] );
	self.window.representedFilename = path;
    startFullScrCBox.state = preferences.startFullScr;
    startAutoCBox.state = preferences.startAuto;
    intervalDgt.doubleValue = preferences.interval;
    [svPhotoPopUp selectItemAtIndex:preferences.svPhoto];
    [svVideoPopUp selectItemAtIndex:preferences.svVideo];
    NSImage *photosIcon = photos_app_icon();
    photosIcon.size = (NSSize){16, 16};
    [svPhotoPopUp itemAtIndex:SvPhtInPhotosLib].image = photosIcon;
    [svVideoPopUp itemAtIndex:SvVidInPhotosLib].image = photosIcon;
}
- (IBAction)chooseSvPhoto:(id)sender {
	preferences.svPhoto = (SaveModeForPhoto)svPhotoPopUp.indexOfSelectedItem;
}
- (IBAction)chooseSvVideo:(id)sender {
	preferences.svVideo = (SaveModeForVideo)svVideoPopUp.indexOfSelectedItem;
}
- (IBAction)switchStartFullScr:(id)sender {
	preferences.startFullScr = (BOOL)startFullScrCBox.state;
}
- (IBAction)switchAuto:(id)sender {
	preferences.startAuto = (BOOL)startAutoCBox.state;
}
- (IBAction)changeInterval:(id)sender {
	preferences.interval = intervalDgt.doubleValue;
	[NSNotificationCenter.defaultCenter postNotificationName:noteIntervalChanged object:nil];
}
//
- (void)windowDidResignKey:(NSNotification *)notification {
	[preferences save];
}
@end
