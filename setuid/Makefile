TOOL_NAME := setuid
setuid_C_FILES = setuid.c
setuid_PACKAGE_TARGET_DIR = /usr/libexec/cydelete

include ../framework/makefiles/common.mk
include ../framework/makefiles/tool.mk

after-setuid-stage::
	$(FAKEROOT) chmod 6755 $(FW_STAGING_DIR)/usr/libexec/cydelete/setuid
