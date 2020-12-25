export ARHCS = arm64 arm64e
export TARGET = iphone:clang:latest:11.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CornerLock
CornerLock_FILES = Tweak.x CornerLockController.x CornerLockWindow.x
CornerLock_FRAMEWORKS = UIKit
CornerLock_PRIVATE_FRAMEWORKS = BackBoardServices SpringBoardUIServices SpringBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk
