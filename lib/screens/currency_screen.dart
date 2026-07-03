import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});
  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final _db = DatabaseHelper.instance;
  List<Currency> _currencies = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final currencies = await _db.getCurrencies();
    if (mounted) setState(() { _currencies = currencies; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('العملات وأسعار الصرف')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('عملة جديدة'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _currencies.isEmpty
                ? const EmptyState(message: 'لا توجد عملات', icon: Icons.currency_exchange)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _currencies.length,
                    itemBuilder: (_, i) {
                      final c = _currencies[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: c.isDefault ? AppTheme.primary.withAlpha(26) : Colors.grey[100],
                            child: Text(c.symbol.isEmpty ? c.code.substring(0, 1) : c.symbol,
                                style: TextStyle(fontWeight: FontWeight.bold, color: c.isDefault ? AppTheme.primary : Colors.grey[700], fontSize: 13)),
                          ),
                          title: Row(children: [
                            Flexible(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            if (c.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
                                child: const Text('الرئيسية', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                            ],
                          ]),
                          subtitle: Text('${c.code} • سعر الصرف: ${c.exchangeRate}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showEditDialog(c),
                              tooltip: 'تعديل السعر',
                            ),
                            IconButton(
                              icon: const Icon(Icons.history, size: 20),
                              onPressed: () => _showHistory(c),
                              tooltip: 'سجل الأسعار',
                            ),
                            if (!c.isDefault) ...[
                              IconButton(
                                icon: const Icon(Icons.star_border, size: 20, color: AppTheme.warning),
                                onPressed: () => _confirmSetDefault(c),
                                tooltip: 'جعلها الرئيسية',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                onPressed: () => _confirmDelete(c),
                                tooltip: 'حذف',
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة عملة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العملة *')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'الرمز (USD)'),
                  textCapitalization: TextCapitalization.characters)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: symbolCtrl, decoration: const InputDecoration(labelText: 'العلامة (\$)'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: rateCtrl, decoration: const InputDecoration(
              labelText: 'سعر الصرف مقابل العملة الرئيسية',
              helperText: 'مثال: 1 دولار = 1310 دينار → أدخل 1310',
            ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) return;
                try {
                  await _db.insertCurrency(Currency(
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().toUpperCase(),
                    symbol: symbolCtrl.text.trim(),
                    exchangeRate: double.tryParse(rateCtrl.text) ?? 1,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Currency c) {
    final nameCtrl = TextEditingController(text: c.name);
    final symbolCtrl = TextEditingController(text: c.symbol);
    final rateCtrl = TextEditingController(text: c.exchangeRate.toString());

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل ${c.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العملة')),
            const SizedBox(height: 10),
            TextField(controller: symbolCtrl, decoration: const InputDecoration(labelText: 'العلامة')),
            const SizedBox(height: 10),
            TextField(
              controller: rateCtrl,
              decoration: InputDecoration(
                labelText: c.isDefault ? 'سعر الصرف (ثابت = 1 للعملة الرئيسية)' : 'سعر الصرف',
                helperText: 'السعر الحالي: ${c.exchangeRate}',
                suffixIcon: const Icon(Icons.currency_exchange),
              ),
              enabled: !c.isDefault,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primary.withAlpha(13), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(child: Text('تغيير السعر سيُسجَّل تلقائياً في سجل التاريخ، ولن يؤثر على القيود السابقة (تبقى محفوظة بالسعر وقت تسجيلها).', style: TextStyle(fontSize: 11, color: AppTheme.primary))),
              ]),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                try {
                  c.name = nameCtrl.text.trim();
                  c.symbol = symbolCtrl.text.trim();
                  if (!c.isDefault) c.exchangeRate = double.tryParse(rateCtrl.text) ?? c.exchangeRate;
                  await _db.updateCurrency(c);
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
      ),
    );
  }

  void _showHistory(Currency c) async {
    final history = await _db.getCurrencyRateHistory(c.id!);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('سجل أسعار ${c.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: history.isEmpty
                ? const Center(child: Text('لا توجد تغييرات مسجلة'))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (_, i) {
                      final h = history[i];
                      final increased = h.newRate > h.oldRate;
                      return ListTile(
                        dense: true,
                        leading: Icon(increased ? Icons.trending_up : Icons.trending_down,
                            color: increased ? AppTheme.success : AppTheme.error, size: 20),
                        title: Text('${h.oldRate} → ${h.newRate}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(formatDate(h.changedAt.substring(0, 10)), style: const TextStyle(fontSize: 11)),
                        trailing: Text('${increased ? '+' : ''}${(h.newRate - h.oldRate).toStringAsFixed(2)}',
                            style: TextStyle(color: increased ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      ),
    );
  }

  void _confirmSetDefault(Currency c) async {
    final hasHistory = await _db.hasAnyTransactions();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير العملة الرئيسية'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ستصبح "${c.name}" هي العملة الرئيسية، وستُعاد حساب أسعار صرف كل العملات الأخرى نسبةً إليها تلقائياً.'),
            if (hasHistory) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.warning.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'لديك قيود مسجلة بالفعل. تغيير العملة الرئيسية الآن قد يجعل التقارير المجمّعة (ميزان المراجعة، قائمة الدخل، الميزانية) للفترات السابقة غير دقيقة، لأن تلك القيود محفوظة بمعادلها بعملة الأساس القديمة. يُفضّل تغيير العملة الرئيسية فقط في بداية استخدام التطبيق.',
                    style: TextStyle(fontSize: 11, color: AppTheme.warning),
                  )),
                ]),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: hasHistory ? AppTheme.warning : AppTheme.primary),
              onPressed: () async {
                try {
                  await _db.setDefaultCurrency(c.id!);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.name} أصبحت العملة الرئيسية'), backgroundColor: AppTheme.success));
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                }
              },
              child: Text(hasHistory ? 'متابعة رغم ذلك' : 'تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Currency c) async {
    final canDelete = await _db.canDeleteCurrency(c.id!);
    if (!mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكن حذف "${c.name}": إما رئيسية أو مستخدمة في حسابات'), backgroundColor: AppTheme.error));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف العملة'),
          content: Text('حذف "${c.name}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async {
                try {
                  await _db.deleteCurrency(c.id!);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
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
