#!/usr/bin/env bash
# ==============================================================================
# QsyRemote - Cloudflare Tunnel 官方免费内网穿透一键助手
# 免公网 IP、免改光猫防火墙、不限流量不限速，通过 Cloudflare 骨干网直通
# ==============================================================================

set -e

PORT=${1:-8920}

echo "========================================================"
echo "🚀 QsyRemote - Cloudflare Tunnel 免费内网穿透助手"
echo "========================================================"

# 检查是否安装了 cloudflared
if ! command -v cloudflared &> /dev/null; then
    echo "⚠️ 检测到未安装 cloudflared，正在通过 brew 自动安装..."
    if command -v brew &> /dev/null; then
        brew install cloudflared
    else
        echo "❌ 未检测到 Homebrew，请手动安装 cloudflared 或访问: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
        exit 1
    fi
fi

echo "✅ cloudflared 已就绪！"
echo "🌐 正在为本地端口 $PORT 建立 Cloudflare 穿透隧道..."
echo "💡 提示：按 Ctrl+C 可随时停止穿透。"
echo "--------------------------------------------------------"

# 启动 Quick Tunnel
cloudflared tunnel --url tcp://127.0.0.1:$PORT
