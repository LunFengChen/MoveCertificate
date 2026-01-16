# MoveCertificate

[English](#english) | 中文

支持 Android 7 - 16，兼容 Magisk / KernelSU / APatch

基于 [ys1231/MoveCertificate](https://github.com/ys1231/MoveCertificate) 二次开发，更方便个人/群控使用的版本。告别各种繁琐步骤：
- 不再需要 手机设置的证书安装程序
- 批量安装时不再需要证书计算hash
- 不再需要 shell命令
- 不再需要 证书格式转换；

## 使用方法

**方法1：CI 内置证书（适合群控/刷机党，无需本地环境）**

1. Fork 本仓库
2. 把证书文件（.pem/.crt/.cer）放到 `certificates/` 目录
3. Push 触发 GitHub Actions 自动构建
4. 从 Actions 或 Releases 下载带证书的模块

**方法2：adb 推送安装（Magisk/KernelSU/APatch 通用）**

推送各种类型的证书到指定目录

```bash
# 支持任意格式，重启时自动转换
adb push cert.pem /data/local/tmp/cert/
adb reboot
```

**方法3：WebUI 安装（KernelSU/APatch）**

推送各种类型的证书到候选目录

我一般是点击抓包软件app中的导出证书，如reqable
```bash
adb push cert.pem /sdcard/Download/
# 模块 → ⚙️ → 候选区域点 ➕ → 重启
```

<img src="screenshots/1.png" width="300" alt="WebUI 证书列表">
<img src="screenshots/2.png" width="300" alt="WebUI 证书详情">

## 本地构建

```bash
./build.sh                    # 默认构建
./build.sh -v v1.1.0          # 指定版本
./build.sh -c ./my-certs      # 内置证书
```

---

<a name="english"></a>
# MoveCertificate (English)

Supports Android 7 - 16, compatible with Magisk / KernelSU / APatch

Enhanced [ys1231/MoveCertificate](https://github.com/ys1231/MoveCertificate) for easier personal/batch deployment.

## New Features

- Auto-convert `.pem` `.crt` `.cer` to system format (.0), no manual hash calculation
- Built-in cert-hash tool, works on Magisk/KernelSU/APatch
- WebUI certificate management (KernelSU/APatch) with details viewer

## Usage

**Method 1: CI bundled certs (for batch deployment, no local env needed)**

1. Fork this repo
2. Put cert files (.pem/.crt/.cer) in `certificates/` directory
3. Push to trigger GitHub Actions build
4. Download module with bundled certs from Actions or Releases

**Method 2: adb push (Magisk/KernelSU/APatch)**
```bash
# Any format supported, auto-convert on reboot
adb push cert.pem /data/local/tmp/cert/
adb reboot
```

**Method 3: WebUI (KernelSU/APatch)**
```bash
adb push cert.pem /sdcard/Download/
# Module → ⚙️ → Click ➕ in Candidates → Reboot
```

## Build

```bash
./build.sh                    # Default
./build.sh -v v1.1.0          # Custom version
./build.sh -c ./my-certs      # Bundle certs
```
