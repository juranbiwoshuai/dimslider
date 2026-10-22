// DimSlider - 把控制中心的亮度滑块映射成「降低白点值」强度
// 亮度被强制锁在 100%，滑块只控制白点值（不改 PWM 占空比，因此不增加频闪）
//
// 代码思路与私有 API 用法参考自 jschiefner/advanced-brightness-slider-tweak (GPL-3.0)
// 白点值强度 API 来自 opa334/WhitePointModule
// 本项目同样以 GPL-3.0 发布

#import <UIKit/UIKit.h>

extern "C" {
	void MADisplayFilterPrefSetReduceWhitePointIntensity(CGFloat intensity);
	CGFloat MADisplayFilterPrefGetReduceWhitePointIntensity(void);
}

@interface AXSettings : NSObject
+ (id)sharedInstance;
- (BOOL)reduceWhitePointEnabled;
- (void)setReduceWhitePointEnabled:(BOOL)enabled;
@end

@interface SBDisplayBrightnessController : NSObject
- (void)setBrightnessLevel:(float)level;
- (void)setBrightnessLevel:(float)level animated:(BOOL)animated;
@end

@interface CCUICAPackageDescription : NSObject
- (NSURL *)packageURL;
@end

@interface CCUIContinuousSliderView : UIControl
@property (nonatomic, assign) BOOL isBrightnessSlider;
- (void)setValue:(float)value;
- (void)setGlyphPackageDescription:(CCUICAPackageDescription *)desc;
- (void)_handleValueChangeGestureRecognizer:(UIPanGestureRecognizer *)recognizer;
@end

static const char *kBrightnessGlyph = "file:///System/Library/ControlCenter/Bundles/DisplayModule.bundle/Brightness.ca/";

static float gSliderLevel = 1.0f;   // 0 = 最暗（白点值100%），1 = 最亮（白点值0%）
static float gPanStartLevel = 1.0f;
static BOOL  gDidInit = NO;

static float Clamp01(float v)
{
	return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
}

static void ApplySliderLevel(float level)
{
	gSliderLevel = Clamp01(level);

	CGFloat intensity = (CGFloat)(1.0f - gSliderLevel);

	AXSettings *settings = [AXSettings sharedInstance];
	if (settings && ![settings reduceWhitePointEnabled]) {
		[settings setReduceWhitePointEnabled:YES];
	}
	MADisplayFilterPrefSetReduceWhitePointIntensity(intensity);

	NSLog(@"[DimSlider] slider=%.3f intensity=%.3f", gSliderLevel, (float)intensity);
}

static void ForceFullBrightness(void)
{
	SBDisplayBrightnessController *controller = [%c(SBDisplayBrightnessController) new];
	if (!controller) return;
	if ([controller respondsToSelector:@selector(setBrightnessLevel:animated:)]) {
		[controller setBrightnessLevel:1.0f animated:NO];
	} else {
		[controller setBrightnessLevel:1.0f];
	}
}

// 亮度锁：任何写入都改成 1.0
%hook SBDisplayBrightnessController
- (void)setBrightnessLevel:(float)level
{
	%orig(1.0f);
}
- (void)setBrightnessLevel:(float)level animated:(BOOL)animated
{
	%orig(1.0f, animated);
}
%end

%hook CCUIContinuousSliderView

- (void)setGlyphPackageDescription:(CCUICAPackageDescription *)desc
{
	%orig;
	NSString *url = [[desc packageURL] absoluteString];
	self.isBrightnessSlider = [url isEqualToString:[NSString stringWithUTF8String:kBrightnessGlyph]];

	if (self.isBrightnessSlider && !gDidInit) {
		gDidInit = YES;
		gSliderLevel = Clamp01(1.0f - (float)MADisplayFilterPrefGetReduceWhitePointIntensity());
		ApplySliderLevel(gSliderLevel);
		ForceFullBrightness();
		NSLog(@"[DimSlider] initialized, restored level=%.3f", gSliderLevel);
	}
}

- (void)setValue:(float)value
{
	if (!self.isBrightnessSlider) return %orig;

	if (value >= 0.0f) {
		// 系统想同步真实亮度 → 忽略，只回写我们自己的滑块位置
		%orig(gSliderLevel);
	} else {
		%orig(-value);
	}
}

- (void)_handleValueChangeGestureRecognizer:(UIPanGestureRecognizer *)recognizer
{
	if (!self.isBrightnessSlider) return %orig;

	if ([recognizer state] == UIGestureRecognizerStateBegan) {
		gPanStartLevel = gSliderLevel;
	}

	CGPoint translation = [recognizer translationInView:self];
	float delta = -(float)(translation.y / self.frame.size.height);

	ApplySliderLevel(gPanStartLevel + delta);

	[self setValue:gSliderLevel];
}

%end

%ctor
{
	NSLog(@"[DimSlider] loaded");
}
