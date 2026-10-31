#!/bin/bash
set -e

echo "=========================================================="
echo "   QsyRemote macOS Universal 二进制打包脚本              "
echo "   支持架构: Intel (x86_64) + Apple Silicon (arm64)      "
echo "=========================================================="

APP_NAME="QsyRemote"
BUILD_DIR="build_macos"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "[1/4] 编译 macOS Universal 2 通用双架构核心..."
clang++ -std=c++17 -O3 -fobjc-arc \
  -arch x86_64 -arch arm64 \
  -mmacosx-version-min=10.15 \
  -I./client/core \
  -I./client/core/capture \
  -I./client/core/input \
  -I./client/core/protocol \
  -I./client/core/codec \
  -I./client/core/network \
  -I./client/ui \
  client/core/capture/capturer_factory.cpp \
  client/core/capture/mac/sc_capturer.mm \
  client/core/capture/mac/cg_capturer.mm \
  client/core/input/input_injector.cpp \
  client/core/input/mac/mac_input.mm \
  client/core/protocol/packet.cpp \
  client/core/codec/fast_codec.cpp \
  client/core/network/net_client.cpp \
  client/core/network/stun_client.cpp \
  client/core/network/upnp_mapper.cpp \
  client/core/network/lan_discovery.cpp \
  client/core/session/remote_session.cpp \
  client/resources/embedded_donate_png.cpp \
  client/ui/mac_gui.mm \
  client/main.cpp \
  -framework Cocoa \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework CoreVideo \
  -framework CoreMedia \
  -framework ScreenCaptureKit \
  -framework ImageIO \
  -framework AVFoundation \
  -framework AudioToolbox \
  -o "${MACOS_DIR}/${APP_NAME}"

echo "[2/4] 验证 Universal 2 双架构二进制架构..."
lipo -info "${MACOS_DIR}/${APP_NAME}"

echo "[3/4] 生成 macOS 权限合规 Info.plist..."
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>QsyRemote</string>
    <key>CFBundleIdentifier</key>
    <string>com.qsy.remote</string>
    <key>CFBundleName</key>
    <string>QsyRemote</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>QsyRemote 需要屏幕录制权限以捕获当前屏幕并提供远程协助服务。</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>QsyRemote 需要辅助功能权限以模拟键盘和鼠标操作。</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>QsyRemote 需要访问麦克风以支持远程协助中的实时双向语音对讲与连麦通话。</string>
    <key>NSCameraUsageDescription</key>
    <string>QsyRemote 需要访问摄像头以支持远程协助中的双方视频连麦与画中画头像交流。</string>
</dict>
</plist>
EOF

if [ -f "client/resources/AppIcon.icns" ]; then
    mkdir -p "${RESOURCES_DIR}"
    cp "client/resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

if [ -f "client/resources/logo.png" ]; then
    mkdir -p "${RESOURCES_DIR}"
    cp "client/resources/logo.png" "${RESOURCES_DIR}/logo.png"
fi

if [ -f "client/resources/bin/qsyshare" ]; then
    mkdir -p "${RESOURCES_DIR}"
    cp "client/resources/bin/qsyshare" "${RESOURCES_DIR}/qsyshare"
    chmod +x "${RESOURCES_DIR}/qsyshare"
    codesign --force --sign - "${RESOURCES_DIR}/qsyshare"
fi

if [ -f "client/resources/bin/cloudflared" ]; then
    mkdir -p "${RESOURCES_DIR}"
    cp "client/resources/bin/cloudflared" "${RESOURCES_DIR}/cloudflared"
    chmod +x "${RESOURCES_DIR}/cloudflared"
    codesign --force --sign - "${RESOURCES_DIR}/cloudflared"
fi

if [ -f "client/resources/donate.png" ]; then
    mkdir -p "${RESOURCES_DIR}"
    cp "client/resources/donate.png" "${RESOURCES_DIR}/donate.png"
fi

echo "[3.5] 进行 macOS 本地代码签名 (确保 TCC 屏幕录制权限持久化绑定)..."
codesign --force --deep --sign - "${APP_BUNDLE}"
codesign -dvvv "${APP_BUNDLE}"

echo "[4/4] 打包生成可分发 DMG 镜像 (集成 /Applications 拖拽安装软链接)..."
if which hdiutil >/dev/null 2>&1; then
    DMG_STAGING="${BUILD_DIR}/dmg_staging"
    rm -rf "${DMG_STAGING}"
    mkdir -p "${DMG_STAGING}"
    cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
    ln -s /Applications "${DMG_STAGING}/Applications"
    hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${BUILD_DIR}/${APP_NAME}-macOS-Universal.dmg"
    rm -rf "${DMG_STAGING}"
    echo "=========================================================="
    echo "[SUCCESS] macOS DMG 打包完成: ${BUILD_DIR}/${APP_NAME}-macOS-Universal.dmg"
    echo "=========================================================="
fi

if [ -d "/Applications/${APP_NAME}.app" ] || [ "$1" == "--install" ]; then
    echo "[5/5] 同步更新 /Applications/${APP_NAME}.app..."
    pkill -f "QsyRemote" 2>/dev/null || true
    sleep 0.5
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
    echo "[SUCCESS] 已同步安装至 /Applications/${APP_NAME}.app"
fi

