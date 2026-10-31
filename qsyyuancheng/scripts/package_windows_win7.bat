@echo off
@chcp 65001 >nul
setlocal enabledelayedexpansion

echo ==========================================================
echo    QsyRemote Windows 7 兼容版极速打包工具 (MSVC)
echo    目标平台: Windows 7 / 8 / 10 / 11 (x64 架构)
echo ==========================================================

REM 1. 检查当前是否已在 MSVC 命令行环境中
where cl.exe >nul 2>nul
if %errorlevel% equ 0 goto :COMPILER_READY

echo [*] 正在自动搜索本机 Visual Studio C++ 编译环境...

REM 2. 通过 vswhere 工具自动定位 VS 安装路径
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
            echo [+] 自动找到 Visual Studio: %%i
            call "%%i\VC\Auxiliary\Build\vcvars64.bat"
            goto :CHECK_CL
        )
    )
)

REM 3. 常见默认安装路径穷举检测
if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" (
    call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    goto :CHECK_CL
)
if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" (
    call "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    goto :CHECK_CL
)
if exist "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    call "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    goto :CHECK_CL
)
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" (
    call "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
    goto :CHECK_CL
)
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
    call "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    goto :CHECK_CL
)

:CHECK_CL
where cl.exe >nul 2>nul
if %errorlevel% equ 0 goto :COMPILER_READY

echo.
echo ==========================================================
echo [!] 提示: 未在系统中检测到 MSVC 编译器 [cl.exe]。
echo.
echo 原因分析与解决建议：
echo 1. 若当前虚拟机中【已安装】Visual Studio：
echo    请在 Windows 开始菜单中搜索并打开：
echo    "x64 Native Tools Command Prompt for VS 2022" 命令行窗口，
echo    然后进入此目录重新执行本脚本即可。
echo.
echo 2. 若当前虚拟机【尚未安装】C++ 编译工具：
echo    请下载安装 "Visual Studio 2022 Community" (免费版)
echo    并在安装向导中勾选：【使用 C++ 的桌面开发】工作负荷。
echo ==========================================================
pause
exit /b 1

:COMPILER_READY
set "BUILD_DIR=build_win"
set "OUT_EXE=QsyRemote.exe"

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

echo [1/3] 正在生成参数清单并编译 C++17 核心模块...

set "RSP_FILE=%BUILD_DIR%\cl_build.rsp"

(
    echo /nologo /O2 /std:c++17 /MT /utf-8 /EHsc
    echo /D_WIN32_WINNT=0x0601 /DWINVER=0x0601 /DUNICODE /D_UNICODE /DNOMINMAX /DWIN32_LEAN_AND_MEAN
    echo /I "client\core"
    echo /I "client\core\capture"
    echo /I "client\core\input"
    echo /I "client\core\protocol"
    echo /I "client\core\codec"
    echo /I "client\core\network"
    echo /I "client\core\session"
    echo /I "client\ui"
    echo client\core\capture\capturer_factory.cpp
    echo client\core\capture\win\dxgi_capturer.cpp
    echo client\core\capture\win\gdi_capturer.cpp
    echo client\core\input\input_injector.cpp
    echo client\core\input\win\win_input.cpp
    echo client\core\protocol\packet.cpp
    echo client\core\codec\fast_codec.cpp
    echo client\core\network\net_client.cpp
    echo client\core\network\stun_client.cpp
    echo client\core\network\upnp_mapper.cpp
    echo client\core\network\lan_discovery.cpp
    echo client\core\session\remote_session.cpp
    echo client\resources\embedded_donate_png.cpp
    echo client\ui\win_gui.cpp
    echo client\main.cpp
) > "%RSP_FILE%"

echo [*] 正在编译 C++17 源代码 (开启 /utf-8 严格编码支持)...
cl @"%RSP_FILE%" /c /Fo"%BUILD_DIR%\\"
if %errorlevel% neq 0 goto :COMPILE_FAILED

if exist "client\resources\app.rc" echo [*] 正在编译应用图标与版本资源清单 app.rc...
if exist "client\resources\app.rc" rc.exe /nologo /i "client\resources" /fo"%BUILD_DIR%\app.res" client\resources\app.rc
set EXTRA_RES=
if exist "%BUILD_DIR%\app.res" set EXTRA_RES="%BUILD_DIR%\app.res"

