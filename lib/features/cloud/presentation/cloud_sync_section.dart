import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/cloud_providers.dart';
import '../domain/cloud_provider.dart';

/// Settings panel that exposes cloud-sync controls: sign in/out, force a
/// sync, view what's about to be uploaded, etc.
class CloudSyncSection extends ConsumerStatefulWidget {
  const CloudSyncSection({super.key});

  @override
  ConsumerState<CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<CloudSyncSection> {
  Future<CloudAuthState>? _authFuture;
  bool _busy = false;

  Future<void> _signIn(CloudProvider provider) async {
    setState(() {
      _busy = true;
      _authFuture = provider.signIn();
    });
    try {
      await _authFuture;
    } on CloudAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut(CloudProvider provider) async {
    await provider.signOut();
    setState(() => _authFuture = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out. Local notes are untouched.')),
      );
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(syncEngineProvider).sync();
      if (!mounted) return;
      final msg = result.skipped
          ? (result.reason ?? 'Sync already running.')
          : 'Pushed ${result.uploaded} · pulled ${result.downloaded}'
              '${result.hasErrors ? " · errors" : ""}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = ref.watch(syncEngineProvider);
    final provider = engine.provider;
    final dirtyCountAsync = ref.watch(pendingDirtyCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'CLOUD SYNC',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (!provider.isAvailable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              '${provider.displayName} is not available on this platform.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          FutureBuilder<CloudAuthState>(
            future: _authFuture ?? provider.getAuthState(),
            builder: (context, snapshot) {
              final state = snapshot.data ?? const CloudAuthState(signedIn: false);
              if (state.signedIn) {
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.cloud_done_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(provider.displayName),
                      subtitle: Text(
                        state.userEmail ?? state.userName ?? 'Connected',
                      ),
                    ),
                    if (_providerName(provider) == 'onedrive') ...[
                      ListTile(
                        leading: const Icon(Icons.cloud_sync_outlined),
                        title: Text(_pendingLabel(dirtyCountAsync.valueOrNull ?? 0)),
                        subtitle: Text(
                          'Last-write-wins conflict resolution',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: const Text('Sync now'),
                        onPressed: _busy ? null : _syncNow,
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextButton.icon(
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                      onPressed: _busy ? null : () => _signOut(provider),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      _providerName(provider) == 'onedrive'
                          ? Icons.cloud_outlined
                          : Icons.cloud_queue_rounded,
                    ),
                    title: Text(provider.displayName),
                    subtitle: Text(
                      _providerName(provider) == 'onedrive'
                          ? 'Sign in with your Microsoft 365 account to back up your notes.'
                          : 'Use the system Files app to enable iCloud for Quill.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Connect'),
                        onPressed: _busy ? null : () => _signIn(provider),
                      ),
                    ),
                  ),
                  if (_providerName(provider) == 'onedrive') ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _OneDriveSetupHint(),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
      ],
    );
  }

  String _providerName(CloudProvider p) {
    switch (p.id) {
      case CloudProviderId.oneDrive:
        return 'onedrive';
      case CloudProviderId.icloud:
        return 'icloud';
    }
  }

  String _pendingLabel(int count) {
    if (count == 0) return 'Everything is up to date';
    return '$count note${count == 1 ? "" : "s"} pending upload';
  }
}

class _OneDriveSetupHint extends StatelessWidget {
  const _OneDriveSetupHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You need an Azure AD app registration. Set a public client '
              '(mobile + desktop) with redirect URI msauth.<client-id>://auth, '
              'then enter the client id below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}