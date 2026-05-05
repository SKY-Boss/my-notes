import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/file_service.dart';
import 'app.dart';
import 'providers/notes_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化文件服务和数据库
  final fileService = FileService();
  await fileService.basePath; // 确保目录结构已创建
  await DatabaseService().init(fileService.dbPath);

  // 启动时清理过期回收站
  await DatabaseService().cleanExpiredTrash();

  runApp(
    ChangeNotifierProvider(
      create: (_) => NotesProvider(),
      child: const NotesApp(),
    ),
  );
}
