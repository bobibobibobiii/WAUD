import 'package:cloudbase_ce/cloudbase_ce.dart';
import '../models/models.dart';
import 'cloud_auth_service.dart';
import 'database_service.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  Future<void> syncNow() async {
    final auth = CloudAuthService();
    if (!auth.isAvailable) throw StateError(auth.initError ?? '国内云未就绪：CloudBase 未初始化成功。');
    final uid = auth.currentUserId;
    if (uid == null || uid.isEmpty) throw StateError('尚未登录，无法同步。');
    final core = auth.core;
    if (core == null) throw StateError('国内云未就绪：CloudBase 未初始化成功。');

    final localDb = DatabaseService();
    final cloudDb = CloudBaseDatabase(core);

    await _syncCategories(localDb, cloudDb, uid);
    await _syncActions(localDb, cloudDb, uid);
    await _syncRecords(localDb, cloudDb, uid);

    await _purgeDeletedOlderThan(cloudDb, uid, 'categories', retentionDays: 30);
    await _purgeDeletedOlderThan(cloudDb, uid, 'actions', retentionDays: 30);
    await _purgeDeletedOlderThan(cloudDb, uid, 'records', retentionDays: 30);
  }

  Future<void> _purgeDeletedOlderThan(
    CloudBaseDatabase cloudDb,
    String uid,
    String collName, {
    required int retentionDays,
  }) async {
    final cutoffMillis = DateTime.now().millisecondsSinceEpoch - Duration(days: retentionDays).inMilliseconds;
    while (true) {
      final resp = await cloudDb
          .collection(collName)
          .where({
            'uid': uid,
            'isDeleted': true,
            'deletedAtMillis': cloudDb.command.lte(cutoffMillis),
          })
          .limit(100)
          .get();
      final list = (resp.data as List?) ?? const [];
      if (list.isEmpty) break;
      for (final item in list) {
        final map = (item as Map).cast<String, dynamic>();
        final id = map['_id'] as String?;
        if (id == null) continue;
        await cloudDb.collection(collName).doc(id).remove();
      }
    }
  }

  Future<void> _syncCategories(DatabaseService localDb, CloudBaseDatabase cloudDb, String uid) async {
    final remoteResp = await cloudDb.collection('categories').where({'uid': uid}).limit(1000).get();
    final remoteList = (remoteResp.data as List?) ?? const [];
    final remote = <String, Map<String, dynamic>>{};
    for (final item in remoteList) {
      final m = (item as Map).cast<String, dynamic>();
      final id = m['_id'] as String?;
      if (id == null) continue;
      remote[id] = m;
    }

    for (final entry in remote.entries) {
      final id = entry.key;
      final data = entry.value;
      final remoteUpdated = (data['updatedAtMillis'] as num?)?.toInt() ?? 0;
      final remoteDeleted = (data['isDeleted'] as bool?) ?? false;
      final remoteDeletedAt = (data['deletedAtMillis'] as num?)?.toInt() ?? 0;
      final local = localDb.categories.get(id);
      final localUpdated = local?.updatedAtMillis ?? 0;
      if (local == null || remoteUpdated > localUpdated) {
        final name = (data['name'] as String?) ?? '';
        final colorHex = (data['colorHex'] as String?) ?? '#B5B5B5';
        final category = Category(
          id: id,
          name: name,
          colorHex: colorHex,
          updatedAtMillis: remoteUpdated,
          isDeleted: remoteDeleted,
          deletedAtMillis: remoteDeletedAt,
        );
        await localDb.categories.put(id, category);
      }
    }

    for (final c in localDb.categories.values) {
      final remoteData = remote[c.id];
      final remoteUpdated = (remoteData?['updatedAtMillis'] as num?)?.toInt() ?? 0;
      if (remoteData == null || c.updatedAtMillis > remoteUpdated) {
        await cloudDb.collection('categories').doc(c.id).set({
          'uid': uid,
          'name': c.name,
          'colorHex': c.colorHex,
          'updatedAtMillis': c.updatedAtMillis,
          'isDeleted': c.isDeleted,
          'deletedAtMillis': c.deletedAtMillis,
        });
      }
    }
  }

  Future<void> _syncActions(DatabaseService localDb, CloudBaseDatabase cloudDb, String uid) async {
    final remoteResp = await cloudDb.collection('actions').where({'uid': uid}).limit(1000).get();
    final remoteList = (remoteResp.data as List?) ?? const [];
    final remote = <String, Map<String, dynamic>>{};
    for (final item in remoteList) {
      final m = (item as Map).cast<String, dynamic>();
      final id = m['_id'] as String?;
      if (id == null) continue;
      remote[id] = m;
    }

    for (final entry in remote.entries) {
      final id = entry.key;
      final data = entry.value;
      final remoteUpdated = (data['updatedAtMillis'] as num?)?.toInt() ?? 0;
      final remoteDeleted = (data['isDeleted'] as bool?) ?? false;
      final remoteDeletedAt = (data['deletedAtMillis'] as num?)?.toInt() ?? 0;
      final local = localDb.actions.get(id);
      final localUpdated = local?.updatedAtMillis ?? 0;
      if (local == null || remoteUpdated > localUpdated) {
        final name = (data['name'] as String?) ?? '';
        final categoryId = (data['categoryId'] as String?) ?? '';
        final isPinned = (data['isPinned'] as bool?) ?? true;
        final sortOrder = (data['sortOrder'] as num?)?.toInt() ?? 0;
        final action = ActionItem(
          id: id,
          name: name,
          categoryId: categoryId,
          isPinned: isPinned,
          sortOrder: sortOrder,
          updatedAtMillis: remoteUpdated,
          isDeleted: remoteDeleted,
          deletedAtMillis: remoteDeletedAt,
        );
        await localDb.actions.put(id, action);
      }
    }

    for (final a in localDb.actions.values) {
      final remoteData = remote[a.id];
      final remoteUpdated = (remoteData?['updatedAtMillis'] as num?)?.toInt() ?? 0;
      if (remoteData == null || a.updatedAtMillis > remoteUpdated) {
        await cloudDb.collection('actions').doc(a.id).set({
          'uid': uid,
          'name': a.name,
          'categoryId': a.categoryId,
          'isPinned': a.isPinned,
          'sortOrder': a.sortOrder,
          'updatedAtMillis': a.updatedAtMillis,
          'isDeleted': a.isDeleted,
          'deletedAtMillis': a.deletedAtMillis,
        });
      }
    }
  }

  Future<void> _syncRecords(DatabaseService localDb, CloudBaseDatabase cloudDb, String uid) async {
    final remoteResp = await cloudDb.collection('records').where({'uid': uid}).limit(1000).get();
    final remoteList = (remoteResp.data as List?) ?? const [];
    final remote = <String, Map<String, dynamic>>{};
    for (final item in remoteList) {
      final m = (item as Map).cast<String, dynamic>();
      final id = m['_id'] as String?;
      if (id == null) continue;
      remote[id] = m;
    }

    for (final entry in remote.entries) {
      final id = entry.key;
      final data = entry.value;
      final remoteUpdated = (data['updatedAtMillis'] as num?)?.toInt() ?? 0;
      final remoteDeleted = (data['isDeleted'] as bool?) ?? false;
      final remoteDeletedAt = (data['deletedAtMillis'] as num?)?.toInt() ?? 0;
      final local = localDb.records.get(id);
      final localUpdated = local?.updatedAtMillis ?? 0;
      if (local == null || remoteUpdated > localUpdated) {
        final tsMillis = (data['timestampMillis'] as num?)?.toInt() ?? 0;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(tsMillis);
        final actionName = (data['actionName'] as String?) ?? '';
        final categoryName = (data['categoryName'] as String?) ?? '';
        final colorHex = (data['colorHex'] as String?) ?? '#B5B5B5';
        final note = data['note'] as String?;
        final record = Record(
          id: id,
          timestamp: timestamp,
          actionName: actionName,
          categoryName: categoryName,
          colorHex: colorHex,
          note: note,
          updatedAtMillis: remoteUpdated,
          isDeleted: remoteDeleted,
          deletedAtMillis: remoteDeletedAt,
        );
        await localDb.records.put(id, record);
      }
    }

    for (final r in localDb.records.values) {
      final remoteData = remote[r.id];
      final remoteUpdated = (remoteData?['updatedAtMillis'] as num?)?.toInt() ?? 0;
      if (remoteData == null || r.updatedAtMillis > remoteUpdated) {
        await cloudDb.collection('records').doc(r.id).set({
          'uid': uid,
          'timestampMillis': r.timestamp.millisecondsSinceEpoch,
          'actionName': r.actionName,
          'categoryName': r.categoryName,
          'colorHex': r.colorHex,
          'note': r.note,
          'updatedAtMillis': r.updatedAtMillis,
          'isDeleted': r.isDeleted,
          'deletedAtMillis': r.deletedAtMillis,
        });
      }
    }
  }
}
