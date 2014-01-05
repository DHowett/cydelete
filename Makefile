TWEAK_NAME := CyDelete
CyDelete_LOGOS_FILES := Hook.xm
CyDelete_FRAMEWORKS := UIKit

SUBPROJECTS := setuid preferences

CFLAGS += -I SpringBoard

TARGET := iphone:7.0:6.0
ARCHS := arm64 armv7

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
include $(THEOS)/makefiles/aggregate.mk

after-stage::
	find $(FW_STAGING_DIR) -iname '*.plist' -or -iname '*.strings' -exec plutil -convert binary1 {} \;
	find $(FW_STAGING_DIR) -iname '*.png' -exec pincrush -i {} \;
