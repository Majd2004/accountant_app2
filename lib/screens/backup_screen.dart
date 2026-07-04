import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _db = DatabaseHelper.instance;
  List<String> _backups = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _loadBackups(); }

  Future<void> _loadBackups() async {
    final backups = await _db.getBackupFiles();
    if (mounted) setState(() => _backups = backups);
  }

  String _formatBackupName(String path) {
    final name = path.split('/').last;
    return name.replaceAll('backup_', '').replaceAll('.db', '').replaceAll('T', ' ').replaceAll('-', '/').substring(0, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('النسخ الاحتياطي')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Backup card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Icon(Icons.backup, size: 48, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text('إنشاء نسخة احتياطية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('تحفظ بيانات التطبيق كاملة في ملف يمكنك مشاركته أو الاحتفاظ به',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(
                      onPressed: _loading ? null : _createBackup,
                      icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: Text(_loading ? 'جاري الحفظ...' : 'حفظ نسخة'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _loading ? null : _shareBackup,
                      icon: const Icon(Icons.share),
                      label: const Text('مشاركة'),
                    )),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // Restore card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Icon(Icons.restore, size: 48, color: AppTheme.warning),
                  const SizedBox(height: 12),
                  const Text('استعادة نسخة احتياطية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('اختر ملف نسخة احتياطية (.db) لاستعادة البيانات منه',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.error.withAlpha(13), borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [
                      Icon(Icons.warning, color: AppTheme.error, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text('تحذير: ستُحذف جميع البيانات الحالية عند الاستعادة', style: TextStyle(fontSize: 12, color: AppTheme.error))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                    onPressed: _loading ? null : _restoreBackup,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('اختيار ملف للاستعادة'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // Backup files list
            if (_backups.isNotEmpty) ...[
              const SectionHeader(title: 'النسخ الاحتياطية المحفوظة'),
              ..._backups.map((path) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.folder, color: AppTheme.primary),
                  title: Text(_formatBackupName(path), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(path.split('/').last, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.restore, size: 20, color: AppTheme.warning),
                      onPressed: () => _restoreFromFile(path),
                      tooltip: 'استعادة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: AppTheme.error),
                      onPressed: () => _deleteBackup(path),
                      tooltip: 'حذف',
                    ),
                  ]),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _loading = true);
    try {
      final path = await _db.backupDatabase();
      await _loadBackups();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم الحفظ: ${path.split('/').last}'),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _shareBackup() async {
    setState(() => _loading = true);
    try {
      await _db.shareBackup();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await _restoreFromFile(path);
  }

  Future<void> _restoreFromFile(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الاستعادة'),
          content: const Text('سيتم حذف جميع البيانات الحالية واستبدالها بالنسخة الاحتياطية. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await _db.restoreDatabase(path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الاستعادة. أعد تشغيل التطبيق.'), backgroundColor: AppTheme.success, duration: Duration(seconds: 5)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteBackup(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف النسخة'),
          content: const Text('هل تريد حذف هذه النسخة الاحتياطية؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await File(path).delete();
    _loadBackups();
  }
}
