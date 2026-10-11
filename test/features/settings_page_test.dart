import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/data/connection_store.dart';
import 'package:openrdc/data/credential_vault.dart';
import 'package:openrdc/data/preferences_store.dart';
import 'package:openrdc/data/storage_paths.dart';
import 'package:openrdc/engine/rdc_engine.dart';
import 'package:openrdc/features/settings/settings_page.dart';
import 'package:openrdc/models/credential.dart';
import 'package:openrdc/models/gateway.dart';
import 'package:openrdc/models/pc_connection.dart';

import '../support/test_app.dart';

void main() {
  late Directory tempDir;
  late StoragePaths paths;
  late ConnectionStore store;
  late PreferencesStore preferences;
  late MemoryCredentialVault vault;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('openrdc_settings_test');
    paths = StoragePaths.forDirectory(tempDir);
    store = ConnectionStore(paths);
    preferences = PreferencesStore(paths);
    vault = MemoryCredentialVault();
    await store.load();
    await preferences.load();
  });

  tearDown(() async {
    store.dispose();
    preferences.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        home: SettingsPage(
          store: store,
          preferences: preferences,
          vault: vault,
          engine: RdcEngine.create(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Seeding goes through runAsync: the store writes to disk, and the body of a
  /// testWidgets test runs in a fake-async zone where real I/O never completes.
  Future<void> seed(
    WidgetTester tester, {
    List<Credential> credentials = const [],
    List<Gateway> gateways = const [],
  }) async {
    await tester.runAsync(() async {
      for (final credential in credentials) {
        await store.upsertCredential(credential);
      }
      for (final gateway in gateways) {
        await store.upsertGateway(gateway);
      }
    });
  }

  group('layout', () {
    testWidgets('shows every section', (tester) async {
      await pumpSettings(tester);

      expect(find.text('外观'), findsOneWidget);
      expect(find.text('用户账户'), findsOneWidget);
      expect(find.text('网关'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('reports the app and engine versions', (tester) async {
      await pumpSettings(tester);

      expect(find.text('应用版本'), findsOneWidget);
      expect(find.text('远程桌面引擎'), findsOneWidget);
      // The engine describes itself, and in a test run there is no native
      // library to describe: the row is present either way, and which string
      // it carries depends on whether the DLL loaded.
      final engine = RdcEngine.create();
      expect(
        find.text(engine.isAvailable ? engine.backendName : '不可用'),
        findsOneWidget,
      );
    });
  });

  group('appearance', () {
    testWidgets('starts on the stored mode', (tester) async {
      await pumpSettings(tester);
      expect(find.text('跟随系统'), findsOneWidget);
    });

    testWidgets('changing the mode stores it', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('跟随系统'));
      await tester.pumpAndSettle();
      // Diagnose: is the menu open at all, and is the item enabled?
      expect(find.text('深色'), findsOneWidget, reason: '菜单应已展开');
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();

      // Only the wiring is checked here. Whether it reaches the disk is a
      // question about the store, and is tested there: the write is
      // fire-and-forget, and real file I/O never completes inside the
      // fake-async zone a widget test runs in.
      expect(preferences.preferences.themeMode, ThemeMode.dark);
    });
  });

  group('user accounts', () {
    testWidgets('explains the empty state', (tester) async {
      await pumpSettings(tester);
      expect(find.text('尚未保存任何凭据。'), findsOneWidget);
    });

    testWidgets('lists saved credentials by friendly name', (tester) async {
      await seed(
        tester,
        credentials: const [
          Credential(
            id: 'c1',
            friendlyName: '工作账户',
            username: 'alice',
            domain: 'CORP',
          ),
        ],
      );
      await pumpSettings(tester);

      expect(find.text('工作账户'), findsOneWidget);
      // The qualified name is the subtitle, so the account is identifiable even
      // when the friendly name is vague.
      expect(find.text(r'CORP\alice'), findsOneWidget);
      expect(find.text('尚未保存任何凭据。'), findsNothing);
    });

    testWidgets('falls back to the user name when there is no friendly name', (
      tester,
    ) async {
      await seed(
        tester,
        credentials: const [
          Credential(id: 'c1', friendlyName: '', username: 'bob'),
        ],
      );
      await pumpSettings(tester);

      expect(find.text('bob'), findsWidgets);
    });

    testWidgets('deleting removes the record and its password', (tester) async {
      // The password lives in the system store, so removing only the record
      // would leave the secret behind — which is the whole reason this page
      // exists.
      await seed(
        tester,
        credentials: const [
          Credential(id: 'c1', friendlyName: '工作账户', username: 'alice'),
        ],
      );
      await vault.store('c1', 'hunter2');
      await pumpSettings(tester);

      await tester.tap(find.byTooltip('删除').first);
      await tester.pumpAndSettle();
      expect(find.text('删除这个凭据？'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        expect(await vault.retrieve('c1'), isNull);
      });
      expect(store.credentials, isEmpty);
    });

    testWidgets('cancelling a delete keeps the credential', (tester) async {
      await seed(
        tester,
        credentials: const [
          Credential(id: 'c1', friendlyName: '工作账户', username: 'alice'),
        ],
      );
      await pumpSettings(tester);

      await tester.tap(find.byTooltip('删除').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();

      expect(store.credentials, hasLength(1));
    });
  });

  group('gateways', () {
    testWidgets('explains the empty state', (tester) async {
      await pumpSettings(tester);
      expect(find.text('尚未保存任何网关。'), findsOneWidget);
    });

    testWidgets('lists a gateway with its address', (tester) async {
      await seed(
        tester,
        gateways: const [
          Gateway(id: 'g1', hostname: 'gw.example.com', friendlyName: '公司网关'),
        ],
      );
      await pumpSettings(tester);

      expect(find.text('公司网关'), findsOneWidget);
      expect(find.text('gw.example.com:443'), findsOneWidget);
    });

    testWidgets('deleting a gateway also clears it from connections', (
      tester,
    ) async {
      await seed(
        tester,
        gateways: const [Gateway(id: 'g1', hostname: 'gw.example.com')],
      );
      // A connection pointing at it, to prove the reference is cleaned up
      // rather than left dangling.
      await tester.runAsync(() async {
        await store.upsertConnection(
          const PcConnection(id: 'pc1', hostname: '10.0.0.1', gatewayId: 'g1'),
        );
      });
      await pumpSettings(tester);

      await tester.tap(find.byTooltip('删除').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();

      expect(store.gateways, isEmpty);
      expect(store.connections.single.gatewayId, isNull);
    });
  });
}
