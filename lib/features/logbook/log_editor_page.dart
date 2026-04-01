import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/services/access_policy.dart';

class LogEditorPage extends StatefulWidget {
  final LogModel? log;
  final int? index;
  final LogController controller;
  final dynamic currentUser;

  const LogEditorPage({
    super.key,
    this.log,
    this.index,
    required this.controller,
    required this.currentUser,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  bool _isSaving = false;
  late LogCategory _selectedCategory;
  late bool _isPublic;

  void _replaceSelectedText(String newText, {int? selectionOffset}) {
    final selection = _descController.selection;
    final text = _descController.text;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final updatedText = text.replaceRange(start, end, newText);
    _descController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(
        offset: start + (selectionOffset ?? newText.length),
      ),
    );
  }

  void _wrapSelection(String before, String after, {String placeholder = ''}) {
    final selection = _descController.selection;
    final text = _descController.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final selectedText =
        start != end ? text.substring(start, end) : placeholder;
    final newText = '$before$selectedText$after';
    final cursorOffset = before.length + selectedText.length;
    _replaceSelectedText(newText, selectionOffset: cursorOffset);
  }

  void _prefixSelection(String prefix, {String placeholder = 'Item baru'}) {
    final selection = _descController.selection;
    final text = _descController.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final selectedText =
        start != end ? text.substring(start, end) : placeholder;
    final lines = selectedText.split('\n');
    final formatted = lines.map((line) => '$prefix$line').join('\n');
    _replaceSelectedText(formatted, selectionOffset: formatted.length);
  }

  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EBDD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B7D6B).withOpacity(0.35),
              ),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF8A6F4D)),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _descController = TextEditingController(
      text: widget.log?.description ?? '',
    );
    _selectedCategory = widget.log?.category ?? LogCategory.other;
    _isPublic = widget.log?.isPublic ?? false;

    // Listener agar Pratinjau terupdate otomatis
    _descController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descController.text.trim();

    // ── Permission guard (defence-in-depth) ──────────────────────
    final String userId = (widget.currentUser['id'] ?? '').toString();
    final String userTeamId =
        (widget.currentUser['teamId'] ?? widget.controller.teamId).toString();
    final String targetTeamId = widget.log?.teamId ?? widget.controller.teamId;

    if (!AccessPolicy.isSameTeam(userTeamId, targetTeamId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses ditolak: catatan ini bukan tim Anda.'),
          backgroundColor: Color(0xFF9E5A5A),
        ),
      );
      return;
    }

    if (widget.log != null &&
        !AccessPolicy.canModifyLog(
          currentUserId: userId,
          logAuthorId: widget.log!.authorId,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya pemilik catatan yang boleh mengedit.'),
          backgroundColor: Color(0xFF9E5A5A),
        ),
      );
      return;
    }
    // ─────────────────────────────────────────────────────────────

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul dan isi catatan harus diisi.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.log == null) {
        await widget.controller.addLog(
          title,
          description,
          widget.currentUser['id'] ?? widget.controller.username,
          widget.controller.teamId,
          category: _selectedCategory,
          isPublic: _isPublic,
        );
      } else {
        await widget.controller.updateLog(
          widget.index!,
          title,
          description,
          _selectedCategory,
          _isPublic,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan catatan: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    // JANGAN LUPA: Bersihkan controller agar tidak memory leak
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Widget _buildPreview() {
    final title = _titleController.text.trim();
    final content = _descController.text;
    final catColor =
        categoryColors[_selectedCategory] ?? const Color(0xFF8B7D6B);
    final catBg =
        categoryBgColors[_selectedCategory] ?? const Color(0xFFF5EFE8);
    final catIcon = categoryIcons[_selectedCategory] ?? Icons.category;
    final catLabel =
        categoryLabels[_selectedCategory] ?? _selectedCategory.name;
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          if (title.isEmpty)
            const Text(
              '(Judul belum diisi)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
          const SizedBox(height: 10),
          // Category chip + date row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: catColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(catIcon, size: 13, color: catColor),
                    const SizedBox(width: 5),
                    Text(
                      catLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: catColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          // Markdown content
          content.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '(Isi catatan belum diisi)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : MarkdownBody(
                  data: content,
                  softLineBreak: true,
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String userId = (widget.currentUser['id'] ?? '').toString();
    final bool isOwner = widget.log == null || widget.log?.authorId == userId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.log == null ? 'Catatan Baru' : 'Edit Catatan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Editor"),
              Tab(text: "Pratinjau"),
            ],
          ),
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Editor
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Owner-only reminder
                  if (widget.log != null && !isOwner)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCA2C)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock,
                              size: 16, color: Color(0xFFB8860B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hanya pemilik (${widget.log!.authorId}) yang bisa mengedit catatan ini.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF856404),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "Judul"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LogCategory>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: "Kategori",
                      prefixIcon: Icon(
                        categoryIcons[_selectedCategory],
                        color: categoryColors[_selectedCategory],
                        size: 20,
                      ),
                    ),
                    selectedItemBuilder: (context) {
                      return LogCategory.values.map((cat) {
                        final color =
                            categoryColors[cat] ?? const Color(0xFF8B7D6B);
                        final bg =
                            categoryBgColors[cat] ?? const Color(0xFFF5EFE8);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcons[cat], size: 14, color: color),
                              const SizedBox(width: 6),
                              Text(
                                categoryLabels[cat] ?? cat.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: color,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    items: LogCategory.values.map((cat) {
                      final color =
                          categoryColors[cat] ?? const Color(0xFF8B7D6B);
                      final bg =
                          categoryBgColors[cat] ?? const Color(0xFFF5EFE8);
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(categoryIcons[cat],
                                  size: 16, color: color),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              categoryLabels[cat] ?? cat.name,
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bagikan ke Tim (Public)'),
                    subtitle: Text(
                      _isPublic
                          ? 'Semua anggota tim bisa melihat catatan ini'
                          : 'Private: hanya Anda yang bisa melihat',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() => _isPublic = value);
                    },
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Format Markdown',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFormatButton(
                          icon: Icons.format_bold,
                          tooltip: 'Bold',
                          onTap: () => _wrapSelection(
                            '**',
                            '**',
                            placeholder: 'teks tebal',
                          ),
                        ),
                        _buildFormatButton(
                          icon: Icons.format_italic,
                          tooltip: 'Italic',
                          onTap: () => _wrapSelection(
                            '*',
                            '*',
                            placeholder: 'teks miring',
                          ),
                        ),
                        _buildFormatButton(
                          icon: Icons.title,
                          tooltip: 'Heading',
                          onTap: () =>
                              _prefixSelection('# ', placeholder: 'Judul'),
                        ),
                        _buildFormatButton(
                          icon: Icons.format_list_bulleted,
                          tooltip: 'Bullet List',
                          onTap: () => _prefixSelection('- '),
                        ),
                        _buildFormatButton(
                          icon: Icons.format_list_numbered,
                          tooltip: 'Numbered List',
                          onTap: () => _prefixSelection('1. '),
                        ),
                        _buildFormatButton(
                          icon: Icons.check_box_outlined,
                          tooltip: 'Checklist',
                          onTap: () => _prefixSelection('- [ ] '),
                        ),
                        _buildFormatButton(
                          icon: Icons.format_quote,
                          tooltip: 'Quote',
                          onTap: () =>
                              _prefixSelection('> ', placeholder: 'kutipan'),
                        ),
                        _buildFormatButton(
                          icon: Icons.code,
                          tooltip: 'Inline Code',
                          onTap: () => _wrapSelection(
                            '`',
                            '`',
                            placeholder: 'kode',
                          ),
                        ),
                        _buildFormatButton(
                          icon: Icons.link,
                          tooltip: 'Link',
                          onTap: () => _wrapSelection(
                            '[',
                            '](https://)',
                            placeholder: 'tautan',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _descController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: "Tulis laporan dengan format Markdown...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab 2: Rich Preview
            _buildPreview(),
          ],
        ),
      ),
    );
  }
}
