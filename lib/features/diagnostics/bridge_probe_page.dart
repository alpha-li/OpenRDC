/// Milestone 1 verification surface.
///
/// This page exists to prove, on real hardware, that the whole chain works:
/// Dart -> FFI -> frame ring -> engine texture -> Flutter. It is deliberately
/// not part of the product UI; it gets replaced by the connection centre once
/// the real RDP session lands.
///
/// The test pattern is built to answer questions that are otherwise guesswork:
///
///   * The bands are red, green, blue, white from top to bottom. The engine's
///     pixel-buffer texture carries no format field, so the channel order is an
///     implicit contract. If the top band renders blue and the third renders
///     red, the engine wants BGRA and the producer must swizzle.
///   * The sweeping bar makes frame delivery visible; a bar that stutters or
///     tears points at the ring handoff rather than the protocol.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../engine/rdc_engine.dart';
import '../../l10n/engine_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/fluent_colors.dart';

class BridgeProbePage extends StatefulWidget {
  const BridgeProbePage({super.key});

  @override
  State<BridgeProbePage> createState() => _BridgeProbePageState();
}

class _BridgeProbePageState extends State<BridgeProbePage> {
  final RdcEngine _engine = RdcEngine.create();
  final List<StreamSubscription<RdcEngineEvent>> _subscriptions = [];

  RdcSessionStatus _status = RdcSessionStatus.idle;
  RdcDesktopSize? _desktopSize;
  String? _error;
  bool _running = false;

