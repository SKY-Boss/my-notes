import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    context.read<NotesProvider>().loadTrash();
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selected.clear();
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _restoreSelected() async {
    final provider = context.read<NotesProvider>();
    for (final id in _selected.toList()) {
      await provider.restoreNote(id);
    }
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    provider.loadTrash();
  }

  Future<void> _deleteSelected() async {
    final provider = context.read<NotesProvider>();
    final count = _selected.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('永久删除'),
        content: Text('确定要永久删除 $count 条笔记吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final id in _selected.toList()) {
      await provider.permanentlyDelete(id);
    }
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    provider.loadTrash();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '已选 ${_selected.length} 项' : '回收站'),
        actions: [
          if (provider.trashNotes.isNotEmpty)
            IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.checklist),
              onPressed: _toggleSelectMode,
              tooltip: _selectMode ? '取消选择' : '批量选择',
            ),
        ],
      ),
      body: provider.trashNotes.isEmpty
          ? Center(
              child: Text('回收站为空',
                  style: TextStyle(color: colorScheme.outline)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.trashNotes.length,
              itemBuilder: (context, index) {
                final note = provider.trashNotes[index];
                final isSelected = _selected.contains(note.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? colorScheme.primaryContainer.withOpacity(0.3)
                      : null,
                  child: ListTile(
                    leading: _selectMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleItem(note.id),
                          )
                        : const Icon(Icons.restore_from_trash_outlined),
                    title: Text(
                        note.title.isEmpty ? '无标题' : note.title),
                    subtitle:
                        Text('删除于 ${_formatDate(note.deletedAt!)}'),
                    trailing: _selectMode
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_forever,
                                color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('永久删除'),
                                  content: const Text(
                                      '确定要永久删除这条笔记吗？此操作不可撤销。'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('取消')),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('删除',
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                provider.permanentlyDelete(note.id);
                              }
                            },
                          ),
                    onTap: _selectMode
                        ? () => _toggleItem(note.id)
                        : () => provider.restoreNote(note.id),
                  ),
                );
              },
            ),

      // 批量操作栏
      bottomNavigationBar: _selectMode && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _restoreSelected,
                        icon: const Icon(Icons.restore),
                        label: Text('还原(${_selected.length})'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deleteSelected,
                        icon:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        label: Text('删除(${_selected.length})',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
