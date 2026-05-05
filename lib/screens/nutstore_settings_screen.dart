import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/nutstore_sync_service.dart';
import '../providers/notes_provider.dart';

/// 坚果云 WebDAV 同步设置页面
class NutstoreSettingsScreen extends StatefulWidget {
  const NutstoreSettingsScreen({super.key});

  @override
  State<NutstoreSettingsScreen> createState() => _NutstoreSettingsScreenState();
}

class _NutstoreSettingsScreenState extends State<NutstoreSettingsScreen> {
  final _syncService = NutstoreSyncService();
  final _urlController = TextEditingController(text: 'https://dav.jianguoyun.com/dav/');
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _configured = false;
  bool _testing = false;
  bool _syncing = false;
  String? _error;
  String? _status;
  String? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _syncService.loadConfig();
    setState(() {
      _configured = _syncService.isConfigured;
      _urlController.text = _syncService.savedUrl;
      _userController.text = _syncService.savedUser;
    });
    final lastSync = await _syncService.getLastSyncTime();
    if (lastSync != null) {
      setState(() {
        _lastSync = '${lastSync.month}/${lastSync.day} '
            '${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    setState(() {
      _testing = true;
      _error = null;
      _status = null;
    });

    final url = _urlController.text.trim();
    final user = _userController.text.trim();
    final password = _passwordController.text;

    if (url.isEmpty || user.isEmpty || password.isEmpty) {
      setState(() {
        _error = '请填写完整信息';
        _testing = false;
      });
      return;
    }

    final error = await _syncService.configure(
      url: url,
      user: user,
      password: password,
    );

    setState(() {
      _testing = false;
      if (error == null) {
        _configured = true;
        _status = '连接成功！同步已启用';
      } else {
        _error = error;
      }
    });
  }

  Future<void> _disable() async {
    await _syncService.disable();
    setState(() {
      _configured = false;
      _error = null;
      _status = null;
    });
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _error = null;
      _status = null;
    });

    try {
      final provider = context.read<NotesProvider>();
      final uploadedCount = await provider.syncAllToCloud();
      setState(() {
        _syncing = false;
        _status = '同步完成，已上传 $uploadedCount 条笔记';
        _lastSync = '刚刚';
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _error = '同步失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('云同步'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 状态卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _configured
                  ? Colors.green.shade50
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _configured ? Colors.green.shade200 : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _configured ? Icons.cloud_done : Icons.cloud_off,
                  color: _configured ? Colors.green : colorScheme.outline,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _configured ? '坚果云已连接' : '未配置',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_lastSync != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '上次同步：$_lastSync',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '需要使用坚果云的第三方应用密码，'
                    '不是登录密码。请在坚果云网页「安全选项」中生成。',
                    style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // WebDAV 地址
          Text('WebDAV 地址', style: textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://dav.jianguoyun.com/dav/',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              isDense: true,
            ),
          ),

          const SizedBox(height: 16),

          // 账号
          Text('坚果云账号（邮箱）', style: textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _userController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'your@email.com',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              isDense: true,
            ),
          ),

          const SizedBox(height: 16),

          // 应用密码
          Text('第三方应用密码', style: textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '在坚果云网页生成的应用密码',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              isDense: true,
            ),
          ),

          const SizedBox(height: 24),

          // 按钮
          if (_configured) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _syncing ? null : _syncNow,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(_syncing ? '同步中...' : '立即同步'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _disable,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('断开连接'),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _testing ? null : _testAndSave,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link, size: 18),
                label: Text(_testing ? '正在验证...' : '验证并启用同步'),
              ),
            ),
          ],

          // 状态信息
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_status != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status!,
                      style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
