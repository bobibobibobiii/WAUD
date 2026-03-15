import 'package:flutter/cupertino.dart';
import '../services/services.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final CloudAuthService _auth = CloudAuthService();
  final CloudSyncService _sync = CloudSyncService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  bool _loading = false;
  bool _syncing = false;
  bool _smsSending = false;
  bool _smsLogging = false;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _auth.init();
    if (!mounted) return;
    setState(() {
      _ready = true;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final card = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final subTextColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bg.withValues(alpha: 0.8),
        border: null,
        middle: const Text('账户与同步'),
      ),
      child: SafeArea(
        child: !_ready
            ? const Center(child: CupertinoActivityIndicator())
            : StreamBuilder(
          stream: _auth.authStateChanges,
          initialData: _auth.currentUserId,
          builder: (context, snapshot) {
            final userId = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('状态', style: TextStyle(color: subTextColor, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        userId == null ? '游客模式（仅本机存储）' : '已登录（可多端同步）',
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      if (!_auth.isAvailable) ...[
                        const SizedBox(height: 10),
                        Text(
                          _auth.initError ?? '国内云未就绪：CloudBase 未初始化成功。',
                          style: TextStyle(color: subTextColor, fontSize: 13),
                        ),
                      ],
                      if (userId != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '用户ID: $userId',
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13)),
                  ),
                if (userId == null) _buildLoginCard(card, textColor, subTextColor) else _buildSyncCard(card, textColor, subTextColor),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginCard(Color card, Color textColor, Color subTextColor) {
    final enabled = _auth.isAvailable && !_loading && !_smsSending && !_smsLogging;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('登录后同步', style: TextStyle(color: subTextColor, fontSize: 13)),
          const SizedBox(height: 12),
          Text(
            '面向国内用户，建议使用微信登录作为跨设备身份。',
            style: TextStyle(color: subTextColor, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: enabled ? _signInWithWeChat : null,
              child: _loading ? const CupertinoActivityIndicator() : const Text('微信登录'),
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: CupertinoColors.separator.resolveFrom(context)),
          const SizedBox(height: 18),
          Text('短信验证码登录', style: TextStyle(color: subTextColor, fontSize: 13)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            placeholder: '手机号（支持 +86）',
            clearButtonMode: OverlayVisibilityMode.editing,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _smsCodeController,
                  keyboardType: TextInputType.number,
                  placeholder: '验证码',
                  clearButtonMode: OverlayVisibilityMode.editing,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(width: 10),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onPressed: (!_auth.isAvailable || _smsSending || _smsLogging || _loading) ? null : _sendSmsCode,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                child: _smsSending ? const CupertinoActivityIndicator() : const Text('获取验证码'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: (!_auth.isAvailable || _smsLogging || _smsSending || _loading) ? null : _signInWithSms,
              child: _smsLogging ? const CupertinoActivityIndicator() : const Text('短信登录并同步'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard(Color card, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('同步', style: TextStyle(color: subTextColor, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: _syncing ? null : _syncNow,
              child: _syncing ? const CupertinoActivityIndicator() : const Text('立即同步'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              onPressed: _loading ? null : _signOut,
              child: const Text('退出登录', style: TextStyle(color: CupertinoColors.destructiveRed)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithWeChat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_auth.isAvailable) {
        setState(() => _error = _auth.initError ?? '国内云未就绪：CloudBase 未初始化成功。');
        return;
      }
      await _auth.signInByWeChat().timeout(const Duration(seconds: 25));
      await _sync.syncNow().timeout(const Duration(seconds: 25));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _auth.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizePhone(String input) {
    final raw = input.trim();
    if (raw.startsWith('+86') && !raw.startsWith('+86 ')) {
      final fixed = raw.replaceFirst('+86', '+86 ');
      if (fixed.startsWith('+86 ')) return fixed;
    }
    if (raw.startsWith('+')) return raw;
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    if (digits.length == 11 && RegExp(r'^\d{11}$').hasMatch(digits)) return '+86 $digits';
    return raw;
  }

  Future<void> _sendSmsCode() async {
    setState(() {
      _smsSending = true;
      _error = null;
    });
    try {
      if (!_auth.isAvailable) {
        setState(() => _error = _auth.initError ?? '国内云未就绪：CloudBase 未初始化成功。');
        return;
      }
      final phone = _normalizePhone(_phoneController.text);
      if (phone.isEmpty) {
        setState(() => _error = '请输入手机号。');
        return;
      }
      await _auth.requestSmsCode(phone).timeout(const Duration(seconds: 25));
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: const Text('验证码已发送'),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _auth.errorMessage(e));
    } finally {
      if (mounted) setState(() => _smsSending = false);
    }
  }

  Future<void> _signInWithSms() async {
    setState(() {
      _smsLogging = true;
      _error = null;
    });
    try {
      if (!_auth.isAvailable) {
        setState(() => _error = _auth.initError ?? '国内云未就绪：CloudBase 未初始化成功。');
        return;
      }
      final phone = _normalizePhone(_phoneController.text);
      final code = _smsCodeController.text.trim();
      if (phone.isEmpty || code.isEmpty) {
        setState(() => _error = '请输入手机号与验证码。');
        return;
      }
      final didSignUp = await _auth.signInWithSmsCode(phone, code).timeout(const Duration(seconds: 25));
      await _sync.syncNow().timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() => _smsCodeController.clear());
      if (didSignUp && mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            content: const Text('检测到首次登录，已为你自动注册账号。'),
            actions: [
              CupertinoDialogAction(
                child: const Text('确定'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _auth.errorMessage(e));
    } finally {
      if (mounted) setState(() => _smsLogging = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      await _sync.syncNow().timeout(const Duration(seconds: 25));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _auth.errorMessage(e));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _auth.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

