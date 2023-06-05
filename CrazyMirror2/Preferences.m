//
//  Preferences.m
//  Crazy Mirror 2
//
//  Created by Tatsuo Unemi on 2023/05/21.
//

#import "Preferences.h"

static NSString *keyStartWithFullScr = @"StartWithFullScreen",
	*keyStartWithAuto = @"StartWithAuto", *keyAutoInterval = @"AutoInterval",
	*keySaveModeForPhoto = @"SaveModeForPhoto", *keySaveModeForVideo = @"SaveModeForVideo",
	*keyRecAudioFrom = @"RecAudioFrom", *keyPortraitMode = @"PortraitMode";
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
static AVCaptureDeviceDiscoverySession *micSearch = nil;
NSArray<AVCaptureDevice *> *get_microphones(void) {
	if (micSearch == nil) micSearch = [AVCaptureDeviceDiscoverySession
		discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone,
			AVCaptureDeviceTypeExternalUnknown]
			mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
	return micSearch.devices;
}
@implementation PreferenceData
- (instancetype)init {
	if ((self = [super init]) == nil) return nil;
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	NSNumber *num;
	if ((num = [ud objectForKey:keyStartWithFullScr])) _startFullScr = num.boolValue;
	if ((num = [ud objectForKey:keyStartWithAuto])) _startAuto = num.boolValue;
	if ((num = [ud objectForKey:keyPortraitMode])) _portraitMode = num.boolValue;
	if ((num = [ud objectForKey:keySaveModeForPhoto])) _svPhoto = num.intValue;
	if ((num = [ud objectForKey:keySaveModeForVideo])) _svVideo = num.intValue;
	if ((num = [ud objectForKey:keyPhotoCount])) _photoCount = num.integerValue;
	if ((num = [ud objectForKey:keyVideoCount])) _videoCount = num.integerValue;
	if ((num = [ud objectForKey:keyAutoInterval])) _interval = num.doubleValue;
	else _interval = 10.; // factory default
	NSString *str;
	if ((str = [ud objectForKey:keyRecAudioFrom])) _recAudioFrom = str;
	return self;
}
- (void)save {
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	[ud setBool:_startFullScr forKey:keyStartWithFullScr];
	[ud setBool:_startAuto forKey:keyStartWithAuto];
	[ud setBool:_portraitMode forKey:keyPortraitMode];
	[ud setInteger:_svPhoto forKey:keySaveModeForPhoto];
	[ud setInteger:_svVideo forKey:keySaveModeForVideo];
	[ud setDouble:_interval forKey:keyAutoInterval];
	if (_recAudioFrom != nil) [ud setObject:_recAudioFrom forKey:keyRecAudioFrom];
	else [ud removeObjectForKey:keyRecAudioFrom];
}
- (void)incPhotoCount {
	[NSUserDefaults.standardUserDefaults setInteger:(++ _photoCount) forKey:keyPhotoCount];
}
- (void)incVideoCount {
	[NSUserDefaults.standardUserDefaults setInteger:(++ _videoCount) forKey:keyVideoCount];
}
@end

@interface Preferences () {
	IBOutlet NSButton *recAudioCBox, *startFullScrCBox, *startAutoCBox, *portraitCBox;
	IBOutlet NSPopUpButton *svPhotoPopUp, *svVideoPopUp, *audioSrcPopUp;
	IBOutlet NSTextField *intervalDgt;
}
@end
@implementation Preferences
- (NSString *)windowNibName { return @"Preferences"; }
- (void)setupMicMenu {
	[audioSrcPopUp removeAllItems];
	for (AVCaptureDevice *dev in get_microphones())
		[audioSrcPopUp addItemWithTitle:dev.localizedName];
	NSString *micName = preferences.recAudioFrom? preferences.recAudioFrom :
		[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio].localizedName;
	NSMenuItem *item = [audioSrcPopUp itemWithTitle:micName];
	if (item != nil) [audioSrcPopUp selectItem:item];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (object == micSearch) [self setupMicMenu];
}
- (void)windowDidLoad {
    [super windowDidLoad];
	NSString *path = NSBundle.mainBundle.resourcePath;
	do { path = [path stringByDeletingLastPathComponent]; }
	while ( ![path hasSuffix:@".app"] );
	self.window.representedFilename = path;
	recAudioCBox.state = (preferences.recAudioFrom != nil);
    startFullScrCBox.state = preferences.startFullScr;
    startAutoCBox.state = preferences.startAuto;
	portraitCBox.state = preferences.portraitMode;
	intervalDgt.doubleValue = preferences.interval;
    [svPhotoPopUp selectItemAtIndex:preferences.svPhoto];
    [svVideoPopUp selectItemAtIndex:preferences.svVideo];
    NSImage *photosIcon = photos_app_icon();
    photosIcon.size = (NSSize){16, 16};
    [svPhotoPopUp itemAtIndex:SvPhtInPhotosLib].image = photosIcon;
    [svVideoPopUp itemAtIndex:SvVidInPhotosLib].image = photosIcon;
	[self setupMicMenu];
	[micSearch addObserver:self forKeyPath:@"devices"
		options:NSKeyValueObservingOptionNew context:NULL];
}
- (IBAction)chooseSvPhoto:(id)sender {
	preferences.svPhoto = (SaveModeForPhoto)svPhotoPopUp.indexOfSelectedItem;
}
- (IBAction)chooseSvVideo:(id)sender {
	preferences.svVideo = (SaveModeForVideo)svVideoPopUp.indexOfSelectedItem;
}
- (IBAction)chooseAudioSrc:(id)sender {
	if (recAudioCBox.state) preferences.recAudioFrom = audioSrcPopUp.titleOfSelectedItem;
}
- (IBAction)switchRecAudio:(id)sender {
	preferences.recAudioFrom = recAudioCBox.state?
		audioSrcPopUp.titleOfSelectedItem : nil;
}
- (IBAction)switchPortraitMode:(id)sender {
	preferences.portraitMode = (BOOL)portraitCBox.state;
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
