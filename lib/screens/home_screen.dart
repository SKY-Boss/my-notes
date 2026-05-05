import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';
import 'trash_screen.dart';
import 'nutstore_settings_screen.dart';

// 预设文件夹颜色（Material 浅色系）
const List<Color> _folderColors = [
  Colors.transparent,
  Color(0xFFFFCDD2), // 红
  Color(0xFFFFE0B2), // 橙
  Color(0xFFFFF9C4), // 黄
  Color(0xFFC8E6C9), // 绿
  Color(0xFFBBDEFB), // 蓝
  Color(0xFFE1BEE7), // 紫
  Color(0xFFE0E0E0), // 灰
];

const List<Color> _folderColorsDark = [
  Colors.transparent,
  Color(0xFF4E1A1E), // 深红
  Color(0xFF4E331A), // 深橙
  Color(0xFF4E4A1A), // 深黄
  Color(0xFF1A4E1E), // 深绿
  Color(0xFF1A334E), // 深蓝
  Color(0xFF3E1A4E), // 深紫
  Color(0xFF3E3E3E), // 深灰
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showSearch = false;
  int _pickedColor = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotesProvider>();
      provider.loadFolders();
      provider.loadNotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  Color _getFolderColor(FolderModel folder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? _folderColorsDark : _folderColors;
    final idx = folder.color.clamp(0, colors.length - 1);
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,

      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                decoration: BoxDecoration(color: colorScheme.primaryContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 36, color: colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('随记',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${provider.notes.length} 条笔记',
                        style: TextStyle(
                            color: colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),

              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('全部笔记'),
                selected: provider.currentFolderId == null,
                selectedTileColor:
                    colorScheme.primaryContainer.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  provider.setFolder(null);
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('未分类'),
                selected: provider.currentFolderId == '__uncategorized__',
                selectedTileColor:
                    colorScheme.primaryContainer.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  provider.setFolder('__uncategorized__');
                  Navigator.pop(context);
                },
              ),

              const Divider(indent: 16, endIndent: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('文件夹',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: colorScheme.outline)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _showCreateFolderDialog(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: provider.folders.isEmpty
                    ? Center(
                        child: Text('还没有文件夹',
                            style: TextStyle(color: colorScheme.outline)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: provider.folders.length,
                        itemBuilder: (context, index) {
                          final folder = provider.folders[index];
                          return _buildFolderTile(folder, provider);
                        },
                      ),
              ),

              const Divider(indent: 16, endIndent: 16),

              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('回收站'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TrashScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('云同步'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NutstoreSettingsScreen()));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),

      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: _showSearch
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: '搜索笔记...', border: InputBorder.none),
                    onChanged: (q) => provider.search(q),
                  )
                : Text(provider.currentFolderId != null
                    ? _folderName(provider)
                    : '全部笔记'),
            actions: [
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      provider.search('');
                    }
                  });
                },
              ),
            ],
          ),
          provider.loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : provider.notes.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.note_add_outlined,
                                size: 64, color: colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('还没有笔记',
                                style: TextStyle(color: colorScheme.outline)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildNoteCard(provider.notes[index]),
                          childCount: provider.notes.length,
                        ),
                      ),
                    ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNote(provider),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFolderTile(FolderModel folder, NotesProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = provider.currentFolderId == folder.id;
    final folderColor = _getFolderColor(folder);

    return ListTile(
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: folderColor == Colors.transparent
              ? (isSelected ? colorScheme.primaryContainer : Colors.transparent)
              : folderColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          isSelected ? Icons.folder : Icons.folder_outlined,
          size: 16,
          color: folderColor == Colors.transparent
              ? (isSelected ? colorScheme.primary : colorScheme.outline)
              : colorScheme.onSurface,
        ),
      ),
      title: Text(folder.name,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      trailing: PopupMenuButton<String>(
        tooltip: '',
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (action) {
          if (action == 'rename') _showRenameDialog(folder);
          if (action == 'delete') _confirmDeleteFolder(folder);
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          const PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
      onTap: () {
        provider.setFolder(folder.id);
        Navigator.pop(context);
      },
    );
  }

  // ─── 颜色选择器 ───

  Widget _buildColorPicker(void Function(VoidCallback) dialogSetState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? _folderColorsDark : _folderColors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(colors.length, (i) {
        final isSelected = _pickedColor == i;
        return GestureDetector(
          onTap: () => dialogSetState(() => _pickedColor = i),
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (colors[i] == Colors.transparent
                        ? Theme.of(context).colorScheme.outline
                        : Colors.transparent),
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check, size: 14,
                    color: colors[i] == Colors.transparent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface)
                : (colors[i] == Colors.transparent
                    ? Icon(Icons.block, size: 14,
                        color: Theme.of(context).colorScheme.outline)
                    : null),
          ),
        );
      }),
      ),
    );
  }

  // ─── 对话框 ───

  void _showCreateFolderDialog() {
    _folderController.clear();
    _pickedColor = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _folderController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '文件夹名称'),
              ),
              const SizedBox(height: 16),
              _buildColorPicker(setDialogState),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            TextButton(
              onPressed: () {
                if (_folderController.text.trim().isNotEmpty) {
                  context
                      .read<NotesProvider>()
                      .createFolder(_folderController.text.trim(),
                          color: _pickedColor);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(FolderModel folder) {
    _folderController.text = folder.name;
    _pickedColor = folder.color;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _folderController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '文件夹名称'),
              ),
              const SizedBox(height: 16),
              _buildColorPicker(setDialogState),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            TextButton(
              onPressed: () {
                if (_folderController.text.trim().isNotEmpty) {
                  final p = context.read<NotesProvider>();
                  p.renameFolder(
                      folder.id, _folderController.text.trim());
                  // 同时更新颜色
                  folder.color = _pickedColor;
                  p.loadFolders();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFolder(FolderModel folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text('确定要删除文件夹「${folder.name}」吗？\n文件夹内的笔记将移回全部笔记。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<NotesProvider>().deleteFolder(folder.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── 笔记操作 ───

  Widget _buildNoteCard(NoteModel note) {
    return NoteCard(
      note: note,
      onTap: () => _openEditor(note),
      onPin: () => context.read<NotesProvider>().togglePin(note),
      onLock: () => context.read<NotesProvider>().toggleLock(note),
      onDelete: () => context.read<NotesProvider>().deleteNote(note.id),
      onMove: () => _showMoveDialog(note),
    );
  }

  String _folderName(NotesProvider provider) {
    if (provider.currentFolderId == '__uncategorized__') return '未分类';
    final folder = provider.folders
        .where((f) => f.id == provider.currentFolderId)
        .firstOrNull;
    return folder?.name ?? '笔记';
  }

  Future<void> _createNote(NotesProvider provider) async {
    final note = await provider.createNote();
    if (mounted) _openEditor(note);
  }

  void _openEditor(NoteModel note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(noteId: note.id)),
    ).then((_) {
      context.read<NotesProvider>().loadNotes();
    });
  }

  void _showMoveDialog(NoteModel note) {
    final provider = context.read<NotesProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移动到文件夹'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (note.folderId != null)
                ListTile(
                  leading: const Icon(Icons.folder_off_outlined),
                  title: const Text('移出文件夹'),
                  onTap: () {
                    provider.moveNote(note, null);
                    Navigator.pop(ctx);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(note.folderId != null ? '全部笔记' : '全部笔记（根目录）'),
                onTap: () {
                  provider.moveNote(note, null);
                  Navigator.pop(ctx);
                },
              ),
              ...provider.folders.map((f) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(f.name),
                    onTap: () {
                      provider.moveNote(note, f.id);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }
}
