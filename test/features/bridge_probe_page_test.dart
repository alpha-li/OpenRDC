import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/test_app.dart';
import 'package:openrdc/features/diagnostics/bridge_probe_page.dart';

void main() {
  // These assertions deliberately stay independent of whether the native DLL is
  // present, so the suite behaves the same on a machine that has not built the
  // plugin yet: the page must render and explain itself either way, rather than
  // throwing during widget construction.
  Widget wrap() => testApp(home: const BridgeProbePage());

  testWidgets('renders its diagnostics without a native library', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('OpenRDC 原生桥接自检'), findsOneWidget);
    expect(find.text('后端'), findsOneWidget);
    expect(find.text('引擎可用'), findsOneWidget);
    expect(find.text('纹理 ID'), findsOneWidget);
    expect(find.text('会话状态'), findsOneWidget);
  });

  testWidgets('explains the channel-order check, since the pixel buffer has no '
      'format field', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.textContaining('红、绿、蓝、白'), findsOneWidget);
    expect(find.textContaining('交换 R/B 通道'), findsOneWidget);
  });

  testWidgets('shows a placeholder instead of a Texture when no texture is '
      'registered', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    // A negative texture id means the platform glue did not register one;
    // building a Texture widget with it would be an engine error.
    if (find.textContaining('未注册纹理').evaluate().isNotEmpty) {
      expect(find.byType(Texture), findsNothing);
    } else {
      // The DLL and its Flutter glue were both present.
      expect(find.byType(Texture), findsOneWidget);
    }
  });

  testWidgets('starts in the idle state', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('空闲'), findsOneWidget);
  });
}
