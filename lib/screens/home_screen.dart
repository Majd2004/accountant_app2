import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  Map<String, double> _summary = {};
  bool _loading = true;
  String _currencySymbol = 'د.ع';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _db.getFinancialSummary();
    final cur = await _db.getDefaultCurrency();
    if (mounted) setState(() {
      _summary = summary;
      _currencySymbol = cur?.symbol ?? 'د.ع';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('المحاسب الشامل'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.pushNamed(context, '/search')),
            IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, '/settings').then((_) => _load())),
          ],
        ),
        drawer: _buildDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildFinancialCards(),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'العمليات السريعة'),
                    const SizedBox(height: 8),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'الإدارة'),
                    const SizedBox(height: 8),
                    _buildManagementGrid(),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final netIncome = _summary['net_income'] ?? 0;
    final isProfit = netIncome >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(77), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          const Text('الوضع المالي العام (بعملة الأساس)', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatAmount(_summary['assets'] ?? 0, symbol: _currencySymbol),
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        const Text('إجمالي الأصول', style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(isProfit ? Icons.trending_up : Icons.trending_down,
                color: isProfit ? Colors.greenAccent : Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(
              '${isProfit ? 'ربح' : 'خسارة'}: ${formatAmount(netIncome.abs(), symbol: _currencySymbol)}',
              style: TextStyle(
                color: isProfit ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold, fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFinancialCards() {
    final cards = [
      {'label': 'الأصول', 'key': 'assets', 'icon': Icons.account_balance_wallet, 'color': const Color(0xFF1976D2)},
      {'label': 'الخصوم', 'key': 'liabilities', 'icon': Icons.money_off, 'color': const Color(0xFFD32F2F)},
      {'label': 'الإيرادات', 'key': 'revenue', 'icon': Icons.trending_up, 'color': const Color(0xFF388E3C)},
      {'label': 'المصروفات', 'key': 'expenses', 'icon': Icons.payment, 'color': const Color(0xFFF57C00)},
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards.map((c) {
        final value = _summary[c['key'] as String] ?? 0;
        final color = c['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(right: BorderSide(color: color, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(c['icon'] as IconData, color: color, size: 22),
            const SizedBox(height: 6),
            Text(c['label'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(formatAmount(value, symbol: _currencySymbol),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'label': 'قيد جديد', 'icon': Icons.edit_document, 'color': const Color(0xFF1565C0), 'route': '/journal'},
      {'label': 'سند', 'icon': Icons.receipt_long, 'color': const Color(0xFF2E7D32), 'route': '/voucher'},
      {'label': 'حوالة', 'icon': Icons.swap_horiz, 'color': const Color(0xFF0277BD), 'route': '/transfer'},
      {'label': 'فاتورة', 'icon': Icons.description, 'color': const Color(0xFFE65100), 'route': '/invoice'},
    ];
    return Row(
      children: actions.map((a) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, a['route'] as String).then((_) => _load()),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: (a['color'] as Color).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (a['color'] as Color).withAlpha(77)),
              ),
              child: Column(children: [
                Icon(a['icon'] as IconData, color: a['color'] as Color, size: 26),
                const SizedBox(height: 6),
                Text(a['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: a['color'] as Color)),
              ]),
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildManagementGrid() {
    final items = [
      {'label': 'دليل الحسابات', 'icon': Icons.menu_book, 'color': const Color(0xFF6A1B9A), 'route': '/accounts'},
      {'label': 'كشف حساب', 'icon': Icons.account_balance, 'color': const Color(0xFF00838F), 'route': '/statement'},
      {'label': 'التقارير المالية', 'icon': Icons.bar_chart, 'color': const Color(0xFFAD1457), 'route': '/reports'},
      {'label': 'المنتجات', 'icon': Icons.inventory_2, 'color': const Color(0xFF2E7D32), 'route': '/products'},
      {'label': 'المخازن', 'icon': Icons.warehouse, 'color': const Color(0xFF4E342E), 'route': '/warehouses'},
      {'label': 'العملات', 'icon': Icons.currency_exchange, 'color': const Color(0xFF00695C), 'route': '/currencies'},
      {'label': 'نسخ احتياطي', 'icon': Icons.backup, 'color': const Color(0xFF1565C0), 'route': '/backup'},
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.1,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items.map((item) {
        final color = item['color'] as Color;
        return InkWell(
          onTap: () => Navigator.pushNamed(context, item['route'] as String).then((_) => _load()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4)],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
                child: Icon(item['icon'] as IconData, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(item['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.account_balance, size: 48, color: Colors.white),
              const SizedBox(height: 10),
              const Text('المحاسب الشامل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('نظام محاسبة متكامل', style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 13)),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              _tile(Icons.home, 'الرئيسية', () { Navigator.pop(context); }),
              _tile(Icons.edit_document, 'القيود اليومية', () { Navigator.pop(context); Navigator.pushNamed(context, '/journal').then((_) => _load()); }),
              _tile(Icons.receipt_long, 'سند قبض/صرف', () { Navigator.pop(context); Navigator.pushNamed(context, '/voucher').then((_) => _load()); }),
              _tile(Icons.swap_horiz, 'حوالة', () { Navigator.pop(context); Navigator.pushNamed(context, '/transfer').then((_) => _load()); }),
              _tile(Icons.description, 'الفواتير', () { Navigator.pop(context); Navigator.pushNamed(context, '/invoice').then((_) => _load()); }),
              const Divider(),
              _tile(Icons.menu_book, 'دليل الحسابات', () { Navigator.pop(context); Navigator.pushNamed(context, '/accounts').then((_) => _load()); }),
              _tile(Icons.account_balance, 'كشف حساب', () { Navigator.pop(context); Navigator.pushNamed(context, '/statement'); }),
              _tile(Icons.bar_chart, 'التقارير المالية', () { Navigator.pop(context); Navigator.pushNamed(context, '/reports'); }),
              _tile(Icons.inventory_2, 'المنتجات', () { Navigator.pop(context); Navigator.pushNamed(context, '/products'); }),
              _tile(Icons.warehouse, 'المخازن', () { Navigator.pop(context); Navigator.pushNamed(context, '/warehouses'); }),
              _tile(Icons.currency_exchange, 'العملات وأسعار الصرف', () { Navigator.pop(context); Navigator.pushNamed(context, '/currencies').then((_) => _load()); }),
              const Divider(),
              _tile(Icons.backup, 'النسخ الاحتياطي', () { Navigator.pop(context); Navigator.pushNamed(context, '/backup'); }),
              _tile(Icons.settings, 'الإعدادات', () { Navigator.pop(context); Navigator.pushNamed(context, '/settings').then((_) => _load()); }),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: AppTheme.primary, size: 22),
    title: Text(title, style: const TextStyle(fontSize: 14)),
    onTap: onTap,
  );
}
