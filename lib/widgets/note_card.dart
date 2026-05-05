import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onLock;
  final VoidCallback onDelete;
  final VoidCallback onMove;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onPin,
    required this.onLock,
    required this.onDelete,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Slidable(
      key: Key(note.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.52,
        children: [
          _buildAction(
            icon: note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: note.isPinned ? '取消\n置顶' : '置顶',
            color: Colors.purple.shade400,
            onTap: (ctx) {
              Slidable.of(ctx)?.close();
              onPin();
            },
          ),
          _buildAction(
            icon: note.isLocked ? Icons.lock : Icons.lock_open,
            label: note.isLocked ? '解锁' : '加锁',
            color: Colors.orange.shade400,
            onTap: (ctx) {
              Slidable.of(ctx)?.close();
              onLock();
            },
          ),
          _buildAction(
            icon: Icons.delete_outline,
            label: '删除',
            color: Colors.red.shade400,
            onTap: (ctx) {
              Slidable.of(ctx)?.close();
              _confirmDelete(context);
            },
          ),
          _buildAction(
            icon: Icons.drive_file_move_outlined,
            label: '移动',
            color: Colors.blue.shade400,
            onTap: (ctx) {
              Slidable.of(ctx)?.close();
              onMove();
            },
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.push_pin,
                            size: 14, color: colorScheme.primary),
                      ),
                    if (note.isLocked)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.lock,
                            size: 13, color: colorScheme.outline),
                      ),
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? '无标题' : note.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.isFavored)
                      Icon(Icons.star,
                          size: 16, color: colorScheme.tertiary),
                  ],
                ),
                if (note.previewText != null &&
                    note.previewText!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.previewText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatDate(note.updatedAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ...note.tags.take(3).map(
                            (tag) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                    ],
                    const Spacer(),
                    if (note.hasImage)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.image_outlined,
                            size: 14, color: colorScheme.outline),
                      ),
                    if (note.hasVideo)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.videocam_outlined,
                            size: 14, color: colorScheme.outline),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required void Function(BuildContext) onTap,
  }) {
    return Expanded(
      child: Builder(
        builder: (ctx) => GestureDetector(
          onTap: () => onTap(ctx),
          child: Container(
            color: color,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text(
            '确定要删除「${note.title.isEmpty ? '无标题' : note.title}」吗？\n\n笔记将移入回收站。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.month}/${date.day}';
  }
}
