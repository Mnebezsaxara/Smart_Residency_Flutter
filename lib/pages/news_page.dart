import 'package:flutter/material.dart';

import '../services/api_client.dart';

class News {
  final String id;
  final String title;
  final String body;
  final String author;
  final int? entrance;
  final DateTime createdAt;
  final bool isPinned;

  const News({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    this.entrance,
    required this.createdAt,
    required this.isPinned,
  });

  factory News.fromMap(Map<String, dynamic> map) {
    return News(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      entrance: map['entrance'] as int?,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isPinned: map['is_pinned'] == true,
    );
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final ApiClient _api = ApiClient.instance;
  bool get _isAdmin => _api.userRole == 'admin';

  List<News> _news = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final res = await _api.get('/news');
      final items = (res.data as List)
          .map((item) => News.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (!mounted) return;
      setState(() {
        _news = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки новостей: $e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteNews(String newsId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить новость?'),
        content: const Text('Это действие невозможно отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.delete('/admin/news/$newsId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Новость удалена')),
      );
      await _loadNews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    }
  }

  Future<void> _showCreateNewsSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateNewsSheet(onSuccess: _loadNews),
    );

    if (result == true) {
      await _loadNews();
    }
  }

  Future<void> _showEditNewsSheet(News news) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditNewsSheet(news: news, onSuccess: _loadNews),
    );

    if (result == true) {
      await _loadNews();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новости в ЖК'),
        actions: [
          if (_isAdmin)
            IconButton(
              onPressed: _showCreateNewsSheet,
              icon: const Icon(Icons.add),
              tooltip: 'Добавить новость',
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 42),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _loadNews,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _news.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.newspaper_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Нет новостей',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNews,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _news.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _NewsCard(
                            news: _news[i],
                            isAdmin: _isAdmin,
                            onEdit: () => _showEditNewsSheet(_news[i]),
                            onDelete: () => _deleteNews(_news[i].id),
                          ),
                        ),
                      ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final News news;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NewsCard({
    required this.news,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (news.isPinned)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.push_pin,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Закреплено',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                          ],
                        ),
                      Text(
                        news.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Редактировать'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outlined,
                                size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Удалить',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_horiz),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(news.body),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  news.author,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(news.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (news.entrance != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.apartment, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Подъезд ${news.entrance}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }
}

class _CreateNewsSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const _CreateNewsSheet({required this.onSuccess});

  @override
  State<_CreateNewsSheet> createState() => _CreateNewsSheetState();
}

class _CreateNewsSheetState extends State<_CreateNewsSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isPinned = false;
  bool _forAllEntrances = true;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _createNews() async {
    FocusScope.of(context).unfocus();
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiClient.instance.post(
        '/admin/news',
        data: {
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'entrance': _forAllEntrances ? null : 1,
          'is_pinned': _isPinned,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Новость добавлена')),
      );
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Новая новость', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              enabled: !_loading,
              decoration: const InputDecoration(labelText: 'Заголовок'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              enabled: !_loading,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Текст новости'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isPinned,
              onChanged: _loading ? null : (v) => setState(() => _isPinned = v ?? false),
              title: const Text('Закрепить в начале'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _forAllEntrances,
              onChanged: _loading ? null : (v) => setState(() => _forAllEntrances = v ?? true),
              title: const Text('Для всех подъездов'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _createNews,
                    child: Text(_loading ? 'Добавление...' : 'Добавить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _EditNewsSheet extends StatefulWidget {
  final News news;
  final VoidCallback onSuccess;

  const _EditNewsSheet({required this.news, required this.onSuccess});

  @override
  State<_EditNewsSheet> createState() => _EditNewsSheetState();
}

class _EditNewsSheetState extends State<_EditNewsSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late bool _isPinned;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.news.title);
    _bodyController = TextEditingController(text: widget.news.body);
    _isPinned = widget.news.isPinned;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _updateNews() async {
    FocusScope.of(context).unfocus();
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiClient.instance.put(
        '/admin/news/${widget.news.id}',
        data: {
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'is_pinned': _isPinned,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Новость обновлена')),
      );
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Редактировать новость',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              enabled: !_loading,
              decoration: const InputDecoration(labelText: 'Заголовок'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              enabled: !_loading,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Текст новости'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isPinned,
              onChanged:
                  _loading ? null : (v) => setState(() => _isPinned = v ?? false),
              title: const Text('Закрепить в начале'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _updateNews,
                    child: Text(_loading ? 'Обновление...' : 'Обновить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
