// ============================================================================
//  本机私有配置 —— 复制成 secrets.h 再填，**不要提交到 git**
//
//  用法：
//      copy include\secrets.example.h include\secrets.h
//      （然后编辑 include/secrets.h 填上真实值）
//
//  为什么不直接写在 src/main.cpp 里：
//    WiFi 密码、绑定码一旦进了 git 就等于泄密，而且以后换网、换密码还要改代码。
//    main.cpp 里对每一项都有 #ifndef 兜底，不建 secrets.h 也能编译。
// ============================================================================

#define HR_WIFI_SSID   "你的WiFi名"
#define HR_WIFI_PASS   "你的WiFi密码"

// 本地联调填电脑的局域网 IP（板子不能用 127.0.0.1），并保证板和电脑在同一 WiFi
// 例：http://192.168.1.10:8080
#define HR_API_BASE    "http://139.129.108.119:8080"

// App「我的 → 设备管理」生成的 6 位绑定码（10 分钟内有效、只能用一次）
#define HR_BIND_CODE   "000000"

// 设备序列号：同一块板子保持不变，改名等于换了一台设备（要重新绑定）
#define HR_DEVICE_SN   "HR-BRIDGE-001"

// 手环的 BLE 广播名（nRF Connect 里看到的）；留空则连第一个广播 0x180D 的设备
#define HR_BAND_NAME   "HR-287"
