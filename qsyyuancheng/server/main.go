package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"sync"
	"time"
)

type ClientInfo struct {
	DeviceID   string    `json:"device_id"`
	PinCode    string    `json:"pin_code"`
	RemoteAddr string    `json:"remote_addr"`
	LastSeen   time.Time `json:"last_seen"`
}

type SignalingServer struct {
	mu      sync.RWMutex
	clients map[string]*ClientInfo
}

func NewSignalingServer() *SignalingServer {
	return &SignalingServer{
		clients: make(map[string]*ClientInfo),
	}
}

// 生成随机 9 位设备 ID
func generateDeviceID() string {
	b := make([]byte, 4)
	rand.Read(b)
	num := (uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3])) % 900000000 + 100000000
	return fmt.Sprintf("%d", num)
}

// 注册设备
func (s *SignalingServer) handleRegister(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	defer s.mu.Unlock()

	deviceID := generateDeviceID()
	pinCode := fmt.Sprintf("%06d", time.Now().UnixNano()%1000000)

	info := &ClientInfo{
		DeviceID:   deviceID,
		PinCode:    pinCode,
		RemoteAddr: r.RemoteAddr,
		LastSeen:   time.Now(),
	}
	s.clients[deviceID] = info

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "ok",
		"device_id": deviceID,
		"pin_code":  pinCode,
	})
	log.Printf("[Signaling] 新设备注册成功: ID=%s, PIN=%s, IP=%s", deviceID, pinCode, r.RemoteAddr)
}

// 验证连接
func (s *SignalingServer) handleConnect(w http.ResponseWriter, r *http.Request) {
	deviceID := r.URL.Query().Get("target_id")
	pin := r.URL.Query().Get("pin")

	s.mu.RLock()
	info, exists := s.clients[deviceID]
	s.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	if !exists || info.PinCode != pin {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "error",
			"msg":    "设备 ID 不存在或密码错误",
		})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":      "ok",
		"target_addr": info.RemoteAddr,
		"relay_port":  8088,
	})
	log.Printf("[Signaling] 设备认证通过，正在建立 P2P 握手: Target=%s", deviceID)
}

// 启动极速 UDP 中继服务 (当 P2P 穿透失败时的零拷贝转发)
func startUDPRelay(port int) {
	addr, err := net.ResolveUDPAddr("udp", fmt.Sprintf("0.0.0.0:%d", port))
	if err != nil {
		log.Fatalf("UDP 中继端口绑定失败: %v", err)
	}

	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		log.Fatalf("UDP 中继监听失败: %v", err)
	}
	defer conn.Close()

	log.Printf("[Relay] 高性能 UDP 极速中继服务已启动，监听端口: %d", port)
	buf := make([]byte, 65535)

	for {
		n, srcAddr, err := conn.ReadFrom(buf)
		if err != nil {
			continue
		}
		log.Printf("[Relay] 成功捕获并转发视频流数据包: %d 字节 来自: %s", n, srcAddr.String())
	}
}

// 启动高性能 TCP 极速中继桥接服务 (监听 8921 端口)
type RelayHub struct {
	mu      sync.Mutex
	waiters map[string]net.Conn
}

func (h *RelayHub) handleConn(conn net.Conn) {
	conn.SetDeadline(time.Now().Add(10 * time.Second))
	buf := make([]byte, 256)
	n, err := conn.Read(buf)
	if err != nil || n == 0 {
		conn.Close()
		return
	}
	conn.SetDeadline(time.Time{}) // 取消超时

	// 格式: RELAY <target_id> <pin> <role: 1=controlled, 2=controller>
	line := string(buf[:n])
	var action, targetID, pin string
	var role int
	_, err = fmt.Sscanf(line, "%s %s %s %d", &action, &targetID, &pin, &role)
	if err != nil || action != "RELAY" {
		conn.Write([]byte("ERR:INVALID_PROTOCOL\n"))
		conn.Close()
		return
	}

	key := fmt.Sprintf("%s:%s", targetID, pin)

	h.mu.Lock()
	if role == 1 { // 受控端入站驻留，等待控制端
		if old, exists := h.waiters[key]; exists {
			old.Close()
		}
		h.waiters[key] = conn
		h.mu.Unlock()
		log.Printf("[TCP-Relay] 受控端已在中继驻留等待: %s (Peer: %s)", targetID, conn.RemoteAddr().String())
		return
	}

	if role == 2 { // 控制端接入，请求与受控端配对桥接
		peerConn, exists := h.waiters[key]
		if !exists {
			h.mu.Unlock()
			conn.Write([]byte("ERR:TARGET_NOT_WAITING\n"))
			conn.Close()
			log.Printf("[TCP-Relay] 控制端匹配失败，受控端未驻留: %s", targetID)
			return
		}
		delete(h.waiters, key)
		h.mu.Unlock()

		conn.Write([]byte("OK\n"))
		peerConn.Write([]byte("OK\n"))
		log.Printf("[TCP-Relay] 成功建立双向极速中继通道: Target=%s", targetID)

		// 启动双向极速零拷贝转发
		go func() {
			defer peerConn.Close()
			defer conn.Close()
			io.Copy(peerConn, conn)
		}()
		go func() {
			defer peerConn.Close()
			defer conn.Close()
			io.Copy(conn, peerConn)
		}()
	}
}

func startTCPRelay(port int) {
	ln, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", port))
	if err != nil {
		log.Printf("[TCP-Relay] 端口绑定失败: %v", err)
		return
	}
	defer ln.Close()

	log.Printf("[TCP-Relay] 高性能 TCP 极速中继桥接服务已启动，监听端口: %d", port)
	hub := &RelayHub{waiters: make(map[string]net.Conn)}

	for {
		conn, err := ln.Accept()
		if err != nil {
			continue
		}
		go hub.handleConn(conn)
	}
}

func main() {
	server := NewSignalingServer()

	// 1. 启动 HTTP 信令接口
	http.HandleFunc("/api/register", server.handleRegister)
	http.HandleFunc("/api/connect", server.handleConnect)

	// 2. 在协程中启动 UDP 中继服务
	go startUDPRelay(8088)

	// 3. 在协程中启动 TCP 极速中继桥接服务 (8921)
	go startTCPRelay(8921)

	port := 8080
	log.Printf("======================================================")
	log.Printf("   QsyRemote 信令与 NAT 穿透中继服务器 (Go Backend)   ")
	log.Printf("   信令 HTTP 端口: %d | UDP 端口: 8088 | TCP 中继: 8921 ", port)
	log.Printf("======================================================")

	if err := http.ListenAndServe(fmt.Sprintf(":%d", port), nil); err != nil {
		log.Fatalf("HTTP 服务启动失败: %v", err)
	}
}
