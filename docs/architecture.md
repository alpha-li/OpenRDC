# OpenRDC 项目说明：目标、功能与架构

面向接手这个仓库的人：这份文档说明它要做什么、现在能做什么、内部是怎么搭起来的。
文案与本地化的规则见 [localization.md](localization.md)。

## 一、项目目标

**一句话**：一个 Windows App 风格的远程桌面客户端，界面用 Flutter，协议用 FreeRDP。

具体取向：

- **界面学 Windows App（微软远程桌面）**：连接中心是卡片网格，会话里是浮动连接栏而非停靠标题栏，
  配色与控件尺寸取自 WinUI 的 Fluent 令牌（见 `lib/theme/fluent_colors.dart`）。
- **协议不自研**：RDP 交给 FreeRDP，本项目只做「把 FreeRDP 接进 Flutter」这一件事，并且把它做成
  一层边界清晰的 C ABI，而不是把 FreeRDP 的用法撒进界面代码。
- **中文优先**：ARB 的模板是中文（`lib/l10n/app_zh.arb`），英文随行；缺失的英文会回退到中文而不是占位符。
- **分发就是解压即用**：Release 目录是自包含的（exe + Flutter 引擎 + FreeRDP 全套 DLL），
  不需要目标机器装 vcpkg 或任何开发工具。唯一的外部前提是 **VC++ 运行库**
  （exe 动态链接 `vcruntime140.dll` / `msvcp140.dll`，这两个不在包内，靠系统的
  Microsoft Visual C++ 2015–2022 Redistributable）。

非目标（当前明确不做）：跨平台（只有 Windows 的构建与胶水层）、自研 RDP 协议栈、多窗口/多会话并行
（一个进程一个会话，见 `rdc_session.h` 的说明）。

## 二、功能现状

### 主界面：连接中心

`lib/features/connection_center/connection_center_page.dart`，卡片见 `lib/widgets/pc_card.dart`。

- **分页**：主页 / 设备 / 收藏夹，标签带数量。主页与收藏夹目前显示同一组内容（收藏的电脑）；设备显示全部。
- **搜索**：匹配名称、主机名、分组，不区分大小写。无匹配、无电脑、收藏夹为空各有对应的空状态。
- **排序**：最近使用（默认，从未连接过的排在最后）、名称、手动（目前即录入顺序，拖拽排序尚未实现）。
- **视图**：网格（默认，卡片宽 240–300）与列表（40px 紧凑行，无缩略图）。
- **卡片**：整张卡就是连接入口（没有单独的「连接」按钮）；显示名称与主机名；
  缩略图是上一次会话的截图（见下文「会话预览」），没有则回退到显示器插图；
  悬停出现收藏星标与「更多选项」菜单（编辑 / 收藏 / 删除）。删除会连同缩略图一起清掉。
- 连接文件损坏时隔离为 `.corrupt-<时间戳>` 并在工具栏下方给出提示，程序以空列表继续运行。

### 电脑编辑器（一台电脑的连接配置）

`lib/features/pc_editor/pc_editor_page.dart`，四个分页：

| 分页 | 内容 |
|---|---|
| 常规 | 电脑名称（可含端口）、端口、友好名称、分组；凭据选择（每次询问 / 已保存的账户，可新建）；网关选择（可新建/编辑）；断线自动重连、连接到管理员会话、交换鼠标按键 |
| 显示 | 分辨率预设（1024×768 … 3840×2160）；色彩质量（32/24/16 位）；全屏启动会话、调整会话以适应窗口、在调整大小时更新分辨率 |
| 设备和音频 | 剪贴板重定向（双向 / 仅本地到远程 / 仅远程到本地 / 禁用）；声音播放位置（在此电脑 / 在远程电脑 / 从不）；驱动器重定向 |
| 文件夹 | 把本地文件夹作为网络驱动器共享进会话，每行可设只读 |

有意未暴露的项（代码里有注释）：多显示器选择、麦克风 / 打印机 / 智能卡 / 摄像头重定向。
模型里存了这些字段，但不发送给引擎——**唯一例外**是多显示器：模型默认值是「所有显示器」，
会话会照样把 multimon 请求发给 FreeRDP，而内核构建不支持跨屏，请求被忽略（`rdc_session.cpp` 里有日志）。

