TWEAK_NAME := CyDelete
CyDelete_LOGOS_FILES := Hook.xm
CyDelete_FRAMEWORKS := UIKit

SUBPROJECTS := setuid preferences

export TARGET := iphone:clang
export ARCHS := arm64 armv6

export THEOS_PLATFORM_SDK_ROOT_armv6 := /Applications/Xcode_armv6.app/Contents/Developer
export SDKVERSION_armv6 := 5.0
export TARGET_IPHONEOS_DEPLOYMENT_VERSION := 3.0
export TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64 := 7.0

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
include $(THEOS)/makefiles/aggregate.mk

after-stage::
	find $(FW_STAGING_DIR) -iname '*.plist' -or -iname '*.strings' -exec plutil -convert binary1 {} \;
	find $(FW_STAGING_DIR) -iname '*.png' -exec pincrush -i {} \;
