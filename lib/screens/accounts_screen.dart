import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  List<Account> _accounts = [];
  bool _loading = true;
  late TabController _tabs;

  final _categories = [
    {'key': null, 'label': 'الكل'},
    {'key': 'asset', 'label': 'أصول'},
    {'key': 'liability', 'label': 'خصوم'},
    {'key': 'equity', 'label': 'ملكية'},
    {'key': 'revenue', 'label': 'إيرادات'},
    {'key': 'expense', 'label': 'مصروفات'},
  ];

  int _selectedCat = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _tabs.addListener(() { setState(() => _selectedCat = _tabs.index); _load(); });
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cat = _categories[_selectedCat]['key'];
    final accounts = await _db.getAccounts(category: cat);
    if (mounted) setState(() { _accounts = accounts; _loading = false; });
  }

  Color _categoryColor(AccountCategory c) {
    switch (c) {
      case AccountCategory.asset: return const Color(0xFF1976D2);
      case AccountCategory.liability: return const Color(0xFFD32F2F);
      case AccountCategory.equity: return const Color(0xFF6A1B9A);
      case AccountCategory.revenue: return const Color(0xFF388E3C);
      case AccountCategory.expense: return const Color(0xFFF57C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دليل الحسابات'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: _categories.map((c) => Tab(text: c['label'] as String)).toList(),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAccountDialog(),
          icon: const Icon(Icons.add),
          label: const Text('حساب جديد'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _accounts.isEmpty
                ? const EmptyState(message: 'لا توجد حسابات', icon: Icons.menu_book)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _accounts.length,
                    itemBuilder: (_, i) {
                      final a = _accounts[i];
                      final color = _categoryColor(a.category);
                      final display = accountDisplayBalance(a);
                      final displayColor = display.isNormal ? AppTheme.success : AppTheme.warning;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withAlpha(26),
                            child: Icon(Icons.account_circle, color: color),
                          ),
                          title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${a.category.nameAr} • ${a.type} • ${a.currencyCode}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(
                              formatAmount(display.amount, symbol: a.currencyCode),
                              style: TextStyle(fontWeight: FontWeight.bold, color: displayColor, fontSize: 14),
                            ),
                            Text(display.label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ]),
                          onTap: () => _showAccountDialog(account: a),
                          onLongPress: () => _confirmDelete(a),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showAccountDialog({Account? account}) {
    final isEdit = account != null;
    final nameCtrl = TextEditingController(text: account?.name ?? '');
    final typeCtrl = TextEditingController(text: account?.type ?? '');
    final notesCtrl = TextEditingController(text: account?.notes ?? '');
    var selectedCategory = account?.category ?? AccountCategory.asset;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEdit ? 'تعديل الحساب' : 'حساب جديد'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الحساب *')),
                const SizedBox(height: 12),
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'نوع الحساب (عميل، مورد...)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: AccountCategory.values.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.nameAr),
                  )).toList(),
                  onChanged: (v) { if (v != null) setS(() => selectedCategory = v); },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha(13), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'نصيحة: حساب أي عميل يُصنَّف "أصول" (لأنه يدين لك)، وحساب أي مورد يُصنَّف "خصوم" (لأنك تدين له).',
                      style: TextStyle(fontSize: 11, color: AppTheme.primary),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 2),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    if (isEdit) {
                      account!.name = nameCtrl.text.trim();
                      account.type = typeCtrl.text.trim();
                      account.category = selectedCategory;
                      account.notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
                      await _db.updateAccount(account);
                    } else {
                      await _db.insertAccount(Account(
                        name: nameCtrl.text.trim(),
                        type: typeCtrl.text.trim(),
                        category: selectedCategory,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      ));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.error));
                  }
                },
                child: Text(isEdit ? 'حفظ' : 'إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Account a) async {
    final canDelete = await _db.canDeleteAccount(a.id!);
    if (!mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا يمكن حذف حساب له قيود مسجلة'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحساب'),
          content: Text('هل تريد حذف "${a.name}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async {
                await _db.deleteAccount(a.id!);
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
