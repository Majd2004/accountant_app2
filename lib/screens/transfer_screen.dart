import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _db = DatabaseHelper.instance;
  List<JournalEntry> _transfers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _db.getJournalEntries(type: 'حوالة');
    if (mounted) setState(() { _transfers = entries; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الحوالات')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openDialog,
          icon: const Icon(Icons.add),
          label: const Text('حوالة جديدة'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _transfers.isEmpty
                ? const EmptyState(message: 'لا توجد حوالات', icon: Icons.swap_horiz)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _transfers.length,
                    itemBuilder: (_, i) {
                      final e = _transfers[i];
                      final total = e.lines.fold(0.0, (s, l) => s + l.debit);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.swap_horiz, color: Color(0xFF1565C0)),
                          ),
                          title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(formatDate(e.date)),
                          trailing: Text(formatAmount(total),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          onLongPress: () => _confirmDelete(e),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _openDialog() async {
    final accounts = await _db.getAccounts();
    if (!mounted) return;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    Account? fromAccount, toAccount;
    String date = DateTime.now().toIso8601String().substring(0, 10);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final currencyMismatch = fromAccount != null && toAccount != null &&
              fromAccount!.currencyCode != toAccount!.currencyCode;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Row(children: [
                Icon(Icons.swap_horiz, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('حوالة جديدة'),
              ]),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: DateTime.parse(date), firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (d != null) setS(() => date = d.toIso8601String().substring(0, 10));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary), const SizedBox(width: 8), Text(formatDate(date))]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ *'),
                      keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Account>(
                    decoration: const InputDecoration(labelText: 'من حساب *'),
                    items: accounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.currencyCode})', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setS(() => fromAccount = v),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Account>(
                    decoration: const InputDecoration(labelText: 'إلى حساب *'),
                    items: accounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.currencyCode})', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setS(() => toAccount = v),
                    isExpanded: true,
                  ),
                  if (currencyMismatch)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.warning.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                      child: const Row(children: [
                        Icon(Icons.warning_amber, size: 16, color: AppTheme.warning),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'الحسابان بعملتين مختلفتين. سيُسجَّل نفس الرقم بعملة كل حساب. إن لم يتطابق القيد بعملة الأساس ستظهر رسالة توازن.',
                          style: TextStyle(fontSize: 11, color: AppTheme.warning),
                        )),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'البيان *')),
                  const SizedBox(height: 12),
                  TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'المرجع')),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0 || fromAccount == null || toAccount == null || descCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تأكد من ملء جميع الحقول'), backgroundColor: AppTheme.error));
                      return;
                    }
                    try {
                      await _db.insertJournalEntry(JournalEntry(
                        date: date,
                        description: descCtrl.text.trim(),
                        reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                        entryType: 'حوالة',
                        lines: [
                          JournalLine(accountId: toAccount!.id!, accountName: toAccount!.name, debit: amount),
                          JournalLine(accountId: fromAccount!.id!, accountName: fromAccount!.name, credit: amount),
                        ],
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(JournalEntry e) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحوالة'),
          content: Text('حذف "${e.description}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async { await _db.deleteJournalEntry(e.id!); if (ctx.mounted) Navigator.pop(ctx); _load(); },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}
