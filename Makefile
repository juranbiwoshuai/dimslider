ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DimSlider
DimSlider_FILES = Tweak.xm
DimSlider_FRAMEWORKS = UIKit
DimSlider_LDFLAGS = -undefined dynamic_lookup
DimSlider_CFLAGS = -fobjc-arc -Wno-unused-variable

include $(THEOS_MAKE_PATH)/tweak.mk
