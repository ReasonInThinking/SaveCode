import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SnippetVaultApp());
}

class CodeBlock {
  String subtitle;
  String code;

  CodeBlock({required this.subtitle, required this.code});

  Map<String, dynamic> toJson() => {
        'subtitle': subtitle,
        'code': code,
      };

  factory CodeBlock.fromJson(Map<String, dynamic> json) => CodeBlock(
        subtitle: json['subtitle']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
      );
}

class Snippet {
  String id;
  String title;
  String tag;
  List<CodeBlock> blocks;

  Snippet({
    required this.id,
    required this.title,
    required this.tag,
    required this.blocks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'tag': tag,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory Snippet.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    if (rawBlocks is List) {
      return Snippet(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'Без названия',
        tag: json['tag']?.toString() ?? 'Code',
        blocks: rawBlocks
            .whereType<Map<String, dynamic>>()
            .map((b) => CodeBlock.fromJson(b))
            .toList(),
      );
    }
    return Snippet(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Без названия',
      tag: json['tag']?.toString() ?? 'Code',
      blocks: [
        CodeBlock(
          subtitle: '',
          code: json['code']?.toString() ?? '',
        ),
      ],
    );
  }
}

class SnippetVaultApp extends StatelessWidget {
  const SnippetVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snippet Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2A2A2A),
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Snippet> _snippets = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String get _storagePath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.snippet_vault.json';
  }

  @override
  void initState() {
    super.initState();
    _loadSnippets();
  }

  Future<void> _loadSnippets() async {
    try {
      final file = File(_storagePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is List) {
          setState(() {
            _snippets = decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => Snippet.fromJson(e))
                .toList();
          });
        }
      } else {
        setState(() {
          _snippets = [
            Snippet(
              id: '1',
              title: 'Создание и запуск Flutter на Linux',
              tag: 'Flutter',
              blocks: [
                CodeBlock(
                  subtitle: '1. Создание проекта',
                  code: 'flutter create --platforms=linux my_app',
                ),
                CodeBlock(
                  subtitle: '2. Запуск через X11',
                  code: 'GDK_BACKEND=x11 flutter run -d linux',
                ),
              ],
            ),
          ];
        });
        await _saveSnippets();
      }
    } catch (e) {
      _showMessage('Ошибка загрузки данных: $e');
    }
  }

  Future<void> _saveSnippets() async {
    try {
      final file = File(_storagePath);
      final jsonString = const JsonEncoder.withIndent('  ')
          .convert(_snippets.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      _showMessage('Ошибка сохранения: $e');
    }
  }


  Future<void> _exportBackup() async {
    try {
      final home = Platform.environment['HOME'] ?? '.';
      final date = DateTime.now().toIso8601String().split('T').first;
      final backupPath = '$home/snippets_backup_$date.json';
      final file = File(backupPath);
      final jsonString = const JsonEncoder.withIndent('  ')
          .convert(_snippets.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
      _showMessage('Бэкап сохранен: $backupPath');
    } catch (e) {
      _showMessage('Ошибка создания бэкапа: $e');
    }
  }

  Future<void> _importBackup() async {
    final pathController = TextEditingController(
      text: '${Platform.environment['HOME'] ?? ''}/snippets_backup.json',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановить из бэкапа'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Укажите полный путь к JSON-файлу бэкапа:'),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '/home/user/snippets_backup.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final file = File(pathController.text.trim());
              if (await file.exists()) {
                try {
                  final content = await file.readAsString();
                  final decoded = jsonDecode(content);
                  if (decoded is List) {
                    setState(() {
                      _snippets = decoded
                          .whereType<Map<String, dynamic>>()
                          .map((e) => Snippet.fromJson(e))
                          .toList();
                    });
                    await _saveSnippets();
                    if (mounted) Navigator.pop(context);
                    _showMessage('Успешно загружено ${_snippets.length} записей!');
                  }
                } catch (e) {
                  _showMessage('Неверный формат файла!');
                }
              } else {
                _showMessage('Файл не найден по этому пути');
              }
            },
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.tealAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF252525),
        behavior: SnackBarBehavior.floating,
        width: 520, // Аккуратная фиксированная ширина по центру
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Овальная капсула
          side: const BorderSide(color: Colors.white12), // Тонкая рамка
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  Future<void> _showSnippetDialog([Snippet? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final tagController = TextEditingController(text: existing?.tag ?? '');

    final List<Map<String, TextEditingController>> blockControllers = existing != null
        ? existing.blocks
            .map((b) => {
                  'subtitle': TextEditingController(text: b.subtitle),
                  'code': TextEditingController(text: b.code),
                })
            .toList()
        : [
            {
              'subtitle': TextEditingController(text: 'Шаг 1'),
              'code': TextEditingController(),
            }
          ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Новый сниппет' : 'Редактировать'),
          content: SizedBox(
            width: 850,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: titleController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Общий заголовок (для поиска)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: tagController,
                          decoration: const InputDecoration(
                            labelText: 'Тег / Язык',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(blockControllers.length, (i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: blockControllers[i]['subtitle'],
                                  decoration: const InputDecoration(
                                    labelText: 'Название шага / подзаголовок',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (blockControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () {
                                    setDialogState(() {
                                      blockControllers.removeAt(i);
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: blockControllers[i]['code'],
                            maxLines: 6,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
                            decoration: const InputDecoration(
                              labelText: 'Код или команда',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        blockControllers.add({
                          'subtitle': TextEditingController(text: 'Шаг ${blockControllers.length + 1}'),
                          'code': TextEditingController(),
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить еще блок кода'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final newBlocks = blockControllers
                    .where((bc) => bc['code']!.text.trim().isNotEmpty)
                    .map((bc) => CodeBlock(
                          subtitle: bc['subtitle']!.text.trim(),
                          code: bc['code']!.text,
                        ))
                    .toList();

                if (newBlocks.isEmpty) return;

                setState(() {
                  if (existing == null) {
                    _snippets.insert(
                      0,
                      Snippet(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        tag: tagController.text.trim().isEmpty
                            ? 'Code'
                            : tagController.text.trim(),
                        blocks: newBlocks,
                      ),
                    );
                  } else {
                    existing.title = titleController.text.trim();
                    existing.tag = tagController.text.trim().isEmpty
                        ? 'Code'
                        : tagController.text.trim();
                    existing.blocks = newBlocks;
                  }
                });
                await _saveSnippets();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final filtered = _snippets.where((s) {
      final q = _searchQuery.toLowerCase();
      final inBlocks = s.blocks.any((b) =>
          b.subtitle.toLowerCase().contains(q) ||
          b.code.toLowerCase().contains(q));
      return s.title.toLowerCase().contains(q) ||
          s.tag.toLowerCase().contains(q) ||
          inBlocks;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('БАЗА_КОДА'),
        actions: [
          IconButton(
            tooltip: 'Создать бэкап в домашнюю папку',
            icon: const Icon(Icons.download),
            onPressed: _exportBackup,
          ),
          IconButton(
            tooltip: 'Восстановить из бэкапа',
            icon: const Icon(Icons.upload),
            onPressed: _importBackup,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Поиск по заголовку, шагам, тегу или коду...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Ничего не найдено. Нажмите кнопку ниже, чтобы добавить код.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.tealAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.tag,
                                      style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Редактировать',
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showSnippetDialog(item),
                                  ),
                                  IconButton(
                                    tooltip: 'Удалить',
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20, color: Colors.redAccent),
                                    onPressed: () async {
                                      setState(() => _snippets.remove(item));
                                      await _saveSnippets();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...item.blocks.map((block) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (block.subtitle.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            block.subtitle,
                                            style: const TextStyle(
                                              color: Colors.tealAccent,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        width: double.infinity,
                                        constraints: const BoxConstraints(maxHeight: 220),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF121212),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: SelectableText(
                                                  block.code,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 20,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Копировать этот блок',
                                              icon: const Icon(Icons.copy,
                                                  size: 18, color: Colors.white70),
                                              onPressed: () {
                                                Clipboard.setData(
                                                    ClipboardData(text: block.code));
                                                _showMessage('Скопировано в буфер обмена!');
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSnippetDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить инструкцию'),
      ),
    );
  }
}
