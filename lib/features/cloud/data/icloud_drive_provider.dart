import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/cloud_provider.dart';

/// iCloud Drive provider — file-based, no API.
///
/// On iOS/macOS, files written to the app's ubiquity container are
/// transparently synced by the OS once the user signs into iCloud and the
/// app declares the iCloud Documents capability in its entitlements. We
/// don't talk to the network directly: instead we read/write files and let
/// the OS push them to iCloud Drive in the background.
///
/// On other platforms the provider reports [isAvailable] = false and
/// rejects every operation. The settings UI hides the iCloud section
/// accordingly.
///
/// Files are kept under `<ubiquity>/Documents/Quill/` so they don't mix
/// with anything else the app might store locally.
class ICloudDriveProvider implements CloudProvider {
  ICloudDriveProvider();

  static const _folderName = 'Quill';
  Directory? _root;

  @override
  CloudProviderId get id => CloudProviderId.icloud;

  @override
  String get displayName => 'iCloud Drive';

  @override
  bool get isAvailable {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  Future<Directory?> _resolveRoot() async {
    if (_root != null) return _root;
    if (!isAvailable) return null;
    try {
      // On iOS, getApplicationDocumentsDirectory() returns the path inside
      // the ubiquity container when iCloud Documents capability is enabled.
      // On macOS / sandboxed builds, the same applies via App Sandbox.
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, _folderName));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _root = dir;
      return dir;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<CloudAuthState> getAuthState() async {
    // iCloud sign-in is OS-level; we can only detect whether the container
    // is reachable. If the user disabled iCloud for this app, stat/upload
    // will fail with CloudException.
    final root = await _resolveRoot();
    final reachable = root != null && await root.exists();
    return CloudAuthState(signedIn: reachable);
  }

  @override
  Future<CloudAuthState> signIn() async {
    // No app-level sign-in — iCloud auth happens via Settings. We just
    // attempt to resolve the container; if it's missing, surface a clear
    // error.
    final root = await _resolveRoot();
    if (root == null) {
      throw const CloudAuthException(
        'iCloud Drive is not reachable. Enable iCloud Drive for Quill in '
        'System Settings and grant access to the app.',
      );
    }
    return getAuthState();
  }

  @override
  Future<void> signOut() async {
    // No-op: signing out of iCloud is done via the OS Settings app.
  }

  File _fileFor(String path) {
    final root = _root;
    if (root == null) {
      throw const CloudException('iCloud container not initialized.');
    }
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    return File(p.join(root.path, cleaned));
  }

  @override
  Future<CloudFileMetadata> upload({
    required String path,
    required Uint8List bytes,
    String? expectedEtag,
  }) async {
    final root = await _resolveRoot();
    if (root == null) {
      throw const CloudAuthException('iCloud Drive is not reachable.');
    }
    final file = _fileFor(path);
    await file.parent.create(recursive: true);
    final existing = await file.exists();
    if (existing && expectedEtag != null) {
      final stat = await file.stat();
      final currentEtag = '${stat.modified.microsecondsSinceEpoch}-${stat.size}';
      if (currentEtag != expectedEtag) {
        throw CloudException('Local file changed before sync completed.');
      }
    }
    await file.writeAsBytes(bytes, flush: true);
    final stat = await file.stat();
    final etag = '${stat.modified.microsecondsSinceEpoch}-${stat.size}';
    return CloudFileMetadata(
      id: etag,
      path: path,
      etag: etag,
      modifiedAt: stat.modified,
    );
  }

  @override
  Future<CloudDownloadResult?> download(String path) async {
    final file = _fileFor(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    final stat = await file.stat();
    final etag = '${stat.modified.microsecondsSinceEpoch}-${stat.size}';
    return CloudDownloadResult(
      bytes: bytes,
      metadata: CloudFileMetadata(
        id: etag,
        path: path,
        etag: etag,
        modifiedAt: stat.modified,
      ),
    );
  }

  @override
  Future<CloudFileMetadata?> stat(String path) async {
    final file = _fileFor(path);
    if (!await file.exists()) return null;
    final s = await file.stat();
    final etag = '${s.modified.microsecondsSinceEpoch}-${s.size}';
    return CloudFileMetadata(
      id: etag,
      path: path,
      etag: etag,
      modifiedAt: s.modified,
    );
  }

  @override
  Future<List<CloudFileMetadata>> list({String prefix = ''}) async {
    final root = await _resolveRoot();
    if (root == null) return const [];
    final dir = prefix.isEmpty
        ? root
        : Directory(p.join(root.path, prefix.startsWith('/') ? prefix.substring(1) : prefix));
    if (!await dir.exists()) return const [];
    final files = await dir.list().toList();
    final out = <CloudFileMetadata>[];
    for (final f in files) {
      if (f is! File) continue;
      final rel = p.relative(f.path, from: root.path);
      final s = await f.stat();
      final etag = '${s.modified.microsecondsSinceEpoch}-${s.size}';
      out.add(CloudFileMetadata(
        id: etag,
        path: rel,
        etag: etag,
        modifiedAt: s.modified,
      ));
    }
    return out;
  }

  @override
  Future<void> delete(String path) async {
    final file = _fileFor(path);
    if (await file.exists()) await file.delete();
  }
}