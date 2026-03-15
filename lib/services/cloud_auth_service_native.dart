import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloudbase_ce/cloudbase_ce.dart';
import 'package:flutter/foundation.dart';

class _GatewayError implements Exception {
  final String code;
  final String message;
  _GatewayError(this.code, this.message);
}

class CloudAuthService {
  static final CloudAuthService _instance = CloudAuthService._internal();
  factory CloudAuthService() => _instance;
  CloudAuthService._internal();

  bool _initialized = false;
  bool _available = false;
  String? _initError;
  CloudBaseCore? _core;
  CloudBaseAuth? _auth;
  CloudBaseUserInfo? _userInfo;
  String? _gatewayUserId;
  final StreamController<String?> _userIdStream = StreamController<String?>.broadcast();
  String _envId = '';
  String? _lastVerificationId;
  bool? _lastIsUser;

  bool get isAvailable => _available;
  String? get initError => _initError;
  String? get currentUserId => _gatewayUserId ?? _userInfo?.uuid;
  Stream<String?> get authStateChanges => _userIdStream.stream;
  CloudBaseCore? get core => _core;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final env = const String.fromEnvironment('CLOUDBASE_ENV');
    final key = _pickAccessKey();
    final version = _pickAccessVersion();
    _envId = env;
    if (env.isEmpty || key.isEmpty || version.isEmpty) {
      _available = false;
      _initError = '国内云未配置：请设置 CLOUDBASE_ENV / CLOUDBASE_KEY / CLOUDBASE_VERSION（可用 --dart-define 传入）。';
      _userIdStream.add(null);
      return;
    }
    _core = CloudBaseCore.init({
      'env': env,
      'appAccess': {
        'key': key,
        'version': version,
      },
      'timeout': 8000,
    });
    _auth = CloudBaseAuth(_core!);
    _available = true;
    _initError = null;

