import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final TextEditingController _folderController = TextEditingController();

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: _folderController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件夹名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (_folderController.text.trim().isNotEmpty) {
                context
                    .read<NotesProvider>()
                    .createFolder(_folderController.text.trim());
                Navigator.pop(ctx);
                _folderController.clear();
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(String id, String currentName) {
    _folderController.text = currentName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: _folderController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (_folderController.text.trim().isNotEmpty) {
                context
                    .read<NotesProvider>()
                    .renameFolder(id, _folderController.text.trim());
                Navigator.pop(ctx);
                _folderController.clear();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件夹'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: provider.folders.isEmpty
          ? Center(
              child: Text('还没有文件夹',
                  style: TextStyle(color: colorScheme.outline)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.folders.length + 1, // +1 for "全部笔记"
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "全部笔记"入口
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: provider.currentFolderId == null
                        ? colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('全部笔记'),
                      trailing: Text(
                        '${provider.notes.length}',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                      onTap: () {
                        provider.setFolder(null);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }

                final folder = provider.folders[index - 1];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: provider.currentFolderId == folder.id
                      ? colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.name),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'rename') {
                          _showRenameDialog(folder.id, folder.name);
                        } else if (action == 'delete') {
                          provider.deleteFolder(folder.id);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('重命名'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('删除', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                    onTap: () {
                      provider.setFolder(folder.id);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }
}
