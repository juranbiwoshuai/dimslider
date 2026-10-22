# DimSlider

把控制中心的亮度滑块，改成控制「降低白点值」的强度。

- 屏幕亮度被强制锁在 100%（PWM 占空比最大，频闪最小）
- 往下拉滑块 = 白点值变强 = 画面变暗（但频闪不变）
- 往上拉滑块 = 白点值变弱 = 画面变亮

适用于 iPhone 14 / iOS 16.0 + Dopamine 无根越狱。

## 原理

iOS 的「降低白点值」是在显示管线里压低像素驱动值，不改变 OLED 面板的 PWM 开关节奏。
所以在 100% 亮度下用它压暗，视觉上变暗了，但频闪水平保持在最好的状态。

## 安装（编译好的 deb）

1. 把 deb 传到手机（微信文件传输助手、QQ、AirDrop 都行）
2. 用 Filza 找到它，点开，选 Install
3. 会自动 respring，然后去控制中心试

## 卸载

Sileo → 已安装 → DimSlider → 卸载。
或者 Filza 删掉 `/var/jb/Library/MobileSubstrate/DynamicLibraries/DimSlider.dylib` 后 respring。

## 出问题时的急救

如果装了以后无限安全模式或桌面起不来：

1. 打开 Dopamine → 设置 → 关闭 Tweak Injection → 注销
2. 或按音量键进安全模式
3. 进 Filza 删掉 dylib 后重新越狱

## 已知限制

- 只拦截了 SpringBoard 层的亮度写入。App 内直接调系统亮度的行为、以及过热保护强制降亮度，拦不住
- 亮度锁 100% 会加速 OLED 老化，建议白点值常年保持在 30%–60%，别长时间显示纯白
- 装之前请先在「设置 → 辅助功能 → 显示与文字大小」里把自动亮度关掉，否则亮度会被环境光反复拉扯

## 致谢

- 思路与私有 API 用法参考 [jschiefner/advanced-brightness-slider-tweak](https://github.com/jschiefner/advanced-brightness-slider-tweak)（GPL-3.0）
- 白点值强度 API 来自 [opa334/WhitePointModule](https://github.com/opa334/WhitePointModule)

## 许可

GPL-3.0，见 LICENSE。
