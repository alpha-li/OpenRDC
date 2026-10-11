// Replaces Chinese string literals in the product UI with generated
// localisation accessors.
//
// A migration aid kept beside the tooling rather than deleted: a future string
// change goes through the same mapping, and re-deriving it by hand is the
// tedious part. Run from the repository root:
//
//   dart run tool/localize.dart
//
// The diagnostic page, the model layer's value formatting ("1920 x 1080" is not
// copy) and the native and storage error messages are deliberately not listed.
// The first two are not product copy; the last two need an error-code
// indirection before they can be translated, which is a separate change.
import 'dart:io';

const Map<String, String> mapping = {
  '取消': 'cancel',
  '保存': 'save',
  '添加': 'add',
  '编辑': 'edit',
  '删除': 'delete',
  '移除': 'remove',
  '返回': 'back',
  '是': 'yes',
  '否': 'no',
  '刷新': 'refresh',
  '连接': 'connect',
  '停止': 'stop',
  '不可用': 'unavailable',
  '未配置': 'notConfigured',
  '可选': 'optional',

  '主页': 'tabHome',
  '设备': 'tabDevices',
  '收藏夹': 'tabFavorites',

  '搜索': 'search',
  '排序方式': 'sortBy',
  '最近使用': 'sortRecency',
  '名称': 'sortName',
  '手动': 'sortManual',
  '切换为列表视图': 'switchToList',
  '切换为网格视图': 'switchToGrid',
  '添加电脑': 'addPc',
  '更多选项': 'moreOptions',

  '还没有保存任何电脑': 'emptyNoDevicesTitle',
  '添加一台电脑即可开始远程连接。': 'emptyNoDevicesBody',
  '这里还没有内容': 'emptyFavoritesTitle',
  '添加到收藏夹的电脑会显示在这里。': 'emptyFavoritesBody',
  '没有匹配的结果': 'emptySearchTitle',

  '远程桌面': 'cardRemoteDesktop',
  '添加到收藏夹': 'cardAddToFavorites',
  '从收藏夹中移除': 'cardRemoveFromFavorites',

  '删除这台电脑？': 'deletePcTitle',

  '编辑电脑': 'editorEditPcTitle',
  '常规': 'tabGeneral',
  '显示': 'tabDisplay',
  '设备和音频': 'tabDevicesAndAudio',
  '文件夹': 'tabFolders',

  '电脑名称': 'fieldPcName',
  '主机名或 IP 地址，可含端口': 'fieldPcNamePlaceholder',
  '端口': 'fieldPort',
  '友好名称': 'fieldFriendlyName',
  '留空则显示电脑名称': 'fieldFriendlyNamePlaceholder',
  '分组': 'fieldGroup',
  '请填写电脑名称或 IP 地址': 'validationPcNameRequired',

  '凭据': 'credentials',
  '用户账户': 'fieldUserAccount',
  '每次询问': 'askEveryTime',
  '新建凭据': 'newCredential',
  '编辑凭据': 'editCredential',
  '用户名': 'credentialUsername',
  '用户名 或 域\\用户名': 'credentialUsernamePlaceholder',
  '密码': 'credentialPassword',
  '可选，用于在列表中识别': 'credentialFriendlyNamePlaceholder',
  '请填写用户名': 'validationUsernameRequired',
  '显示密码': 'showPassword',
  '隐藏密码': 'hidePassword',
  '当前版本尚未接入系统凭据管理器，密码只在本次运行期间有效，重启后需要重新输入。':
      'vaultNotPersistentWarning',
  '记住密码': 'rememberPassword',
  '保存到系统凭据管理器，以后连接不再询问': 'rememberPasswordBody',
  '密码只在本次运行期间保留，重启后需要重新输入。': 'passwordOnlyThisSession',

  '网关': 'gateway',
  '新建网关': 'newGateway',
  '编辑网关': 'editGateway',
  '网关地址': 'gatewayAddress',
  '例如 gateway.example.com': 'gatewayAddressPlaceholder',
  '网关凭据': 'gatewayCredentials',
  '与电脑凭据相同': 'gatewaySameAsPc',
  '本地地址绕过网关': 'fieldBypassGateway',
  '访问本地网络中的电脑时直连，不经过网关': 'fieldBypassGatewayBody',
  '请填写网关地址': 'validationGatewayRequired',

  '会话': 'session',
  '断线时自动重新连接': 'fieldReconnect',
  '连接到管理员会话': 'fieldAdminSession',
  '以控制台会话登录，用于排查问题': 'fieldAdminSessionBody',
  '交换鼠标按键': 'fieldSwapMouseButtons',

  '分辨率': 'fieldResolution',
  '色彩质量': 'fieldColorQuality',
  '最高质量（32 位）': 'colorQualityHighest',
  '增强色（24 位）': 'colorQualityEnhanced',
  '高彩色（16 位）': 'colorQualityHigh',
  '窗口行为': 'displayWindowBehaviour',
  '全屏启动会话': 'fieldStartFullScreen',
  '调整会话以适应窗口': 'fieldFitToWindow',
  '缩放画面以填满窗口，远程分辨率保持不变': 'fieldFitToWindowBody',
  '在调整大小时更新分辨率': 'fieldUpdateResolutionOnResize',
  '窗口变化时通知远程主机切换分辨率': 'fieldUpdateResolutionOnResizeBody',

  '剪贴板': 'clipboard',
  '剪贴板重定向': 'fieldClipboardRedirection',
  '双向': 'clipboardBidirectional',
  '仅本地到远程': 'clipboardLocalToRemote',
  '仅远程到本地': 'clipboardRemoteToLocal',
  '禁用': 'clipboardDisabled',

  '音频': 'audio',
  '播放声音': 'fieldAudioPlayback',
  '在此电脑上': 'audioOnThisComputer',
  '在远程电脑上': 'audioOnRemotePc',
  '从不播放': 'audioNever',

  '驱动器': 'fieldRedirectDrives',

  '重定向文件夹': 'redirectedFolders',
  '尚未添加文件夹。添加后，本地文件夹会作为网络驱动器出现在远程会话中。': 'foldersEmpty',
  '添加文件夹': 'addFolder',
  '例如 D:\\项目': 'folderPathPlaceholder',
  '只读': 'folderReadOnly',

  '最小化': 'sessionMinimize',
  '全屏 (Ctrl+Alt+Enter)': 'sessionFullScreen',
  '固定连接栏': 'sessionPinBar',
  '取消固定连接栏': 'sessionUnpinBar',
  '会话选项': 'sessionOptions',
  '发送 Ctrl+Alt+Del': 'sessionSendCad',
  '重新连接': 'sessionReconnect',
  '断开连接': 'sessionDisconnect',
  '远程桌面引擎不可用': 'sessionEngineUnavailable',

  '空闲': 'statusIdle',
  '正在连接': 'statusConnecting',
  '正在验证身份': 'statusAuthenticating',
  '已连接': 'statusConnected',
  '正在断开连接': 'statusDisconnecting',
  '已断开连接': 'statusDisconnected',
  '连接失败': 'statusFailed',

  '无法验证远程计算机的身份。是否仍要连接？': 'certificateUntrustedTitle',
  '已保存的证书发生了变化': 'certificateChangedTitle',
  '这台计算机出示的证书与之前保存的不一致。如果这不是你预期的变更（例如重装了系统或更换了证书），也可能是有人在中间截获你的连接。':
      'certificateChangedBody',
  '证书中的名称与这台计算机不符': 'certificateNameMismatchTitle',
  '证书不是为这个地址签发的。如果这台计算机改名或换了地址，这属于正常；否则说明你连接的并不是它自称的那台机器。':
      'certificateNameMismatchBody',
  '请求连接的远程计算机': 'certificateRequestedHost',
  '证书中的名称': 'certificateName',
  '（证书中没有名称）': 'certificateNoName',
  '颁发者': 'certificateIssuer',
  '之前的指纹': 'certificatePreviousFingerprint',
  '当前指纹': 'certificateCurrentFingerprint',
  '指纹': 'certificateFingerprint',
  '（无）': 'certificateNone',
  '选择「是」将接受新的证书并替换已保存的证书。': 'certificateAcceptChanged',
  '选择「是」后，将记住这台计算机的证书，以后连接不再提示。': 'certificateAcceptRemembered',
};

