/// Persistence for saved PCs, credentials and gateways.
///
/// One JSON document holds all three, because they reference each other by id
/// and a partial write would otherwise be able to leave a connection pointing
/// at a credential that no longer exists.
///
/// Secrets are not stored here. [Credential] holds only the user name; the
/// password lives in the platform vault and is fetched at connect time.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/credential.dart';
import '../models/gateway.dart';
import '../models/json_utils.dart';
import '../models/pc_connection.dart';
import 'storage_paths.dart';

/// What went wrong with the store, as a category rather than a sentence.
///
/// The store is a data layer, and a sentence it wrote would be untranslatable:
/// by the time it reaches the screen it is a `String` with no way back to a
/// translation. The UI maps these to words.
enum ConnectionStoreError {
  /// The file exists but could not be read.
  unreadable,

  /// The file parsed as JSON but is not a connection document.
  malformed,

  /// Written by a newer version of the app than this one.
  unsupportedVersion,

  /// The store could not be written.
  writeFailed,
}

/// Raised when the store cannot be read or written.
class ConnectionStoreException implements Exception {
  ConnectionStoreException(this.kind, [this.cause]);

  final ConnectionStoreError kind;
  final Object? cause;

  @override
  String toString() =>
      'ConnectionStoreException: ${kind.name}'
      '${cause == null ? '' : ' ($cause)'}';
}

class ConnectionStore extends ChangeNotifier {
  ConnectionStore(this.paths);

  /// Bumped whenever the on-disk shape changes, so a future version can migrate
  /// instead of discarding the user's saved PCs.
  static const int schemaVersion = 1;

  final StoragePaths paths;

  final List<PcConnection> _connections = [];
  final List<Credential> _credentials = [];
  final List<Gateway> _gateways = [];

  bool _loaded = false;
  ConnectionStoreError? _loadError;

  /// Unmodifiable views. The store is the only thing allowed to mutate them, so
  /// that every change goes through a save.
  List<PcConnection> get connections => List.unmodifiable(_connections);
  List<Credential> get credentials => List.unmodifiable(_credentials);
  List<Gateway> get gateways => List.unmodifiable(_gateways);

  bool get isLoaded => _loaded;

  /// Non-null when the last load failed. The UI surfaces this rather than
  /// pretending the user has no saved PCs.
  ConnectionStoreError? get loadError => _loadError;

  /// PCs pinned to Favorites, in recency order.
  List<PcConnection> get favorites =>
      _connections.where((connection) => connection.favorite).toList();