  /// Outcome of the credential store round trip, shown alongside the other
  /// bridge facts.
  String _credentialProbe = '检查中…';

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      _engine.events.listen((event) {
        if (!mounted) {
          return;
        }
        setState(() {
          switch (event) {
            case RdcStatusEvent(:final status):
              _status = status;
              if (status.isTerminal) {
                _running = false;
              }
            case RdcDesktopSizeEvent(:final size):
              _desktopSize = size;
            case RdcErrorEvent(:final message):
              _error = message;
            case RdcClipboardEvent(:final text):
              // Nothing here consumes the clipboard; record it so the text is
              // not left sitting in the bridge's pending slot.
              _error = '收到剪贴板内容（${text.length} 字符）';
            case RdcCursorEvent(:final cursor):
              // Nothing to draw here: this page checks the pipeline, and a
              // cursor has no part in it.
              _error = '收到远端光标（${cursor.kind.name}）';
            case RdcCertificateEvent(:final certificate):
              // This page is a pipeline check, not a trust decision surface, so
              // it refuses rather than accepting on the user's behalf. It has to
              // answer something: the session thread is blocked on the reply.
              _error = '证书需要确认（${certificate.host}），诊断页面不予处理';
              _engine.respondToCertificate(RdcCertificateDecision.reject);
          }
        });
      }),
    );
    // Start immediately: the reason to open this page is to find out whether
    // frames flow, so requiring a second click to answer that is friction for
    // no benefit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    _runCredentialProbe();
  }

  /// Round-trips a value through the platform secret store.
  ///
  /// Worth doing here rather than only through the UI: the store is a platform
  /// facility reached through FFI, and a silent failure would show up much later
  /// as a password prompt the user thought they had answered for good. The probe
  /// writes, reads back, compares, and cleans up after itself.
  Future<void> _runCredentialProbe() async {
    if (!_engine.isCredentialStorePersistent) {
      if (mounted) {
        setState(() => _credentialProbe = '平台不支持');
      }
      return;
    }

    const id = 'openrdc-self-check';
    const secret = 'probe-1234-凭据';
    String result;
    try {
      final stored = await _engine.storeCredential(id, secret);
      if (!stored) {
        result = '写入失败';
      } else {
        final readBack = await _engine.loadCredential(id);
        await _engine.deleteCredential(id);
        if (readBack == null) {
          result = '读回为空';
        } else if (readBack != secret) {
          result = '读回不一致：$readBack';
        } else {
          result = '往返成功';
        }
      }
    } on Object catch (error) {
      result = '异常：$error';
    }

    if (mounted) {
      setState(() => _credentialProbe = result);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _engine.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _error = null;
    });
    try {
      final result = _engine.startTestPattern(width: 1280, height: 720);
      setState(() {
        _running = result == 0;
        if (result != 0) {
          _error = '启动失败，返回码 $result';
        }
      });
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }

  void _stop() {
    _engine.stop();
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Scaffold(
      backgroundColor: colors.solidBackgroundFillColorBase,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'OpenRDC 原生桥接自检',
                  style: TextStyle(
                    fontSize: 28,
                    height: 36 / 28,
                    fontWeight: FontWeight.w600,
                    color: colors.textFillColorPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '用于验证 Dart → FFI → 帧环 → 引擎纹理 → Flutter 的完整链路。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: colors.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _InfoCard(
                  rows: [
                    ('后端', _engine.backendName),
                    ('引擎可用', _engine.isAvailable ? '是' : '否'),
                    ('纹理 ID', '${_engine.textureId}'),
                    ('会话状态', _status.label(AppLocalizations.of(context))),
                    ('远程分辨率', _desktopSize?.toString() ?? '—'),
                    ('凭据存储', _credentialProbe),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBar(message: _error!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ProbeButton(
                      icon: FluentIcons.play_24_regular,
                      label: '启动测试图案',
                      onPressed: _engine.isAvailable && !_running
                          ? _start
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _ProbeButton(
                      icon: FluentIcons.stop_24_regular,
                      label: '停止',
                      onPressed: _running ? _stop : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _TexturePreview(
                  textureId: _engine.textureId,
                  size: _desktopSize,
                ),
                const SizedBox(height: 24),
                _DiagnosticNotes(colors: colors),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackgroundFillColorDefault,
        border: Border.all(color: colors.cardStrokeColorDefault),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: colors.textFillColorSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: colors.textFillColorPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackgroundFillColorDefault,
        border: Border.all(color: colors.systemFillColorCritical),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            FluentIcons.warning_24_regular,
            size: 20,
            color: colors.systemFillColorCritical,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: colors.textFillColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbeButton extends StatelessWidget {
  const _ProbeButton({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final enabled = onPressed != null;
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: enabled
              ? colors.textFillColorPrimary
              : colors.textFillColorDisabled,
          backgroundColor: colors.controlFillColorDefault,
          side: BorderSide(color: colors.controlStrokeColorDefault),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

/// Renders whatever the native side has published, scaled to fit.
class _TexturePreview extends StatelessWidget {
  const _TexturePreview({required this.textureId, required this.size});

  final int textureId;
  final RdcDesktopSize? size;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    if (textureId < 0) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: colors.controlFillColorDisabled,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.cardStrokeColorDefault),
        ),
        alignment: Alignment.center,
        child: Text(
          '未注册纹理（textureId = $textureId）',
          style: TextStyle(fontSize: 14, color: colors.textFillColorSecondary),
        ),
      );
    }

    final aspectRatio = size?.aspectRatio ?? 16 / 9;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '画面输出',
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
            color: colors.textFillColorPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.surfaceStrokeColorDefault),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Texture(
                  textureId: textureId,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticNotes extends StatelessWidget {
  const _DiagnosticNotes({required this.colors});

  final FluentColors colors;

  @override
  Widget build(BuildContext context) {
    const notes = [
      '色带自上而下应为：红、绿、蓝、白。',
      '若顶部显示为蓝、第三条显示为红，则引擎期望 BGRA，需要在生产者侧交换 R/B 通道。',
      '白色扫描条应平滑右移；卡顿或撕裂指向帧环交接问题，而非协议问题。',
    ];
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackgroundFillColorSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '判读说明',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w600,
              color: colors.textFillColorPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: colors.textFillColorTertiary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: colors.textFillColorSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