### 会话

`lib/features/session/session_page.dart`（界面与连接栏）、`desktop_surface.dart`（画面与输入）。

- **画面**：FreeRDP 渲染到帧环，Flutter 侧以 `Texture` 呈现。可等比缩放填充窗口（letterbox），
  也可按 1:1 显示并在放不下时滚动——后者文字最清晰。
- **鼠标**：移动（含无按键的悬停）、左中右键、滚轮；坐标按画面几何映射，边缘钳制。
- **键盘**：以扫描码发送，由**远端**的布局决定每个键产生什么字符（与硬件 KVM 一致）。
  无法用扫描码表达的键（媒体键等）退回按字符发送。
- **键盘接管**（连接期间）：见「三、核心架构 → 键盘接管」。
- **光标**：远端的光标形状是位图，取回来按热点画在指针位置，本机光标随之隐藏；
  远端说「用默认箭头」时用系统箭头，说「隐藏」时两边都不显示。
- **剪贴板**：文本双向重定向，受连接设置的分向开关约束。Flutter 没有剪贴板变更通知，
  本机剪贴板以 700ms 轮询。**文件剪贴板尚未实现**（需要 file-contents 子协议与临时目录）。
- **连接栏**：浮动胶囊，鼠标靠近窗口顶部 40px 显示，离开 3 秒后自动隐藏（拖动、离开窗口、
  回到热区等情形都有对应处理）；可固定。按钮：固定、状态点、名称、全屏/恢复、最小化、
  更多（发送 Ctrl+Alt+Del / 重新连接 / 断开连接）。
- **本地快捷键**：Ctrl+Alt+Home 唤出连接栏，Ctrl+Alt+Enter 切换全屏；这两个组合被客户端消费，不发给远端。
- **窗口**：「全屏」是本库去掉窗口边框、铺满显示器实现的，进入前的窗口几何被保存，退出时精确还原
  （包括之前是最大化）。离开会话页会自动退出全屏并归还键盘。
- **证书与凭据**：首次/变更的证书弹出不可点空白关闭的对话框（Esc 或关窗视为拒绝），
  指纹用等宽字体展示；连接设置为「每次询问」或凭据没有已存密码时，先弹出用户名/密码对话框；
  密码存进 Windows 凭据管理器（可选「记住密码」）。
- **会话预览**：连接成功 5 秒后取一帧存为卡片缩略图（此时远端若还没画出东西则每 5 秒重试，最多 3 次）。
- **合成会话**：核心带一个合成图源（`rdc_testpattern.cpp`），在没有可连主机时也能验证
  帧环 → 纹理 → Flutter 这条通路，以及把「画面坏了」归因到桥接还是网络。只在诊断页被调用。

### 设置

`lib/features/settings/settings_page.dart`：外观（跟随系统 / 浅色 / 深色）、用户账户（凭据的增删改）、
网关（增删改）、关于（应用版本、远程桌面引擎版本）。

### 命令行与诊断

`lib/main.dart`：

```
--connect host[:port]   直接打开会话，不显示连接中心
--user name             --connect 的用户名，可写 DOMAIN\user
--domain name           --connect 的域
--fullscreen            直接以全屏开始
--ignore-cert           跳过该连接的证书提示（默认不跳过）
--diagnostics           打开原生桥自检页
```

`--connect` 的密码来自环境变量 `OPENRDC_PASSWORD`，不走命令行（命令行会被别的进程看见）。
诊断页（`lib/features/diagnostics/bridge_probe_page.dart`）不是产品界面的一部分，文案也不走 ARB。

### 本地化

中文是模板与回退语言，英文随行；跟随系统语言，没有应用内切换开关。规则见 [localization.md](localization.md)。

### 尚未实现 / 已知限制

