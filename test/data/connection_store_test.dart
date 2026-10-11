import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/data/connection_store.dart';
import 'package:openrdc/data/storage_paths.dart';
import 'package:openrdc/models/credential.dart';
import 'package:openrdc/models/gateway.dart';
import 'package:openrdc/models/pc_connection.dart';

void main() {
  late Directory tempDir;
  late StoragePaths paths;
  late ConnectionStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('openrdc_store_test');
    paths = StoragePaths.forDirectory(tempDir);
    store = ConnectionStore(paths);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  PcConnection sampleConnection({
    String id = 'pc-1',
    String host = '10.0.0.5',
  }) => PcConnection(id: id, hostname: host, friendlyName: '开发机');

  group('load', () {
    test('treats a missing file as a first run rather than an error', () async {
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.loadError, isNull);
      expect(store.connections, isEmpty);
    });

    test('treats an empty file as an empty store', () async {
      await paths.ensureExists();
      await File(paths.connectionsFile).writeAsString('   ');
      await store.load();
      expect(store.loadError, isNull);
      expect(store.connections, isEmpty);
    });

    test('quarantines a corrupt file and still starts', () async {
      await paths.ensureExists();
      await File(paths.connectionsFile).writeAsString('{ this is not json');

      await store.load();

      expect(store.isLoaded, isTrue);
      expect(store.loadError, isNotNull);
      expect(store.connections, isEmpty);

      // The original must survive under a new name, so the user can recover it.
      final quarantined = tempDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('.corrupt-'))
          .toList();
      expect(quarantined, hasLength(1));
      expect(quarantined.single.readAsStringSync(), '{ this is not json');
    });

    test('refuses a document written by a newer schema', () async {
      await paths.ensureExists();
      await File(paths.connectionsFile).writeAsString(
        jsonEncode({
          'schemaVersion': ConnectionStore.schemaVersion + 1,
          'connections': [],
        }),
      );

      await store.load();

      // The store reports a category rather than a sentence, so the assertion
      // is on the category: the wording belongs to the UI and may be
      // translated, but the reason is a fact about the file.
      expect(store.loadError, ConnectionStoreError.unsupportedVersion);
    });
  });

  group('persistence', () {
    test('round-trips connections, credentials and gateways', () async {
      await store.load();
      await store.upsertCredential(
        const Credential(
          id: 'cred-1',
          friendlyName: '工作账户',
          username: 'alice',
          domain: 'CORP',
        ),
      );
      await store.upsertGateway(
        const Gateway(
          id: 'gw-1',
          hostname: 'gw.example.com',
          friendlyName: '公司网关',
        ),
      );
      await store.upsertConnection(
        sampleConnection().copyWith(
          credentialId: 'cred-1',
          credentialMode: CredentialMode.saved,
          gatewayId: 'gw-1',
        ),
      );

      final reloaded = ConnectionStore(paths);
      await reloaded.load();

      expect(reloaded.credentials, hasLength(1));
      expect(reloaded.credentials.single.qualifiedUsername, r'CORP\alice');
      expect(reloaded.gateways.single.effectiveHostname, 'gw.example.com');
      expect(reloaded.gateways.single.effectivePort, 443);
      expect(reloaded.connections.single.displayName, '开发机');
      expect(reloaded.connections.single.credentialId, 'cred-1');
      expect(reloaded.connections.single.gatewayId, 'gw-1');
    });

    test('leaves no temporary file behind', () async {
      await store.load();
      await store.upsertConnection(sampleConnection());

      final leftovers = tempDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('upsert replaces rather than duplicating', () async {
      await store.load();
      await store.upsertConnection(sampleConnection());
      await store.upsertConnection(sampleConnection(host: '10.0.0.9'));

      expect(store.connections, hasLength(1));
      expect(store.connections.single.hostname, '10.0.0.9');
    });
  });

  group('referential cleanup', () {
    test(
      'deleting a credential detaches it from connections and gateways',
      () async {
        await store.load();
        await store.upsertCredential(
          const Credential(
            id: 'cred-1',
            friendlyName: '工作账户',
            username: 'alice',
          ),
        );
        await store.upsertGateway(
          const Gateway(
            id: 'gw-1',
            hostname: 'gw.example.com',
            credentialId: 'cred-1',
          ),
        );
        await store.upsertConnection(
          sampleConnection().copyWith(
            credentialId: 'cred-1',
            credentialMode: CredentialMode.saved,
          ),
        );

        await store.deleteCredential('cred-1');

        final connection = store.connections.single;
        expect(connection.credentialId, isNull);
        // Falling back to prompting is the only safe mode once the credential is
        // gone; leaving it as `saved` would make the session fail to start.
        expect(connection.credentialMode, CredentialMode.askEveryTime);
        expect(store.gateways.single.credentialId, isNull);
      },
    );

    test('deleting a gateway clears the reference from connections', () async {
      await store.load();
      await store.upsertGateway(
        const Gateway(id: 'gw-1', hostname: 'gw.example.com'),
      );
      await store.upsertConnection(
        sampleConnection().copyWith(gatewayId: 'gw-1'),
      );

      await store.deleteGateway('gw-1');

      expect(store.gateways, isEmpty);
      expect(store.connections.single.gatewayId, isNull);
      expect(store.connections.single.usesGateway, isFalse);
    });

    test('deleting a connection takes its session preview with it', () async {
      await store.load();
      await store.upsertConnection(sampleConnection(id: 'pc-1'));
      final thumbnail = File(paths.thumbnailFor('pc-1'));
      await thumbnail.create(recursive: true);
      expect(thumbnail.existsSync(), isTrue);

      await store.deleteConnection('pc-1');

      expect(store.connections, isEmpty);
      expect(thumbnail.existsSync(), isFalse);
    });
  });

  group('favorites and recency', () {
    test('filters favorites', () async {
      await store.load();
      await store.upsertConnection(sampleConnection(id: 'pc-1'));
      await store.upsertConnection(
        sampleConnection(id: 'pc-2', host: '10.0.0.6'),
      );
      await store.setFavorite('pc-2', favorite: true);

      expect(store.favorites.map((c) => c.id), ['pc-2']);
    });

    test('records the last connection time', () async {
      await store.load();
      await store.upsertConnection(sampleConnection());
      final when = DateTime(2026, 5, 4, 12, 30);

      await store.markConnected('pc-1', at: when);

      expect(store.connections.single.lastConnectedAt, when);
    });

    test('markConnected on an unknown id is a no-op', () async {
      await store.load();
      await store.markConnected('nope', at: DateTime(2026));
      expect(store.connections, isEmpty);
    });
  });
}
