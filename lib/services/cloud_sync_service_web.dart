class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  Future<void> syncNow() async {
    throw StateError('网页版不提供云端同步。');
  }
}