echo [2/3] 正在静态链接各模块并注入 Windows 7 (NT 6.1) 原生视窗子系统 (注入管理员提权清单与应用图标)...
link.exe /nologo /OUT:"%BUILD_DIR%\%OUT_EXE%" /SUBSYSTEM:WINDOWS,6.01 /ENTRY:mainCRTStartup /MANIFEST:EMBED /MANIFESTUAC:"level='requireAdministrator' uiAccess='false'" "%BUILD_DIR%\*.obj" %EXTRA_RES% d3d11.lib dxgi.lib user32.lib gdi32.lib ws2_32.lib dwmapi.lib shell32.lib comctl32.lib gdiplus.lib ole32.lib comdlg32.lib iphlpapi.lib wininet.lib advapi32.lib winmm.lib
if %errorlevel% neq 0 goto :COMPILE_FAILED

echo [3/3] 正在检测与集成 Qsyshare 官方穿透组件 (qsyshare.exe) 与赞助图片...
if exist "client\resources\app.ico" copy /y "client\resources\app.ico" "%BUILD_DIR%\app.ico" >nul 2>nul
if exist "client\resources\logo.png" copy /y "client\resources\logo.png" "%BUILD_DIR%\logo.png" >nul 2>nul
if not exist "%BUILD_DIR%\qsyshare.exe" if exist "qsyshare.exe" copy /y "qsyshare.exe" "%BUILD_DIR%\" >nul
if not exist "%BUILD_DIR%\qsyshare.exe" if exist "client\resources\bin\qsyshare.exe" copy /y "client\resources\bin\qsyshare.exe" "%BUILD_DIR%\" >nul
if not exist "%BUILD_DIR%\qsyshare.exe" if exist "cloudflared.exe" copy /y "cloudflared.exe" "%BUILD_DIR%\qsyshare.exe" >nul
if not exist "%BUILD_DIR%\qsyshare.exe" if exist "client\resources\bin\cloudflared.exe" copy /y "client\resources\bin\cloudflared.exe" "%BUILD_DIR%\qsyshare.exe" >nul

if exist "client\resources\donate.png" (
    copy /y "client\resources\donate.png" "%BUILD_DIR%\donate.png" >nul
    copy /y "client\resources\donate.png" "donate.png" >nul
)

if exist "%BUILD_DIR%\qsyshare.exe" (
    echo [+] Qsyshare 官方穿透组件已就绪: %BUILD_DIR%\qsyshare.exe
    if not exist "qsyshare.exe" copy /y "%BUILD_DIR%\qsyshare.exe" "qsyshare.exe" >nul
) else (
    echo [*] 正在尝试下载官方穿透组件...
    where curl.exe >nul 2>nul
    if !errorlevel! equ 0 (
        curl.exe -f -s -L --connect-timeout 3 -m 6 "https://mirror.ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -o "%BUILD_DIR%\qsyshare.exe" >nul 2>nul
    )
    if exist "%BUILD_DIR%\qsyshare.exe" (
        echo [+] 成功自动集成官方 qsyshare.exe 穿透组件
        if not exist "qsyshare.exe" copy /y "%BUILD_DIR%\qsyshare.exe" "qsyshare.exe" >nul
    ) else (
        echo [i] 提示: 未检测到 qsyshare.exe。
        echo [i] 提示: 主程序已就绪！如需使用官方穿透隧道，将官方 qsyshare.exe 与 QsyRemote.exe 放在同级目录下即可。
    )
)

copy /y "%BUILD_DIR%\%OUT_EXE%" "%OUT_EXE%" >nul 2>nul
if exist "%OUT_EXE%" echo [+] 已同步输出可执行文件至根目录: %OUT_EXE%

echo.
echo ==========================================================
echo [SUCCESS] Windows 可执行文件打包成功: %BUILD_DIR%\%OUT_EXE%
echo.
echo 架构特性:
echo   [+] 兼容 Windows 7 / 8 / 10 / 11 (x64)
echo   [+] Win8+ 自动启用 DXGI GPU 显卡硬件采集
echo   [+] Win7 / 虚拟机自动启用极速 GDI 兼容采集
echo   [+] 静态编译 /MT，无须任何第三方 VC++ 运行库
echo   [+] 支持 Qsyshare 穿透隧道与专属信令双通道
echo ==========================================================
goto :DONE

:COMPILE_FAILED
echo.
echo [ERROR] 编译或链接过程出错，请检查上方 MSVC 报错信息。
pause
exit /b 1

:DONE
echo.
echo 打包完成，请按任意键退出...
pause >nul
