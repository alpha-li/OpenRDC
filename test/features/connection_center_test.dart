import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/test_app.dart';
import 'package:openrdc/data/connection_store.dart';
import 'package:openrdc/data/credential_vault.dart';
import 'package:openrdc/data/storage_paths.dart';
import 'package:openrdc/features/connection_center/connection_center_page.dart';
import 'package:openrdc/models/pc_connection.dart';
import 'package:openrdc/widgets/pc_card.dart';

void main() {
  late Directory tempDir;
  late ConnectionStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('openrdc_cc_test');
    store = ConnectionStore(StoragePaths.forDirectory(tempDir));
    await store.load();
  });

  tearDown(() async {
    store.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap({
    void Function(PcConnection)? onConnect,
    ConnectionCenterTab? tab,
  }) => testApp(
    home: ConnectionCenterPage(
      store: store,
      vault: MemoryCredentialVault(),
      onConnect: onConnect,
      initialTab: tab ?? ConnectionCenterTab.devices,
    ),
  );

  PcConnection pc(
    String id,
    String name, {
    bool favorite = false,
    String? group,
  }) => PcConnection(
    id: id,
    hostname: '$id.example.com',
    friendlyName: name,
    group: group ?? '',
    favorite: favorite,
  );

  /// Seeds the store before a widget is pumped.
  ///
  /// This has to run through [WidgetTester.runAsync]: the body of a
  /// `testWidgets` test executes in a fake-async zone where the store's real
  /// file writes would never complete, and awaiting one would simply hang the
  /// test rather than fail it.
  Future<void> seed(WidgetTester tester, List<PcConnection> connections) async {
    await tester.runAsync(() async {
      for (final connection in connections) {
        await store.upsertConnection(connection);
      }
    });
  }

  group('session previews', () {
    // The path is handed over whether or not the file is there: a card whose
    // preview has never been taken draws its own artwork instead, and checking
    // the disk for every card on every rebuild would be work for nothing.
    testWidgets('a card is given the path its preview would be at', (
      tester,
    ) async {
      await seed(tester, [pc('dev', '开发机')]);
      await tester.pumpWidget(wrap());
      await tester.pump();

      final card = tester.widget<PcCard>(find.byType(PcCard).first);
      expect(card.thumbnailPath, store.paths.thumbnailFor('dev'));
    });

    testWidgets('each card is given its own', (tester) async {
      await seed(tester, [pc('dev', '开发机'), pc('srv', '服务器')]);
      await tester.pumpWidget(wrap());
      await tester.pump();

      final paths = tester
          .widgetList<PcCard>(find.byType(PcCard))
          .map((card) => card.thumbnailPath)
          .toSet();

      expect(paths, {
        store.paths.thumbnailFor('dev'),
        store.paths.thumbnailFor('srv'),
      });
    });
  });

  group('empty state', () {
    testWidgets('invites the user to add a PC when nothing is saved', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('还没有保存任何电脑'), findsOneWidget);
      expect(find.text('添加电脑'), findsOneWidget);
    });

    testWidgets('does not offer "add a PC" when a search matched nothing', (
      tester,
    ) async {
      // Offering to add a PC when the user simply mistyped a search term would
      // be answering the wrong question.
      await seed(tester, [pc('dev', '开发机')]);
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();

      expect(find.text('没有匹配的结果'), findsOneWidget);
      expect(find.text('添加电脑'), findsNothing);
    });

    testWidgets(
      'explains an empty favourites tab differently from an empty store',
      (tester) async {
        await seed(tester, [pc('dev', '开发机')]);
        await tester.pumpWidget(wrap(tab: ConnectionCenterTab.favorites));
        await tester.pump();

        expect(find.text('这里还没有内容'), findsOneWidget);
        expect(find.text('还没有保存任何电脑'), findsNothing);
      },
    );
  });

  group('localisation', () {
    testWidgets('renders in English when the locale says so', (tester) async {
      // Every other test pins Chinese, which would keep passing even if the
      // English column of the ARB were empty, misspelled, or wired to the
      // wrong key. This is the one that would notice.
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          home: ConnectionCenterPage(
            store: store,
            vault: MemoryCredentialVault(),
            initialTab: ConnectionCenterTab.devices,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No PCs saved yet'), findsOneWidget);
      expect(find.text('Add PC'), findsOneWidget);
      expect(find.text('还没有保存任何电脑'), findsNothing);
    });
  });

  group('grid', () {
    testWidgets('renders one card per saved PC', (tester) async {
      await seed(tester, [pc('a', '开发机'), pc('b', '测试机')]);
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byType(PcCard), findsNWidgets(2));
      expect(find.text('开发机'), findsOneWidget);
      expect(find.text('测试机'), findsOneWidget);
    });

    testWidgets(
      'tapping a card connects — there is no separate connect button',
      (tester) async {
        await seed(tester, [pc('a', '开发机')]);
        PcConnection? connected;
        await tester.pumpWidget(
          wrap(onConnect: (connection) => connected = connection),
        );
        await tester.pump();

        await tester.tap(find.byType(PcCard));
        await tester.pump();

        expect(connected?.id, 'a');
      },
    );

    testWidgets('shows the host under the name only when they differ', (
      tester,
    ) async {
      await seed(tester, [
        pc('a', '开发机'),
        // Same string for both, so it should not be repeated.
        const PcConnection(id: 'b', hostname: 'plain-host'),
      ]);
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('a.example.com'), findsOneWidget);
      expect(find.text('plain-host'), findsOneWidget);
    });
  });

  group('tabs', () {
    testWidgets('filters to favourites', (tester) async {
      await seed(tester, [pc('a', '开发机', favorite: true), pc('b', '测试机')]);
      await tester.pumpWidget(wrap(tab: ConnectionCenterTab.favorites));
      await tester.pump();

      expect(find.byType(PcCard), findsOneWidget);
      expect(find.text('开发机'), findsOneWidget);
    });

    testWidgets('switching tabs changes the contents', (tester) async {
      await seed(tester, [pc('a', '开发机', favorite: true), pc('b', '测试机')]);
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(PcCard), findsNWidgets(2));

      await tester.tap(find.textContaining('收藏夹'));
      await tester.pumpAndSettle();

      expect(find.byType(PcCard), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('matches on name, host and group', (tester) async {
      await seed(tester, [pc('alpha', '开发机'), pc('beta', '测试机', group: '预发布')]);

      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), '预发布');
      await tester.pump();
      expect(find.text('测试机'), findsOneWidget);
      expect(find.text('开发机'), findsNothing);

      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump();
      expect(find.text('开发机'), findsOneWidget);
      expect(find.text('测试机'), findsNothing);
    });

    testWidgets('is case-insensitive', (tester) async {
      await seed(tester, [pc('Alpha', '开发机')]);
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'ALPHA');
      await tester.pump();

      expect(find.byType(PcCard), findsOneWidget);
    });
  });

  group('sorting', () {
    testWidgets('puts never-connected PCs after recently used ones', (
      tester,
    ) async {
      await seed(tester, [
        pc('used', '用过').copyWith(lastConnectedAt: DateTime(2026, 5, 1)),
        pc('fresh', '没用过'),
      ]);

      await tester.pumpWidget(wrap());
      await tester.pump();

      final cards = tester.widgetList<PcCard>(find.byType(PcCard)).toList();
      expect(cards.first.connection.id, 'used');
      expect(cards.last.connection.id, 'fresh');
    });
  });
}
