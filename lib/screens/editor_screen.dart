import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../providers/notes_provider.dart';
import '../services/file_service.dart';

class EditorScreen extends StatefulWidget {
  final String noteId;
  const EditorScreen({super.key, required this.noteId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late QuillController _quillController;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final FileService _fs = FileService();
  bool _loading = true;
  bool _modified = false;
  bool _inserting = false;
  String _noteTitle = '';
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _smallEmbeds = {};

  // 当前激活的格式
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
  bool _strike = false;
  int? _headerLevel;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _loadNote();
  }

  @override
  void dispose() {
    _autoSave();
    _quillController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String _stripMarkdown(String md) {
    return md
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\*{1,3}(.*?)\*{1,3}'), r'$1')
        .replaceAll(RegExp(r'`{1,3}[^`]*`{1,3}'), '')
        .replaceAll(RegExp(r'!\[\]\(.*?\)'), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\(.*?\)'), r'$1')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^>\s+', multiLine: true), '')
        .trim();
  }

  Future<void> _loadNote() async {
    final provider = context.read<NotesProvider>();
    final note =
        provider.notes.where((n) => n.id == widget.noteId).firstOrNull;
    if (note == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _noteTitle = note.title;
    _titleController.text = note.title;

    final content = await _fs.readContent(widget.noteId);
    if (content.isNotEmpty) {
      try {
        final json = jsonDecode(content);
        if (json is Map && json.containsKey('delta')) {
          _quillController = QuillController(
            document: Document.fromJson(json['delta'] as List<dynamic>),
            selection: const TextSelection.collapsed(offset: 0),
          );
          if (json['small'] is List) {
            _smallEmbeds.addAll((json['small'] as List).cast<String>());
          }
        } else if (json is List) {
          _quillController = QuillController(
            document: Document.fromJson(json),
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } catch (_) {
        final plain = _stripMarkdown(content);
        _quillController = QuillController(
          document: Document()..insert(0, plain),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    }

    _quillController.addListener(() {
      if (!_modified) _modified = true;
      _updateFormatState();
    });

    setState(() => _loading = false);
  }

  void _updateFormatState() {
    final sel = _quillController.getSelectionStyle().attributes;
    setState(() {
      _bold = sel.containsKey(Attribute.bold.key);
      _italic = sel.containsKey(Attribute.italic.key);
      _underline = sel.containsKey(Attribute.underline.key);
      _strike = sel.containsKey(Attribute.strikeThrough.key);
      final hv = sel.containsKey(Attribute.h1.key) ? 1
          : sel.containsKey(Attribute.h2.key) ? 2
          : sel.containsKey(Attribute.h3.key) ? 3
          : null;
      _headerLevel = hv;
    });
  }

  Future<void> _autoSave() async {
    if (!_modified) return;
    final provider = context.read<NotesProvider>();
    final json = jsonEncode({
      'delta': _quillController.document.toDelta().toJson(),
      'small': _smallEmbeds.toList(),
    });
    await _fs.writeContent(widget.noteId, json);
    final note =
        provider.notes.where((n) => n.id == widget.noteId).firstOrNull;
    if (note != null) {
      note.title = _noteTitle;
      await provider.updateNoteMeta(note);
    }
    _modified = false;
  }

  // ─── 格式操作（显式切换，解决 flutter_quill 不自动 toggle 的问题） ───

  void _toggleBold() {
    if (_bold) {
      _quillController.formatSelection(
          Attribute.clone(Attribute.bold, null));
    } else {
      _quillController.formatSelection(Attribute.bold);
    }
    _focusNode.requestFocus();
  }

  void _toggleItalic() {
    if (_italic) {
      _quillController.formatSelection(
          Attribute.clone(Attribute.italic, null));
    } else {
      _quillController.formatSelection(Attribute.italic);
    }
    _focusNode.requestFocus();
  }

  void _toggleUnderline() {
    if (_underline) {
      _quillController.formatSelection(
          Attribute.clone(Attribute.underline, null));
    } else {
      _quillController.formatSelection(Attribute.underline);
    }
    _focusNode.requestFocus();
  }

  void _toggleStrike() {
    if (_strike) {
      _quillController.formatSelection(
          Attribute.clone(Attribute.strikeThrough, null));
    } else {
      _quillController.formatSelection(Attribute.strikeThrough);
    }
    _focusNode.requestFocus();
  }

  void _setHeaderLevel(int level) {
    switch (level) {
      case 1: _quillController.formatSelection(Attribute.h1);
      case 2: _quillController.formatSelection(Attribute.h2);
      case 3: _quillController.formatSelection(Attribute.h3);
    }
    _focusNode.requestFocus();
  }

  void _removeHeader() {
    _quillController.formatSelection(const HeaderAttribute());
    _focusNode.requestFocus();
  }

  // ─── 插入媒体 ───

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('从相册选择图片'),
              onTap: () {
                Navigator.pop(ctx);
                _insertImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍摄照片'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('从相册选择视频'),
              onTap: () {
                Navigator.pop(ctx);
                _insertVideo();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _insertImage() async {
    if (_inserting) return;
    setState(() => _inserting = true);
    try {
      final xFile = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 90);
      if (xFile == null) { setState(() => _inserting = false); return; }
      final relativePath = await _fs.saveImage(File(xFile.path));
      final absPath = _fs.getMediaAbsolutePath(relativePath);
      final index = _quillController.selection.baseOffset;
      _quillController.document.insert(index, BlockEmbed.image(absPath));
      _quillController.document.insert(index + 1, '\n');
      _quillController.updateSelection(
          TextSelection.collapsed(offset: index + 2), ChangeSource.local);
      _modified = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片已插入'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _inserting = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_inserting) return;
    setState(() => _inserting = true);
    try {
      final xFile = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 90);
      if (xFile == null) { setState(() => _inserting = false); return; }
      final relativePath = await _fs.saveImage(File(xFile.path));
      final absPath = _fs.getMediaAbsolutePath(relativePath);
      final index = _quillController.selection.baseOffset;
      _quillController.document.insert(index, BlockEmbed.image(absPath));
      _quillController.document.insert(index + 1, '\n');
      _quillController.updateSelection(
          TextSelection.collapsed(offset: index + 2), ChangeSource.local);
      _modified = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片已插入'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _inserting = false);
    }
  }

  Future<void> _insertVideo() async {
    if (_inserting) return;
    setState(() => _inserting = true);
    try {
      final xFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (xFile == null) { setState(() => _inserting = false); return; }
      final relativePath = await _fs.saveVideo(File(xFile.path));
      final absPath = _fs.getMediaAbsolutePath(relativePath);
      final index = _quillController.selection.baseOffset;
      _quillController.document.insert(index, BlockEmbed.video(absPath));
      _quillController.document.insert(index + 1, '\n');
      _quillController.updateSelection(
          TextSelection.collapsed(offset: index + 2), ChangeSource.local);
      _modified = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('视频已插入'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('视频插入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _inserting = false);
    }
  }

  /// 全屏查看图片
  void _viewImageFullscreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(url)),
            ),
          ),
        ),
      ),
    );
  }

  /// 全屏播放视频
  void _playVideo(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoPlayerScreen(videoPath: url),
      ),
    );
  }

