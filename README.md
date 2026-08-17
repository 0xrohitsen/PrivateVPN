# 🛡️ PrivateVPN — Self-Hosted WireGuard VPN for Android

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-10%2B-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![WireGuard](https://img.shields.io/badge/WireGuard-GoBackend-88171A?logo=wireguard&logoColor=white)](https://www.wireguard.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**PrivateVPN** is an ultra-fast, modern, privacy-first WireGuard VPN client and server suite. Built from the ground up for self-hosters who demand total control over their data, zero logs, per-app routing, and multi-device management.

---

## ✨ Features

- 🚀 **100% Self-Hosted & Zero Logs:** Your server, your encryption keys, zero intermediary tracking.
- ⚡ **WireGuard Native Performance:** Powered by the official Android `GoBackend` for blazing speeds and minimal battery consumption.
- 🎛️ **Per-App VPN Filter (Split Tunneling):** Choose precisely which apps route through your VPS and which apps bypass the VPN.
- 🔄 **Auto-Recovery & Reconnect:** Application singleton architecture ensures the tunnel state seamlessly persists across app backgrounding, task swiping, and reboots.
- 👥 **Multi-Device Server Manager:** 1-Click interactive script to generate, manage, list, and revoke configurations for up to dozens of client devices.
- 🎨 **Modern Dark UI:** Material 3 design system with live connection timers, real-time public IP resolver, and connection pulse animations.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PrivateVPN Android App                   │
├─────────────────────────┬───────────────────────────────────┤
│    Flutter UI Layer     │ Material 3, Dark Mode, Diagnostics │
├─────────────────────────┼───────────────────────────────────┤
│    Native Kotlin Layer  │ MethodChannel, Foreground Service │
├─────────────────────────┼───────────────────────────────────┤
│    WireGuard Engine     │ WireGuard-Android GoBackend       │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
      Encrypted Traffic             Direct Traffic
      (Selected Apps)              (Bypassed Apps)
             │                            │
             ▼                            ▼
   ┌───────────────────┐             ┌────────┐
   │ Private VPS (wg0) │             │ Normal │
   │ WireGuard Server  │             │  ISP   │
   └─────────┬─────────┘             └────────┘
             │
      Public Internet
```

---

## ⚡ 1-Minute Server Setup (Ubuntu / Debian VPS)

Run this one-line command on your Ubuntu (20.04/22.04/24.04/26.04) or Debian server as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/0xrohitsen/PrivateVPN/main/scripts/privatevpn-server.sh | sudo bash
```

*(Alternatively, clone the repository and run `sudo bash scripts/privatevpn-server.sh`)*

### 🎮 Interactive Server Management Menu

Running the script anytime brings up the server control panel:

```text
=====================================================
          PrivateVPN — Server Manager                
=====================================================
Server IP: 62.238.101.17 | Port: 51820 | Status: ACTIVE
Configured Peers: 3
-----------------------------------------------------
  1) ➕ Add / Generate New Device Client
  2) 📊 List Connected Devices & Live Traffic Stats
  3) 🔍 View Device Config & QR Code
  4) 🗑️  Remove / Revoke Device Client
  5) 🔄 Restart WireGuard Server
  6) ⚠️  Uninstall WireGuard Server
  7) 🚪 Exit
-----------------------------------------------------
Choose an option [1-7]:
```

---

## 📱 Android App Setup

### Method 1: 1-Click `.conf` Import (Recommended)
1. In the terminal output from the server script, copy the `[Interface]` `.conf` text.
2. In the PrivateVPN app, tap **Settings (⚙️)** → **Import / Export**.
3. Paste the configuration and tap **Save**.

### Method 2: Manual Credentials Entry
In **Settings (⚙️)**, enter the generated credentials:
- **Server Endpoint:** `YOUR_SERVER_IP:51820`
- **Server Public Key:** `Server public key from setup`
- **Client Address:** `10.8.0.X/32` *(Must match the specific device IP)*
- **Client Private Key:** `Client private key from setup`
- **DNS:** `1.1.1.1`

---

## 🛠️ Building From Source

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or later)
- Android SDK (API level 34+)
- JDK 17

### 1. Clone the repository
```bash
git clone https://github.com/0xrohitsen/PrivateVPN.git
cd PrivateVPN
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Build Debug APK
```bash
flutter build apk --debug
```

### 4. Build Signed Release APK
1. Create `android/key.properties` from the template:
   ```bash
   cp android/key.properties.example android/key.properties
   ```
2. Generate your release keystore:
   ```bash
   keytool -genkey -v -keystore android/app/privatevpn-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias privatevpn
   ```
3. Fill in your passwords and alias in `android/key.properties`.
4. Compile the signed release APK:
   ```bash
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔒 Security & Privacy

- **No Third-Party Trackers:** No analytics SDKs, no ad networks, no external tracking.
- **Cryptographic Security:** Uses WireGuard's state-of-the-art cryptography (Noise protocol framework, Curve25519, ChaCha20, Poly1305, BLAKE2s).
- **Hardened IP Forwarding:** Firewall rules strictly enforce isolation and forward only legitimate WireGuard subnet packets (`10.8.0.0/24`) through NAT Masquerading.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
