import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../domain/cloud_provider.dart';

/// Microsoft OneDrive implementation of [CloudProvider].
///
/// Uses Microsoft Graph API (https://graph.microsoft.com/v1.0/me/drive/...)
/// for file operations and OAuth 2.0 via [flutter_appauth] for
/// authentication. Tokens are kept in memory only — re-auth is required on
/// cold start, which keeps the OAuth configuration minimal.
///
/// The user must register an Azure AD application at
/// https://portal.azure.com → Microsoft Entra ID → App registrations, then
/// provide the client_id at first sign-in. Public client (mobile) flow with
/// PKCE is used so no client secret is needed.
class OneDriveProvider implements CloudProvider {
  OneDriveProvider({FlutterAppAuth? auth, http.Client? client})
      : _appAuth = auth ?? FlutterAppAuth(),
        _http = client ?? http.Client();

  static const _authority = 'https://login.microsoftonline.com/common';
  static const _tokenEndpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const _graphBase = 'https://graph.microsoft.com/v1.0/me/drive';
  static const _scopes = ['openid', 'profile', 'offline_access', 'Files.ReadWrite', 'User.Read'];

  /// Folder under /me/drive/root where Quill stores its files. Acts as a
  /// namespace so we don't pollute the user's drive.
  static const _remoteFolder = 'Quill';

  final FlutterAppAuth _appAuth;
  final http.Client _http;

  String? _clientId;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _userEmail;
  String? _userName;

  /// Set the Azure AD application client id. Must be called before [signIn].
  /// In a future revision this could be wired through Settings UI.
  void configureClientId(String clientId) {
    _clientId = clientId;
  }

  String? get clientId => _clientId;

  @override
  CloudProviderId get id => CloudProviderId.oneDrive;

  @override
  String get displayName => 'Microsoft OneDrive';

  @override
  bool get isAvailable => true;

  @override
  Future<CloudAuthState> getAuthState() async {
    if (_accessToken == null || _expiresAt == null) {
      return CloudAuthState.signedOut;
    }
    if (DateTime.now().isAfter(_expiresAt!)) {
      // Try a silent refresh.
      final refreshed = await _refreshTokens();
      if (!refreshed) return CloudAuthState.signedOut;
    }
    return CloudAuthState(
      signedIn: true,
      userEmail: _userEmail,
      userName: _userName,
    );
  }

