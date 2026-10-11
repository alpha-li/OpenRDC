import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/models/credential.dart';
import 'package:openrdc/models/gateway.dart';
import 'package:openrdc/models/pc_connection.dart';

void main() {
  group('host and port resolution', () {
    test('uses the separate port when the host has none', () {
      const connection = PcConnection(
        id: 'a',
        hostname: 'pc.example.com',
        port: 3390,
      );
      expect(connection.effectiveHostname, 'pc.example.com');
      expect(connection.effectivePort, 3390);
    });

    test('prefers an explicit host:port over the separate port field', () {
      // The app lets `host:port` be typed straight into the PC name box, so the
      // embedded port has to win or the typed value would be silently ignored.
      const connection = PcConnection(
        id: 'a',
        hostname: 'pc.example.com:4443',
        port: 3389,
      );
      expect(connection.effectiveHostname, 'pc.example.com');
      expect(connection.effectivePort, 4443);
    });

    test('handles a bare IP', () {
      const connection = PcConnection(id: 'a', hostname: '192.168.1.10');
      expect(connection.effectiveHostname, '192.168.1.10');
      expect(connection.effectivePort, PcConnection.defaultPort);
    });

    test('falls back to the raw string when it is not a usable host', () {
      const connection = PcConnection(id: 'a', hostname: 'not a host');
      expect(connection.effectiveHostname, 'not a host');
    });
  });

  group('display name', () {
    test('prefers the friendly name', () {
      const connection = PcConnection(
        id: 'a',
        hostname: '10.0.0.5',
        friendlyName: '开发机',
      );
      expect(connection.displayName, '开发机');
    });

    test('falls back to the host when no friendly name was given', () {
      const connection = PcConnection(id: 'a', hostname: '10.0.0.5');
      expect(connection.displayName, '10.0.0.5');
    });
  });

  group('copyWith', () {
    const base = PcConnection(
      id: 'a',
      hostname: 'pc',
      credentialId: 'cred-1',
      credentialMode: CredentialMode.saved,
      gatewayId: 'gw-1',
    );

    test('clears a reference only when explicitly asked', () {
      // Without the explicit flag, `credentialId: null` would be
      // indistinguishable from "not provided", and every unrelated edit would
      // silently drop the credential.
      expect(base.copyWith(friendlyName: 'x').credentialId, 'cred-1');
      expect(base.copyWith(clearCredentialId: true).credentialId, isNull);
      expect(base.copyWith(clearGatewayId: true).gatewayId, isNull);
      expect(base.copyWith(clearGatewayId: true).credentialId, 'cred-1');
    });

    test('keeps the id stable', () {
      expect(base.copyWith(friendlyName: 'x').id, 'a');
    });

    test('replaces nested settings wholesale', () {
      final updated = base.copyWith(
        display: const PcDisplaySettings(updateResolutionOnResize: false),
      );
      expect(updated.display.updateResolutionOnResize, isFalse);
    });
  });

  group('json', () {
    test('round-trips every field', () {
      final original = PcConnection(
        id: 'pc-1',
        hostname: 'pc.example.com:3390',
        friendlyName: '开发机',
        port: 3390,
        group: '工作',
        credentialMode: CredentialMode.saved,
        credentialId: 'cred-1',
        gatewayId: 'gw-1',
        reconnectIfDropped: false,
        adminSession: true,
        swapMouseButtons: true,
        display: const PcDisplaySettings(
          resolution: Resolution(2560, 1440),
          displayMode: DisplayMode.selectDisplays,
          startFullScreen: true,
          fitSessionToWindow: true,
          updateResolutionOnResize: false,
          colorDepth: 24,
        ),
        redirection: const PcRedirectionSettings(
          clipboardMode: ClipboardMode.remoteToLocal,
          audioPlayback: AudioPlaybackMode.never,
          redirectPrinters: true,
          redirectSmartCards: false,
          redirectDrives: true,
          redirectMicrophone: true,
          redirectCamera: true,
          folders: [RedirectedFolder(path: r'D:\项目', readOnly: true)],
        ),
        favorite: true,
        lastConnectedAt: DateTime(2026, 5, 4, 12, 30),
        createdAt: DateTime(2026, 1, 1),
      );

      final restored = PcConnection.fromJson(original.toJson());

      expect(restored.hostname, original.hostname);
      expect(restored.friendlyName, original.friendlyName);
      expect(restored.group, '工作');
      expect(restored.credentialId, 'cred-1');
      expect(restored.gatewayId, 'gw-1');
      expect(restored.reconnectIfDropped, isFalse);
      expect(restored.adminSession, isTrue);
      expect(restored.swapMouseButtons, isTrue);
      expect(restored.display.resolution, const Resolution(2560, 1440));
      expect(restored.display.displayMode, DisplayMode.selectDisplays);
      expect(restored.display.colorDepth, 24);
      expect(restored.redirection.clipboardMode, ClipboardMode.remoteToLocal);
      expect(restored.redirection.audioPlayback, AudioPlaybackMode.never);
      expect(restored.redirection.redirectCamera, isTrue);
      expect(restored.redirection.folders.single.path, r'D:\项目');
      expect(restored.redirection.folders.single.readOnly, isTrue);
      expect(restored.favorite, isTrue);
      expect(restored.lastConnectedAt, DateTime(2026, 5, 4, 12, 30));
      expect(restored.createdAt, DateTime(2026, 1, 1));
    });

    test('fills in defaults for a sparse document', () {
      // Forward compatibility: a connection saved by an older build must still
      // load rather than throwing on a missing key.
      final restored = PcConnection.fromJson({'id': 'pc-1', 'hostname': 'pc'});

      expect(restored.port, PcConnection.defaultPort);
      expect(restored.credentialMode, CredentialMode.askEveryTime);
      expect(restored.display.resolution, Resolution.fullHd);
      expect(restored.display.updateResolutionOnResize, isTrue);
      expect(restored.redirection.clipboardMode, ClipboardMode.bidirectional);
      expect(restored.redirection.folders, isEmpty);
      expect(restored.favorite, isFalse);
    });

    test('ignores a malformed nested block instead of throwing', () {
      final restored = PcConnection.fromJson({
        'id': 'pc-1',
        'hostname': 'pc',
        'display': 'not a map',
        'redirection': 42,
      });
      expect(restored.display.resolution, Resolution.fullHd);
      expect(restored.redirection.folders, isEmpty);
    });
  });

  group('Resolution', () {
    test('lists presets in non-decreasing order', () {
      // Width alone is not strictly increasing: 1280x720 and 1280x1024 share a
      // width, which is intentional. What matters is that the list reads as
      // sorted and contains no duplicates.
      for (var i = 1; i < Resolution.presets.length; i++) {
        expect(
          Resolution.presets[i].width,
          greaterThanOrEqualTo(Resolution.presets[i - 1].width),
          reason: '预设分辨率应按宽度排序',
        );
      }
      expect(Resolution.presets.toSet(), hasLength(Resolution.presets.length));
    });

    test('formats its label', () {
      expect(const Resolution(1920, 1080).label, '1920 × 1080');
    });
  });

  group('RedirectedFolder', () {
    test('derives a share name from a Windows path', () {
      expect(const RedirectedFolder(path: r'D:\项目\资料').shareName, '资料');
    });

    test('derives a share name from a POSIX path', () {
      expect(
        const RedirectedFolder(path: '/home/alice/docs').shareName,
        'docs',
      );
    });

    test('survives a path with a trailing separator', () {
      expect(const RedirectedFolder(path: r'D:\项目\').shareName, '项目');
    });
  });

  group('Credential', () {
    test('qualifies the user name with the domain when present', () {
      const credential = Credential(
        id: 'c',
        friendlyName: 'x',
        username: 'alice',
        domain: 'CORP',
      );
      expect(credential.qualifiedUsername, r'CORP\alice');
    });

    test('leaves a bare user name alone', () {
      const credential = Credential(
        id: 'c',
        friendlyName: 'x',
        username: 'alice',
      );
      expect(credential.qualifiedUsername, 'alice');
    });

    test(
      'compares by id so a rename does not look like a different credential',
      () {
        const a = Credential(id: 'c', friendlyName: 'old', username: 'alice');
        const b = Credential(id: 'c', friendlyName: 'new', username: 'alice');
        expect(a, b);
      },
    );
  });

  group('Gateway', () {
    test('uses the PC credential when it names none of its own', () {
      // "No credential of its own" is how the form expresses "same as the PC",
      // and it is what the protocol's UseSameCredentials setting means.
      const gateway = Gateway(id: 'g', hostname: 'gw.example.com');
      expect(gateway.usesPcCredential, isTrue);
    });

    test('does not claim to reuse the PC credential when it names one', () {
      const gateway = Gateway(
        id: 'g',
        hostname: 'gw.example.com',
        credentialId: 'cred-1',
        credentialMode: CredentialMode.saved,
      );
      expect(gateway.usesPcCredential, isFalse);
    });

    test('defaults to port 443 and honours an embedded port', () {
      expect(
        const Gateway(id: 'g', hostname: 'gw.example.com').effectivePort,
        443,
      );
      expect(
        const Gateway(id: 'g', hostname: 'gw.example.com:8443').effectivePort,
        8443,
      );
      expect(
        const Gateway(
          id: 'g',
          hostname: 'gw.example.com:8443',
        ).effectiveHostname,
        'gw.example.com',
      );
    });
  });
}