    try {
      final store = await CloudBaseStore().init();
      final savedUserId = await store.get('${_envId}_waud_gateway_user_id');
      if (savedUserId is String && savedUserId.isNotEmpty) {
        _gatewayUserId = savedUserId;
        _userIdStream.add(_gatewayUserId);
        return;
      }

      final state = await _auth!.getAuthState();
      if (state == null) {
        _userInfo = null;
        _gatewayUserId = null;
        _userIdStream.add(null);
        return;
      }
      _userInfo = await _auth!.getUserInfo();
      _gatewayUserId = null;
      _userIdStream.add(_userInfo?.uuid);
    } catch (e) {
      _userInfo = null;
      _gatewayUserId = null;
      _userIdStream.add(null);
      _initError = errorMessage(e);
    }
  }

  Future<void> signOut() async {
    final core = _core;
    final auth = _auth;
    if (_gatewayUserId != null) {
      final store = await CloudBaseStore().init();
      await store.remove('${_envId}_waud_gateway_user_id');
      _gatewayUserId = null;
      _userIdStream.add(null);
      return;
    }
    if (core == null || auth == null) throw StateError(_initError ?? '国内云未就绪：请先完成 CloudBase 初始化。');
    await auth.signOut();
    _userInfo = null;
    _userIdStream.add(null);
  }

  Future<void> signInByWeChat() async {
    final auth = _requireAuth();
    final wxAppId = const String.fromEnvironment('WECHAT_APP_ID');
    final wxUniLink = const String.fromEnvironment('WECHAT_UNI_LINK');
    if (wxAppId.isEmpty || wxUniLink.isEmpty) {
      throw StateError('微信登录未配置：请设置 WECHAT_APP_ID 与 WECHAT_UNI_LINK（可用 --dart-define 传入）。');
    }
    await auth.signInByWx(wxAppId: wxAppId, wxUniLink: wxUniLink);
    _userInfo = await auth.getUserInfo();
    _userIdStream.add(_userInfo?.uuid);
  }

  Future<void> signInWithTicket(String ticket) async {
    final auth = _requireAuth();
    if (ticket.trim().isEmpty) throw StateError('登录凭据无效。');
    await auth.signInWithTicket(ticket.trim());
    _userInfo = await auth.getUserInfo();
    _userIdStream.add(_userInfo?.uuid);
  }

  Future<void> requestSmsCode(String phone) async {
    _requireAuth();
    final normalized = phone.trim();
    if (normalized.isEmpty) throw StateError('请输入手机号。');

    final resp = await _postGatewayJson(
      '/auth/v1/verification',
      {
        'phone_number': normalized,
        'target': 'ANY',
      },
    );
    final verificationId = resp['verification_id'] as String?;
    if (verificationId == null || verificationId.isEmpty) {
      throw StateError('发送验证码失败：缺少 verification_id。');
    }
    _lastVerificationId = verificationId;
    _lastIsUser = resp['is_user'] as bool?;
  }

  Future<bool> signInWithSmsCode(String phone, String code) async {
    _requireAuth();
    final normalizedPhone = phone.trim();
    final normalizedCode = code.trim();
    if (normalizedPhone.isEmpty || normalizedCode.isEmpty) throw StateError('请输入手机号与验证码。');
    final verificationId = _lastVerificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw StateError('请先获取验证码。');
    }

    final verifyResp = await _postGatewayJson(
      '/auth/v1/verification/verify',
      {
        'verification_id': verificationId,
        'verification_code': normalizedCode,
      },
    );
    final token = verifyResp['verification_token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('验证码校验失败：缺少 verification_token。');
    }

    Map<String, dynamic> tokenResp;
    var didSignUp = false;
    try {
      tokenResp = await _postGatewayJson(
        '/auth/v1/signin',
        {
          'verification_token': token,
        },
      );
    } on _GatewayError catch (e) {
      if (_shouldAutoSignUp(e, _lastIsUser)) {
        didSignUp = true;
        tokenResp = await _postGatewayJson(
          '/auth/v1/signup',
          {
            'phone_number': normalizedPhone,
            'verification_token': token,
          },
        );
      } else {
        rethrow;
      }
    }

    final userId = tokenResp['sub'] as String?;
    if (userId == null || userId.isEmpty) {
      throw StateError('登录失败：服务未返回用户ID（sub）。');
    }
    final store = await CloudBaseStore().init();
    await store.set('${_envId}_waud_gateway_user_id', userId);
    _gatewayUserId = userId;
    _userIdStream.add(_gatewayUserId);
    return didSignUp;
  }

  CloudBaseAuth _requireAuth() {
    final auth = _auth;
    if (!_available || auth == null || _core == null) {
      throw StateError(_initError ?? '国内云未就绪：请先完成 CloudBase 初始化。');
    }
    return auth;
  }

  String _gatewayBaseUrl() {
    final env = _envId;
    if (env.isEmpty) throw StateError('国内云未配置：缺少环境ID。');
    return 'https://$env.api.tcloudbasegateway.com';
  }

  Map<String, String> _buildGatewayHeaders() {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    final clientId = const String.fromEnvironment('CLOUDBASE_CLIENT_ID').trim();
    final clientSecret = const String.fromEnvironment('CLOUDBASE_CLIENT_SECRET').trim();
    if (clientId.isNotEmpty && clientSecret.isNotEmpty) {
      final token = base64.encode(utf8.encode('$clientId:$clientSecret'));
      headers[HttpHeaders.authorizationHeader] = 'Basic $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _postGatewayJson(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${_gatewayBaseUrl()}$path');
    final headers = _buildGatewayHeaders();

    final clientId = const String.fromEnvironment('CLOUDBASE_CLIENT_ID').trim();
    if (clientId.isNotEmpty) {
      body['client_id'] = clientId;
    } else if (_envId.isNotEmpty) {
      body['client_id'] = _envId;
    }

    final client = HttpClient();
    try {
      final req = await client.postUrl(url);
      headers.forEach(req.headers.set);
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 10));
      final raw = await res.transform(utf8.decoder).join();
      final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      if (decoded is! Map) throw StateError('服务返回异常。');
      final map = decoded.cast<String, dynamic>();

      final hasDataKeys = map.containsKey('access_token') || map.containsKey('verification_id') || map.containsKey('verification_token');
      final hasGatewayCode = map['code'] is String;
      if (res.statusCode >= 400 || map.containsKey('error') || (hasGatewayCode && !hasDataKeys)) {
        final code = (map['error'] as String?) ?? (map['code'] as String?) ?? 'UNKNOWN_ERROR';
        throw _GatewayError(code, _formatGatewayError(map));
      }
      return map;
    } on TimeoutException {
      throw StateError('请求超时，请检查网络后重试。');
    } on SocketException {
      throw StateError('网络连接失败，请检查网络或稍后重试。');
    } on HandshakeException {
      throw StateError('网络握手失败，可能被网络环境拦截或证书异常，请切换网络后重试。');
    } on HttpException {
      throw StateError('网络请求异常，请稍后重试。');
    } on FormatException {
      throw StateError('服务返回异常，请稍后重试。');
    } finally {
      client.close(force: true);
    }
  }

  bool _shouldAutoSignUp(_GatewayError error, bool? lastIsUser) {
    if (lastIsUser == false) return true;
    final code = error.code.toLowerCase();
    final msg = error.message.toLowerCase();
    if (code.contains('user_not_found') || code.contains('user_not_exist') || code.contains('user_not_exists')) return true;
    if (msg.contains('user not exist') || msg.contains('not exist') || msg.contains('未注册')) return true;
    return false;
  }

  String _formatGatewayError(Map<String, dynamic> map) {
    final description = map['error_description'] as String?;
    final error = map['error'] as String?;
    final message = map['message'] as String?;
    final code = map['code'] as String?;
    if (description != null && description.isNotEmpty) return description;
    if (message == 'User not exist.') return '该手机号未注册，已为你自动创建账号后重试。';
    if (code == 'INVALID_ENV') return '环境ID无效，请检查 CLOUDBASE_ENV 是否正确。';
    if (code == 'captcha_required') return '需要先完成图形验证码验证。';
    if (error == 'captcha_required') return '需要先完成图形验证码验证。';
    if (error == 'rate_limit_exceeded') return '发送过于频繁，请稍后再试。';
    if (error == 'invalid_phone_number') return '手机号格式不正确，请使用 +86 前缀。';
    if (error == 'invalid_verification_code') return '验证码错误，请重新输入。';
    if (error == 'user_not_found') return '该手机号未注册。';
    if (message != null && message.isNotEmpty) return message;
    if (code != null && code.isNotEmpty) return '请求失败（$code）。';
    if (error != null && error.isNotEmpty) return '请求失败（$error）。';
    return '请求失败，请稍后再试。';
  }

  String _pickAccessKey() {
    final generic = const String.fromEnvironment('CLOUDBASE_KEY');
    if (generic.isNotEmpty) return generic;
    if (kIsWeb) return '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment('CLOUDBASE_KEY_ANDROID');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const String.fromEnvironment('CLOUDBASE_KEY_IOS');
    }
    return '';
  }

  String _pickAccessVersion() {
    final generic = const String.fromEnvironment('CLOUDBASE_VERSION');
    if (generic.isNotEmpty) return generic;
    if (kIsWeb) return '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment('CLOUDBASE_VERSION_ANDROID');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const String.fromEnvironment('CLOUDBASE_VERSION_IOS');
    }
    return '';
  }

  String errorMessage(Object error) {
    if (error is StateError) return error.message;
    if (error is TimeoutException) return '请求超时，请检查网络后重试。';
    if (error is _GatewayError) return error.message;
    if (error is SocketException) return '网络连接失败，请检查网络或稍后重试。';
    if (error is HandshakeException) return '网络握手失败，可能被网络环境拦截或证书异常，请切换网络后重试。';
    if (error is HttpException) return '网络请求异常，请稍后重试。';
    if (error is FormatException) return '服务返回异常，请稍后重试。';
    if (error is CloudBaseException) {
      final code = error.code ?? '';
      final message = error.message ?? '';
      if (message.isNotEmpty) return message;
      if (code.isNotEmpty) return '云服务错误（$code）。';
      return '云服务错误。';
    }
    final msg = error.toString();
    if (msg.isEmpty || msg.startsWith('Instance of')) return '操作失败，请稍后再试。';
    return '操作失败：$msg';
  }
}