  @override
  Future<CloudAuthState> signIn() async {
    final clientId = _clientId;
    if (clientId == null || clientId.isEmpty) {
      throw const CloudAuthException(
        'OneDrive is not configured. Set the Azure AD client id in Settings.',
      );
    }
    final redirect = _redirectUriFor(clientId);
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirect,
        discoveryUrl: '$_authority/v2.0/.well-known/openid-configuration',
        scopes: _scopes,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: '$_authority/oauth2/v2.0/authorize',
          tokenEndpoint: _tokenEndpoint,
        ),
      ),
    );
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _expiresAt = result.accessTokenExpirationDateTime;
    await _fetchUserProfile();
    return getAuthState();
  }

  @override
  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _userEmail = null;
    _userName = null;
  }

  /// Microsoft 365 (work / school) accounts require a tenant-specific
  /// authority; consumer accounts use /common. AppAuth's PKCE flow picks
  /// the right one from the discovery document automatically.
  String _redirectUriFor(String clientId) {
    if (Platform.isIOS || Platform.isMacOS) {
      return 'msauth.$clientId://auth';
    }
    return 'https://localhost/oauth-callback';
  }

  Future<bool> _refreshTokens() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse(_tokenEndpoint),
        body: {
          'client_id': _clientId,
          'scope': _scopes.join(' '),
          'refresh_token': refresh,
          'grant_type': 'refresh_token',
        },
      );
      if (resp.statusCode != 200) return false;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      _accessToken = json['access_token'] as String;
      _refreshToken = (json['refresh_token'] as String?) ?? _refreshToken;
      final expiresIn = (json['expires_in'] as int?) ?? 3600;
      _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final resp = await _http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: _authHeaders(),
      );
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        _userName = json['displayName'] as String?;
        _userEmail = (json['mail'] as String?) ??
            (json['userPrincipalName'] as String?);
      }
    } catch (e) {
      // Non-fatal — sign-in still succeeded.
    }
  }

  Map<String, String> _authHeaders() => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  String _fullRemotePath(String path) {
    final rel = path.startsWith('/') ? path.substring(1) : path;
    if (rel.startsWith(_remoteFolder)) return rel;
    return p.posix.join(_remoteFolder, rel);
  }

  @override
  Future<CloudFileMetadata> upload({
    required String path,
    required Uint8List bytes,
    String? expectedEtag,
  }) async {
    final remote = _fullRemotePath(path);
    // PUT /me/drive/root:/<path>:/content — creates or replaces atomically.
    final uri = Uri.parse('$_graphBase/root:/$remote:/content');
    final headers = <String, String>{
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/octet-stream',
      if (expectedEtag != null) 'If-Match': expectedEtag,
    };
    final resp = await _http.put(uri, headers: headers, body: bytes);
    if (resp.statusCode == 412) {
      throw CloudException('Remote file has changed; refresh and retry.', statusCode: 412);
    }
    if (resp.statusCode >= 400) {
      throw CloudException('OneDrive upload failed: ${resp.body}', statusCode: resp.statusCode);
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return _metadataFromGraph(json);
  }

  @override
  Future<CloudDownloadResult?> download(String path) async {
    final remote = _fullRemotePath(path);
    final uri = Uri.parse('$_graphBase/root:/$remote:/content');
    final resp = await _http.get(uri, headers: _authHeaders());
    if (resp.statusCode == 404) return null;
    if (resp.statusCode >= 400) {
      throw CloudException('OneDrive download failed: ${resp.body}', statusCode: resp.statusCode);
    }
    final etag = resp.headers['etag'] ?? '';
    final lastModified = resp.headers['last-modified'];
    final modified = lastModified != null
        ? DateTime.tryParse(lastModified) ?? DateTime.now()
        : DateTime.now();
    return CloudDownloadResult(
      bytes: resp.bodyBytes,
      metadata: CloudFileMetadata(
        id: etag,
        path: remote,
        etag: etag,
        modifiedAt: modified,
      ),
    );
  }

  @override
  Future<CloudFileMetadata?> stat(String path) async {
    final remote = _fullRemotePath(path);
    final uri = Uri.parse('$_graphBase/root:/$remote');
    final resp = await _http.get(uri, headers: _authHeaders());
    if (resp.statusCode == 404) return null;
    if (resp.statusCode >= 400) {
      throw CloudException('OneDrive stat failed: ${resp.body}', statusCode: resp.statusCode);
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return _metadataFromGraph(json);
  }

  @override
  Future<List<CloudFileMetadata>> list({String prefix = ''}) async {
    final remote = _fullRemotePath(prefix);
    final uri = Uri.parse('$_graphBase/root:/$remote:/children');
    final resp = await _http.get(uri, headers: _authHeaders());
    if (resp.statusCode == 404) return [];
    if (resp.statusCode >= 400) {
      throw CloudException('OneDrive list failed: ${resp.body}', statusCode: resp.statusCode);
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (json['value'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((m) => m.containsKey('file')) // skip folders
        .toList();
    return [for (final m in items) _metadataFromGraph(m)];
  }

  @override
  Future<void> delete(String path) async {
    final remote = _fullRemotePath(path);
    final uri = Uri.parse('$_graphBase/root:/$remote');
    final resp = await _http.delete(uri, headers: _authHeaders());
    if (resp.statusCode == 404) return;
    if (resp.statusCode >= 400) {
      throw CloudException('OneDrive delete failed: ${resp.body}', statusCode: resp.statusCode);
    }
  }

  CloudFileMetadata _metadataFromGraph(Map<String, dynamic> json) {
    final etag = (json['eTag'] as String?) ?? '';
    final lastModified = DateTime.tryParse(json['lastModifiedDateTime'] as String? ?? '') ??
        DateTime.now();
    final name = (json['name'] as String?) ?? '';
    return CloudFileMetadata(
      id: json['id'] as String? ?? etag,
      path: name,
      etag: etag,
      modifiedAt: lastModified,
    );
  }

  @visibleForTesting
  void debugSetTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 1));
  }
}