  /// Reads the store from disk. A missing file is not an error: it just means
  /// this is a first run.
  Future<void> load() async {
    _connections.clear();
    _credentials.clear();
    _gateways.clear();
    _loadError = null;

    final file = paths.connectionsFileHandle;
    if (!await file.exists()) {
      _loaded = true;
      notifyListeners();
      return;
    }

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _loaded = true;
        notifyListeners();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw ConnectionStoreException(ConnectionStoreError.malformed);
      }
      _readDocument(decoded);
      _loaded = true;
    } on Object catch (error) {
      // Keep the bad file so the user can recover it by hand, and carry on with
      // an empty store rather than refusing to start.
      _loadError = error is ConnectionStoreException
          ? error.kind
          : ConnectionStoreError.unreadable;
      await _quarantineUnreadableFile(file);
      _loaded = true;
    }
    notifyListeners();
  }

  Future<void> upsertConnection(PcConnection connection) async {
    final index = _connections.indexWhere(
      (existing) => existing.id == connection.id,
    );
    if (index >= 0) {
      _connections[index] = connection;
    } else {
      _connections.add(connection);
    }
    await _save();
  }

  Future<void> deleteConnection(String id) async {
    _connections.removeWhere((connection) => connection.id == id);
    await _save();
    // The session preview belongs to the PC that is gone. Best effort: an
    // orphaned picture is untidy, not a reason to fail the deletion.
    try {
      final thumbnail = File(paths.thumbnailFor(id));
      if (thumbnail.existsSync()) {
        await thumbnail.delete();
      }
    } on Object {
      // Left behind; nothing depends on it being gone.
    }
  }

  Future<void> setFavorite(String id, {required bool favorite}) async {
    final index = _connections.indexWhere((connection) => connection.id == id);
    if (index < 0) {
      return;
    }
    _connections[index] = _connections[index].copyWith(favorite: favorite);
    await _save();
  }

  /// Records that a session was opened, which drives the "recently used" sort.
  Future<void> markConnected(String id, {required DateTime at}) async {
    final index = _connections.indexWhere((connection) => connection.id == id);
    if (index < 0) {
      return;
    }
    _connections[index] = _connections[index].copyWith(lastConnectedAt: at);
    await _save();
  }

  Future<void> upsertCredential(Credential credential) async {
    final index = _credentials.indexWhere(
      (existing) => existing.id == credential.id,
    );
    if (index >= 0) {
      _credentials[index] = credential;
    } else {
      _credentials.add(credential);
    }
    await _save();
  }

  /// Removes a credential and detaches it from anything that referenced it, so
  /// no connection is left pointing at a credential that is gone.
  Future<void> deleteCredential(String id) async {
    _credentials.removeWhere((credential) => credential.id == id);
    for (var i = 0; i < _connections.length; i++) {
      final connection = _connections[i];
      if (connection.credentialId == id) {
        _connections[i] = connection.copyWith(
          clearCredentialId: true,
          credentialMode: CredentialMode.askEveryTime,
        );
      }
    }
    for (var i = 0; i < _gateways.length; i++) {
      if (_gateways[i].credentialId == id) {
        _gateways[i] = _gateways[i].copyWith(clearCredentialId: true);
      }
    }
    await _save();
  }

  Future<void> upsertGateway(Gateway gateway) async {
    final index = _gateways.indexWhere((existing) => existing.id == gateway.id);
    if (index >= 0) {
      _gateways[index] = gateway;
    } else {
      _gateways.add(gateway);
    }
    await _save();
  }

  /// Removes a gateway and clears the reference from any connection using it.
  Future<void> deleteGateway(String id) async {
    _gateways.removeWhere((gateway) => gateway.id == id);
    for (var i = 0; i < _connections.length; i++) {
      if (_connections[i].gatewayId == id) {
        _connections[i] = _connections[i].copyWith(clearGatewayId: true);
      }
    }
    await _save();
  }

  PcConnection? connectionById(String id) =>
      _connections.where((connection) => connection.id == id).firstOrNull;

  Credential? credentialById(String id) =>
      _credentials.where((credential) => credential.id == id).firstOrNull;

  Gateway? gatewayById(String id) =>
      _gateways.where((gateway) => gateway.id == id).firstOrNull;

  // -------------------------------------------------------------------------

  void _readDocument(Map<String, Object?> document) {
    final version = document['schemaVersion'] as int? ?? schemaVersion;
    if (version > schemaVersion) {
      throw ConnectionStoreException(
        ConnectionStoreError.unsupportedVersion,
        // Developer-facing detail, deliberately not translated: it names the
        // schema numbers, which are the same in every language.
        'document schema $version, this build supports $schemaVersion',
      );
    }

    // Each entry is validated on its own so one malformed record costs the user
    // that record, not the whole file.
    for (final entry in asList(document['credentials'])) {
      if (entry is Map<String, Object?>) {
        _credentials.add(Credential.fromJson(entry));
      }
    }
    for (final entry in asList(document['gateways'])) {
      if (entry is Map<String, Object?>) {
        _gateways.add(Gateway.fromJson(entry));
      }
    }
    for (final entry in asList(document['connections'])) {
      if (entry is Map<String, Object?>) {
        _connections.add(PcConnection.fromJson(entry));
      }
    }
  }

  Map<String, Object?> _buildDocument() => {
    'schemaVersion': schemaVersion,
    'connections': _connections
        .map((connection) => connection.toJson())
        .toList(),
    'credentials': _credentials
        .map((credential) => credential.toJson())
        .toList(),
    'gateways': _gateways.map((gateway) => gateway.toJson()).toList(),
  };

  Future<void> _save() async {
    try {
      await paths.ensureExists();
      final file = paths.connectionsFileHandle;
      final temp = File('${file.path}.tmp');

      // Write-and-rename so an interrupted save cannot leave a half-written
      // document where the user's connections used to be.
      await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_buildDocument()),
        flush: true,
      );
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
    } on Object catch (error) {
      throw ConnectionStoreException(ConnectionStoreError.writeFailed, error);
    }
    notifyListeners();
  }

  /// Renames an unreadable store out of the way so the next save starts clean
  /// and the original is still on disk to inspect.
  Future<void> _quarantineUnreadableFile(File file) async {
    try {
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      await file.rename('${file.path}.corrupt-$stamp');
    } on Object {
      // Best effort only; failing to move it must not stop the app starting.
    }
  }
}
