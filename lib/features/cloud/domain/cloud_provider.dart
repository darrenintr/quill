import 'dart:typed_data';

/// Stable identifier for a cloud storage provider. Strings are persisted in
/// the database ([Notes.cloudProvider]) — never reorder or rename them
/// without a migration.
enum CloudProviderId {
  oneDrive,
  icloud,
}

/// Snapshot of the provider's authentication state. The engine inspects this
/// at app start to decide whether to attempt sync.
class CloudAuthState {
  const CloudAuthState({
    required this.signedIn,
    this.userEmail,
    this.userName,
  });

  final bool signedIn;
  final String? userEmail;
  final String? userName;

  static const signedOut = CloudAuthState(signedIn: false);
}

/// Metadata returned by [CloudProvider.upload] / [CloudProvider.download].
/// [etag] is whatever opaque token the provider returns (Graph API uses
/// eTags, iCloud doesn't — we use updatedAt millis for iCloud).
class CloudFileMetadata {
  const CloudFileMetadata({
    required this.id,
    required this.path,
    required this.etag,
    required this.modifiedAt,
  });

  final String id;
  final String path;
  final String etag;
  final DateTime modifiedAt;
}

/// Result of fetching a remote file. [metadata] is None if the file does not
/// exist remotely.
class CloudDownloadResult {
  const CloudDownloadResult({required this.bytes, required this.metadata});
  final Uint8List bytes;
  final CloudFileMetadata metadata;
}

/// Operations every cloud provider must support. The implementation may
/// throw [CloudAuthException] / [CloudNotFoundException] / [CloudException]
/// to signal specific failure modes; the [SyncEngine] translates these into
/// user-facing messages.
abstract class CloudProvider {
  /// Stable id persisted to the database.
  CloudProviderId get id;

  /// Human-readable name shown in settings.
  String get displayName;

  /// Whether this provider is reachable on the current platform / build.
  /// iCloud Drive is only meaningful on iOS/macOS; OneDrive is everywhere.
  bool get isAvailable;

  Future<CloudAuthState> getAuthState();

  /// Triggers the OAuth flow. On success, persists tokens internally so
  /// subsequent calls don't re-authenticate.
  Future<CloudAuthState> signIn();

  /// Wipes tokens and signs the user out. Local notes are untouched.
  Future<void> signOut();

  /// Uploads [bytes] to [path] (provider-relative). If [expectedEtag] is
  /// provided, the upload fails if the remote etag has changed (optimistic
  /// concurrency control). Returns the new metadata.
  Future<CloudFileMetadata> upload({
    required String path,
    required Uint8List bytes,
    String? expectedEtag,
  });

  /// Downloads the file at [path]. Throws [CloudNotFoundException] if missing.
  Future<CloudDownloadResult?> download(String path);

  /// Lightweight check: returns the file's metadata without downloading its
  /// contents. Returns null if absent.
  Future<CloudFileMetadata?> stat(String path);

  /// Lists files under [prefix]. Used for full reconciliation on first sync.
  Future<List<CloudFileMetadata>> list({String prefix = ''});

  Future<void> delete(String path);
}

class CloudException implements Exception {
  const CloudException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'CloudException: $message';
}

class CloudAuthException extends CloudException {
  const CloudAuthException(super.message);
}

class CloudNotFoundException extends CloudException {
  const CloudNotFoundException(super.message);
}