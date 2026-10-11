// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'OpenRDC';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get back => '返回';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get refresh => '刷新';

  @override
  String get connect => '连接';

  @override
  String get close => '关闭';

  @override
  String get stop => '停止';

  @override
  String get unavailable => '不可用';

  @override
  String get notConfigured => '未配置';

  @override
  String get optional => '可选';

  @override
  String get tabHome => '主页';

  @override
  String get tabDevices => '设备';

  @override
  String get tabFavorites => '收藏夹';

  @override
  String get search => '搜索';

  @override
  String get sortBy => '排序方式';

  @override
  String get sortRecency => '最近使用';

  @override
  String get sortName => '名称';

  @override
  String get sortManual => '手动';

  @override
  String get switchToList => '切换为列表视图';

  @override
  String get switchToGrid => '切换为网格视图';

  @override
  String get addPc => '添加电脑';

  @override
  String get moreOptions => '更多选项';

  @override
  String get emptyNoDevicesTitle => '还没有保存任何电脑';

  @override
  String get emptyNoDevicesBody => '添加一台电脑即可开始远程连接。';

  @override
  String get emptyFavoritesTitle => '这里还没有内容';

  @override
  String get emptyFavoritesBody => '添加到收藏夹的电脑会显示在这里。';

  @override
  String get emptySearchTitle => '没有匹配的结果';

  @override
  String emptySearchBody(String query) {
    return '没有与「$query」匹配的电脑。';
  }

  @override
  String get cardRemoteDesktop => '远程桌面';

  @override
  String get cardAddToFavorites => '添加到收藏夹';

  @override
  String get cardRemoveFromFavorites => '从收藏夹中移除';

  @override
  String get deletePcTitle => '删除这台电脑？';

  @override
  String deletePcBody(String name) {
    return '将从连接中心移除「$name」。此操作不会影响远程电脑本身。';
  }

  @override
  String get editorAddPcTitle => '添加电脑';

  @override
  String get editorEditPcTitle => '编辑电脑';

  @override
  String get tabGeneral => '常规';

  @override
  String get tabDisplay => '显示';

  @override
  String get tabDevicesAndAudio => '设备和音频';

  @override
  String get tabFolders => '文件夹';

  @override
  String get fieldPcName => '电脑名称';

  @override
  String get fieldPcNamePlaceholder => '主机名或 IP 地址，可含端口';

  @override
  String get fieldPort => '端口';

  @override
  String get fieldFriendlyName => '友好名称';

  @override
  String get fieldFriendlyNamePlaceholder => '留空则显示电脑名称';

  @override
  String get fieldGroup => '分组';

  @override
  String get validationPcNameRequired => '请填写电脑名称或 IP 地址';

  @override
  String get credentials => '凭据';

  @override
  String get fieldUserAccount => '用户账户';

  @override
  String get askEveryTime => '每次询问';

  @override
  String get newCredential => '新建凭据';

  @override
  String get editCredential => '编辑凭据';

  @override
  String get credentialUsername => '用户名';

  @override
  String get credentialUsernamePlaceholder => '用户名 或 域\\用户名';

  @override
  String get credentialPassword => '密码';

  @override
  String get credentialFriendlyNamePlaceholder => '可选，用于在列表中识别';

  @override
  String get validationUsernameRequired => '请填写用户名';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get vaultNotPersistentWarning =>
      '当前版本尚未接入系统凭据管理器，密码只在本次运行期间有效，重启后需要重新输入。';

  @override
  String get rememberPassword => '记住密码';

  @override
  String get rememberPasswordBody => '保存到系统凭据管理器，以后连接不再询问';

  @override
  String get passwordOnlyThisSession => '密码只在本次运行期间保留，重启后需要重新输入。';

  @override
  String get credentialPasswordNotSaved => '尚未为此凭据保存密码。';

  @override
  String get storeErrorUnreadable => '无法读取已保存的连接，已从空白开始。原文件已备份。';

  @override
  String get storeErrorMalformed => '已保存的连接文件内容无效，已从空白开始。原文件已备份。';

  @override
  String get storeErrorUnsupportedVersion => '连接文件由更新版本的应用写入，请升级后再打开。';

  @override
  String get storeErrorWriteFailed => '无法保存连接，本次更改未写入磁盘。';

  @override
  String get gateway => '网关';

  @override
  String get newGateway => '新建网关';

  @override
  String get editGateway => '编辑网关';

  @override
  String get gatewayAddress => '网关地址';

  @override
  String get gatewayAddressPlaceholder => '例如 gateway.example.com';

  @override
  String get gatewayCredentials => '网关凭据';

  @override
  String get gatewaySameAsPc => '与电脑凭据相同';

  @override
  String get fieldBypassGateway => '本地地址绕过网关';

  @override
  String get fieldBypassGatewayBody => '访问本地网络中的电脑时直连，不经过网关';

  @override
  String get validationGatewayRequired => '请填写网关地址';

  @override
  String get session => '会话';

  @override
  String get fieldReconnect => '断线时自动重新连接';

  @override
  String get fieldAdminSession => '连接到管理员会话';

  @override
  String get fieldAdminSessionBody => '以控制台会话登录，用于排查问题';

  @override
  String get fieldSwapMouseButtons => '交换鼠标按键';

  @override
  String get fieldResolution => '分辨率';

  @override
  String get fieldColorQuality => '色彩质量';

  @override
  String get colorQualityHighest => '最高质量（32 位）';

  @override
  String get colorQualityEnhanced => '增强色（24 位）';

  @override
  String get colorQualityHigh => '高彩色（16 位）';

  @override
  String get displayWindowBehaviour => '窗口行为';

  @override
  String get fieldStartFullScreen => '全屏启动会话';

  @override
  String get fieldFitToWindow => '调整会话以适应窗口';

  @override
  String get fieldFitToWindowBody => '缩放画面以填满窗口，远程分辨率保持不变';

  @override
  String get fieldUpdateResolutionOnResize => '在调整大小时更新分辨率';

  @override
  String get fieldUpdateResolutionOnResizeBody => '窗口变化时通知远程主机切换分辨率';

  @override
  String get clipboard => '剪贴板';

  @override
  String get fieldClipboardRedirection => '剪贴板重定向';

  @override
  String get clipboardBidirectional => '双向';

  @override
  String get clipboardLocalToRemote => '仅本地到远程';

  @override
  String get clipboardRemoteToLocal => '仅远程到本地';

  @override
  String get clipboardDisabled => '禁用';

  @override
  String get audio => '音频';

  @override
  String get fieldAudioPlayback => '播放声音';

  @override
  String get audioOnThisComputer => '在此电脑上';

  @override
  String get audioOnRemotePc => '在远程电脑上';

  @override
  String get audioNever => '从不播放';

  @override
  String get devices => '设备';

  @override
  String get fieldRedirectDrives => '驱动器';

  @override
  String get redirectedFolders => '重定向文件夹';

  @override
  String get foldersEmpty => '尚未添加文件夹。添加后，本地文件夹会作为网络驱动器出现在远程会话中。';

  @override
  String get addFolder => '添加文件夹';

  @override
  String get folderPathPlaceholder => '例如 D:\\项目';

  @override
  String get folderReadOnly => '只读';

  @override
  String get sessionMinimize => '最小化';

  @override
  String get sessionFullScreen => '全屏 (Ctrl+Alt+Enter)';

  @override
  String get sessionRestoreWindow => '恢复到全屏前的窗口大小 (Ctrl+Alt+Enter)';

  @override
  String get sessionPinBar => '固定连接栏';

  @override
  String get sessionUnpinBar => '取消固定连接栏';

  @override
  String get sessionOptions => '会话选项';

  @override
  String get sessionSendCad => '发送 Ctrl+Alt+Del';

  @override
  String get sessionReconnect => '重新连接';

  @override
  String get sessionDisconnect => '断开连接';

  @override
  String get sessionEngineUnavailable => '远程桌面引擎不可用';

  @override
  String get statusIdle => '空闲';

  @override
  String get statusConnecting => '正在连接';

  @override
  String get statusAuthenticating => '正在验证身份';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusDisconnecting => '正在断开连接';

  @override
  String get statusDisconnected => '已断开连接';

  @override
  String get statusFailed => '连接失败';

  @override
  String get certificateUntrustedTitle => '无法验证远程计算机的身份。是否仍要连接？';

  @override
  String get certificateChangedTitle => '已保存的证书发生了变化';

  @override
  String get certificateChangedBody =>
      '这台计算机出示的证书与之前保存的不一致。如果这不是你预期的变更（例如重装了系统或更换了证书），也可能是有人在中间截获你的连接。';

  @override
  String get certificateNameMismatchTitle => '证书中的名称与这台计算机不符';

  @override
  String get certificateNameMismatchBody =>
      '证书不是为这个地址签发的。如果这台计算机改名或换了地址，这属于正常；否则说明你连接的并不是它自称的那台机器。';

  @override
  String get certificateRequestedHost => '请求连接的远程计算机';

  @override
  String get certificateName => '证书中的名称';

  @override
  String get certificateNoName => '（证书中没有名称）';

  @override
  String get certificateIssuer => '颁发者';

  @override
  String get certificatePreviousFingerprint => '之前的指纹';

  @override
  String get certificateCurrentFingerprint => '当前指纹';

  @override
  String get certificateFingerprint => '指纹';

  @override
  String get certificateNone => '（无）';

  @override
  String get certificateAcceptChanged => '选择「是」将接受新的证书并替换已保存的证书。';

  @override
  String get certificateAcceptRemembered => '选择「是」后，将记住这台计算机的证书，以后连接不再提示。';

  @override
  String get settings => '设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsThemeMode => '外观模式';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsUserAccounts => '用户账户';

  @override
  String get settingsUserAccountsBody =>
      '保存的凭据用于远程电脑登录。密码存放在系统凭据管理器中，可在此处或系统的凭据界面删除。';

  @override
  String get settingsAccountsEmpty => '尚未保存任何凭据。';

  @override
  String get accountDeleteTitle => '删除这个凭据？';

  @override
  String accountDeleteBody(String name) {
    return '将从系统凭据管理器中移除「$name」的密码。使用它的连接会改为每次询问。';
  }

  @override
  String get settingsGateways => '网关';

  @override
  String get settingsGatewaysBody => '网关可以让远程连接经由它中转，用于访问内网中的电脑。';

  @override
  String get settingsGatewaysEmpty => '尚未保存任何网关。';

  @override
  String get gatewayDeleteTitle => '删除这个网关？';

  @override
  String gatewayDeleteBody(String name) {
    return '将移除「$name」。仍在引用它的连接会改为直连，需要时再重新指定。';
  }

  @override
  String get settingsAbout => '关于';

  @override
  String get aboutVersion => '应用版本';

  @override
  String get aboutEngine => '远程桌面引擎';

  @override
  String get aboutEngineUnavailable => '不可用';

  @override
  String get errorConnectFailed => '无法连接到远程电脑。请检查地址与端口是否正确，以及网络是否可达。';

  @override
  String get errorTlsFailed => '与远程电脑建立安全连接失败。可能是对方证书有问题，或中间有设备在干扰。';

  @override
  String get errorPasswordExpired => '账户密码已过期或必须先修改密码，请在远程电脑上处理后再连接。';

  @override
  String get errorAuthFailed => '登录被拒绝。请确认用户名和密码，以及该账户是否有权远程登录。';

  @override
  String get errorNoCredentials => '远程电脑要求提供用户名和密码。';

  @override
  String get errorSessionStart => '远程桌面引擎无法启动会话。';

  @override
  String get errorInternal => '远程桌面引擎内部错误，会话无法继续。';

  @override
  String get errorAlreadyRunning => '已有一个会话在运行。';

  @override
  String get errorEngineUnavailable => '远程桌面引擎不可用，可能是原生组件未能加载。';

  @override
  String get errorEngineDisposed => '会话已结束。';
}
