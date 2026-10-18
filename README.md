# OpenRDC

Windows App 风格的远程桌面客户端。界面用 Flutter，协议交给 FreeRDP。

支持 **Windows** 与 **Linux**：Windows 实现了全部功能（键盘有一个未解决的问题，见「已知限制」）；Linux 可以构建、连接、显示画面并使用鼠标，窗口控制与凭据存储已实现，键盘接管有意未实现。

## 现在能做什么

- **连接中心**：卡片与列表两种视图、搜索、排序、收藏、主页 / 设备 / 收藏夹三个分页
- **每台电脑的配置**：凭据、网关、分辨率、色彩深度、全屏、断线重连、剪贴板方向、驱动器与文件夹重定向
- **会话**：画面经纹理呈现，鼠标（含滚轮）、键盘扫描码、远端光标、文本剪贴板、证书询问、会话预览缩略图
- **设置**：外观、用户账户、网关、关于
- **命令行**：`--connect host[:port]`、`--user`、`--domain`、`--fullscreen`、`--ignore-cert`、`--diagnostics`；`--connect` 的密码从环境变量 `OPENRDC_PASSWORD` 读取，不出现在进程列表里

## 架构

```
lib/                          Flutter：界面、数据层、引擎接口
  data/                       连接、偏好、缩略图、凭据库
  engine/                     RdcEngine 接口与事件类型（web 走 stub）
packages/rdc_bridge/
  lib/rdc_bridge.dart         手写 FFI 绑定，镜像 C ABI
  src/                        可移植核心，C++17，不含任何 Flutter 头文件
  src/platform/{windows,linux,null}/   窗口、凭据、键盘的实现
  windows/ linux/             Flutter 插件胶水（纹理注册、窗口句柄）
windows/ linux/               应用外壳，由 Flutter 生成
docs/                         架构与本地化说明
```

核心与界面之间只有一层 C ABI（[`src/rdc_api.h`](packages/rdc_bridge/src/rdc_api.h)），`dart:ffi` 只出现在 [`rdc_engine_bridge.dart`](lib/engine/rdc_engine_bridge.dart) 一个文件里。这样核心可以单独构建、单独推理，换平台只是换胶水层。细节见 [docs/architecture.md](docs/architecture.md)。

没有 FreeRDP 时核心会编译出 stub，导出完整 ABI，调用方得到「built without protocol support」而不是链接失败。

## 构建

前置：**Flutter 3.47.7**（Dart ≥ 3.11.5）。

### Windows

需要 Visual Studio 2022 的 **使用 C++ 的桌面开发** 工作负载（含 MSVC、CMake 与 Windows SDK），以及用 vcpkg 安装的 FreeRDP：

```bat
vcpkg install "freerdp[client]:x64-windows"
setx VCPKG_ROOT "C:\path\to\vcpkg"
flutter build windows --release
```

产物在 `build\windows\x64\runner\Release\`。目录自包含（exe + Flutter 引擎 + FreeRDP 全套 DLL），目标机器只需要 VC++ 2015–2022 运行库。

若未开启 Windows 开发者模式，`flutter build` 建插件符号链接会失败；替代办法是给 `windows/flutter/ephemeral/.plugin_symlinks/rdc_bridge` 建一个指向 `packages/rdc_bridge` 的目录 junction。

### Linux

```bash
sudo apt-get install clang ninja-build pkg-config libgtk-3-dev liblzma-dev \
                     libstdc++-12-dev freerdp3-dev libssl-dev libsecret-1-dev
flutter build linux --release
```

产物在 `build/linux/x64/release/bundle/`。FreeRDP 使用发行版的包，不复制进 bundle。

> 同一份检出交替构建两个平台时，切换后要先跑对应平台的 `flutter pub get`：`.dart_tool/` 是单份的，两个平台会互相覆盖。

## 测试

```bash
flutter test
```

目前 153 个用例，覆盖数据层、引擎常量、界面与本地化。原生侧没有单元测试，以 `OPENRDC_LOG=1` 的日志加手工验证为准——尤其是键盘路径，合成按键进不了 Flutter 窗口。

## 数据存放

| 平台 | 位置 |
|---|---|
| Windows | `%APPDATA%\OpenRDC\` |
| Linux | `$XDG_CONFIG_HOME/openrdc/` 或 `~/.config/openrdc/` |

连接与偏好是 JSON，缩略图是 PNG。密码不写文件：Windows 走凭据管理器，Linux 走 Secret Service（libsecret）。

## 已知限制

- **剪贴板文件传输**未实现，只重定向文本
- **动态分辨率**请求链路完整，但实测主机不打开 DisplayControl 动态通道，因此不生效；画面会按比例缩放并留黑边
- **多显示器、打印、智能卡、麦克风、摄像头**：模型里有字段，未发给引擎
- **Windows 键盘有一个未解决的问题**：当本机本身是「被另一台机器 RDP 进来」的会话时，会话里的字母键收不到（删除、空格等正常）；直接在本机操作则正常。已定位到本地输入法在按键到达应用前参与组字的可能性，但尚未修复
- **Linux 键盘接管有意未实现**：Windows 钩子拿的那些键（Super、Alt+Tab 等）在 Linux 属于窗口管理器，应用要拿只能抓整个键盘；Wayland 下合成器禁止全局拦截。普通按键路径不受影响
- **Linux 凭据**需要运行中的 Secret Service；没有时退化为每次询问密码，不会失败
- 没有安装包、代码签名与 CI，产物是便携目录

## 许可

MIT，见 [LICENSE](LICENSE)。
