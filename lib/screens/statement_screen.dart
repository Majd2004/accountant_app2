import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});
  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final _db = DatabaseHelper.instance;
  List<Account> _accounts = [];
  Account? _selectedAccount;
  List<Map<String, dynamic>> _lines = [];
  bool _loading = false;
  DateTime? _from, _to;
  double _runningBalance = 0;

  @override
  void initState() { super.initState(); _loadAccounts(); }

  Future<void> _loadAccounts() async {
    final accounts = await _db.getAccounts();
    if (mounted) setState(() => _accounts = accounts);
  }

  Future<void> _loadStatement() async {
    if (_selectedAccount == null) return;
    setState(() => _loading = true);
    final fromStr = _from?.toIso8601String().substring(0, 10);
    final toStr = _to?.toIso8601String().substring(0, 10);
    final lines = await _db.getAccountStatement(_selectedAccount!.id!, dateFrom: fromStr, dateTo: toStr);
    double balance = 0;
    final processed = lines.map((l) {
      balance += (l['debit'] as num).toDouble() - (l['credit'] as num).toDouble();
      return {...l, 'running_balance': balance};
    }).toList();
    if (mounted) setState(() { _lines = processed; _runningBalance = balance; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDebitSide = _runningBalance >= 0;
    final isNormal = _selectedAccount != null && (isDebitSide == _selectedAccount!.category.isDebitNormal);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('كشف حساب')),
        body: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              DropdownButtonFormField<Account>(
                value: _selectedAccount,
                decoration: const InputDecoration(labelText: 'اختر الحساب', prefixIcon: Icon(Icons.account_circle)),
                items: _accounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.category.nameAr})', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) { setState(() { _selectedAccount = v; _lines = []; }); if (v != null) _loadStatement(); },
                isExpanded: true,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) { setState(() => _from = d); _loadStatement(); }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(_from != null ? formatDate(_from!.toIso8601String()) : 'من تاريخ', style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) { setState(() => _to = d); _loadStatement(); }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(_to != null ? formatDate(_to!.toIso8601String()) : 'إلى تاريخ', style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                )),
                if (_from != null || _to != null) IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () { setState(() { _from = null; _to = null; }); _loadStatement(); },
                ),
              ]),
            ]),
          ),
          if (_selectedAccount != null && _lines.isNotEmpty)
            Container(
              color: AppTheme.primary.withAlpha(13),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${_lines.length} حركة', style: const TextStyle(fontSize: 13, color: AppTheme.primary)),
                Text(
                  'الرصيد: ${formatAmount(_runningBalance.abs(), symbol: _selectedAccount!.currencyCode)} ${isDebitSide ? 'مدين' : 'دائن'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: isNormal ? AppTheme.success : AppTheme.warning),
                ),
              ]),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lines.isEmpty
                    ? EmptyState(
                        message: _selectedAccount == null ? 'اختر حساباً لعرض كشفه' : 'لا توجد حركات للحساب المحدد',
                        icon: Icons.account_balance,
                      )
                    : Column(children: [
                        Container(
                          color: Colors.grey[100],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(children: [
                            const SizedBox(width: 70, child: Text('التاريخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            const Expanded(child: Text('البيان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 70, child: Text('مدين', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            const SizedBox(width: 70, child: Text('دائن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            const SizedBox(width: 80, child: Text('الرصيد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          ]),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _lines.length,
                            itemBuilder: (_, i) {
                              final l = _lines[i];
                              final debit = (l['debit'] as num).toDouble();
                              final credit = (l['credit'] as num).toDouble();
                              final bal = (l['running_balance'] as num).toDouble();
                              return Container(
                                decoration: BoxDecoration(
                                  color: i.isOdd ? Colors.grey[50] : Colors.white,
                                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Row(children: [
                                  SizedBox(width: 70, child: Text(formatDate(l['date'] as String), style: const TextStyle(fontSize: 11))),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(l['description'] as String, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                    if (l['reference'] != null) Text(l['reference'] as String, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                  ])),
                                  SizedBox(width: 70, child: Text(debit > 0 ? formatAmount(debit, symbol: '') : '', style: const TextStyle(fontSize: 12, color: AppTheme.success), textAlign: TextAlign.center)),
                                  SizedBox(width: 70, child: Text(credit > 0 ? formatAmount(credit, symbol: '') : '', style: const TextStyle(fontSize: 12, color: AppTheme.error), textAlign: TextAlign.center)),
                                  SizedBox(width: 80, child: Text(formatAmount(bal.abs(), symbol: ''),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bal >= 0 ? AppTheme.success : AppTheme.error), textAlign: TextAlign.center)),
                                ]),
                              );
                            },
                          ),
                        ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
