// DimSlider - 把控制中心的亮度滑块映射成「降低白点值」强度
// 亮度被强制锁在 100%，滑块只控制白点值（不改 PWM 占空比，因此不增加频闪）
//
// 代码思路与私有 API 用法参考自 jschiefner/advanced-brightness-slider-tweak (GPL-3.0)
// 白点值强度 API 来自 opa334/WhitePointModule
// 本项目同样以 GPL-3.0 发布

#import <UIKit/UIKit.h>
#import <dlfcn.h>

// 私有类一律运行时用 NSClassFromString 拿，避免链接期依赖私有框架
@protocol AXSettingsProtocol <NSObject>
- (BOOL)reduceWhitePointEnabled;
- (void)setReduceWhitePointEnabled:(BOOL)enabled;
@end

typedef void (*SetRWPIntensityFn)(CGFloat);
typedef CGFloat (*GetRWPIntensityFn)(void);

@interface SBDisplayBrightnessController : NSObject
- (void)setBrightnessLevel:(float)level;
- (void)setBrightnessLevel:(float)level animated:(BOOL)animated;
@end

@interface CCUICAPackageDescription : NSObject
- (NSURL *)packageURL;
@end

@interface CCUIContinuousSliderView : UIControl
- (void)setValue:(float)value;
- (void)setGlyphPackageDescription:(CCUICAPackageDescription *)desc;
- (void)_handleValueChangeGestureRecognizer:(UIPanGestureRecognizer *)recognizer;
@end

static const char *kBrightnessGlyph = "file:///System/Library/ControlCenter/Bundles/DisplayModule.bundle/Brightness.ca/";

static __weak CCUIContinuousSliderView *gSliderView = nil;
static float gSliderLevel = 1.0f;   // 0 = 最暗（白点值 100%），1 = 最亮（白点值 0%）
static float gPanStartLevel = 1.0f;
static BOOL  gDidInit = NO;

static float Clamp01(float v)
{
	return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
}

static id<AXSettingsProtocol> AXSettingsInstance(void)
{
	static id instance = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		Class cls = NSClassFromString(@"AXSettings");
		if ([cls respondsToSelector:@selector(sharedInstance)]) {
			instance = (id)[cls performSelector:@selector(sharedInstance)];
		}
	});
	return instance;
}

static void *MediaAccessibilityHandle(void)
{
	static void *handle = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		handle = dlopen("/System/Library/Frameworks/MediaAccessibility.framework/MediaAccessibility", RTLD_LAZY);
	});
	return handle;
}

static SetRWPIntensityFn SetIntensityFn(void)
{
	static SetRWPIntensityFn fn = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		void *handle = MediaAccessibilityHandle();
		if (handle) {
			fn = (SetRWPIntensityFn)dlsym(handle, "MADisplayFilterPrefSetReduceWhitePointIntensity");
		}
		if (!fn) {
			fn = (SetRWPIntensityFn)dlsym(RTLD_DEFAULT, "MADisplayFilterPrefSetReduceWhitePointIntensity");
		}
	});
	return fn;
}

static GetRWPIntensityFn GetIntensityFn(void)
{
	static GetRWPIntensityFn fn = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		void *handle = MediaAccessibilityHandle();
		if (handle) {
			fn = (GetRWPIntensityFn)dlsym(handle, "MADisplayFilterPrefGetReduceWhitePointIntensity");
		}
		if (!fn) {
			fn = (GetRWPIntensityFn)dlsym(RTLD_DEFAULT, "MADisplayFilterPrefGetReduceWhitePointIntensity");
		}
	});
	return fn;
}

static void ApplySliderLevel(float level)
{
	gSliderLevel = Clamp01(level);

	CGFloat intensity = (CGFloat)(1.0f - gSliderLevel);

	id<AXSettingsProtocol> settings = AXSettingsInstance();
	if (settings && ![settings reduceWhitePointEnabled]) {
		[settings setReduceWhitePointEnabled:YES];
	}

	SetRWPIntensityFn setFn = SetIntensityFn();
	if (setFn) {
		setFn(intensity);
	}

	NSLog(@"[DimSlider] slider=%.3f intensity=%.3f", gSliderLevel, (float)intensity);
}

static void ForceFullBrightness(void)
{
	Class cls = NSClassFromString(@"SBDisplayBrightnessController");
	if (!cls) return;

	SBDisplayBrightnessController *controller = (SBDisplayBrightnessController *)[[cls alloc] init];
	if (!controller) return;

	if ([controller respondsToSelector:@selector(setBrightnessLevel:animated:)]) {
		[controller setBrightnessLevel:1.0f animated:NO];
	} else if ([controller respondsToSelector:@selector(setBrightnessLevel:)]) {
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
	if (![url isEqualToString:[NSString stringWithUTF8String:kBrightnessGlyph]]) return;

	gSliderView = self;

	if (!gDidInit) {
		gDidInit = YES;

		GetRWPIntensityFn getFn = GetIntensityFn();
		float current = getFn ? (float)getFn() : 0.0f;
		gSliderLevel = Clamp01(1.0f - current);

		ApplySliderLevel(gSliderLevel);
		ForceFullBrightness();

		NSLog(@"[DimSlider] initialized, restored level=%.3f", gSliderLevel);
	}
}

- (void)setValue:(float)value
{
	if (self != gSliderView) return %orig;

	if (value >= 0.0f) {
		// 系统想同步真实亮度 → 忽略，只回写我们自己的滑块位置
		%orig(gSliderLevel);
	} else {
		%orig(-value);
	}
}

- (void)_handleValueChangeGestureRecognizer:(UIPanGestureRecognizer *)recognizer
{
	if (self != gSliderView) return %orig;

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
