cmake_minimum_required(VERSION 3.16)
project(QsyRemote VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configure output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# -------------------------------------------------------------
# OS Detection & Target Adjustments
# -------------------------------------------------------------
if(WIN32)
    message(STATUS "Target OS: Windows (Compatible with Win7 ~ Win11)")
    # Target Windows 7 (0x0601) as minimum supported OS
    add_definitions(-D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -DUNICODE -D_UNICODE)
    set(PLATFORM_LIBS d3d11 dxgi d3dcompiler user32 gdi32 ws2_32 dwmapi winmm)
elseif(APPLE)
    message(STATUS "Target OS: macOS (Universal: Intel x86_64 + Apple Silicon arm64)")
    # Minimum macOS target
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING "Minimum OS X deployment version" FORCE)
    set(PLATFORM_LIBS
        "-framework Cocoa"
        "-framework CoreGraphics"
        "-framework CoreVideo"
        "-framework CoreMedia"
        "-framework ScreenCaptureKit"
        "-framework ImageIO"
        "-framework Metal"
        "-framework OpenGL"
    )
    # Enable Objective-C++
    enable_language(OBJCXX)
endif()

# Core include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/client/core
    ${CMAKE_CURRENT_SOURCE_DIR}/client/core/capture
    ${CMAKE_CURRENT_SOURCE_DIR}/client/core/input
    ${CMAKE_CURRENT_SOURCE_DIR}/client/core/protocol
    ${CMAKE_CURRENT_SOURCE_DIR}/client/core/codec
    ${CMAKE_CURRENT_SOURCE_DIR}/client/core/network
    ${CMAKE_CURRENT_SOURCE_DIR}/client/core/session
    ${CMAKE_CURRENT_SOURCE_DIR}/client/ui
)

# Core Sources
set(CORE_SOURCES
    client/core/capture/capturer_factory.cpp
    client/core/protocol/packet.cpp
    client/core/input/input_injector.cpp
    client/core/codec/fast_codec.cpp
    client/core/network/net_client.cpp
    client/core/network/stun_client.cpp
    client/core/network/upnp_mapper.cpp
    client/core/network/lan_discovery.cpp
    client/core/session/remote_session.cpp
)

if(WIN32)
    list(APPEND CORE_SOURCES
        client/core/capture/win/dxgi_capturer.cpp
        client/core/capture/win/gdi_capturer.cpp
        client/core/input/win/win_input.cpp
    )
elseif(APPLE)
    list(APPEND CORE_SOURCES
        client/core/capture/mac/sc_capturer.mm
        client/core/capture/mac/cg_capturer.mm
        client/core/input/mac/mac_input.mm
    )
endif()

# Core Static Library
add_library(qsy_core STATIC ${CORE_SOURCES})
target_link_libraries(qsy_core PUBLIC ${PLATFORM_LIBS})

# Client Test/Runner Executable
add_executable(qsy_client client/main.cpp)
target_link_libraries(qsy_client PRIVATE qsy_core)
