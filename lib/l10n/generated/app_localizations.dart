import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'OpenRDC'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @yes.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get no;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @connect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connect;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @stop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stop;

  /// No description provided for @unavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get unavailable;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get notConfigured;

  /// No description provided for @optional.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get optional;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'主页'**
  String get tabHome;

  /// No description provided for @tabDevices.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get tabDevices;

  /// No description provided for @tabFavorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏夹'**
  String get tabFavorites;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @sortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get sortBy;

  /// No description provided for @sortRecency.
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get sortRecency;

  /// No description provided for @sortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get sortName;

  /// No description provided for @sortManual.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get sortManual;

  /// No description provided for @switchToList.
  ///
  /// In zh, this message translates to:
  /// **'切换为列表视图'**
  String get switchToList;

  /// No description provided for @switchToGrid.
  ///
  /// In zh, this message translates to:
  /// **'切换为网格视图'**
  String get switchToGrid;

  /// No description provided for @addPc.
  ///
  /// In zh, this message translates to:
  /// **'添加电脑'**
  String get addPc;

  /// No description provided for @moreOptions.
  ///
  /// In zh, this message translates to:
  /// **'更多选项'**
  String get moreOptions;

  /// No description provided for @emptyNoDevicesTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有保存任何电脑'**
  String get emptyNoDevicesTitle;

  /// No description provided for @emptyNoDevicesBody.
  ///
  /// In zh, this message translates to:
  /// **'添加一台电脑即可开始远程连接。'**
  String get emptyNoDevicesBody;

  /// No description provided for @emptyFavoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'这里还没有内容'**
  String get emptyFavoritesTitle;

  /// No description provided for @emptyFavoritesBody.
  ///
  /// In zh, this message translates to:
  /// **'添加到收藏夹的电脑会显示在这里。'**
  String get emptyFavoritesBody;

  /// No description provided for @emptySearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的结果'**
  String get emptySearchTitle;

  /// No description provided for @emptySearchBody.
  ///
  /// In zh, this message translates to:
  /// **'没有与「{query}」匹配的电脑。'**
  String emptySearchBody(String query);

  /// No description provided for @cardRemoteDesktop.
  ///
  /// In zh, this message translates to:
  /// **'远程桌面'**
  String get cardRemoteDesktop;

  /// No description provided for @cardAddToFavorites.
  ///
  /// In zh, this message translates to:
  /// **'添加到收藏夹'**
  String get cardAddToFavorites;

  /// No description provided for @cardRemoveFromFavorites.
  ///
  /// In zh, this message translates to:
  /// **'从收藏夹中移除'**
  String get cardRemoveFromFavorites;

  /// No description provided for @deletePcTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这台电脑？'**
  String get deletePcTitle;

  /// No description provided for @deletePcBody.
  ///
  /// In zh, this message translates to:
  /// **'将从连接中心移除「{name}」。此操作不会影响远程电脑本身。'**
  String deletePcBody(String name);

  /// No description provided for @editorAddPcTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加电脑'**
  String get editorAddPcTitle;

  /// No description provided for @editorEditPcTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑电脑'**
  String get editorEditPcTitle;

  /// No description provided for @tabGeneral.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get tabGeneral;

  /// No description provided for @tabDisplay.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get tabDisplay;

  /// No description provided for @tabDevicesAndAudio.
  ///
  /// In zh, this message translates to:
  /// **'设备和音频'**
  String get tabDevicesAndAudio;

  /// No description provided for @tabFolders.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get tabFolders;

  /// No description provided for @fieldPcName.
  ///
  /// In zh, this message translates to:
  /// **'电脑名称'**
  String get fieldPcName;

  /// No description provided for @fieldPcNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'主机名或 IP 地址，可含端口'**
  String get fieldPcNamePlaceholder;

  /// No description provided for @fieldPort.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get fieldPort;

  /// No description provided for @fieldFriendlyName.
  ///
  /// In zh, this message translates to:
  /// **'友好名称'**
  String get fieldFriendlyName;

  /// No description provided for @fieldFriendlyNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'留空则显示电脑名称'**
  String get fieldFriendlyNamePlaceholder;

  /// No description provided for @fieldGroup.
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get fieldGroup;

  /// No description provided for @validationPcNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写电脑名称或 IP 地址'**
  String get validationPcNameRequired;

  /// No description provided for @credentials.
  ///
  /// In zh, this message translates to:
  /// **'凭据'**
  String get credentials;

  /// No description provided for @fieldUserAccount.
  ///
  /// In zh, this message translates to:
  /// **'用户账户'**
  String get fieldUserAccount;

  /// No description provided for @askEveryTime.
  ///
  /// In zh, this message translates to:
  /// **'每次询问'**
  String get askEveryTime;

  /// No description provided for @newCredential.
  ///
  /// In zh, this message translates to:
  /// **'新建凭据'**
  String get newCredential;

  /// No description provided for @editCredential.
  ///
  /// In zh, this message translates to:
  /// **'编辑凭据'**
  String get editCredential;

  /// No description provided for @credentialUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get credentialUsername;

  /// No description provided for @credentialUsernamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'用户名 或 域\\用户名'**
  String get credentialUsernamePlaceholder;

  /// No description provided for @credentialPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get credentialPassword;

  /// No description provided for @credentialFriendlyNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'可选，用于在列表中识别'**
  String get credentialFriendlyNamePlaceholder;

  /// No description provided for @validationUsernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写用户名'**
  String get validationUsernameRequired;

  /// No description provided for @showPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get hidePassword;

  /// No description provided for @vaultNotPersistentWarning.
  ///
  /// In zh, this message translates to:
  /// **'当前版本尚未接入系统凭据管理器，密码只在本次运行期间有效，重启后需要重新输入。'**
  String get vaultNotPersistentWarning;

  /// No description provided for @rememberPassword.
  ///
  /// In zh, this message translates to:
  /// **'记住密码'**
  String get rememberPassword;

  /// No description provided for @rememberPasswordBody.
  ///
  /// In zh, this message translates to:
  /// **'保存到系统凭据管理器，以后连接不再询问'**
  String get rememberPasswordBody;

  /// No description provided for @passwordOnlyThisSession.
  ///
  /// In zh, this message translates to:
  /// **'密码只在本次运行期间保留，重启后需要重新输入。'**
  String get passwordOnlyThisSession;

  /// No description provided for @credentialPasswordNotSaved.
  ///
  /// In zh, this message translates to:
  /// **'尚未为此凭据保存密码。'**
  String get credentialPasswordNotSaved;

  /// No description provided for @storeErrorUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取已保存的连接，已从空白开始。原文件已备份。'**
  String get storeErrorUnreadable;

  /// No description provided for @storeErrorMalformed.
  ///
  /// In zh, this message translates to:
  /// **'已保存的连接文件内容无效，已从空白开始。原文件已备份。'**
  String get storeErrorMalformed;

  /// No description provided for @storeErrorUnsupportedVersion.
  ///
  /// In zh, this message translates to:
  /// **'连接文件由更新版本的应用写入，请升级后再打开。'**
  String get storeErrorUnsupportedVersion;

  /// No description provided for @storeErrorWriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法保存连接，本次更改未写入磁盘。'**
  String get storeErrorWriteFailed;

  /// No description provided for @gateway.
  ///
  /// In zh, this message translates to:
  /// **'网关'**
  String get gateway;

  /// No description provided for @newGateway.
  ///
  /// In zh, this message translates to:
  /// **'新建网关'**
  String get newGateway;

  /// No description provided for @editGateway.
  ///
  /// In zh, this message translates to:
  /// **'编辑网关'**
  String get editGateway;

  /// No description provided for @gatewayAddress.
  ///
  /// In zh, this message translates to:
  /// **'网关地址'**
  String get gatewayAddress;

  /// No description provided for @gatewayAddressPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如 gateway.example.com'**
  String get gatewayAddressPlaceholder;

  /// No description provided for @gatewayCredentials.
  ///
  /// In zh, this message translates to:
  /// **'网关凭据'**
  String get gatewayCredentials;

  /// No description provided for @gatewaySameAsPc.
  ///
  /// In zh, this message translates to:
  /// **'与电脑凭据相同'**
  String get gatewaySameAsPc;

  /// No description provided for @fieldBypassGateway.
  ///
  /// In zh, this message translates to:
  /// **'本地地址绕过网关'**
  String get fieldBypassGateway;

  /// No description provided for @fieldBypassGatewayBody.
  ///
  /// In zh, this message translates to:
  /// **'访问本地网络中的电脑时直连，不经过网关'**
  String get fieldBypassGatewayBody;

  /// No description provided for @validationGatewayRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写网关地址'**
  String get validationGatewayRequired;

  /// No description provided for @session.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get session;

  /// No description provided for @fieldReconnect.
  ///
  /// In zh, this message translates to:
  /// **'断线时自动重新连接'**
  String get fieldReconnect;

  /// No description provided for @fieldAdminSession.
  ///
  /// In zh, this message translates to:
  /// **'连接到管理员会话'**
  String get fieldAdminSession;

  /// No description provided for @fieldAdminSessionBody.
  ///
  /// In zh, this message translates to:
  /// **'以控制台会话登录，用于排查问题'**
  String get fieldAdminSessionBody;

  /// No description provided for @fieldSwapMouseButtons.
  ///
  /// In zh, this message translates to:
  /// **'交换鼠标按键'**
  String get fieldSwapMouseButtons;

  /// No description provided for @fieldResolution.
  ///
  /// In zh, this message translates to:
  /// **'分辨率'**
  String get fieldResolution;

  /// No description provided for @fieldColorQuality.
  ///
  /// In zh, this message translates to:
  /// **'色彩质量'**
  String get fieldColorQuality;

  /// No description provided for @colorQualityHighest.
  ///
  /// In zh, this message translates to:
  /// **'最高质量（32 位）'**
  String get colorQualityHighest;

  /// No description provided for @colorQualityEnhanced.
  ///
  /// In zh, this message translates to:
  /// **'增强色（24 位）'**
  String get colorQualityEnhanced;

  /// No description provided for @colorQualityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高彩色（16 位）'**
  String get colorQualityHigh;

  /// No description provided for @displayWindowBehaviour.
  ///
  /// In zh, this message translates to:
  /// **'窗口行为'**
  String get displayWindowBehaviour;

  /// No description provided for @fieldStartFullScreen.
  ///
  /// In zh, this message translates to:
  /// **'全屏启动会话'**
  String get fieldStartFullScreen;

  /// No description provided for @fieldFitToWindow.
  ///
  /// In zh, this message translates to:
  /// **'调整会话以适应窗口'**
  String get fieldFitToWindow;

  /// No description provided for @fieldFitToWindowBody.
  ///
  /// In zh, this message translates to:
  /// **'缩放画面以填满窗口，远程分辨率保持不变'**
  String get fieldFitToWindowBody;

  /// No description provided for @fieldUpdateResolutionOnResize.
  ///
  /// In zh, this message translates to:
  /// **'在调整大小时更新分辨率'**
  String get fieldUpdateResolutionOnResize;

  /// No description provided for @fieldUpdateResolutionOnResizeBody.
  ///
  /// In zh, this message translates to:
  /// **'窗口变化时通知远程主机切换分辨率'**
  String get fieldUpdateResolutionOnResizeBody;

  /// No description provided for @clipboard.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板'**
  String get clipboard;

  /// No description provided for @fieldClipboardRedirection.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板重定向'**
  String get fieldClipboardRedirection;

  /// No description provided for @clipboardBidirectional.
  ///
  /// In zh, this message translates to:
  /// **'双向'**
  String get clipboardBidirectional;

  /// No description provided for @clipboardLocalToRemote.
  ///
  /// In zh, this message translates to:
  /// **'仅本地到远程'**
  String get clipboardLocalToRemote;

  /// No description provided for @clipboardRemoteToLocal.
  ///
  /// In zh, this message translates to:
  /// **'仅远程到本地'**
  String get clipboardRemoteToLocal;

  /// No description provided for @clipboardDisabled.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get clipboardDisabled;

  /// No description provided for @audio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get audio;

  /// No description provided for @fieldAudioPlayback.
  ///
  /// In zh, this message translates to:
  /// **'播放声音'**
  String get fieldAudioPlayback;

  /// No description provided for @audioOnThisComputer.
  ///
  /// In zh, this message translates to:
  /// **'在此电脑上'**
  String get audioOnThisComputer;

  /// No description provided for @audioOnRemotePc.
  ///
  /// In zh, this message translates to:
  /// **'在远程电脑上'**
  String get audioOnRemotePc;

  /// No description provided for @audioNever.
  ///
  /// In zh, this message translates to:
  /// **'从不播放'**
  String get audioNever;

  /// No description provided for @devices.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get devices;

  /// No description provided for @fieldRedirectDrives.
  ///
  /// In zh, this message translates to:
  /// **'驱动器'**
  String get fieldRedirectDrives;

  /// No description provided for @redirectedFolders.
  ///
  /// In zh, this message translates to:
  /// **'重定向文件夹'**
  String get redirectedFolders;

  /// No description provided for @foldersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加文件夹。添加后，本地文件夹会作为网络驱动器出现在远程会话中。'**
  String get foldersEmpty;

  /// No description provided for @addFolder.
  ///
  /// In zh, this message translates to:
  /// **'添加文件夹'**
  String get addFolder;

  /// No description provided for @folderPathPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如 D:\\项目'**
  String get folderPathPlaceholder;

  /// No description provided for @folderReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'只读'**
  String get folderReadOnly;

  /// No description provided for @sessionMinimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get sessionMinimize;

  /// No description provided for @sessionFullScreen.
  ///
  /// In zh, this message translates to:
  /// **'全屏 (Ctrl+Alt+Enter)'**
  String get sessionFullScreen;

  /// No description provided for @sessionRestoreWindow.
  ///
  /// In zh, this message translates to:
  /// **'恢复到全屏前的窗口大小 (Ctrl+Alt+Enter)'**
  String get sessionRestoreWindow;

  /// No description provided for @sessionPinBar.
  ///
  /// In zh, this message translates to:
  /// **'固定连接栏'**
  String get sessionPinBar;

  /// No description provided for @sessionUnpinBar.
  ///
  /// In zh, this message translates to:
  /// **'取消固定连接栏'**
  String get sessionUnpinBar;

  /// No description provided for @sessionOptions.
  ///
  /// In zh, this message translates to:
  /// **'会话选项'**
  String get sessionOptions;

  /// No description provided for @sessionSendCad.
  ///
  /// In zh, this message translates to:
  /// **'发送 Ctrl+Alt+Del'**
  String get sessionSendCad;

  /// No description provided for @sessionReconnect.
  ///
  /// In zh, this message translates to:
  /// **'重新连接'**
  String get sessionReconnect;

  /// No description provided for @sessionDisconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开连接'**
  String get sessionDisconnect;

  /// No description provided for @sessionEngineUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'远程桌面引擎不可用'**
  String get sessionEngineUnavailable;

  /// No description provided for @statusIdle.
  ///
  /// In zh, this message translates to:
  /// **'空闲'**
  String get statusIdle;

  /// No description provided for @statusConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接'**
  String get statusConnecting;

  /// No description provided for @statusAuthenticating.
  ///
  /// In zh, this message translates to:
  /// **'正在验证身份'**
  String get statusAuthenticating;

  /// No description provided for @statusConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get statusConnected;

  /// No description provided for @statusDisconnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在断开连接'**
  String get statusDisconnecting;

  /// No description provided for @statusDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'已断开连接'**
  String get statusDisconnected;

  /// No description provided for @statusFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get statusFailed;

  /// No description provided for @certificateUntrustedTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法验证远程计算机的身份。是否仍要连接？'**
  String get certificateUntrustedTitle;

  /// No description provided for @certificateChangedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已保存的证书发生了变化'**
  String get certificateChangedTitle;

  /// No description provided for @certificateChangedBody.
  ///
  /// In zh, this message translates to:
  /// **'这台计算机出示的证书与之前保存的不一致。如果这不是你预期的变更（例如重装了系统或更换了证书），也可能是有人在中间截获你的连接。'**
  String get certificateChangedBody;

  /// No description provided for @certificateNameMismatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'证书中的名称与这台计算机不符'**
  String get certificateNameMismatchTitle;

  /// No description provided for @certificateNameMismatchBody.
  ///
  /// In zh, this message translates to:
  /// **'证书不是为这个地址签发的。如果这台计算机改名或换了地址，这属于正常；否则说明你连接的并不是它自称的那台机器。'**
  String get certificateNameMismatchBody;

  /// No description provided for @certificateRequestedHost.
  ///
  /// In zh, this message translates to:
  /// **'请求连接的远程计算机'**
  String get certificateRequestedHost;

  /// No description provided for @certificateName.
  ///
  /// In zh, this message translates to:
  /// **'证书中的名称'**
  String get certificateName;

  /// No description provided for @certificateNoName.
  ///
  /// In zh, this message translates to:
  /// **'（证书中没有名称）'**
  String get certificateNoName;

  /// No description provided for @certificateIssuer.
  ///
  /// In zh, this message translates to:
  /// **'颁发者'**
  String get certificateIssuer;

  /// No description provided for @certificatePreviousFingerprint.
  ///
  /// In zh, this message translates to:
  /// **'之前的指纹'**
  String get certificatePreviousFingerprint;

  /// No description provided for @certificateCurrentFingerprint.
  ///
  /// In zh, this message translates to:
  /// **'当前指纹'**
  String get certificateCurrentFingerprint;

  /// No description provided for @certificateFingerprint.
  ///
  /// In zh, this message translates to:
  /// **'指纹'**
  String get certificateFingerprint;

  /// No description provided for @certificateNone.
  ///
  /// In zh, this message translates to:
  /// **'（无）'**
  String get certificateNone;

  /// No description provided for @certificateAcceptChanged.
  ///
  /// In zh, this message translates to:
  /// **'选择「是」将接受新的证书并替换已保存的证书。'**
  String get certificateAcceptChanged;

  /// No description provided for @certificateAcceptRemembered.
  ///
  /// In zh, this message translates to:
  /// **'选择「是」后，将记住这台计算机的证书，以后连接不再提示。'**
  String get certificateAcceptRemembered;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'外观模式'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsUserAccounts.
  ///
  /// In zh, this message translates to:
  /// **'用户账户'**
  String get settingsUserAccounts;

  /// No description provided for @settingsUserAccountsBody.
  ///
  /// In zh, this message translates to:
  /// **'保存的凭据用于远程电脑登录。密码存放在系统凭据管理器中，可在此处或系统的凭据界面删除。'**
  String get settingsUserAccountsBody;

  /// No description provided for @settingsAccountsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未保存任何凭据。'**
  String get settingsAccountsEmpty;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这个凭据？'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'将从系统凭据管理器中移除「{name}」的密码。使用它的连接会改为每次询问。'**
  String accountDeleteBody(String name);

  /// No description provided for @settingsGateways.
  ///
  /// In zh, this message translates to:
  /// **'网关'**
  String get settingsGateways;

  /// No description provided for @settingsGatewaysBody.
  ///
  /// In zh, this message translates to:
  /// **'网关可以让远程连接经由它中转，用于访问内网中的电脑。'**
  String get settingsGatewaysBody;

  /// No description provided for @settingsGatewaysEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未保存任何网关。'**
  String get settingsGatewaysEmpty;

  /// No description provided for @gatewayDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这个网关？'**
  String get gatewayDeleteTitle;

  /// No description provided for @gatewayDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'将移除「{name}」。仍在引用它的连接会改为直连，需要时再重新指定。'**
  String gatewayDeleteBody(String name);

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'应用版本'**
  String get aboutVersion;

  /// No description provided for @aboutEngine.
  ///
  /// In zh, this message translates to:
  /// **'远程桌面引擎'**
  String get aboutEngine;

  /// No description provided for @aboutEngineUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get aboutEngineUnavailable;

  /// No description provided for @errorConnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到远程电脑。请检查地址与端口是否正确，以及网络是否可达。'**
  String get errorConnectFailed;

  /// No description provided for @errorTlsFailed.
  ///
  /// In zh, this message translates to:
  /// **'与远程电脑建立安全连接失败。可能是对方证书有问题，或中间有设备在干扰。'**
  String get errorTlsFailed;

  /// No description provided for @errorPasswordExpired.
  ///
  /// In zh, this message translates to:
  /// **'账户密码已过期或必须先修改密码，请在远程电脑上处理后再连接。'**
  String get errorPasswordExpired;

  /// No description provided for @errorAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录被拒绝。请确认用户名和密码，以及该账户是否有权远程登录。'**
  String get errorAuthFailed;

  /// No description provided for @errorNoCredentials.
  ///
  /// In zh, this message translates to:
  /// **'远程电脑要求提供用户名和密码。'**
  String get errorNoCredentials;

  /// No description provided for @errorSessionStart.
  ///
  /// In zh, this message translates to:
  /// **'远程桌面引擎无法启动会话。'**
  String get errorSessionStart;

  /// No description provided for @errorInternal.
  ///
  /// In zh, this message translates to:
  /// **'远程桌面引擎内部错误，会话无法继续。'**
  String get errorInternal;

  /// No description provided for @errorAlreadyRunning.
  ///
  /// In zh, this message translates to:
  /// **'已有一个会话在运行。'**
  String get errorAlreadyRunning;

  /// No description provided for @errorEngineUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'远程桌面引擎不可用，可能是原生组件未能加载。'**
  String get errorEngineUnavailable;

  /// No description provided for @errorEngineDisposed.
  ///
  /// In zh, this message translates to:
  /// **'会话已结束。'**
  String get errorEngineDisposed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
