TWEAK_NAME := CyDelete
CyDelete_LOGOS_FILES = Hook.xm
CyDelete_FRAMEWORKS = UIKit

SUBPROJECTS = setuid preferences

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
include framework/makefiles/aggregate.mk
