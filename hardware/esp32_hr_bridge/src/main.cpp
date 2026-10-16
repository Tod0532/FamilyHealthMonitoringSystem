// ============================================================================
//  ESP32-S3 手环心率桥接固件
//
//  链路：手环（BLE 从机，心率服务 0x180D）
//          --BLE 通知(0x2A37)--> 本板（BLE 主机）
//          --WiFi/HTTP--> 家庭健康中心后端 --> App 显示与预警
//
//  已经用 nRF Connect 确认过：手环能连接并读到 0x180D 上的心率，
//  因此本固件按标准心率服务实现，不需要厂商私有协议。
//
//  为什么让板子当主机（而不是手机直连手环）：
//  BLE 从机通常只允许一个主机连接 —— 手机连上后板子就连不上。
//  让板子常连手环，手机只负责看数据，不会互相抢连接。
//
//  上报用现有接口（POST /api/health-data），因此**后端无需改动**即可跑通：
//    1) POST /api/auth/login {phone,password} → 拿 accessToken
//    2) POST /api/health-data {memberId,dataType,value1,...} 带 Bearer token
//  token 过期会自动重新登录；断网时读数进环形缓存，恢复后续传。
//
//  如需改成"设备令牌"模式（不用账号密码），见 README 的说明。
// ============================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <NimBLEDevice.h>
#include <time.h>

// ============================== 配置区 ==============================
// 全部集中在这里，改完直接烧写，不需要动其它代码。

static const char* WIFI_SSID = "你的WiFi名";
static const char* WIFI_PASS = "你的WiFi密码";

// 后端地址（阿里云）或本地调试地址（配合 adb reverse 时是 127.0.0.1 不行，
// 板子要填电脑的局域网 IP，例如 http://192.168.1.10:8080）
static const char* API_BASE = "http://139.129.108.119:8080";

// 用于登录的账号（与 App 同一个账号，数据就会出现在同一个家庭里）
static const char* API_PHONE = "13800138000";
static const char* API_PASSWORD = "abc123456";

// 这条心率记录归属到哪个家庭成员（memberId）。
// 取法：App → 成员页，或直接查库 `select id,name from family_member;`
static const long MEMBER_ID = 1;

// 手环的广播名（可用 nRF Connect 看到的那个名字，例如 "HR-287" / "G81-31824"）
// 留空表示"连接第一个广播了 0x180D 的设备"，更省事但可能连到别的设备
static const char* BAND_NAME = "HR-287";

// 上报策略：心率发生明显变化才上报，或至少每 HEARTBEAT_REPORT_MS 报一次
static const int   HR_CHANGE_THRESHOLD = 3;         // 变化 ≥3 bpm 就报
static const uint32_t HEARTBEAT_REPORT_MS = 60000;  // 否则每 60 秒报一次
static const uint32_t HR_STALE_MS = 10000;          // 超过 10 秒没新数据视为无效

// ============================== 常量 ==============================
static NimBLEClient* g_client = nullptr;
static NimBLERemoteCharacteristic* g_hrChar = nullptr;
static volatile int      g_lastHr = 0;
static volatile uint32_t g_lastHrMs = 0;
static volatile bool     g_connected = false;

static String g_token;
static uint32_t g_tokenAtMs = 0;
static const uint32_t TOKEN_TTL_MS = 90 * 60 * 1000UL; // 提前于后端 2h 过期

// 断网缓存（环形）
static const int CACHE_N = 30;
static int  g_cacheHr[CACHE_N];
static long g_cacheEpoch[CACHE_N];
static int  g_cacheCount = 0;

static int  g_lastReportedHr = -1;
static uint32_t g_lastReportMs = 0;

// ============================== BLE ==============================

// 心率通知回调：按 BLE 规范解析 0x2A37
//   data[0] = flags   bit0=1 → 心率是 2 字节(uint16)，否则 1 字节
//                     bit4=1 → 后面跟 RR 间期（本固件不使用）
static void onHrNotify(NimBLERemoteCharacteristic* ch, uint8_t* data,
                       size_t len, bool isNotify) {
  (void)ch; (void)isNotify;
  if (len < 2) return;
  const uint8_t flags = data[0];
  int hr = 0;
  if (flags & 0x01) {
    if (len < 3) return;
    hr = data[1] | (data[2] << 8);
  } else {
    hr = data[1];
  }
  if (hr >= 25 && hr <= 250) {
    g_lastHr = hr;
    g_lastHrMs = millis();
    Serial.printf("[BLE] 心率 %d bpm\n", hr);
  }
}

