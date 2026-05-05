import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 文件系统服务 — 管理笔记正文、媒体文件、应用数据目录
///
/// 默认目录（无需权限，立即可用）：
///   Android: /storage/emulated/0/Android/data/com.lch.my_notes/files/MyNotes/
///
/// 可选迁移到公共目录（需 MANAGE_EXTERNAL_STORAGE 权限，夸克可备份）：
///   Android: /storage/emulated/0/MyNotes/
///
/// 目录结构：
///   notes.db          ← SQLite 数据库
///   contents/         ← 笔记正文 Markdown
///   media/            ← 图片和视频
///   thumbnails/       ← 视频缩略图
class FileService {
  static final FileService _instance = FileService._();
  factory FileService() => _instance;
  FileService._();

  final Uuid _uuid = const Uuid();
  String? _basePath;
  bool _usePublicStorage = false;

  /// 是否使用公共存储（夸克可备份）
  bool get usePublicStorage => _usePublicStorage;

  /// 获取存储根目录路径
  Future<String> get basePath async {
    if (_basePath != null) return _basePath!;

    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      // 极端情况降级到应用内部存储
      _basePath = p.join(
        (await getApplicationDocumentsDirectory()).path,
        'MyNotes',
      );
    } else {
      _basePath = p.join(dir.path, 'MyNotes');
    }

    await _ensureDirs();
    return _basePath!;
  }

  Future<void> _ensureDirs() async {
    await Directory(_basePath!).create(recursive: true);
    await Directory(contentsPath).create(recursive: true);
    await Directory(mediaPath).create(recursive: true);
    await Directory(thumbnailsPath).create(recursive: true);
  }

  /// 尝试迁移到公共目录（夸克可备份）
  /// 返回 true 表示迁移成功，false 表示权限不足
  Future<bool> migrateToPublicStorage() async {
    if (!Platform.isAndroid) return false;

    // 尝试在公共目录创建文件夹
    const publicBase = '/storage/emulated/0/MyNotes';
    try {
      final publicDir = Directory(publicBase);
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }

      // 迁移现有数据
      if (_basePath != null && _basePath != publicBase) {
        await _copyDirectory(Directory(_basePath!), publicDir);
      }

      _basePath = publicBase;
      _usePublicStorage = true;
      await _ensureDirs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyDirectory(Directory source, Directory dest) async {
    if (!await source.exists()) return;
    await for (final entity in source.list(recursive: true)) {
      final relativePath = entity.path.substring(source.path.length + 1);
      final targetPath = p.join(dest.path, relativePath);
      if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      }
    }
  }

  String get contentsPath => p.join(_basePath!, 'contents');
  String get mediaPath => p.join(_basePath!, 'media');
  String get thumbnailsPath => p.join(_basePath!, 'thumbnails');
  String get dbPath => p.join(_basePath!, 'notes.db');

  // ───────────── 笔记正文读写 ─────────────

  /// 读取笔记正文（支持 Delta JSON 和旧 Markdown）
  Future<String> readContent(String noteId) async {
    var file = File(p.join(contentsPath, '$noteId.json'));
    if (await file.exists()) return file.readAsString();
    file = File(p.join(contentsPath, '$noteId.md'));
    if (await file.exists()) return file.readAsString();
    return '';
  }

  /// 写入笔记正文（Delta JSON 格式）
  Future<void> writeContent(String noteId, String content) async {
    final file = File(p.join(contentsPath, '$noteId.json'));
    await file.writeAsString(content);
  }

  /// 删除笔记正文文件
  Future<void> deleteContent(String noteId) async {
    for (final ext in ['.json', '.md']) {
      final file = File(p.join(contentsPath, '$noteId$ext'));
      if (await file.exists()) await file.delete();
    }
  }

  // ───────────── 媒体文件管理 ─────────────

  Future<String> saveImage(File sourceFile) async {
    final ext = p.extension(sourceFile.path);
    final name = 'img_${_uuid.v4()}$ext';
    final dest = File(p.join(mediaPath, name));
    await sourceFile.copy(dest.path);
    return 'media/$name';
  }

  Future<String> saveVideo(File sourceFile) async {
    final ext = p.extension(sourceFile.path);
    final name = 'vid_${_uuid.v4()}$ext';
    final dest = File(p.join(mediaPath, name));
    await sourceFile.copy(dest.path);
    return 'media/$name';
  }

  String getMediaAbsolutePath(String relativePath) {
    return p.join(_basePath!, relativePath);
  }

  // ───────────── 视频缩略图 ─────────────

  String getThumbnailPath(String videoRelativePath) {
    final videoName = p.basenameWithoutExtension(videoRelativePath);
    return p.join(thumbnailsPath, 'thumb_$videoName.jpg');
  }

  // ───────────── 清理 ─────────────

  Future<void> deleteNoteFiles(String noteId) async {
    await deleteContent(noteId);
  }

  Future<int> cleanOrphanMedia(Set<String> referencedPaths) async {
    final mediaDir = Directory(mediaPath);
    if (!await mediaDir.exists()) return 0;

    int count = 0;
    await for (final entity in mediaDir.list()) {
      if (entity is File) {
        final relativePath = 'media/${p.basename(entity.path)}';
        if (!referencedPaths.contains(relativePath)) {
          await entity.delete();
          count++;
        }
      }
    }
    return count;
  }
}
