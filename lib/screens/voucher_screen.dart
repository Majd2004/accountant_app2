import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});
  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  late TabController _tabs;
  List<JournalEntry> _vouchers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => _load());
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  String get _currentType => _tabs.index == 0 ? 'قبض' : 'صرف';

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _db.getJournalEntries(type: _currentType);
    if (mounted) setState(() { _vouchers = entries; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سند قبض / صرف'),
          bottom: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'سند قبض'), Tab(text: 'سند صرف')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openVoucherDialog(),
          icon: const Icon(Icons.add),
          label: Text('سند $_currentType'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _vouchers.isEmpty
                ? EmptyState(message: 'لا توجد سندات $_currentType', icon: Icons.receipt_long)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _vouchers.length,
                    itemBuilder: (_, i) {
                      final e = _vouchers[i];
                      final isReceipt = e.entryType == 'قبض';
                      final total = e.lines.fold(0.0, (s, l) => s + l.debit);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isReceipt ? AppTheme.success : AppTheme.error).withAlpha(26),
                            child: Icon(isReceipt ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isReceipt ? AppTheme.success : AppTheme.error),
                          ),
                          title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Row(children: [
                            Text(formatDate(e.date), style: const TextStyle(fontSize: 12)),
                            if (e.reference != null) Flexible(child: Text(' • ${e.reference}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                          ]),
                          trailing: Text(
                            formatAmount(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isReceipt ? AppTheme.success : AppTheme.error,
                              fontSize: 14,
                            ),
                          ),
                          onLongPress: () => _confirmDelete(e),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _openVoucherDialog() async {
    final accounts = await _db.getAccounts();
    final cashAccounts = accounts.where((a) => a.category == AccountCategory.asset).toList();
    final otherAccounts = accounts;
    if (!mounted) return;

    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    Account? cashAccount;
    Account? otherAccount;
    String date = DateTime.now().toIso8601String().substring(0, 10);
    final isReceipt = _tabs.index == 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final currencyMismatch = cashAccount != null && otherAccount != null &&
              cashAccount!.currencyCode != otherAccount!.currencyCode;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Row(children: [
                Icon(isReceipt ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isReceipt ? AppTheme.success : AppTheme.error),
                const SizedBox(width: 8),
                Text('سند ${isReceipt ? 'قبض' : 'صرف'}'),
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
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(formatDate(date)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'المبلغ *'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Account>(
                    decoration: InputDecoration(labelText: isReceipt ? 'حساب الصندوق/البنك' : 'حساب الدفع'),
                    items: cashAccounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.currencyCode})', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setS(() => cashAccount = v),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Account>(
                    decoration: InputDecoration(labelText: isReceipt ? 'مصدر القبض' : 'جهة الصرف'),
                    items: otherAccounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.currencyCode})', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setS(() => otherAccount = v),
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
                          'الحسابان بعملتين مختلفتين. سيُسجَّل نفس الرقم بعملة كل حساب. إن لم يتطابق القيد بعملة الأساس ستظهر رسالة توازن؛ حدّث سعر الصرف من شاشة العملات إذا لزم.',
                          style: TextStyle(fontSize: 11, color: AppTheme.warning),
                        )),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'البيان *')),
                  const SizedBox(height: 12),
                  TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'رقم المرجع')),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0 || descCtrl.text.trim().isEmpty || cashAccount == null || otherAccount == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تأكد من ملء جميع الحقول'), backgroundColor: AppTheme.error));
                      return;
                    }
                    try {
                      final List<JournalLine> lines;
                      if (isReceipt) {
                        lines = [
                          JournalLine(accountId: cashAccount!.id!, accountName: cashAccount!.name, debit: amount),
                          JournalLine(accountId: otherAccount!.id!, accountName: otherAccount!.name, credit: amount),
                        ];
                      } else {
                        lines = [
                          JournalLine(accountId: otherAccount!.id!, accountName: otherAccount!.name, debit: amount),
                          JournalLine(accountId: cashAccount!.id!, accountName: cashAccount!.name, credit: amount),
                        ];
                      }
                      final entry = JournalEntry(
                        date: date,
                        description: descCtrl.text.trim(),
                        reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                        entryType: isReceipt ? 'قبض' : 'صرف',
                        lines: lines,
                      );
                      await _db.insertJournalEntry(entry);
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
          title: const Text('حذف السند'),
          content: Text('هل تريد حذف "${e.description}"؟ سيتم عكس جميع التأثيرات.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async {
                await _db.deleteJournalEntry(e.id!);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}
