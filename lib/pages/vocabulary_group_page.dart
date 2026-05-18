import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'vocabulary_set_page.dart';

class VocabularyGroupPage extends StatefulWidget {
  final int userId;
  final int groupId;
  final String groupName;

  const VocabularyGroupPage({
    super.key,
    required this.userId,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<VocabularyGroupPage> createState() => _VocabularyGroupPageState();
}

class _VocabularyGroupPageState extends State<VocabularyGroupPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _lists = [];
  bool _isLoading = true;
  bool _isCreatingList = false;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final lists = await _db.getVocabularySetsByGroup(widget.userId, widget.groupId);
      setState(() {
        _lists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('List load error: $e')),
        );
      }
    }
  }

  Future<void> _createNewList() async {
    if (_isCreatingList) return;

    final defaultName = _buildAutoListName();
    final nameController = TextEditingController(text: defaultName);
    final enteredName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New List'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter list name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (enteredName == null || enteredName.isEmpty) return;

    setState(() => _isCreatingList = true);
    try {
      await _db.createVocabularySet(widget.userId, enteredName, groupId: widget.groupId);
      await _loadLists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created $enteredName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingList = false);
      }
    }
  }

  String _buildAutoListName() {
    final baseName = widget.groupName.trim();
    final escapedBase = RegExp.escape(baseName);
    final pattern = RegExp('^$escapedBase List (\\d+)\$');
    int maxIndex = 0;

    for (final item in _lists) {
      final name = (item['name'] as String? ?? '').trim();
      final match = pattern.firstMatch(name);
      if (match == null) continue;
      final index = int.tryParse(match.group(1) ?? '') ?? 0;
      if (index > maxIndex) maxIndex = index;
    }

    return '$baseName List ${maxIndex + 1}';
  }

  Future<void> _deleteList(int setId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete list'),
        content: const Text('Are you sure you want to delete this list? All words inside will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.deleteVocabularySet(setId);
        await _loadLists();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('List deleted!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
                  ),
                  Expanded(
                    child: Text(
                      widget.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primaryContainer,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Group',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary.withAlpha(179),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.groupName,
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${_lists.length} list',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Lists',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_lists.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No lists in this group yet',
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...List.generate(_lists.length, (index) {
                              final item = _lists[index];
                              final setId = item['id'] as int;
                              final setName = item['name'] as String? ?? '';
                              final wordCount = item['wordCount'] as int? ?? 0;
                              final dueCount = item['dueCount'] as int? ?? 0;
                              final progress = (item['progress'] as int? ?? 0).clamp(0, 100);

                              return GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VocabularySetPage(
                                        setId: setId,
                                        setName: setName,
                                        userId: widget.userId,
                                      ),
                                    ),
                                  );
                                  _loadLists();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withAlpha(25),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(Icons.list_alt, color: theme.colorScheme.primary),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              setName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$wordCount words | Due: $dueCount',
                                              style: TextStyle(
                                                color: theme.colorScheme.onSurfaceVariant,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: progress / 100,
                                                minHeight: 6,
                                                backgroundColor: theme.colorScheme.surfaceContainerLow,
                                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteList(setId),
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCreatingList ? null : _createNewList,
        backgroundColor: theme.colorScheme.primary,
        child: _isCreatingList
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: theme.colorScheme.onPrimary,
                  strokeWidth: 2.2,
                ),
              )
            : Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }
}
