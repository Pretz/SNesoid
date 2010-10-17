APP_BUILD_SCRIPT = $(APP_PROJECT_PATH)/Android.mk

compile-s-source = $(eval $(call ev-compile-c-source,$1,$(1:%.s=%.o)))

JNI_H_INCLUDE = $(APP_PROJECT_PATH)/../common/libnativehelper/include/