// 扫描并连接手环
static bool connectBand() {
  Serial.println("[BLE] 开始扫描...");
  NimBLEScan* scan = NimBLEDevice::getScan();
  scan->setActiveScan(true);
  scan->setInterval(100);
  scan->setWindow(80);

  NimBLEScanResults* found = scan->getResults(8000, false); // 扫 8 秒
  if (found == nullptr || found->getCount() == 0) {
    Serial.println("[BLE] 未扫到任何设备");
    scan->clearResults();
    return false;
  }

  NimBLEAdvertisedDevice* target = nullptr;
  for (int i = 0; i < found->getCount(); i++) {
    NimBLEAdvertisedDevice d = found->getDevice(i);
    const bool hasHrs = d.haveServiceUUID() &&
                        d.getServiceUUID().equals(NimBLEUUID((uint16_t)0x180D));
    Serial.printf("[BLE] 发现 %-22s rssi=%d %s\n",
                  d.getName().c_str(), d.getRSSI(),
                  hasHrs ? "[含心率服务]" : "");
    if (target != nullptr) continue;
    if (strlen(BAND_NAME) > 0) {
      if (d.haveName() && d.getName() == BAND_NAME) target = new NimBLEAdvertisedDevice(d);
    } else if (hasHrs) {
      target = new NimBLEAdvertisedDevice(d);
    }
  }
  scan->clearResults();

  if (target == nullptr) {
    Serial.printf("[BLE] 没找到目标手环（配置名 \"%s\"）。"
                  "若名字不对，请按上面打印的实际名字改 BAND_NAME。\n", BAND_NAME);
    return false;
  }

  Serial.printf("[BLE] 连接 %s ...\n", target->getAddress().toString().c_str());
  if (g_client == nullptr) {
    g_client = NimBLEDevice::createClient();
    g_client->setConnectTimeout(10);
    g_client->setReconnectTimeout(4, 30);
  }
  if (!g_client->connect(target)) {
    Serial.println("[BLE] 连接失败");
    return false;
  }
  delete target;

  // 发现心率服务与测量特征
  NimBLERemoteService* hrs = g_client->getService(NimBLEUUID((uint16_t)0x180D));
  if (hrs == nullptr) {
    Serial.println("[BLE] 对方没有 0x180D 心率服务（可能不是运动手环）");
    g_client->disconnect();
    return false;
  }
  g_hrChar = hrs->getCharacteristic(NimBLEUUID((uint16_t)0x2A37));
  if (g_hrChar == nullptr) {
    Serial.println("[BLE] 没有 0x2A37 心率测量特征");
    g_client->disconnect();
    return false;
  }
  if (!g_hrChar->canNotify() || !g_hrChar->subscribe(true, onHrNotify)) {
    Serial.println("[BLE] 订阅通知失败");
    g_client->disconnect();
    return false;
  }
  // 有些手环需要主动读一次才会开始推
  if (g_hrChar->canRead()) {
    NimBLEAttValue v = g_hrChar->readValue();
    if (v.size() >= 2) {
      uint8_t buf[4] = {0};
      memcpy(buf, v.data(), v.size() > 4 ? 4 : v.size());
      onHrNotify(g_hrChar, buf, v.size(), false);
    }
  }
  g_connected = true;
  Serial.println("[BLE] ✅ 已连接并订阅心率通知（请确保手环戴在手腕上）");
  return true;
}

// ============================== WiFi + HTTP ==============================

static void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.printf("[WiFi] 连接 %s ...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) delay(500);
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] ✅ 已连接，IP %s\n", WiFi.localIP().toString().c_str());
    configTime(8 * 3600, 0, "ntp.aliyun.com", "pool.ntp.org"); // 北京时间
  } else {
    Serial.println("[WiFi] ❌ 连接失败（检查 SSID/密码/信号）");
  }
}

// 登录换 token（后端返回 data.accessToken）
static bool login() {
  if (WiFi.status() != WL_CONNECTED) return false;
  HTTPClient http;
  String url = String(API_BASE) + "/api/auth/login";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  StaticJsonDocument<256> req;
  req["phone"] = API_PHONE;
  req["password"] = API_PASSWORD;
  String body;
  serializeJson(req, body);
  const int code = http.POST(body);
  String resp = http.getString();
  http.end();
  if (code != 200) {
    Serial.printf("[API] 登录失败 HTTP %d: %s\n", code, resp.c_str());
    return false;
  }
  DynamicJsonDocument res(4096);
  if (deserializeJson(res, resp) != DeserializationError::Ok) {
    Serial.println("[API] 登录响应解析失败");
    return false;
  }
  const char* tk = res["data"]["accessToken"] | "";
  if (strlen(tk) == 0) {
    Serial.printf("[API] 响应里没有 accessToken: %s\n", resp.c_str());
    return false;
  }
  g_token = tk;
  g_tokenAtMs = millis();
  Serial.println("[API] ✅ 登录成功，已取得 token");
  return true;
}

static String nowIso() {
  time_t t = time(nullptr);
  if (t < 100000) return ""; // 还没对上时间
  struct tm tmNow;
  localtime_r(&t, &tmNow);
  char buf[24];
  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tmNow);
  return String(buf);
}

