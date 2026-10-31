/**
 * QsyRemote - Cloudflare 免费全球信令与中继 Worker
 * 
 * 部署说明：
 * 1. 登录 https://dash.cloudflare.com/ -> Workers & Pages -> Create Application
 * 2. 将本文件全部代码复制粘贴到 Cloudflare Worker 代码编辑器中并点击 "Deploy"
 * 3. 部署完成后，你将获得一个免费域名：https://xxx.xxx.workers.dev
 */

// 存放内存中的在线会话与 WebSocket 连接
const deviceSessions = new Map();
// 存放等待配对的 WebSocket 会话
const relaySockets = new Map();

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // 跨域 CORS 支持
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    // 1. 设备在线注册与心跳: GET /api/register?device_id=xxx&pin=yyy&lan_ip=zzz&port=8920
    if (url.pathname === "/api/register") {
      const rawDeviceId = url.searchParams.get("device_id") || generateDeviceID();
      const deviceId = rawDeviceId.replace(/\s+/g, ""); // 统一无空格标准格式
      const pin = (url.searchParams.get("pin") || generatePin()).replace(/\s+/g, "").trim();
      const lanIp = url.searchParams.get("lan_ip") || "";
      const ipv6 = url.searchParams.get("ipv6") || "";
      const port = url.searchParams.get("port") || "8920";
      const tunnel = url.searchParams.get("tunnel") || "";
      const publicIp = request.headers.get("CF-Connecting-IP") || "unknown";

      const sessionData = {
        deviceId: deviceId,
        pin: pin,
        lanIp: lanIp,
        ipv6: ipv6,
        tunnel: tunnel,
        publicIp: publicIp,
        port: parseInt(port),
        lastSeen: Date.now(),
        country: request.headers.get("CF-IPCountry") || "XX",
      };

      if (env.DEVICE_SESSIONS) {
        await env.DEVICE_SESSIONS.put(deviceId, JSON.stringify(sessionData), { expirationTtl: 86400 });
      }
      deviceSessions.set(deviceId, sessionData);

      return new Response(JSON.stringify({
        status: "ok",
        device_id: deviceId,
        pin: pin,
        client_ip: publicIp,
        stun_servers: [
          "stun:stun.cloudflare.com:3478",
          "stun:stun.nextcloud.com:443",
          "stun:stun.matrix.org:3478",
          "stun:stun.l.google.com:19302"
        ]
      }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    // 2. 伙伴设备验证与候选地址交换: POST /api/connect
    if (url.pathname === "/api/connect") {
      if (request.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

      try {
        const body = await request.json();
        const rawTargetId = String(body.target_id || "");
        const targetId = rawTargetId.replace(/\s+/g, "");
        const targetPin = String(body.pin || "").replace(/\s+/g, "").trim();

        let target = null;
        if (env.DEVICE_SESSIONS) {
          const val = await env.DEVICE_SESSIONS.get(targetId);
          if (val) target = JSON.parse(val);
        }
        if (!target) {
          target = deviceSessions.get(targetId);
        }

        if (!target) {
          return new Response(JSON.stringify({ status: "error", msg: "伙伴设备不在线，请确认被控端软件已启动并联网" }), {
            status: 404,
            headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
          });
        }

        if (target.pin !== targetPin) {
          return new Response(JSON.stringify({ status: "error", msg: "访问密码 (PIN) 错误，请核对对方主界面 6 位密码后重试" }), {
            status: 403,
            headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
          });
        }

        return new Response(JSON.stringify({
          status: "ok",
          msg: "设备认证通过，准备建立极速通道",
          target_ip: target.publicIp,
          target_lan_ip: target.lanIp,
          target_ipv6: target.ipv6 || "",
          target_tunnel: target.tunnel || "",
          target_port: target.port || 8920,
          target_country: target.country
        }), {
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
        });
      } catch (e) {
        return new Response(JSON.stringify({ status: "error", msg: "无效的请求格式: " + e.message }), { status: 400 });
      }
    }

    // 3. 免费 WebSocket 流媒体中继通道 (P2P 穿透失败时的零费用回退)
    if (url.pathname === "/ws") {
      const upgradeHeader = request.headers.get("Upgrade");
      if (!upgradeHeader || upgradeHeader.toLowerCase() !== "websocket") {
        return new Response("Expected WebSocket", { status: 426 });
      }

      const rawDeviceId = url.searchParams.get("device_id") || "";
      const deviceId = rawDeviceId.replace(/\s+/g, "");
      const pin = (url.searchParams.get("pin") || "").trim();
      const role = url.searchParams.get("role") || "1"; // 1 = 受控端驻留, 2 = 控制端连入

      if (!deviceId || !pin) {
        return new Response("Missing device_id or pin", { status: 400 });
      }

      const key = `${deviceId}:${pin}`;
      const webSocketPair = new WebSocketPair();
      const [client, server] = Object.values(webSocketPair);
      server.accept();

      if (role === "1") {
        // 受控端驻留等待控制端连入
        relaySockets.set(key, server);
        server.addEventListener("close", () => {
          if (relaySockets.get(key) === server) relaySockets.delete(key);
        });
      } else if (role === "2") {
        // 控制端请求配对桥接
        const peerWs = relaySockets.get(key);
        if (!peerWs) {
          server.send("ERR:TARGET_NOT_WAITING");
          server.close(1008, "Target not waiting");
          return new Response(null, { status: 101, webSocket: client });
        }
        relaySockets.delete(key);

        // 双方就绪通知
        server.send("OK");
        peerWs.send("OK");

        // 启动双向极速内存透明转发 (支持二进制 ArrayBuffer)
        server.addEventListener("message", event => {
          try { peerWs.send(event.data); } catch (_) {}
        });
        peerWs.addEventListener("message", event => {
          try { server.send(event.data); } catch (_) {}
        });

        server.addEventListener("close", () => {
          try { peerWs.close(); } catch (_) {}
        });
        peerWs.addEventListener("close", () => {
          try { server.close(); } catch (_) {}
        });
      }

      return new Response(null, { status: 101, webSocket: client });
    }

    return new Response("QsyRemote Cloudflare Global Signaling Node Online", { status: 200 });
  }
};

function generateDeviceID() {
  const num = Math.floor(100000000 + Math.random() * 900000000);
  return `${Math.floor(num / 1000000)} ${Math.floor((num / 1000) % 1000)} ${num % 1000}`;
}

function generatePin() {
  return String(Math.floor(100000 + Math.random() * 900000));
}
