import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../services/database_service.dart';
import '../services/file_service.dart';
import '../services/nutstore_sync_service.dart';

class NotesProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final FileService _fs = FileService();
  final NutstoreSyncService _sync = NutstoreSyncService();

  final Uuid _uuid = const Uuid();

  List<NoteModel> _notes = [];
  List<FolderModel> _folders = [];
  String? _currentFolderId;
  String _searchQuery = '';
  bool _loading = false;

  List<NoteModel> get notes => _notes;
  List<FolderModel> get folders => _folders;
  String? get currentFolderId => _currentFolderId;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;

  /// 加载笔记列表
  Future<void> loadNotes() async {
    _loading = true;
    notifyListeners();

    // 处理"未分类"特殊情况
    String? effectiveFolderId = _currentFolderId;
    bool uncategorizedOnly = false;
    if (_currentFolderId == '__uncategorized__') {
      effectiveFolderId = null;
      uncategorizedOnly = true;
    }

    _notes = await _db.getNotes(
      folderId: effectiveFolderId,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      uncategorizedOnly: uncategorizedOnly,
    );

    // 并行加载预览文本
    await _loadPreviews();

    _loading = false;
    notifyListeners();
  }

  /// 加载回收站笔记
  List<NoteModel> _trashNotes = [];
  List<NoteModel> get trashNotes => _trashNotes;

  Future<void> loadTrash() async {
    _trashNotes = await _db.getTrashNotes();
    notifyListeners();
  }

  /// 加载文件夹列表
  Future<void> loadFolders() async {
    _folders = await _db.getFolders();
    notifyListeners();
  }

  /// 设置当前文件夹筛选
  void setFolder(String? folderId) {
    _currentFolderId = folderId;
    loadNotes();
  }

  /// 搜索
  void search(String query) {
    _searchQuery = query;
    loadNotes();
  }

  /// 创建新笔记
  Future<NoteModel> createNote({String? folderId}) async {
    final note = NoteModel(
      id: _uuid.v4(),
      folderId: folderId ?? _currentFolderId,
    );
    await _db.insertNote(note);
    await _fs.writeContent(note.id, '');
    await loadNotes();
    return note;
  }

  /// 更新笔记元数据
  Future<void> updateNoteMeta(NoteModel note) async {
    await _db.updateNote(note);
    await loadNotes();
  }

  /// 保存笔记正文
  Future<void> saveContent(String noteId, String content) async {
    await _fs.writeContent(noteId, content);
    final allNotes = await _db.getNotes();
    final note = allNotes.firstWhere((n) => n.id == noteId, orElse: () => NoteModel(id: noteId));
    await _db.updateNote(note.copyWith());
    await loadNotes();
    _uploadToCloud(noteId, content);
  }

  /// 读取笔记正文
  Future<String> readContent(String noteId) async {
    return await _fs.readContent(noteId);
  }

  /// 软删除
  Future<void> deleteNote(String id) async {
    await _db.softDeleteNote(id);
    await loadNotes();
    _deleteFromCloud(id);
  }

  /// 恢复
  Future<void> restoreNote(String id) async {
    await _db.restoreNote(id);
    await loadNotes();
    await loadTrash();
    // 恢复时重新上传
    final notes = await _db.getNotes();
    final note = notes.where((n) => n.id == id);
    if (note.isNotEmpty) {
      final content = await _fs.readContent(id);
      _uploadToCloud(id, content);
    }
  }

  /// 永久删除
  Future<void> permanentlyDelete(String id) async {
    await _db.permanentlyDeleteNote(id);
    await _fs.deleteNoteFiles(id);
    await loadTrash();
    _deleteFromCloud(id);
  }

  /// 切换置顶
  Future<void> togglePin(NoteModel note) async {
    final updated = note.copyWith(isPinned: !note.isPinned);
    await _db.updateNote(updated);
    await loadNotes();
  }

  /// 切换收藏
  Future<void> toggleFavor(NoteModel note) async {
    final updated = note.copyWith(isFavored: !note.isFavored);
    await _db.updateNote(updated);
    await loadNotes();
  }

  /// 切换锁定
  Future<void> toggleLock(NoteModel note) async {
    final updated = note.copyWith(isLocked: !note.isLocked);
    await _db.updateNote(updated);
    await loadNotes();
  }

  /// 移动笔记到指定文件夹
  Future<void> moveNote(NoteModel note, String? folderId) async {
    note.folderId = folderId;
    note.updatedAt = DateTime.now();
    await _db.updateNote(note);
    await loadNotes();
  }

  // ───────────── 文件夹操作 ─────────────

  Future<void> createFolder(String name, {int color = 0}) async {
    final folder = FolderModel(
      id: _uuid.v4(),
      name: name,
      color: color,
    );
    await _db.insertFolder(folder);
    await loadFolders();
  }

  Future<void> renameFolder(String id, String newName) async {
    final folder = _folders.firstWhere((f) => f.id == id);
    folder.name = newName;
    await _db.updateFolder(folder);
    await loadFolders();
  }

  Future<void> deleteFolder(String id) async {
    await _db.deleteFolder(id);
    await loadFolders();
    await loadNotes();
  }

  // ───────────── 内部 ─────────────

  Future<void> _loadPreviews() async {
    for (final note in _notes) {
      try {
        final content = await _fs.readContent(note.id);
        if (content.isEmpty) {
          note.previewText = '';
          continue;
        }
        // 尝试解析 Delta JSON，提取纯文本
        try {
          final json = jsonDecode(content);
          List<dynamic> delta;
          if (json is Map && json.containsKey('delta')) {
            delta = json['delta'] as List<dynamic>;
          } else if (json is List) {
            delta = json;
          } else {
            note.previewText = '';
            continue;
          }
          final buffer = StringBuffer();
          for (final op in delta) {
            if (op is Map && op.containsKey('insert')) {
              final insert = op['insert'];
              if (insert is String) {
                buffer.write(insert);
              } else if (insert is Map && insert.containsKey('image')) {
                buffer.write('[图片]');
              } else if (insert is Map && insert.containsKey('video')) {
                buffer.write('[视频]');
              }
            }
          }
          final plain = buffer.toString().replaceAll('\n', ' ').trim();
          note.previewText = plain.length > 100
              ? '${plain.substring(0, 100)}...'
              : plain;
        } catch (_) {
          // 不是 JSON，当作纯文本处理
          final plain = content
              .replaceAll(RegExp(r'[#*>`~\[\]()!]'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          note.previewText = plain.length > 100
              ? '${plain.substring(0, 100)}...'
              : plain;
        }
      } catch (_) {
        note.previewText = '';
      }
    }
  }

  // ============ 云同步辅助 ============

  /// 上传笔记 JSON 到云端（异步，不阻塞本地操作）
  void _uploadToCloud(String noteId, String content) {
    _sync.loadConfig().then((_) {
      if (!_sync.isConfigured) return;
      _sync.uploadNote(
        noteId: noteId,
        jsonContent: content,
        modifiedAt: DateTime.now(),
      );
    });
  }

  /// 从云端删除笔记（异步）
  void _deleteFromCloud(String noteId) {
    _sync.loadConfig().then((_) {
      if (!_sync.isConfigured) return;
      _sync.deleteRemoteNote(noteId);
    });
  }

  /// 将本地所有笔记同步到云端（供"立即同步"按钮调用）
  /// 返回成功上传的笔记数量
  Future<int> syncAllToCloud() async {
    await _sync.loadConfig();
    if (!_sync.isConfigured) return 0;

    int count = 0;
    for (final note in _notes) {
      try {
        final content = await _fs.readContent(note.id);
        final success = await _sync.uploadNote(
          noteId: note.id,
          jsonContent: content,
          modifiedAt: note.updatedAt,
        );
        if (success) count++;
      } catch (_) {
        // 单条失败不中断整体同步
      }
    }
    return count;
  }
}