// 上报一条心率
static bool postHeartRate(int hr, long epochSec) {
  if (WiFi.status() != WL_CONNECTED) return false;
  if (g_token.isEmpty() || millis() - g_tokenAtMs > TOKEN_TTL_MS) {
    if (!login()) return false;
  }
  HTTPClient http;
  String url = String(API_BASE) + "/api/health-data";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + g_token);

  DynamicJsonDocument req(512);
  req["memberId"] = MEMBER_ID;
  req["dataType"] = "heart_rate";
  req["value1"] = hr;
  req["unit"] = "bpm";
  req["dataSource"] = "device";
  req["deviceName"] = "ESP32-BLE-HR";
  req["notes"] = "手环BLE自动采集";
  String mt = nowIso();
  if (!mt.isEmpty()) req["measureTime"] = mt;
  String body;
  serializeJson(req, body);

  const int code = http.POST(body);
  String resp = http.getString();
  http.end();
  if (code == 200 || code == 201) {
    Serial.printf("[API] ✅ 已上报心率 %d bpm\n", hr);
    return true;
  }
  if (code == 401) g_token = ""; // token 失效，下次重新登录
  Serial.printf("[API] ❌ 上报失败 HTTP %d: %s\n", code, resp.c_str());
  return false;
}

static void cachePush(int hr, long epochSec) {
  if (g_cacheCount < CACHE_N) {
    g_cacheHr[g_cacheCount] = hr;
    g_cacheEpoch[g_cacheCount] = epochSec;
    g_cacheCount++;
  } else { // 满了就丢最旧的
    for (int i = 1; i < CACHE_N; i++) {
      g_cacheHr[i - 1] = g_cacheHr[i];
      g_cacheEpoch[i - 1] = g_cacheEpoch[i];
    }
    g_cacheHr[CACHE_N - 1] = hr;
    g_cacheEpoch[CACHE_N - 1] = epochSec;
  }
}

static void flushCache() {
  if (g_cacheCount == 0 || WiFi.status() != WL_CONNECTED) return;
  Serial.printf("[API] 补传缓存 %d 条...\n", g_cacheCount);
  int keep = 0;
  for (int i = 0; i < g_cacheCount; i++) {
    if (postHeartRate(g_cacheHr[i], g_cacheEpoch[i])) continue;
    g_cacheHr[keep] = g_cacheHr[i];
    g_cacheEpoch[keep] = g_cacheEpoch[i];
    keep++;
  }
  g_cacheCount = keep;
}

// ============================== 主流程 ==============================

void setup() {
  Serial.begin(115200);
  delay(800);
  Serial.println("\n=== ESP32 手环心率桥接启动 ===");

  NimBLEDevice::init("HealthBridge");
  NimBLEDevice::setPower(ESP_PWR_LVL_P9); // 增强发射功率，连接更稳

  ensureWiFi();
  if (WiFi.status() == WL_CONNECTED) login();

  connectBand();
}

void loop() {
  const uint32_t now = millis();

  // BLE 掉线重连
  if (!g_connected || (g_client != nullptr && !g_client->isConnected())) {
    g_connected = false;
    Serial.println("[BLE] 连接已断，5 秒后重连");
    delay(5000);
    ensureWiFi();
    connectBand();
  }

  // WiFi 断了也重连
  if (WiFi.status() != WL_CONNECTED) {
    ensureWiFi();
  }

  // 心率有效性判断
  const int hr = g_lastHr;
  const bool fresh = (g_lastHrMs != 0) && (now - g_lastHrMs < HR_STALE_MS);

  if (hr > 0 && fresh) {
    const bool changedEnough =
        g_lastReportedHr < 0 || abs(hr - g_lastReportedHr) >= HR_CHANGE_THRESHOLD;
    const bool heartbeatDue = (now - g_lastReportMs) >= HEARTBEAT_REPORT_MS;

    if (changedEnough || heartbeatDue) {
      const long epochSec = (long)time(nullptr);
      if (WiFi.status() == WL_CONNECTED && postHeartRate(hr, epochSec)) {
        g_lastReportedHr = hr;
        g_lastReportMs = now;
      } else {
        Serial.println("[API] 离线，读数进缓存");
        cachePush(hr, epochSec);
        g_lastReportedHr = hr;
        g_lastReportMs = now;
      }
    }
  } else if (g_lastHrMs != 0 && now - g_lastHrMs >= HR_STALE_MS) {
    static uint32_t warnedAt = 0;
    if (now - warnedAt > 30000) {
      Serial.println("[BLE] 已超过 10 秒没有心率数据："
                     "请确认手环戴在手腕上、且没有被其它 App 占用连接");
      warnedAt = now;
    }
  }

  // 有网就补传缓存
  if (WiFi.status() == WL_CONNECTED && g_cacheCount > 0) {
    static uint32_t lastFlush = 0;
    if (now - lastFlush > 15000) {
      lastFlush = now;
      flushCache();
    }
  }

  delay(1000);
}
