import 'package:sqflite/sqflite.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';

/// 单例数据库服务 — 只存元数据，正文和媒体走文件系统
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // path_provider 在 Android 上要用 getApplicationDocumentsDirectory
    // 但那个目录夸克访问不了，数据库文件我们后面通过 FileService 放在公共目录
    // 这里先用一个占位，实际路径由 FileService 传入
    throw UnimplementedError('Use init(dbPath) instead');
  }

  /// 用指定路径初始化数据库（由 FileService 提供外部存储路径）
  Future<void> init(String dbPath) async {
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        folder_id TEXT,
        tags TEXT NOT NULL DEFAULT '[]',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_favored INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0,
        password_hash TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        has_video INTEGER NOT NULL DEFAULT 0,
        has_image INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 索引：加速列表查询
    await db.execute(
        'CREATE INDEX idx_notes_deleted ON notes(deleted_at)');
    await db.execute(
        'CREATE INDEX idx_notes_folder ON notes(folder_id)');
    await db.execute(
        'CREATE INDEX idx_notes_updated ON notes(updated_at DESC)');
    await db.execute(
        'CREATE INDEX idx_notes_pinned ON notes(is_pinned)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE folders ADD COLUMN color INTEGER NOT NULL DEFAULT 0');
    }
  }

  // ───────────── 笔记 CRUD ─────────────

  /// 获取非回收站笔记列表，置顶优先，按更新时间倒序
  Future<List<NoteModel>> getNotes({
    String? folderId,
    String? searchQuery,
    bool uncategorizedOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = StringBuffer('deleted_at IS NULL');
    final args = <dynamic>[];

    if (uncategorizedOnly) {
      where.write(' AND folder_id IS NULL');
    } else if (folderId != null) {
      where.write(' AND folder_id = ?');
      args.add(folderId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.write(' AND title LIKE ?');
      args.add('%$searchQuery%');
    }

    final rows = await db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'is_pinned DESC, updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => NoteModel.fromMap(r)).toList();
  }

  /// 获取回收站笔记（30天内删除的）
  Future<List<NoteModel>> getTrashNotes() async {
    final db = await database;
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final rows = await db.query(
      'notes',
      where: 'deleted_at IS NOT NULL AND deleted_at > ?',
      whereArgs: [thirtyDaysAgo],
      orderBy: 'deleted_at DESC',
    );
    return rows.map((r) => NoteModel.fromMap(r)).toList();
  }

  Future<void> insertNote(NoteModel note) async {
    final db = await database;
    await db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateNote(NoteModel note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  /// 软删除（移入回收站）
  Future<void> softDeleteNote(String id) async {
    final db = await database;
    await db.update(
      'notes',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 从回收站恢复
  Future<void> restoreNote(String id) async {
    final db = await database;
    await db.update(
      'notes',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 永久删除
  Future<void> permanentlyDeleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// 清理过期回收站（超过30天）
  Future<int> cleanExpiredTrash() async {
    final db = await database;
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    return await db.delete(
      'notes',
      where: 'deleted_at IS NOT NULL AND deleted_at <= ?',
      whereArgs: [thirtyDaysAgo],
    );
  }

  // ───────────── 文件夹 CRUD ─────────────

  Future<List<FolderModel>> getFolders({String? parentId}) async {
    final db = await database;
    final rows = await db.query(
      'folders',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map((r) => FolderModel.fromMap(r)).toList();
  }

  Future<void> insertFolder(FolderModel folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFolder(FolderModel folder) async {
    final db = await database;
    await db.update('folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> deleteFolder(String id) async {
    final db = await database;
    // 把该文件夹下的笔记移到根目录
    await db.update('notes', {'folder_id': null},
        where: 'folder_id = ?', whereArgs: [id]);
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // ───────────── 工具 ─────────────

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