- **剪贴板文件传输**：未实现（需要 file-contents 子协议与共享临时目录）。
- **动态分辨率**：请求链路完整（ABI、会话线程发送 40 字节 `DISPLAY_CONTROL_MONITOR_LAYOUT`、
  Dart 侧防抖），但实测主机从不打开 DisplayControl 动态通道，因此不生效；降级是正确的——
  请求被丢弃、桌面保持原尺寸、画面按比例缩放并留黑边。已确认 `freerdp_display_send_monitor_layout`
  是错误函数（会在动态通道上断开连接），不要重试那条路。
- **多显示器**、**打印 / 智能卡 / 麦克风 / 摄像头**：见上文「有意未暴露的项」。
- **手动排序拖拽**、**列表视图缩略图**：未实现。
- **打包 / 签名 / CI**：目前产出的是便携 zip（`build/dist/`），没有安装包、没有代码签名、没有 CI。
- 版本号两处不一致：`pubspec.yaml` 是 `1.0.0+1`（模板默认值），而「关于」页显示 `lib/app_info.dart`
  里的 `0.1.0`；exe 的文件版本取自 pubspec。发布前需要统一。

## 三、核心架构

### 分层

```
lib/features/…        Flutter 界面（连接中心、编辑器、会话、设置）
        │  只认识下面的抽象，不接触 native 类型
lib/engine/…          RdcEngine 接口 + 事件/值类型（web 构建由 rdc_engine_stub.dart 顶上）
        │  条件导入选择实现
lib/engine/rdc_engine_bridge.dart   dart:ffi 只出现在这一个文件里
        │
packages/rdc_bridge/lib/rdc_bridge.dart   手写的 FFI 绑定（镜像 C ABI）
        │
packages/rdc_bridge/src/*.cpp             可移植核心 → rdc_bridge.dll（不含任何 Flutter 头文件）
        │
FreeRDP 3.32.1（vcpkg: freerdp[client]:x64-windows）→ freerdp3.dll / winpr3.dll / OpenSSL

packages/rdc_bridge/windows/rdc_bridge_plugin.cpp   Flutter 插件胶水（唯一接触引擎的一层）
        └─ 注册像素缓冲纹理、把帧环的帧推给引擎、把主窗口句柄交给核心
```

两处刻意的拆分：

- **核心不含 Flutter 头文件**。`rdc_bridge.dll` 由 Dart 用 `DynamicLibrary.open` 直接按名字加载，
  它只通过 `src/rdc_api.h` 的两个回调（事件、帧就绪）与 Flutter 相接。这样核心可以单独构建、
  单独推理，换平台也只是换胶水层。
- **`dart:ffi` 只出现在 `rdc_engine_bridge.dart`**。`lib/engine/rdc_engine.dart` 的值类型
  （`RdcFrame`、`RdcCursorShape`…）都不含 `dart:ui`/FFI 类型，web stub 才能一起编译，
  界面层也才能在测试里被假的引擎驱动。

### C ABI（`packages/rdc_bridge/src/rdc_api.h`）

- **错误码**：负数是本桥接自己的分类（`RDC_ERR_*`，界面有对应文案）。FreeRDP 自己的错误数值
  **故意不外泄**——它们是库的实现细节，一次升级就可能重新编号，而硬编码数值的应用会照常编译、
  只是把故障映射到错误的文案上。库的描述随消息一起带上，供排查。
- **事件**：`rdc_event_fn(kind, code, utf8_message)`，由 `NativeCallable.listener` 异步投递到
  Dart isolate。因此消息字符串必须放在活过本次调用的存储里——核心用 `TempMessage()`（每线程轮转的
  几块缓冲）。栈缓冲或临时对象的 `c_str()` 是 use-after-free，这里真出过这个 bug。
- **字符串**：跨边界的文本一律 UTF-8，只有剪贴板文本用 UTF-16——协议与 Windows 剪贴板本来就是 UTF-16，
  在这里转换只会多一次有损步骤。
- **结构体**：`rdc_connect_params` 里的布尔量是 `int32_t` 而不是 C `bool`，让布局不依赖编译器。

### 线程模型

