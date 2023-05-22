//
//  Preferences.m
//  Crazy Mirror 2
//
//  Created by Tatsuo Unemi on 2023/05/21.
//

#import "Preferences.h"

static NSString *keyStartWithFullScr = @"StartWithFullScreen",
	*keySaveModeForPhoto = @"SaveModeForPhoto", *keySaveModeForVideo = @"SaveModeForVideo";
static NSString *keyPhotoCount = @"PhotoCount", *keyVideoCount = @"VideoCount";

PreferenceData *preferences;

@implementation PreferenceData
- (instancetype)init {
	if ((self = [super init]) == nil) return nil;
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	NSNumber *num;
	if ((num = [ud objectForKey:keyStartWithFullScr])) _startFullScr = num.boolValue;
	if ((num = [ud objectForKey:keySaveModeForPhoto])) _svPhoto = num.intValue;
	if ((num = [ud objectForKey:keySaveModeForVideo])) _svVideo = num.intValue;
	if ((num = [ud objectForKey:keyPhotoCount])) _photoCount = num.integerValue;
	if ((num = [ud objectForKey:keyVideoCount])) _videoCount = num.integerValue;
	return self;
}
- (void)save {
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	[ud setBool:_startFullScr forKey:keyStartWithFullScr];
	[ud setInteger:_svPhoto forKey:keySaveModeForPhoto];
	[ud setInteger:_svVideo forKey:keySaveModeForVideo];
}
- (void)incPhotoCount {
	[NSUserDefaults.standardUserDefaults setInteger:(++ _photoCount) forKey:keyPhotoCount];
}
- (void)incVideoCount {
	[NSUserDefaults.standardUserDefaults setInteger:(++ _videoCount) forKey:keyVideoCount];
}
@end

@interface Preferences () {
	IBOutlet NSButton *startFullScrBtn;
	IBOutlet NSPopUpButton *svPhotoPopUp, *svVideoPopUp;
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
    startFullScrBtn.state = preferences.startFullScr;
    [svPhotoPopUp selectItemAtIndex:preferences.svPhoto];
    [svVideoPopUp selectItemAtIndex:preferences.svVideo];
}
- (IBAction)chooseSvPhoto:(id)sender {
	preferences.svPhoto = (SaveModeForPhoto)svPhotoPopUp.indexOfSelectedItem;
}
- (IBAction)chooseSvVideo:(id)sender {
	preferences.svVideo = (SaveModeForVideo)svVideoPopUp.indexOfSelectedItem;
}
- (IBAction)switchStartFullScr:(id)sender {
	preferences.startFullScr = (BOOL)startFullScrBtn.state;
}
//
- (void)windowDidResignKey:(NSNotification *)notification {
	[preferences save];
}
@end
