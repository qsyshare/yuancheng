# QsyRemote 跨平台极速远程协助系统

> **GitHub 仓库**：[https://github.com/qsyshare/yuancheng](https://github.com/qsyshare/yuancheng)

本项目专为**极速性能、超低延迟、强安全性**打造，采用**纯 C++17 核心 + 运行时动态探测适配架构**，向下兼容 **Windows 7** 与 **macOS 老旧 Intel** 设备，向上充分榨干 **Windows 10/11 (DXGI)** 与 **macOS Apple Silicon (ScreenCaptureKit)** 的硬件潜能。

---

## 🌟 核心特性与架构优势

1. **全世代自适应屏幕采集（零拷贝与无缝降级）**
   - **Windows 8/10/11**：优先启用 `DXGI Desktop Duplication API`，显卡显存零拷贝采集，延迟 `< 5ms`。
   - **Windows 7 兼容模式**：自动识别并平滑降级到 `GDI Direct Memory DIBSection` 采集，单安装包兼容，无需分支维护。
   - **macOS 12.3+**：优先走 `ScreenCaptureKit` 硬件采集，低 CPU 负载。
   - **macOS Intel 老版本**：动态符号绑定 `CoreGraphics` 快照兜底，兼容 macOS 10.15~14。

2. **超低延迟二进制网络协议**
   - 自定义二进制帧结构（`0x51535952` 魔数校验），集成微秒级 RTT 延迟检测。
   - 分离信令（HTTP/WebSocket）与流媒体传输（UDP + 极速中继）。

3. **系统级键鼠无缝模拟**
   - Windows 端采用 `SendInput` 纳秒级事件注入，支持鼠标坐标绝对映射、滚轮与键盘控制。
   - macOS 端采用 `CGEvent` 注入，支持多按键与修饰键。

4. **高并发 Go 语言信令与 NAT 穿透服务**
   - 9 位随机设备码与 6 位动态 PIN 码安全认证机制。
   - 内置 UDP 极速中继隧道，P2P 打洞失败时无缝切换。

---

## 📁 目录结构

```
qsyyuancheng/
├── CMakeLists.txt                 # 跨平台 CMake 构建定义 (Win7+ / macOS 通用二进制)
├── client/                        # 客户端 C++17 核心
│   ├── main.cpp                   # 核心性能基准测试与运行验证程序
│   └── core/
│       ├── capture/               # 屏幕采集引擎
│       │   ├── capturer.h         # 采集器抽象基类
│       │   ├── capturer_factory.h # 自动探测工厂
│       │   ├── capturer_factory.cpp
│       │   ├── win/               # Windows 专属实现 (DXGI + GDI)
│       │   │   ├── dxgi_capturer.h / .cpp
│       │   │   └── gdi_capturer.h  / .cpp
│       │   └── mac/               # macOS 专属实现 (SCKit + CoreGraphics)
│       │       ├── sc_capturer.h   / .mm
│       │       └── cg_capturer.h   / .mm
│       ├── input/                 # 键鼠模拟与注入
│       │   ├── input_injector.h
│       │   ├── input_injector.cpp
│       │   ├── win/win_input.cpp
│       │   └── mac/mac_input.mm
│       └── protocol/              # 二进制低延迟通信协议
│           ├── packet.h
│           └── packet.cpp
└── server/                        # 信令与中继后端 (Go)
    ├── go.mod
    └── main.go
```

---

## 🚀 编译与运行测试

### 1. 运行 C++ 客户端核心基准测试 (macOS)
```bash
./qsy_client_test
```
输出示例：
```
======================================================
   QsyRemote 跨平台极速远程桌面引擎 (C++17 Core)      
   兼容: Windows 7 ~ 11, macOS Intel & Apple Silicon 
======================================================
[+] 当前生效采集引擎: macOS CoreGraphics Legacy Capturer (Intel/Older OS Compatible)
[+] 首帧抓取成功! (分辨率: 3360 x 2100)
[+] 协议校验通过: Magic=0x51535952, Seq=1001
[+] 输入注入模块就绪 (支持鼠标/键盘/滚轮事件模拟)
```

### 2. 编译并启动信令中继服务端 (Go)
```bash
cd server
go run main.go
```
服务将在 `8080` 端口开启设备注册与信令认证，并在 `8088` 端口监听 UDP 极速中继。


## Win10 编译
在新 Win10 电脑上重新编译打包
如果您需要在这台新的 Win10 电脑上从源码重新生成程序：

安装编译环境：

下载并安装 Visual Studio 2022 Community (免费版)；https://visualstudio.microsoft.com/zh-hans/vs/community/

微软官方 .NET Framework 4.8 离线安装包 (中文版)
https://go.microsoft.com/fwlink/?linkid=2088631

安装向导中，勾选 【使用 C++ 的桌面开发】 即可（无需勾选其他组件）。
一键生成可执行文件：

将本工程文件夹（qsyyuancheng）拷贝到该 Win10 电脑上；
进入 scripts 目录，直接双击运行 package_windows_win7.bat；
脚本会自动检测环境、完成高强度编译优化并打包出 QsyRemote.exe（耗时仅需十几秒）；
打包完成后，在根目录或 build_win 目录下直接双击 QsyRemote.exe 运行即可。


## 在Windows使用
免安装直接运行（最快，推荐 ⭐⭐⭐⭐⭐）
如果您之前已经在旧 Windows 电脑上编译打包过：

准备文件： 只需将以下两个文件复制到新 Windows 10 电脑的同一个文件夹下（例如放到 D:\QsyRemote 或桌面）：

QsyRemote.exe（主程序）
cloudflared.exe（改名成 qsyshare.exe）（cf官方穿透组件，就在项目根目录下）

双击启动：

右键 QsyRemote.exe，选择 【以管理员身份运行】；
(如弹出 Windows Defender SmartScreen 提示，点击“更多信息” -> “仍要运行”即可)；
(如弹出 Windows 防火墙提示，请务必勾选【专用网络】与【公用网络】，点击【允许访问】)。
开启远程：

打开后，记下主界面左侧显示的 您的设备 ID 与 动态连接密码；
如果双方不在同一个局域网，点击左侧的 「🚀 一键开启 Cloudflare 官方隧道」（开启后灯会变为绿色就绪）；
在您的 Mac 电脑上输入这台 Win10 的设备 ID 与密码，点击 「🚀 建立极速远程连接」 即可秒级连入！

> 💡 **被控端使用隧道连接配置流程图**：
> 
> ![被控端使用隧道连接配置指引](web/assets/cf_tunnel_guide.png)
> 
> **操作步骤速记**：点击【穿透与中继设置 (高级)】 ➔ 填入专属 Tunnel Token ➔ 点击【保存配置】 ➔ 返回点击【一键开启 Qsyshare 官方隧道】


## Mac端通用版编译
Mac 端 Universal 2 (x86_64 + arm64) 构建验证：
执行 bash scripts/package_macos.sh，编译、链接、代码签名及 DMG 打包全部成功（Exit Code: 0）。
验证结果：Mac 端各项功能完全保持健康且无任何负面影响。

一、：一键自动化打包（推荐）
打开 macOS「终端」（Terminal），进入项目根目录，直接执行：
bash
cd /Users/iruili/Desktop/qsyyuancheng
bash scripts/package_macos.sh

三、 备用方式：使用 CMake 编译
如果您希望使用标准 CMake 工具链进行开发调试，也可以执行：

bash
cd /Users/iruili/Desktop/qsyyuancheng
mkdir -p build && cd build
cmake .. -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"
cmake --build .

## Windows端编译
Windows 端编译与链接依赖验证：
CMakeLists.txt 与 scripts/package_windows_win7.bat 均已加入 winmm.lib，代码中使用 #include <mmsystem.h>，完美覆盖 Windows 7 ~ 11 全平台。

## 音视频协同与视讯流优化
- **Windows 原生免依赖摄像头**：基于 `avicap32.dll` 动态载入，提供独立授权按键【📹 接受并开启摄像头】与一键【📹 开启/关闭摄像头】，支持画中画联动。
- **消灭队头阻塞与远程卡死**：视讯帧（JPEG）严格限速 8 FPS / 320x240（单帧 3~4KB），发送端通过专用非阻塞丢帧通道隔离互斥锁，网络拥塞或键鼠交互时视讯帧 0 耗时自动丢弃，100% 保障鼠标操作与远程屏幕的零延迟流畅度。

## 手机热点与无 VPN 环境智能穿透方案 (LanDiscovery)
- **问题根源**：在国内使用手机热点且未开代理/VPN 时，移动蜂窝运营商防火墙对 Cloudflare 默认 Anycast 节点（`104.21.x.x`）的 TLS 握手进行 TCP RST 阻断，引发苹果 CFNetwork `-1005 (The network connection was lost)`。
- **三重容灾与秒连机制**：
  1. **局域网与手机热点智能广播探针 (LanDiscovery)**：受控端在后台监听 UDP 8922。当控制端输入 9 位设备代码时，自动向 `255.255.255.255`、当前网段广播及手机热点（iOS `172.20.10.x` / Android `192.168.43.x`）发起 150ms 极速嗅探。同热点或同局域网下 **0 毫秒依赖外网，100% 自动秒连**！
  2. **直接输入 IP 支持**：伙伴设备输入框现已支持直接填入对方主界面显示的「本机局域网 IP」（如 `172.20.10.3`），直接走 1ms 本地 TCP 直连，彻底绕开外网信令。
  3. **优雅降级与清晰指引**：信令异常时不再死板中断，优先回退局域网发现；若跨网且信令被阻断，弹出清晰直观的国内手机热点直连与隧道配置指引。

## Tunnels:
tcp://127.0.0.1:8920

## cloudflare 账号中部署 Worker
可选但强烈建议：绑定免费 KV 数据库（设备离线记忆更稳定）
在 Worker 页面左侧点击 KV -> 创建命名空间，名称填 DEVICE_SESSIONS。
回到刚才创建的 Worker -> 点击 设置 (Settings) -> 变量和机密 (Variables and Secrets)。
在 KV 命名空间绑定 中添加：变量名称填 DEVICE_SESSIONS，下拉选择刚才创建的 KV，保存并重新部署即可。

## 如果使用隧道这里免费提供一个公网域名与专属Tunnel Token：（如果多用户同时使用可能会串台，所有建议创建自己的使用，虽然优化了但没有进行验证。）
公网域名：ycaa.worldss.qzz.io
专属Tunnel Token：eyJhIjoiOThhODAzMWRmMDBlY2IzYTllN2M5YzgwMTc1NGY2OTgiLCJ0IjoiN2E3NWIzODctN2NmNy00M2I4LWFhMzktNTVjNjM2ZmEyNzQzIiwicyI6IlpXSm1OelZqWVRBdFlURXdZaTAwWmpFNExUa3laVFV0WlRrNFpHUmtaalk0TlRabCJ9：


  
