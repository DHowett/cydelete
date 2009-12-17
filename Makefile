TWEAK_NAME := CyDelete
CyDelete_OBJCC_FILES = Hook.mm

CyDelete_FRAMEWORKS = UIKit
CyDelete_CFLAGS = -DBUNDLE="@\"$(BUNDLEDIR)/$(BUNDLENAME)\"" -DVERSION="$(VERSION)"

CyDelete_SUBPROJECTS = setuid preferences

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

after-CyDelete-package::
	$(FAKEROOT) chown -R 0:80 $(FW_PACKAGE_STAGING_DIR)