| 线程 | 做什么 | 不能做什么 |
|---|---|---|
| 会话线程（每会话一个） | FreeRDP 事件循环；输入队列的 drain；所有通道回调（剪贴板、光标）都在这里 | 不能在回调里阻塞等待（见下） |
| 平台线程 = Dart UI isolate | 所有 FFI 调用的发起方；窗口命令；键盘钩子的安装 | 不能做长耗时同步工作（会冻住界面与消息循环） |
| 渲染线程（引擎的 raster 线程） | 经插件从帧环取帧上传纹理 | — |

三条硬规则，都是踩过坑换来的：

1. **通道接口在 `freerdp_connect` 返回之后才存在**。`PostConnect` 里查
   `freerdp_channels_get_static_channel_interface` 只会拿到 null，而且**失败是静默的**
   （会话照常跑，只是剪贴板重定向没了）。剪贴板因此在 `RunSession` 里、connect 之后挂接。
2. **`update->*` 回调要在 `PostConnect` 里装**。核心会在 `PostConnect` **之前**调用
   `pointer_cache_register_callbacks()` 覆盖这些回调，装早了会被顶掉、装晚了重连会漏。
   光标（`rdc_cursor.cpp`）因此装在 `PostConnect`。这两条规则看着像、方向相反。
3. **会话回调里不能阻塞等待响应**。事件循环靠 `freerdp_check_event_handles` 驱动，
   在回调里等一个响应会死锁。所以没有「发一个请求等结果」的写法：接收文件（未来）要写成
   由回调推进的状态机。唯一的例外是证书询问——它有目的地阻塞会话线程等界面回答，并且有 60 秒超时。

帧环（`rdc_frame_ring.{h,cpp}`）：三槽，生产者（会话线程）写、消费者（渲染线程）pin 住正在上传的那一帧。
像素数据从不在锁内拷贝，锁只保护槽位簿记；宁可丢一帧也不阻塞协议线程。

输入（鼠标、键盘、文本、Ctrl+Alt+Del）走队列：UI 线程 append，会话线程在每次回到等待之前 drain。
FreeRDP 的输入 API 没有文档化的线程安全保证，队列是让它变成单线程调用的办法。

### 键盘接管（Windows 专用，`rdc_keyboard.cpp`）

非英语输入法能不能用，取决于这里。两个部分：

- **把本地输入法从本进程的窗口上摘下来**（`ImmAssociateContext(hwnd, nullptr)`）。
  应用里没有任何文本输入通道，本地输入法一旦激活就会把按键吃去做本地组字——本地弹候选词、远端收不到。
  摘下之后按键以普通按键消息抵达，由**远端**的输入法组字（候选词出现在远端屏幕上，与 mstsc 一致）。
- **低层键盘钩子**只接管 Windows 自己会消费的键：Win、Alt+Tab、Alt+Esc、Ctrl+Esc、Alt+F4、
  Alt+Space、Ctrl+Space、PrintScreen。吞掉它们并直接投进输入队列；其余按键照旧走
  Flutter → Dart → 扫描码，两条路互不重叠，一个键只会送一次。Ctrl+Alt+Del 无法拦截（系统保留），
  由连接栏按钮合成发送。

两条约束：钩子必须装在**会抽消息的线程**上（Dart UI isolate 就是平台线程；装在不抽消息的线程上会
拖慢全系统键盘），因此由 Dart 调用安装，且 native 侧拒绝在没有消息队列的线程上安装；
关闭时必须恢复输入法关联，否则退出会话后应用自己的输入框（搜索、编辑器）中文打不进去。

### 会话生命周期

```
rdc_connect(params)                 复制参数，起工作线程，立即返回
  └─ WorkerMain                      配置 OpenSSL provider 路径 → 创建上下文与设置
      └─ freerdp_connect             → PreConnect 设置参数 → 证书验证（阻塞等界面）→ 认证
          ├─ PostConnect             gdi_init、帧环 Reset、装光标回调
          └─ RunSession              剪贴板挂接、动态通道订阅
              └─ 事件循环             DrainInput / PumpOutgoing / DrainResize → 等待事件
  └─ 收尾                            剪贴板 Detach、ResetCursor、gdi_free、freerdp_disconnect
```

