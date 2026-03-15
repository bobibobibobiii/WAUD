import 'dart:async';

class CloudAuthService {
  static final CloudAuthService _instance = CloudAuthService._internal();
  factory CloudAuthService() => _instance;
  CloudAuthService._internal();

  bool _initialized = false;
  final StreamController<String?> _userIdStream = StreamController<String?>.broadcast();

  bool get isAvailable => false;
  String? get initError => '网页版不提供云端登录与多端同步（避免在浏览器侧暴露密钥）。';
  String? get currentUserId => null;
  Stream<String?> get authStateChanges => _userIdStream.stream;
  Object? get core => null;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _userIdStream.add(null);
  }

  Future<void> signOut() async {
    _userIdStream.add(null);
  }

  Future<void> signInByWeChat() async {
    throw StateError(initError ?? '不可用');
  }

  Future<void> signInWithTicket(String ticket) async {
    throw StateError(initError ?? '不可用');
  }

  Future<void> requestSmsCode(String phone) async {
    throw StateError(initError ?? '不可用');
  }

  Future<bool> signInWithSmsCode(String phone, String code) async {
    throw StateError(initError ?? '不可用');
  }

  String errorMessage(Object error) {
    if (error is StateError) return error.message;
    final msg = error.toString();
    if (msg.isEmpty || msg.startsWith('Instance of')) return '操作失败，请稍后再试。';
    return '操作失败：$msg';
  }
}
