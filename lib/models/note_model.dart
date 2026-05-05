import 'dart:convert';

class NoteModel {
  final String id;
  String title;
  String? folderId;
  List<String> tags;
  bool isPinned;
  bool isFavored;
  bool isLocked;
  String? passwordHash;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt; // null = 未删除
  bool hasVideo; // 是否包含视频
  bool hasImage; // 是否包含图片

  NoteModel({
    required this.id,
    this.title = '',
    this.folderId,
    List<String>? tags,
    this.isPinned = false,
    this.isFavored = false,
    this.isLocked = false,
    this.passwordHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.hasVideo = false,
    this.hasImage = false,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 获取正文预览（从Markdown文件中提取纯文本前100字）
  String? previewText;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'folder_id': folderId,
      'tags': jsonEncode(tags),
      'is_pinned': isPinned ? 1 : 0,
      'is_favored': isFavored ? 1 : 0,
      'is_locked': isLocked ? 1 : 0,
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'has_video': hasVideo ? 1 : 0,
      'has_image': hasImage ? 1 : 0,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      folderId: map['folder_id'] as String?,
      tags: map['tags'] != null
          ? List<String>.from(jsonDecode(map['tags'] as String))
          : [],
      isPinned: (map['is_pinned'] as int?) == 1,
      isFavored: (map['is_favored'] as int?) == 1,
      isLocked: (map['is_locked'] as int?) == 1,
      passwordHash: map['password_hash'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'] as String)
          : null,
      hasVideo: (map['has_video'] as int?) == 1,
      hasImage: (map['has_image'] as int?) == 1,
    );
  }

  NoteModel copyWith({
    String? title,
    String? folderId,
    List<String>? tags,
    bool? isPinned,
    bool? isFavored,
    bool? isLocked,
    String? passwordHash,
    DateTime? deletedAt,
    bool? hasVideo,
    bool? hasImage,
  }) {
    return NoteModel(
      id: id,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      tags: tags ?? List.from(this.tags),
      isPinned: isPinned ?? this.isPinned,
      isFavored: isFavored ?? this.isFavored,
      isLocked: isLocked ?? this.isLocked,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deletedAt: deletedAt ?? this.deletedAt,
      hasVideo: hasVideo ?? this.hasVideo,
      hasImage: hasImage ?? this.hasImage,
    );
  }

  /// 是否在回收站中
  bool get isInTrash => deletedAt != null;
}