界面侧的状态机是 `RdcSessionStatus`（idle/connecting/authenticating/connected/disconnecting/
disconnected/failed），失败会带一个负面错误码，界面查表换成中文文案。

### 数据与存储

`lib/data/`：

| 文件 | 位置与格式 | 说明 |
|---|---|---|
| `connections.json` | `%APPDATA%\OpenRDC\` | 电脑、凭据记录、网关；带 `schemaVersion` 便于以后迁移；损坏时隔离并继续 |
| `preferences.json` | 同上 | 目前只有主题模式；与连接文件分开存放，因为两者的寿命与失败后果不同 |
| `thumbnails\<连接 id>.png` | 同上 | 会话预览，宽 320px，等比 |
| 密码 | **不进文件** | 走 Windows 凭据管理器（`rdc_credential.cpp`，UTF-16LE blob），键为连接引用的凭据 id |

### 构建与运行

- **依赖**：vcpkg 的 `freerdp[client]:x64-windows`（当前 3.32.1），路径由
  `packages/rdc_bridge/windows/CMakeLists.txt` 里的 `VCPKG_ROOT` 决定（默认 `E:/vcpkg`，可用环境变量覆盖）。
  找不到会在 configure 阶段直接指出该装什么，而不是拖到链接期报几个找不到的 .lib。
- **随包分发的 DLL**：`freerdp3`、`freerdp-client3`、`winpr3`、`libcrypto-3-x64`、`libssl-3-x64`、
  `legacy.dll`、`cjson`、`z`。少一个的表现是启动时「无法继续执行代码」这类与代码无关的弹窗。
- **NLA 的前提**：`legacy.dll` 必须在包里，且核心在连接前调用
  `OSSL_PROVIDER_set_default_search_path(应用目录)`（`rdc_session.cpp` 的 `ConfigureOpenSslProviderPath`）。
  OpenSSL 3 不会在程序旁找 provider，缺了它就加载不到 legacy 提供者 → 没有 md4 → NTLM 被禁用 →
  NLA（现代 Windows 主机都要求）无法认证，而每一步最多只打一条警告日志，用户看到的是连接卡在
  「正在连接」。**`OPENSSL_MODULES` 环境变量在这里无效**（libcrypto 在 DLL 初始化阶段就解析好了搜索路径）。
- **Windows 上的插件软链**：`flutter build windows` 会为原生插件建符号链接，未开启开发者模式时会失败；
  解决办法是给 `windows/flutter/ephemeral/.plugin_symlinks/rdc_bridge` 建目录 junction
  （`cmd //c mklink /J ...`，不需要管理员权限）。
- **日志**：设 `OPENRDC_LOG=1` 后核心把自检信息写到 stderr。找不到问题时的第一站。

### 测试

`flutter test`，142 个用例（`test/{data,engine,features,models,l10n,theme}`）：

- 数据层：连接文件的读写、损坏隔离、引用清理（删凭据/网关/电脑时对连接的连带处理）、缩略图编码。
- 引擎层：把协议常量与 bridge 包的值对钉（两处各自声明同一组数值，只有测试能防它们漂移）。
- 界面层：连接中心、编辑器、设置、会话页（用假引擎驱动事件流）。
- 会话页的测试需要在**假时钟与真异步之间交替推进**：计时器跑在测试时钟上，而解码图片、写文件是真的异步。

native 侧没有测试基建（仓内没有任何 C++ 测试）。因此状态机与平台、协议解耦，便于以后单测；
目前以 `OPENRDC_LOG=1` 的日志加手工验证为准。**合成按键进不了 Flutter 窗口**，涉及键盘的路径
（扫描码映射、键盘接管）只能由人按键验证。

### 工具

`tool/` 下的脚本都从仓库根目录跑，产物与它自己一起提交：

```
dart run tool/make_icon.dart [--preview]   生成应用图标（ico 七个尺寸 + svg）；改设计改 _shapes 里的几何
dart run tool/localize.dart                把中文文案迁移到 ARB 键（再改文案时走同一份映射）
```

`tool/localize.py` 是同一份映射的 Python 版本，早先留下的；这台机器上没有 Python，实际能用的是 Dart 那个。
