import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/test_app.dart';
import 'package:openrdc/data/connection_store.dart';
import 'package:openrdc/data/credential_vault.dart';
import 'package:openrdc/data/storage_paths.dart';
import 'package:openrdc/features/pc_editor/pc_editor_page.dart';
import 'package:openrdc/models/pc_connection.dart';

void main() {
  late Directory tempDir;
  late ConnectionStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('openrdc_editor_test');
    store = ConnectionStore(StoragePaths.forDirectory(tempDir));
    await store.load();
  });

  tearDown(() async {
    store.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Pumps the editor and captures whatever it pops, so the save path can be
  /// asserted on rather than only its side effects.
  Future<List<PcConnection?>> pumpEditor(
    WidgetTester tester, {
    PcConnection? existing,
  }) async {
    final popped = <PcConnection?>[];
    await tester.pumpWidget(
      testApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<PcConnection>(
                    MaterialPageRoute(
                      builder: (context) => PcEditorPage(
                        store: store,
                        vault: MemoryCredentialVault(),
                        existing: existing,
                      ),
                    ),
                  );
                  popped.add(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  group('form', () {
    testWidgets('offers the four tabs the app groups the settings into', (
      tester,
    ) async {
      await pumpEditor(tester);

      expect(find.text('常规'), findsOneWidget);
      expect(find.text('显示'), findsOneWidget);
      expect(find.text('设备和音频'), findsOneWidget);
      expect(find.text('文件夹'), findsOneWidget);
    });

    testWidgets('starts on General with the PC name field', (tester) async {
      await pumpEditor(tester);

      expect(find.text('电脑名称'), findsOneWidget);
      expect(find.text('端口'), findsOneWidget);
      expect(find.text('友好名称'), findsOneWidget);
      expect(find.text('分组'), findsOneWidget);
    });

    testWidgets('refuses to save without a PC name', (tester) async {
      final popped = await pumpEditor(tester);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Still on the editor, with the field flagged: a connection without a
      // host is not a connection.
      expect(find.text('请填写电脑名称或 IP 地址'), findsOneWidget);
      expect(popped, isEmpty);
    });

    testWidgets('returns a connection carrying what was entered', (
      tester,
    ) async {
      final popped = await pumpEditor(tester);

      await tester.enterText(
        find.widgetWithText(TextField, '主机名或 IP 地址，可含端口'),
        '10.0.0.7:3390',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '留空则显示电脑名称'),
        '会议室',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(popped, hasLength(1));
      final connection = popped.single!;
      expect(connection.hostname, '10.0.0.7:3390');
      expect(connection.friendlyName, '会议室');
      // The host carries a port, so it must win over the separate field.
      expect(connection.effectiveHostname, '10.0.0.7');
      expect(connection.effectivePort, 3390);
    });
  });

  group('editing an existing connection', () {
    final existing = PcConnection(
      id: 'pc-1',
      hostname: '10.0.0.1',
      friendlyName: '旧名字',
      favorite: true,
      createdAt: DateTime(2025, 1, 1),
      lastConnectedAt: DateTime(2026, 1, 1),
    );

    testWidgets('prefills the form', (tester) async {
      await pumpEditor(tester, existing: existing);

      expect(find.text('编辑电脑'), findsOneWidget);
      expect(find.widgetWithText(TextField, '10.0.0.1'), findsOneWidget);
      expect(find.widgetWithText(TextField, '旧名字'), findsOneWidget);
    });

    testWidgets('keeps the identity and the things the form does not own', (
      tester,
    ) async {
      final popped = await pumpEditor(tester, existing: existing);

      await tester.enterText(
        find.widgetWithText(TextField, '留空则显示电脑名称'),
        '新名字',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final connection = popped.single!;
      expect(connection.id, 'pc-1');
      expect(connection.friendlyName, '新名字');
      // Not editable here, so losing them would be a silent data loss.
      expect(connection.favorite, isTrue);
      expect(connection.createdAt, DateTime(2025, 1, 1));
      expect(connection.lastConnectedAt, DateTime(2026, 1, 1));
    });
  });

  group('folders tab', () {
    Future<void> openFolders(WidgetTester tester) async {
      await tester.tap(find.text('文件夹'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts empty and explains what folders do', (tester) async {
      await pumpEditor(tester);
      await openFolders(tester);

      expect(find.textContaining('尚未添加文件夹'), findsOneWidget);
      expect(find.text('添加文件夹'), findsOneWidget);
    });

    testWidgets('the added path is editable, not a fixed placeholder', (
      tester,
    ) async {
      // The row used to render the path as read-only text while the code
      // comment claimed it was editable, which made the whole tab decorative:
      // every folder would have been whatever placeholder it shipped with.
      await pumpEditor(tester);
      await openFolders(tester);

      await tester.tap(find.text('添加文件夹'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, r'例如 D:\项目'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, r'例如 D:\项目'),
        r'D:\项目资料',
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, r'D:\项目资料'), findsOneWidget);
    });

    testWidgets('a folder that was added but left blank is not saved', (
      tester,
    ) async {
      final popped = await pumpEditor(tester);

      await tester.enterText(
        find.widgetWithText(TextField, '主机名或 IP 地址，可含端口'),
        '10.0.0.9',
      );
      await tester.pumpAndSettle();
      await openFolders(tester);

      await tester.tap(find.text('添加文件夹'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final connection = popped.single!;
      expect(
        connection.redirection.folders,
        isEmpty,
        reason: '留空的文件夹行不应被保存为共享',
      );
    });

    testWidgets('a filled-in folder is saved with its read-only flag', (
      tester,
    ) async {
      final popped = await pumpEditor(tester);

      await tester.enterText(
        find.widgetWithText(TextField, '主机名或 IP 地址，可含端口'),
        '10.0.0.9',
      );
      await tester.pumpAndSettle();
      await openFolders(tester);

      await tester.tap(find.text('添加文件夹'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, r'例如 D:\项目'),
        r'D:\项目资料',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('只读'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final folder = popped.single!.redirection.folders.single;
      expect(folder.path, r'D:\项目资料');
      expect(folder.readOnly, isTrue);
      expect(folder.shareName, '项目资料');
    });
  });
}