  // ─── 工具栏 ───

  Widget _buildToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;
    final iconColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final activeColor = Theme.of(context).colorScheme.primary;

    Widget btn(IconData icon, VoidCallback onTap,
        {bool active = false, String tooltip = ''}) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: active ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 18,
                  color: active ? activeColor : iconColor),
            ),
          ),
        ),
      );
    }

    // 字号弹出菜单
    final headerLabels = ['正文', '大标题', '中标题', '小标题'];
    final headerIcons = [Icons.text_fields, Icons.looks_one,
        Icons.looks_two, Icons.looks_3];
    final currentLabel = _headerLevel != null
        ? headerLabels[_headerLevel!.clamp(1, 3)]
        : '正文';

    return Container(
      height: 40,
      color: bgColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          // 撤销/重做
          btn(Icons.undo, () {
            _quillController.undo();
            _focusNode.requestFocus();
          }, tooltip: '撤销'),
          btn(Icons.redo, () {
            _quillController.redo();
            _focusNode.requestFocus();
          }, tooltip: '重做'),
          const VerticalDivider(width: 8),

          // 字号选择（弹出菜单）
          PopupMenuButton<int>(
            tooltip: '字号',
            offset: const Offset(0, 40),
            onSelected: (level) {
              if (level == 0) {
                _removeHeader();
              } else {
                _setHeaderLevel(level);
              }
            },
            itemBuilder: (ctx) => List.generate(4, (i) {
              return PopupMenuItem<int>(
                value: i == 0 ? 0 : i,
                child: Row(
                  children: [
                    Icon(headerIcons[i], size: 18),
                    const SizedBox(width: 8),
                    Text(headerLabels[i],
                      style: TextStyle(
                        fontWeight: (_headerLevel == null && i == 0) ||
                            (_headerLevel == i && i > 0)
                            ? FontWeight.bold
                            : null)),
                  ],
                ),
              );
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_size, size: 18, color: iconColor),
                  const SizedBox(width: 2),
                  Text(currentLabel,
                      style: TextStyle(fontSize: 11, color: iconColor)),
                  Icon(Icons.arrow_drop_down, size: 16, color: iconColor),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 8),

          // B I U S
          btn(Icons.format_bold, _toggleBold,
              active: _bold, tooltip: '加粗'),
          btn(Icons.format_italic, _toggleItalic,
              active: _italic, tooltip: '斜体'),
          btn(Icons.format_underline, _toggleUnderline,
              active: _underline, tooltip: '下划线'),
          btn(Icons.format_strikethrough, _toggleStrike,
              active: _strike, tooltip: '删除线'),
          const VerticalDivider(width: 8),

          // 列表/引用
          btn(Icons.format_list_numbered, () {
            _quillController.formatSelection(Attribute.ol);
            _focusNode.requestFocus();
          }, tooltip: '有序列表'),
          btn(Icons.format_list_bulleted, () {
            _quillController.formatSelection(Attribute.ul);
            _focusNode.requestFocus();
          }, tooltip: '无序列表'),
          btn(Icons.format_quote, () {
            _quillController.formatSelection(Attribute.blockQuote);
            _focusNode.requestFocus();
          }, tooltip: '引用'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _autoSave();
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text(_noteTitle.isEmpty ? '新建笔记' : '编辑'),
        actions: [
          if (_inserting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _inserting ? null : _showMediaPicker,
            tooltip: '插入',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              await _autoSave();
              if (mounted) Navigator.pop(context);
            },
            tooltip: '完成',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _titleController,
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: '标题', border: InputBorder.none, contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) { _noteTitle = v; _modified = true; },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: QuillEditor.basic(
                    controller: _quillController,
                    focusNode: _focusNode,
                    scrollController: _scrollController,
                    config: QuillEditorConfig(
                      placeholder: '开始写...',
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      autoFocus: false,
                      expands: true,
                      embedBuilders: [
                        _ImageEmbedBuilder(_smallEmbeds, (url) => _viewImageFullscreen(url), () {
                          setState(() {});
                          _modified = true;
                        }),
                        _VideoEmbedBuilder(_smallEmbeds, (url) => _playVideo(url), () {
                          setState(() {});
                          _modified = true;
                        }),
                      ],
                    ),
                  ),
                ),
                _buildToolbar(),
              ],
            ),
    );
  }
}

