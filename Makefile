# ============================================================
#  HelloTweak 编译配置（Makefile）
#  作用：告诉 Theos 怎么编译你的插件
# ============================================================

# TARGET 格式：平台 : 编译器 : SDK版本 : 最低支持系统
# latest = 自动选最新 SDK，最低支持 iOS 15.0（Dopamine 最低支持 15.0）
export TARGET = iphone:clang:latest:15.0

# 编译两种架构：
#   arm64  —— A12 及以下芯片
#   arm64e —— A12 及以上芯片（你的 iPhone 14 Pro Max 就是 arm64e）
export ARCHS = arm64 arm64e

# ★★★ 关键一行 ★★★
# Dopamine 是 rootless（无根）越狱，必须加这一行，
# 打包出来的 .deb 才会装到 /var/jb 目录，而不是系统根目录。
export THEOS_PACKAGE_SCHEME = rootless

# 引入 Theos 的公共配置（THEOS 是环境变量，指向 Theos 安装路径）
include $(THEOS)/makefiles/common.mk

# 插件名称（同时决定生成的 .dylib 文件名）
TWEAK_NAME = HelloTweak

# 源代码文件列表（多个文件用空格隔开）
HelloTweak_FILES = Tweak.x

# 编译参数：
#   -fobjc-arc                   开启 ARC 自动内存管理
#   -Wno-deprecated-declarations 忽略"过时 API"警告（学习用插件无妨）
HelloTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# 链接的系统框架
HelloTweak_FRAMEWORKS = UIKit

# 引入 Tweak 的编译规则
include $(THEOS_MAKE_PATH)/tweak.mk