const List<String> targets = [
  'lib/features/connection_center/connection_center_page.dart',
  'lib/features/pc_editor/pc_editor_page.dart',
  'lib/features/pc_editor/credential_dialog.dart',
  'lib/features/pc_editor/gateway_dialog.dart',
  'lib/features/session/certificate_prompt.dart',
  'lib/features/session/credential_prompt.dart',
  'lib/features/session/session_page.dart',
  'lib/widgets/pc_card.dart',
];

const String accessor = 'AppLocalizations.of(context).';
const String importLine = "import '../../l10n/generated/app_localizations.dart';";

void main() {
  // Longest first, so a string that contains another is matched before the
  // shorter one can break it apart.
  final pairs = mapping.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));

  var total = 0;
  for (final target in targets) {
    final file = File(target);
    if (!file.existsSync()) {
      stderr.writeln('missing: $target');
      exitCode = 1;
      continue;
    }

    var text = file.readAsStringSync();
    final before = text;
    var count = 0;

    for (final pair in pairs) {
      final literal = "'${pair.key}'";
      if (text.contains(literal)) {
        count += literal.allMatches(text).length;
        text = text.replaceAll(literal, '$accessor${pair.value}');
      }
    }

    if (text == before) {
      stdout.writeln('   0  $target');
      continue;
    }

    if (!text.contains('app_localizations.dart')) {
      final lines = text.split('\n');
      var last = 0;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith("import '")) last = i;
      }
      lines.insert(last + 1, importLine);
      text = lines.join('\n');
    }

    file.writeAsStringSync(text);
    total += count;
    stdout.writeln('${count.toString().padLeft(4)}  $target');
  }
  stdout.writeln('${total.toString().padLeft(4)}  total');
}
