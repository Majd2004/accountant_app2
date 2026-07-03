import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  List<Invoice> _invoices = [];
  bool _loading = true;
  late TabController _tabs;

  final _types = ['بيع', 'شراء', 'مرتجع بيع', 'مرتجع شراء'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _types.length, vsync: this);
    _tabs.addListener(() => _load());
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final invoices = await _db.getInvoices(type: _types[_tabs.index]);
    if (mounted) setState(() { _invoices = invoices; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الفواتير'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: _types.map((t) => Tab(text: t)).toList(),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openInvoiceEditor(),
          icon: const Icon(Icons.add),
          label: Text('فاتورة ${_types[_tabs.index]}'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _invoices.isEmpty
                ? EmptyState(message: 'لا توجد فواتير ${_types[_tabs.index]}', icon: Icons.description)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _invoices.length,
                    itemBuilder: (_, i) {
                      final inv = _invoices[i];
                      final isPaid = inv.remaining <= 0.01;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isPaid ? AppTheme.success.withAlpha(26) : AppTheme.warning.withAlpha(26),
                            child: Icon(Icons.description, color: isPaid ? AppTheme.success : AppTheme.warning),
                          ),
                          title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Row(children: [
                            Text(formatDate(inv.date), style: const TextStyle(fontSize: 12)),
                            if (inv.accountName != null) Flexible(child: Text(' • ${inv.accountName}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                          ]),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(formatAmount(inv.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (!isPaid) Text('متبقي: ${formatAmount(inv.remaining)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.error)),
                          ]),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(children: [
                                if (inv.items.isNotEmpty) ...[
                                  ...inv.items.map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(children: [
                                      Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13))),
                                      Text('${item.quantity} × ${formatAmount(item.unitPrice, symbol: '')}', style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Text(formatAmount(item.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ]),
                                  )),
                                  const Divider(),
                                ],
                                if (inv.tax > 0)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      const Text('الضريبة', style: TextStyle(fontSize: 12)),
                                      Text(formatAmount(inv.tax), style: const TextStyle(fontSize: 12)),
                                    ]),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    const Text('المدفوع', style: TextStyle(fontSize: 12)),
                                    Text(formatAmount(inv.paid), style: const TextStyle(fontSize: 12, color: AppTheme.success)),
                                  ]),
                                ),
                                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  if (!isPaid)
                                    TextButton.icon(
                                      icon: const Icon(Icons.payments, size: 16, color: AppTheme.success),
                                      label: const Text('تسجيل دفعة', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                                      onPressed: () => _showPaymentDialog(inv),
                                    ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, size: 16, color: AppTheme.error),
                                    label: const Text('حذف', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                                    onPressed: () => _confirmDelete(inv),
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
    );
  }

  void _openInvoiceEditor() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceEditor(type: _types[_tabs.index])))
        .then((_) => _load());
  }

  void _showPaymentDialog(Invoice inv) async {
    final accounts = await _db.getAccounts();
    final defaultCur = await _db.getDefaultCurrency();
    final cashAccounts = accounts.where((a) =>
        a.category == AccountCategory.asset && a.currencyCode == (defaultCur?.code ?? 'IQD')).toList();
    if (!mounted) return;

    final amountCtrl = TextEditingController(text: inv.remaining.toStringAsFixed(0));
    final notesCtrl = TextEditingController();
    Account? cashAccount = cashAccounts.isNotEmpty ? cashAccounts.first : null;
    String date = DateTime.now().toIso8601String().substring(0, 10);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تسجيل دفعة — ${inv.invoiceNumber}'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha(13), borderRadius: BorderRadius.circular(8)),
                  child: Text('المتبقي حالياً: ${formatAmount(inv.remaining)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'مبلغ الدفعة *'),
                    keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
                const SizedBox(height: 12),
                DropdownButtonFormField<Account>(
                  value: cashAccount,
                  decoration: const InputDecoration(labelText: 'حساب الاستلام/الدفع *'),
                  items: cashAccounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setS(() => cashAccount = v),
                  isExpanded: true,
                ),
                const SizedBox(height: 12),
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
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount <= 0 || cashAccount == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تأكد من المبلغ والحساب'), backgroundColor: AppTheme.error));
                    return;
                  }
                  try {
                    await _db.recordInvoicePayment(
                      invoiceId: inv.id!,
                      amount: amount,
                      date: date,
                      cashAccountId: cashAccount!.id!,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                  }
                },
                child: const Text('تسجيل'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Invoice inv) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الفاتورة'),
          content: Text('سيتم حذف فاتورة "${inv.invoiceNumber}" وعكس أثرها على المخزون والقيود المحاسبية (بما فيها أي دفعات مسجلة عليها).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async {
                try {
                  await _db.deleteInvoice(inv.id!);
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

class InvoiceEditor extends StatefulWidget {
  final String type;
  const InvoiceEditor({super.key, required this.type});
  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  final _db = DatabaseHelper.instance;
  List<Account> _partyAccounts = []; // عملاء/موردين بعملة الأساس
  List<Account> _cashAccounts = []; // صناديق/بنوك بعملة الأساس
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  List<_InvoiceItemRow> _items = [];
  Account? _selectedAccount;
  Account? _selectedCashAccount;
  Warehouse? _selectedWarehouse;
  final _discountCtrl = TextEditingController(text: '0');
  final _taxPercentCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  bool _saving = false;
  bool _loadingRefs = true;
  String _baseCurrencyCode = 'IQD';

  bool get _isSale => widget.type == 'بيع';
  bool get _isPurchase => widget.type == 'شراء';

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final accounts = await _db.getAccounts();
    final products = await _db.getProducts();
    final warehouses = await _db.getWarehouses();
    final defaultCur = await _db.getDefaultCurrency();
    final baseCode = defaultCur?.code ?? 'IQD';
    if (mounted) {
      setState(() {
        _partyAccounts = accounts.where((a) => a.currencyCode == baseCode).toList();
        _cashAccounts = accounts.where((a) => a.category == AccountCategory.asset && a.currencyCode == baseCode).toList();
        _products = products;
        _warehouses = warehouses;
        _baseCurrencyCode = baseCode;
        _loadingRefs = false;
      });
    }
    if (_items.isEmpty) setState(() => _items.add(_InvoiceItemRow()));
  }

  double get _subtotal => _items.fold(0, (s, i) => s + i.total);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _taxPercent => double.tryParse(_taxPercentCtrl.text) ?? 0;
  double get _tax => (_subtotal - _discount) * _taxPercent / 100;
  double get _total => _subtotal - _discount + _tax;
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _remaining => _total - _paid;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('فاتورة ${widget.type}'),
          actions: [
            if (!_saving)
              TextButton(onPressed: _save, child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
        body: _loadingRefs
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: AppTheme.primary.withAlpha(13), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(child: Text('كل مبالغ الفاتورة بعملة الأساس ($_baseCurrencyCode) لضمان دقة القيد المحاسبي',
                            style: const TextStyle(fontSize: 11, color: AppTheme.primary))),
                      ]),
                    ),
                  Card(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: DateTime.parse(_date), firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (d != null) setState(() => _date = d.toIso8601String().substring(0, 10));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary), const SizedBox(width: 8), Text(formatDate(_date))]),
                          ),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: DropdownButtonFormField<Warehouse?>(
                          value: _selectedWarehouse,
                          decoration: const InputDecoration(labelText: 'المخزن', isDense: true),
                          items: [const DropdownMenuItem(value: null, child: Text('بدون مخزن')),
                            ..._warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w.name)))],
                          onChanged: (v) => setState(() => _selectedWarehouse = v),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<Account>(
                        value: _selectedAccount,
                        decoration: InputDecoration(labelText: _isPurchase ? 'المورد *' : 'العميل *'),
                        items: _partyAccounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _selectedAccount = v),
                        isExpanded: true,
                      ),
                      if (_partyAccounts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('لا يوجد حساب بعملة الأساس بعد. أنشئ حساب عميل/مورد من دليل الحسابات أولاً.',
                              style: TextStyle(fontSize: 11, color: AppTheme.error)),
                        ),
                    ]),
                  )),
                  const SizedBox(height: 12),
                  const SectionHeader(title: 'بنود الفاتورة'),
                  const SizedBox(height: 8),
                  ..._items.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
                  TextButton.icon(
                    onPressed: () => setState(() => _items.add(_InvoiceItemRow())),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('إضافة بند'),
                  ),
                  const SizedBox(height: 12),
                  Card(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      _totalRow('الإجمالي الفرعي', _subtotal),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Expanded(child: Text('الخصم:')),
                        SizedBox(width: 120, child: TextField(
                          controller: _discountCtrl,
                          decoration: const InputDecoration(isDense: true),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          onChanged: (_) => setState(() {}),
                        )),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Expanded(child: Text('نسبة الضريبة %:')),
                        SizedBox(width: 120, child: TextField(
                          controller: _taxPercentCtrl,
                          decoration: const InputDecoration(isDense: true),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          onChanged: (_) => setState(() {}),
                        )),
                      ]),
                      if (_tax > 0) _totalRow('قيمة الضريبة', _tax),
                      const Divider(),
                      _totalRow('الإجمالي', _total, bold: true),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Expanded(child: Text('المدفوع الآن:')),
                        SizedBox(width: 120, child: TextField(
                          controller: _paidCtrl,
                          decoration: const InputDecoration(isDense: true),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          onChanged: (_) => setState(() {}),
                        )),
                      ]),
                      if (_paid > 0) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Account>(
                          value: _selectedCashAccount,
                          decoration: InputDecoration(labelText: _isSale || widget.type == 'مرتجع شراء' ? 'استلام في حساب *' : 'الدفع من حساب *'),
                          items: _cashAccounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _selectedCashAccount = v),
                          isExpanded: true,
                        ),
                      ],
                      _totalRow('المتبقي', _remaining, color: _remaining > 0.01 ? AppTheme.error : AppTheme.success),
                    ]),
                  )),
                  const SizedBox(height: 12),
                  TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 2),
                  const SizedBox(height: 80),
                ]),
              ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(formatAmount(value), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? (bold ? AppTheme.primary : null))),
    ]),
  );

  Widget _buildItemRow(int index, _InvoiceItemRow item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            Expanded(child: DropdownButtonFormField<Product>(
              value: item.product,
              decoration: const InputDecoration(labelText: 'المنتج', isDense: true),
              items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() {
                item.product = v;
                if (v != null) {
                  item.priceCtrl.text = (_isSale || widget.type == 'مرتجع بيع' ? v.salePrice : v.purchasePrice).toStringAsFixed(0);
                }
              }),
              isExpanded: true,
            )),
            const SizedBox(width: 6),
            if (_items.length > 1)
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20), onPressed: () => setState(() => _items.removeAt(index))),
          ]),
          if (item.product != null && (_isSale) && item.qty > item.product!.quantity)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('⚠ الكمية المتاحة: ${item.product!.quantity} ${item.product!.unit} فقط',
                  style: const TextStyle(fontSize: 11, color: AppTheme.error)),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(
              controller: item.qtyCtrl,
              decoration: const InputDecoration(labelText: 'الكمية', isDense: true),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(
              controller: item.priceCtrl,
              decoration: const InputDecoration(labelText: 'السعر', isDense: true),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 10),
            Expanded(child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text(formatAmount(item.total, symbol: ''), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final validItems = _items.where((i) => i.product != null && i.qty > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف بنداً واحداً على الأقل'), backgroundColor: AppTheme.error));
      return;
    }
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isPurchase ? 'اختر المورد' : 'اختر العميل'), backgroundColor: AppTheme.error));
      return;
    }
    if (_paid > 0 && _selectedCashAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر حساب الاستلام/الدفع'), backgroundColor: AppTheme.error));
      return;
    }
    if (_isSale) {
      for (var i in validItems) {
        if (i.qty > i.product!.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية المطلوبة من "${i.product!.name}" أكبر من المتاح (${i.product!.quantity})'), backgroundColor: AppTheme.error));
          return;
        }
      }
    }
    setState(() => _saving = true);
    try {
      final invoice = Invoice(
        invoiceNumber: '',
        date: _date,
        type: widget.type,
        accountId: _selectedAccount!.id,
        cashAccountId: _paid > 0 ? _selectedCashAccount!.id : null,
        warehouseId: _selectedWarehouse?.id,
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        paid: _paid,
        remaining: _remaining,
        currencyCode: _baseCurrencyCode,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        items: validItems.map((i) => InvoiceItem(
          productId: i.product!.id!,
          productName: i.product!.name,
          quantity: i.qty,
          unitPrice: i.price,
          total: i.total,
          unit: i.product!.unit,
        )).toList(),
      );
      await _db.insertInvoice(invoice);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }
}

class _InvoiceItemRow {
  Product? product;
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController(text: '0');
  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get price => double.tryParse(priceCtrl.text) ?? 0;
  double get total => qty * price;
}
