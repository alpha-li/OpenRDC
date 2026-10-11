/// Standalone smoke test for the native bridge.
///
/// This exists so the plugin can be exercised on its own, without the full
/// application and its UI. It reports what the native library says and lets the
/// test pattern be started and stopped; it does not register or display a
/// texture, because registering one requires the plugin's Flutter glue, which
/// this example does not link.
///
/// For the full end-to-end check including the texture path, run the main
/// application instead (`flutter run -d windows` at the repository root).
library;

import 'package:flutter/material.dart';

import 'package:rdc_bridge/rdc_bridge.dart';

void main() {
  runApp(const BridgeSmokeTestApp());
}

class BridgeSmokeTestApp extends StatelessWidget {
  const BridgeSmokeTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: BridgeSmokeTestPage());
  }
}

class BridgeSmokeTestPage extends StatefulWidget {
  const BridgeSmokeTestPage({super.key});

  @override
  State<BridgeSmokeTestPage> createState() => _BridgeSmokeTestPageState();
}

class _BridgeSmokeTestPageState extends State<BridgeSmokeTestPage> {
  final List<String> _log = [];
  String _version = '(未加载)';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!RdcBridge.isSupported) {
      setState(() => _version = '当前平台不受支持');
      return;
    }
    try {
      final bridge = RdcBridge.instance;
      bridge.setEventSink((event) {
        if (!mounted) {
          return;
        }
        setState(() => _log.insert(0, event.toString()));
      });
      setState(() => _version = bridge.version);
    } on RdcUnavailableException catch (error) {
      setState(() => _version = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('rdc_bridge 冒烟测试')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本：$_version'),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: () {
                    final result = RdcBridge.instance.startTestPattern(width: 1280, height: 720);
                    setState(() => _log.insert(0, 'startTestPattern -> $result'));
                  },
                  child: const Text('启动测试图案'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => RdcBridge.instance.stopTestPattern(),
                  child: const Text('停止'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, index) => Text(_log[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
