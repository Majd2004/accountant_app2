import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير المالية'),
          bottom: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'ميزان المراجعة'), Tab(text: 'قائمة الدخل'), Tab(text: 'الميزانية العمومية')],
          ),
        ),
        body: TabBarView(controller: _tabs, children: const [
          _TrialBalanceTab(),
          _IncomeStatementTab(),
          _BalanceSheetTab(),
        ]),
      ),
    );
  }
}

// ==================== TRIAL BALANCE ====================

class _TrialBalanceTab extends StatefulWidget {
  const _TrialBalanceTab();
  @override
  State<_TrialBalanceTab> createState() => _TrialBalanceTabState();
}

class _TrialBalanceTabState extends State<_TrialBalanceTab> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _baseSymbol = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getTrialBalance();
    final cur = await _db.getDefaultCurrency();
    if (mounted) setState(() { _rows = rows; _baseSymbol = cur?.symbol ?? ''; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) return const EmptyState(message: 'لا توجد قيود بعد', icon: Icons.balance);

    double totalDebit = 0, totalCredit = 0;
    for (var r in _rows) {
      totalDebit += (r['total_debit'] as num).toDouble();
      totalCredit += (r['total_credit'] as num).toDouble();
    }
    final balanced = (totalDebit - totalCredit).abs() < 1;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: (balanced ? AppTheme.success : AppTheme.error).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(balanced ? Icons.check_circle : Icons.warning, color: balanced ? AppTheme.success : AppTheme.error, size: 18),
              const SizedBox(width: 8),
              Text(balanced ? 'الميزان متوازن ✓ (بعملة الأساس)' : 'تحذير: الميزان غير متوازن!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: balanced ? AppTheme.success : AppTheme.error, fontSize: 13)),
            ]),
          ),
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const Expanded(flex: 2, child: Text('مدين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              const Expanded(flex: 2, child: Text('دائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
            ]),
          ),
          ..._rows.map((r) {
            final debit = (r['total_debit'] as num).toDouble();
            final credit = (r['total_credit'] as num).toDouble();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
              child: Row(children: [
                Expanded(flex: 3, child: Text(r['name'] as String, style: const TextStyle(fontSize: 13))),
                Expanded(flex: 2, child: Text(debit > 0 ? formatAmount(debit, symbol: '') : '-', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(credit > 0 ? formatAmount(credit, symbol: '') : '-', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
              ]),
            );
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 2, child: Text(formatAmount(totalDebit, symbol: _baseSymbol), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text(formatAmount(totalCredit, symbol: _baseSymbol), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ==================== INCOME STATEMENT ====================

class _IncomeStatementTab extends StatefulWidget {
  const _IncomeStatementTab();
  @override
  State<_IncomeStatementTab> createState() => _IncomeStatementTabState();
}

class _IncomeStatementTabState extends State<_IncomeStatementTab> {
  final _db = DatabaseHelper.instance;
  Map<String, dynamic>? _data;
  bool _loading = true;
  DateTime? _from, _to;
  String _baseSymbol = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getIncomeStatement(
      dateFrom: _from?.toIso8601String().substring(0, 10),
      dateTo: _to?.toIso8601String().substring(0, 10),
    );
    final cur = await _db.getDefaultCurrency();
    if (mounted) setState(() { _data = data; _baseSymbol = cur?.symbol ?? ''; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) { setState(() => _from = d); _load(); }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(_from != null ? formatDate(_from!.toIso8601String()) : 'من تاريخ', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) { setState(() => _to = d); _load(); }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(_to != null ? formatDate(_to!.toIso8601String()) : 'إلى تاريخ (الكل)', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          )),
          if (_from != null || _to != null)
            IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { setState(() { _from = null; _to = null; }); _load(); }),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_data == null || ((_data!['revenues'] as List).isEmpty && (_data!['expenses'] as List).isEmpty))
                ? const EmptyState(message: 'لا توجد بيانات لهذه الفترة', icon: Icons.trending_up)
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const SectionHeader(title: 'الإيرادات'),
                      ...(_data!['revenues'] as List<Map<String, dynamic>>).map((r) => _row(r['name'] as String, r['amount'] as double, AppTheme.success)),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('إجمالي الإيرادات', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(formatAmount(_data!['total_revenue'] as double, symbol: _baseSymbol), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                        ]),
                      ),
                      const Divider(),
                      const SectionHeader(title: 'المصروفات (وتكلفة البضاعة المباعة)'),
                      ...(_data!['expenses'] as List<Map<String, dynamic>>).map((r) => _row(r['name'] as String, r['amount'] as double, AppTheme.error)),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('إجمالي المصروفات', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(formatAmount(_data!['total_expense'] as double, symbol: _baseSymbol), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                        ]),
                      ),
                      const Divider(thickness: 2),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ((_data!['net_income'] as double) >= 0 ? AppTheme.success : AppTheme.error).withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text((_data!['net_income'] as double) >= 0 ? 'صافي الربح' : 'صافي الخسارة',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(formatAmount((_data!['net_income'] as double).abs(), symbol: _baseSymbol),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                                  color: (_data!['net_income'] as double) >= 0 ? AppTheme.success : AppTheme.error)),
                        ]),
                      ),
                    ],
                  ),
      ),
    ]);
  }

  Widget _row(String name, double amount, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
      Text(formatAmount(amount, symbol: ''), style: TextStyle(fontSize: 13, color: color)),
    ]),
  );
}

