import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  final _companyCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final company = await _db.getSetting('company_name');
    if (mounted) setState(() { _companyCtrl.text = company ?? ''; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'معلومات الشركة'),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة', prefixIcon: Icon(Icons.business))),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    await _db.setSetting('company_name', _companyCtrl.text.trim());
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ'), backgroundColor: AppTheme.success));
                  },
                  child: const Text('حفظ'),
                ),
              ]),
            )),
            const SizedBox(height: 16),
            const SectionHeader(title: 'العملات وأسعار الصرف'),
            Card(child: ListTile(
              leading: const Icon(Icons.currency_exchange, color: AppTheme.primary),
              title: const Text('إدارة العملات'),
              subtitle: const Text('تعديل أسعار الصرف وتحديد العملة الرئيسية'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.pushNamed(context, '/currencies'),
            )),
            const SizedBox(height: 16),
            const SectionHeader(title: 'سجل العمليات'),
            Card(child: ListTile(
              leading: const Icon(Icons.history, color: AppTheme.primary),
              title: const Text('سجل التدقيق'),
              subtitle: const Text('جميع العمليات المنجزة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _showAuditLog(),
            )),
            const SizedBox(height: 16),
            const SectionHeader(title: 'النسخ الاحتياطي'),
            Card(child: ListTile(
              leading: const Icon(Icons.backup, color: AppTheme.primary),
              title: const Text('النسخ الاحتياطي والاستعادة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.pushNamed(context, '/backup'),
            )),
          ],
        ),
      ),
    );
  }

  void _showAuditLog() async {
    final logs = await _db.getAuditLog(limit: 200);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          child: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(children: [
              AppBar(title: const Text('سجل التدقيق'), automaticallyImplyLeading: false,
                  actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
              Expanded(child: logs.isEmpty
                  ? const Center(child: Text('لا توجد عمليات'))
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (_, i) {
                        final l = logs[i];
                        final action = l['action'] as String;
                        final color = action == 'INSERT' ? AppTheme.success : action == 'DELETE' ? AppTheme.error : AppTheme.warning;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(backgroundColor: color.withAlpha(26), radius: 14,
                              child: Text(action.substring(0, 1), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))),
                          title: Text('${l['table_name']} #${l['record_id'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                          subtitle: Text(formatDate((l['created_at'] as String).substring(0, 10)), style: const TextStyle(fontSize: 11)),
                          trailing: Text(action, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                        );
                      },
                    )),
            ]),
          ),
        ),
      ),
    );
  }
}
