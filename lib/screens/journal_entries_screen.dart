import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class JournalEntriesScreen extends StatefulWidget {
  const JournalEntriesScreen({super.key});
  @override
  State<JournalEntriesScreen> createState() => _JournalEntriesScreenState();
}

class _JournalEntriesScreenState extends State<JournalEntriesScreen> {
  final _db = DatabaseHelper.instance;
  List<JournalEntry> _entries = [];
  bool _loading = true;
  DateTime? _from, _to;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fromStr = _from != null ? _from!.toIso8601String().substring(0, 10) : null;
    final toStr = _to != null ? _to!.toIso8601String().substring(0, 10) : null;
    final entries = await _db.getJournalEntries(dateFrom: fromStr, dateTo: toStr);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('القيود اليومية'),
          actions: [
            IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilter),
            if (_from != null || _to != null)
              IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() { _from = null; _to = null; }); _load(); }),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEntryEditor(),
          icon: const Icon(Icons.add),
          label: const Text('قيد جديد'),
        ),
        body: Column(children: [
          if (_from != null || _to != null)
            Container(
              color: AppTheme.primary.withAlpha(13),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.filter_alt, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('من: ${_from != null ? formatDate(_from!.toIso8601String()) : "---"} إلى: ${_to != null ? formatDate(_to!.toIso8601String()) : "---"}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
              ]),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const EmptyState(message: 'لا توجد قيود', icon: Icons.edit_document)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) {
                          final e = _entries[i];
                          final totalDebitBase = e.lines.fold(0.0, (s, l) => s + l.debitBase);
                          final totalCreditBase = e.lines.fold(0.0, (s, l) => s + l.creditBase);
                          final isBalanced = (totalDebitBase - totalCreditBase).abs() < 0.5;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withAlpha(26),
                                child: Text('${e.id}', style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Row(children: [
                                Text(formatDate(e.date), style: const TextStyle(fontSize: 12)),
                                if (e.reference != null) ...[
                                  const Text(' • ', style: TextStyle(fontSize: 12)),
                                  Flexible(child: Text(e.reference!, style: const TextStyle(fontSize: 12, color: AppTheme.primary), overflow: TextOverflow.ellipsis)),
                                ],
                              ]),
                              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(formatAmount(totalDebitBase, symbol: ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.success)),
                                Icon(isBalanced ? Icons.check_circle : Icons.warning,
                                    size: 16, color: isBalanced ? AppTheme.success : AppTheme.error),
                              ]),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(children: [
                                    Row(children: [
                                      Expanded(child: Text('الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600]))),
                                      SizedBox(width: 85, child: Text('مدين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                      SizedBox(width: 85, child: Text('دائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                    ]),
                                    const Divider(),
                                    ...e.lines.map((l) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(children: [
                                        Expanded(child: Text('${l.accountName}${l.currencyCode != 'IQD' ? ' (${l.currencyCode})' : ''}', style: const TextStyle(fontSize: 13))),
                                        SizedBox(width: 85, child: Text(l.debit > 0 ? formatAmount(l.debit, symbol: '') : '', style: const TextStyle(fontSize: 13, color: AppTheme.success), textAlign: TextAlign.center)),
                                        SizedBox(width: 85, child: Text(l.credit > 0 ? formatAmount(l.credit, symbol: '') : '', style: const TextStyle(fontSize: 13, color: AppTheme.error), textAlign: TextAlign.center)),
                                      ]),
                                    )),
                                    const Divider(),
                                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                      if (e.relatedInvoiceId == null) ...[
                                        TextButton.icon(
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text('تعديل'),
                                          onPressed: () => _openEntryEditor(entry: e),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          icon: const Icon(Icons.delete, size: 16, color: AppTheme.error),
                                          label: const Text('حذف', style: TextStyle(color: AppTheme.error)),
                                          onPressed: () => _confirmDelete(e),
                                        ),
                                      ] else
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Text('قيد تلقائي من فاتورة — للتعديل/الحذف استخدم شاشة الفواتير',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                                        ),
                                    ]),
                                  ]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  void _showFilter() async {
    DateTime? from = _from, to = _to;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تصفية القيود'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                title: Text('من: ${from != null ? formatDate(from!.toIso8601String()) : "غير محدد"}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: from ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setS(() => from = d);
                },
              ),
              ListTile(
                title: Text('إلى: ${to != null ? formatDate(to!.toIso8601String()) : "غير محدد"}'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: to ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setS(() => to = d);
                },
              ),
            ]),
            actions: [
              TextButton(onPressed: () { setState(() { _from = null; _to = null; }); Navigator.pop(ctx); _load(); }, child: const Text('مسح')),
              ElevatedButton(onPressed: () { setState(() { _from = from; _to = to; }); Navigator.pop(ctx); _load(); }, child: const Text('تطبيق')),
            ],
          ),
        ),
      ),
    );
  }

  void _openEntryEditor({JournalEntry? entry}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => JournalEntryEditor(entry: entry)))
        .then((_) => _load());
  }

  void _confirmDelete(JournalEntry e) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف القيد'),
          content: Text('سيتم حذف القيد "${e.description}" وعكس جميع تأثيراته على الأرصدة. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async {
                try {
                  await _db.deleteJournalEntry(e.id!);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (err) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$err'), backgroundColor: AppTheme.error));
                }
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== JOURNAL ENTRY EDITOR ====================

class JournalEntryEditor extends StatefulWidget {
  final JournalEntry? entry;
  const JournalEntryEditor({super.key, this.entry});
  @override
  State<JournalEntryEditor> createState() => _JournalEntryEditorState();
}

class _JournalEntryEditorState extends State<JournalEntryEditor> {
  final _db = DatabaseHelper.instance;
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  late String _date;
  List<_LineItem> _lines = [];
  List<Account> _accounts = [];
  List<Currency> _currencies = [];
  Currency? _baseCurrency;
  bool _saving = false;
  bool _loadingRefs = true;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now().toIso8601String().substring(0, 10);
    if (widget.entry != null) {
      final e = widget.entry!;
      _descCtrl.text = e.description;
      _refCtrl.text = e.reference ?? '';
      _date = e.date;
      _lines = e.lines.map((l) => _LineItem(accountId: l.accountId, accountName: l.accountName, debit: l.debit, credit: l.credit)).toList();
    }
    if (_lines.isEmpty) { _lines.add(_LineItem()); _lines.add(_LineItem()); }
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    final accounts = await _db.getAccounts();
    final currencies = await _db.getCurrencies();
    final baseCur = await _db.getDefaultCurrency();
    if (mounted) setState(() { _accounts = accounts; _currencies = currencies; _baseCurrency = baseCur; _loadingRefs = false; });
  }

  String _currencyForAccount(int? accountId) {
    if (accountId == null) return _baseCurrency?.code ?? 'IQD';
    final acc = _accounts.where((a) => a.id == accountId);
    return acc.isNotEmpty ? acc.first.currencyCode : (_baseCurrency?.code ?? 'IQD');
  }

  double _rateForCurrency(String code) {
    final c = _currencies.where((c) => c.code == code);
    return c.isNotEmpty ? c.first.exchangeRate : 1.0;
  }

  double _lineDebitBase(_LineItem l) => (l.debit ?? 0) * _rateForCurrency(_currencyForAccount(l.accountId));
  double _lineCreditBase(_LineItem l) => (l.credit ?? 0) * _rateForCurrency(_currencyForAccount(l.accountId));

  double get _totalDebitBase => _lines.fold(0.0, (s, l) => s + _lineDebitBase(l));
  double get _totalCreditBase => _lines.fold(0.0, (s, l) => s + _lineCreditBase(l));
  bool get _isBalanced => (_totalDebitBase - _totalCreditBase).abs() < 0.01 && _totalDebitBase > 0;

  @override
  Widget build(BuildContext context) {
    final baseSymbol = _baseCurrency?.symbol ?? '';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entry == null ? 'قيد جديد' : 'تعديل القيد'),
          actions: [
            if (!_saving)
              TextButton(
                onPressed: _isBalanced ? _save : null,
                child: Text('حفظ', style: TextStyle(color: _isBalanced ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: _loadingRefs
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Container(
                  color: _isBalanced ? AppTheme.success.withAlpha(26) : AppTheme.warning.withAlpha(26),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Icon(_isBalanced ? Icons.check_circle : Icons.info, size: 16,
                          color: _isBalanced ? AppTheme.success : AppTheme.warning),
                      const SizedBox(width: 6),
                      Text(_isBalanced ? 'القيد متوازن ✓' : 'الفرق: ${formatAmount((_totalDebitBase - _totalCreditBase).abs(), symbol: baseSymbol)}',
                          style: TextStyle(fontSize: 13, color: _isBalanced ? AppTheme.success : AppTheme.warning, fontWeight: FontWeight.bold)),
                    ]),
                    Flexible(child: Text('م: ${formatAmount(_totalDebitBase, symbol: baseSymbol)} | د: ${formatAmount(_totalCreditBase, symbol: baseSymbol)}',
                        style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: DateTime.parse(_date), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) setState(() => _date = d.toIso8601String().substring(0, 10));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(children: [
                                const Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text(formatDate(_date)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'المرجع'))),
                      ]),
                      const SizedBox(height: 12),
                      TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'البيان *'), maxLines: 2),
                      const SizedBox(height: 16),
                      const SectionHeader(title: 'سطور القيد'),
                      const SizedBox(height: 8),
                      ..._lines.asMap().entries.map((e) => _buildLine(e.key, e.value)),
                      TextButton.icon(
                        onPressed: () => setState(() => _lines.add(_LineItem())),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('إضافة سطر'),
                      ),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _buildLine(int index, _LineItem line) {
    final currencyCode = _currencyForAccount(line.accountId);
    final showCurrencyTag = currencyCode != (_baseCurrency?.code ?? 'IQD');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: line.accountId,
                decoration: const InputDecoration(labelText: 'الحساب', isDense: true),
                items: _accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(
                  a.currencyCode != (_baseCurrency?.code ?? 'IQD') ? '${a.name} (${a.currencyCode})' : a.name,
                  overflow: TextOverflow.ellipsis,
                ))).toList(),
                onChanged: (v) {
                  final acc = _accounts.firstWhere((a) => a.id == v);
                  setState(() { line.accountId = v; line.accountName = acc.name; });
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 6),
            if (_lines.length > 2)
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20),
                  onPressed: () => setState(() => _lines.removeAt(index))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(
              initialValue: line.debit != null && line.debit! > 0 ? line.debit!.toStringAsFixed(0) : '',
              decoration: InputDecoration(labelText: showCurrencyTag ? 'مدين ($currencyCode)' : 'مدين', isDense: true, prefixText: '+'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (v) => setState(() { line.debit = double.tryParse(v) ?? 0; if ((line.debit ?? 0) > 0) line.credit = 0; }),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(
              initialValue: line.credit != null && line.credit! > 0 ? line.credit!.toStringAsFixed(0) : '',
              decoration: InputDecoration(labelText: showCurrencyTag ? 'دائن ($currencyCode)' : 'دائن', isDense: true, prefixText: '-'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (v) => setState(() { line.credit = double.tryParse(v) ?? 0; if ((line.credit ?? 0) > 0) line.debit = 0; }),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل البيان'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _saving = true);
    try {
      final entry = JournalEntry(
        id: widget.entry?.id,
        date: _date,
        description: _descCtrl.text.trim(),
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        lines: _lines.where((l) => l.accountId != null && ((l.debit ?? 0) > 0 || (l.credit ?? 0) > 0)).map((l) => JournalLine(
          accountId: l.accountId!,
          accountName: l.accountName,
          debit: l.debit ?? 0,
          credit: l.credit ?? 0,
        )).toList(),
      );
      if (widget.entry == null) {
        await _db.insertJournalEntry(entry);
      } else {
        await _db.updateJournalEntry(entry);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }
}

class _LineItem {
  int? accountId;
  String accountName;
  double? debit;
  double? credit;
  _LineItem({this.accountId, this.accountName = '', this.debit, this.credit});
}
