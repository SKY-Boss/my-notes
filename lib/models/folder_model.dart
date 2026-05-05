class FolderModel {
  final String id;
  String name;
  String? parentId;
  int sortOrder;
  int color; // 0-7 预设颜色索引
  final DateTime createdAt;

  FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    this.color = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'sort_order': sortOrder,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      color: (map['color'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
