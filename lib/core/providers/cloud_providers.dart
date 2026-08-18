import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cloud/application/sync_engine.dart';
import '../../features/cloud/data/icloud_drive_provider.dart';
import '../../features/cloud/data/one_drive_provider.dart';
import '../../features/cloud/domain/cloud_provider.dart';
import 'database_providers.dart';

/// The OneDrive provider is a singleton; we hold the instance in a
/// notifier so the settings UI can mutate the client_id without
/// re-instantiating the provider.
final oneDriveProvider = Provider<OneDriveProvider>((ref) {
  return OneDriveProvider();
});

final iCloudDriveProvider = Provider<ICloudDriveProvider>((ref) {
  return ICloudDriveProvider();
});

/// Selects which provider drives the [syncEngineProvider]. For now we
/// hardcode OneDrive since it's the only one with a real API. The settings
/// UI will let users switch once iCloud Drive is wired to NSFileCoordinator.
final activeCloudProviderProvider =
    Provider<CloudProvider>((ref) => ref.watch(oneDriveProvider));

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncEngine(
    provider: ref.watch(activeCloudProviderProvider),
    notesDao: db.notesDao,
    pagesDao: db.drawingPagesDao,
    foldersDao: db.foldersDao,
  );
});

/// How many notes have pending changes for the active provider. Surfaced
/// in the settings UI so users can see what's queued before forcing a sync.
final pendingDirtyCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  final provider = ref.watch(activeCloudProviderProvider);
  final db = ref.watch(databaseProvider);
  final name = switch (provider.id) {
    CloudProviderId.oneDrive => 'onedrive',
    CloudProviderId.icloud => 'icloud',
  };
  return db.notesDao.watchDirty(provider: name).map((rows) => rows.length);
});

/// Watches a single note's sync state — drives the badge on the editor's
/// AppBar. Listens to the DB so renames/edits bump isDirty in real time.
final noteSyncStateProvider =
    StreamProvider.family.autoDispose<NoteSyncBadgeState, String>(
        (ref, noteId) {
  final dao = ref.watch(databaseProvider).notesDao;
  return dao.watchById(noteId).map((row) {
    if (row == null) return NoteSyncBadgeState.localOnly;
    if (!row.isDirty && row.cloudEtag != null) return NoteSyncBadgeState.synced;
    if (row.isDirty && row.cloudEtag != null) return NoteSyncBadgeState.dirty;
    return NoteSyncBadgeState.localOnly;
  });
});

enum NoteSyncBadgeState {
  localOnly,
  dirty,
  synced,
  syncing,
}