// ==================== BALANCE SHEET ====================

class _BalanceSheetTab extends StatefulWidget {
  const _BalanceSheetTab();
  @override
  State<_BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends State<_BalanceSheetTab> {
  final _db = DatabaseHelper.instance;
  Map<String, dynamic>? _data;
  bool _loading = true;
  DateTime? _asOf;
  String _baseSymbol = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getBalanceSheet(asOfDate: _asOf?.toIso8601String().substring(0, 10));
    final cur = await _db.getDefaultCurrency();
    if (mounted) setState(() { _data = data; _baseSymbol = cur?.symbol ?? ''; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _asOf ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (d != null) { setState(() => _asOf = d); _load(); }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('كما في: ${_asOf != null ? formatDate(_asOf!.toIso8601String()) : "اليوم"}', style: const TextStyle(fontSize: 12)),
              const Spacer(),
              if (_asOf != null) IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { setState(() => _asOf = null); _load(); }),
            ]),
          ),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const EmptyState(message: 'لا توجد بيانات', icon: Icons.account_balance)
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: ((_data!['balanced'] as bool) ? AppTheme.success : AppTheme.error).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon((_data!['balanced'] as bool) ? Icons.check_circle : Icons.warning,
                              color: (_data!['balanced'] as bool) ? AppTheme.success : AppTheme.error, size: 16),
                          const SizedBox(width: 8),
                          Text((_data!['balanced'] as bool) ? 'الأصول = الخصوم + حقوق الملكية ✓' : 'تحذير: عدم توازن',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: (_data!['balanced'] as bool) ? AppTheme.success : AppTheme.error)),
                        ]),
                      ),
                      const SectionHeader(title: 'الأصول'),
                      ...(_data!['assets'] as List<Map<String, dynamic>>).map((r) => _row(r['name'] as String, r['amount'] as double)),
                      _totalLine('إجمالي الأصول', _data!['total_assets'] as double, AppTheme.primary),
                      const SizedBox(height: 16),
                      const SectionHeader(title: 'الخصوم'),
                      ...(_data!['liabilities'] as List<Map<String, dynamic>>).map((r) => _row(r['name'] as String, r['amount'] as double)),
                      _totalLine('إجمالي الخصوم', _data!['total_liabilities'] as double, AppTheme.error),
                      const SizedBox(height: 16),
                      const SectionHeader(title: 'حقوق الملكية'),
                      ...(_data!['equity'] as List<Map<String, dynamic>>).map((r) => _row(r['name'] as String, r['amount'] as double)),
                      _row('الأرباح المدورة (محسوبة تلقائياً)', _data!['retained_earnings'] as double),
                      _totalLine('إجمالي حقوق الملكية', _data!['total_equity'] as double, const Color(0xFF6A1B9A)),
                      const SizedBox(height: 16),
                      _totalLine('إجمالي الخصوم + حقوق الملكية',
                          (_data!['total_liabilities'] as double) + (_data!['total_equity'] as double), AppTheme.primary),
                    ],
                  ),
      ),
    ]);
  }

  Widget _row(String name, double amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
      Text(formatAmount(amount, symbol: ''), style: const TextStyle(fontSize: 13)),
    ]),
  );

  Widget _totalLine(String label, double amount, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    margin: const EdgeInsets.only(top: 4),
    decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      Text(formatAmount(amount, symbol: _baseSymbol), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
    ]),
  );
}