// ─── 嵌入渲染 ───

class _ImageEmbedBuilder extends EmbedBuilder {
  final Set<String> smallEmbeds;
  final void Function(String) onTapImage;
  final VoidCallback onChanged;
  _ImageEmbedBuilder(this.smallEmbeds, this.onTapImage, this.onChanged);

  @override String get key => 'image';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final small = smallEmbeds.contains(url);
    return _EmbedWrapper(
      small: small,
      onLongPress: () {
        if (small) { smallEmbeds.remove(url); } else { smallEmbeds.add(url); }
        onChanged();
      },
      child: GestureDetector(
        onTap: () => onTapImage(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(url), fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(height: 120,
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoEmbedBuilder extends EmbedBuilder {
  final Set<String> smallEmbeds;
  final void Function(String) onTap;
  final VoidCallback onChanged;
  _VideoEmbedBuilder(this.smallEmbeds, this.onTap, this.onChanged);

  @override String get key => 'video';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final small = smallEmbeds.contains(url);
    return _EmbedWrapper(
      small: small,
      onLongPress: () {
        if (small) { smallEmbeds.remove(url); } else { smallEmbeds.add(url); }
        onChanged();
      },
      child: GestureDetector(
        onTap: () => onTap(url),
        child: Container(height: small ? 100 : 180,
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: const Center(child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white70)),
        ),
      ),
    );
  }
}

class _EmbedWrapper extends StatelessWidget {
  final Widget child;
  final bool small;
  final VoidCallback onLongPress;
  const _EmbedWrapper({required this.child, required this.small, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: small
            ? SizedBox(width: 120, height: 120,
                child: FittedBox(fit: BoxFit.contain, child: child))
            : child,
      ),
    );
  }
}

// ─── 全屏视频播放 ───

class _VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  const _VideoPlayerScreen({required this.videoPath});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(Icons.play_circle_fill,
                              size: 64, color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
