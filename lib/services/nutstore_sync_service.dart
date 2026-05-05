import 'dart:convert';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 坚果云 WebDAV 云同步服务
///
/// 使用前需要：
/// 1. 注册坚果云账号
/// 2. 在「账户信息 - 安全选项」中生成第三方应用密码
/// 3. 在随记设置中填入邮箱和应用密码
class NutstoreSyncService {
  static const _keyUrl = 'nutstore_url';
  static const _keyUser = 'nutstore_user';
  static const _keyPassword = 'nutstore_password';
  static const _keyEnabled = 'nutstore_enabled';
  static const _keyLastSync = 'nutstore_last_sync';

  static const _remoteBase = '随记';
  static const _remoteNotes = '随记/notes';

  Client? _client;

  String _url = '';
  String _user = '';
  String _password = '';
  bool _enabled = false;

  bool get isConfigured => _enabled && _url.isNotEmpty && _user.isNotEmpty && _password.isNotEmpty;

  /// 公开只读访问器（供设置页面读取已保存的值）
  String get savedUrl => _url;
  String get savedUser => _user;

  /// 加载已保存的配置
  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _url = prefs.getString(_keyUrl) ?? '';
    _user = prefs.getString(_keyUser) ?? '';
    _password = prefs.getString(_keyPassword) ?? '';
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    if (isConfigured) {
      _client = _createClient();
    }
  }

  /// 保存并测试连接
  Future<String?> configure({
    required String url,
    required String user,
    required String password,
  }) async {
    _url = url.trim();
    _user = user.trim();
    _password = password.trim();

    // 确保 URL 以 / 结尾
    if (!_url.endsWith('/')) {
      _url += '/';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, _url);
    await prefs.setString(_keyUser, _user);
    await prefs.setString(_keyPassword, _password);

    _client = _createClient();

    try {
      // 测试连接：尝试创建根目录
      await _ensureRemoteDir(_remoteBase);
      await _ensureRemoteDir(_remoteNotes);
      _enabled = true;
      await prefs.setBool(_keyEnabled, true);
      return null; // 成功，无错误
    } catch (e) {
      _enabled = false;
      await prefs.setBool(_keyEnabled, false);
      return _parseError(e);
    }
  }

  /// 禁用同步
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = false;
    await prefs.setBool(_keyEnabled, false);
    _client = null;
  }

  /// 上传笔记到云端
  Future<bool> uploadNote({
    required String noteId,
    required String jsonContent,
    required DateTime modifiedAt,
  }) async {
    if (!isConfigured || _client == null) return false;
    try {
      await _ensureRemoteDir(_remoteNotes);
      final path = '$_remoteNotes/$noteId.json';
      await _client!.write(path, Uint8List.fromList(utf8.encode(jsonContent)));
      return true;
    } catch (e) {
      print('Nutstore upload failed: $e');
      return false;
    }
  }

  /// 下载单个笔记
  Future<String?> downloadNote(String noteId) async {
    if (!isConfigured || _client == null) return null;
    try {
      final path = '$_remoteNotes/$noteId.json';
      final bytes = await _client!.read(path);
      return utf8.decode(bytes);
    } catch (e) {
      return null; // 文件不存在或网络错误
    }
  }

  /// 列出云端所有笔记 ID
  Future<List<String>> listRemoteNoteIds() async {
    if (!isConfigured || _client == null) return [];
    try {
      await _ensureRemoteDir(_remoteNotes);
      final items = await _client!.readDir(_remoteNotes);
      return items
          .where((item) => (item.name ?? '').endsWith('.json'))
          .map((item) => (item.name ?? '').replaceAll('.json', ''))
          .toList();
    } catch (e) {
      print('Nutstore list failed: $e');
      return [];
    }
  }

  /// 删除云端笔记
  Future<bool> deleteRemoteNote(String noteId) async {
    if (!isConfigured || _client == null) return false;
    try {
      final path = '$_remoteNotes/$noteId.json';
      await _client!.remove(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 上传媒体文件
  Future<bool> uploadMedia({
    required String noteId,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!isConfigured || _client == null) return false;
    try {
      final dir = '$_remoteNotes/$noteId.media';
      await _ensureRemoteDir(dir);
      await _client!.write('$dir/$fileName', Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      print('Nutstore media upload failed: $e');
      return false;
    }
  }

  /// 获取最后同步时间
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_keyLastSync);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  /// 更新最后同步时间
  Future<void> _updateLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSync, DateTime.now().millisecondsSinceEpoch);
  }

  // ============== 内部方法 ==============

  Client _createClient() {
    return newClient(
      _url,
      user: _user,
      password: _password,
    );
  }

  Future<void> _ensureRemoteDir(String path) async {
    try {
      await _client!.mkdirAll(path);
    } catch (e) {
      // 目录可能已存在，忽略
    }
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return '认证失败，请检查邮箱和应用密码';
    }
    if (msg.contains('404')) {
      return '连接失败，请检查 WebDAV 地址';
    }
    if (msg.contains('timeout') || msg.contains('SocketException')) {
      return '网络连接超时，请检查网络';
    }
    return '连接失败：$msg';
  }
}
