import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _db = DatabaseHelper.instance;
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _db.getProducts(search: _search.text.trim().isEmpty ? null : _search.text.trim());
    final warehouses = await _db.getWarehouses();
    if (mounted) setState(() { _products = products; _warehouses = warehouses; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = _products.where((p) => p.isLowStock).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المنتجات والمخزون'),
          actions: [
            if (lowStock > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text('$lowStock منخفض', style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: AppTheme.warning,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showProductDialog(),
          icon: const Icon(Icons.add),
          label: const Text('منتج جديد'),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الكود...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _load(); })
                    : null,
              ),
              onChanged: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const EmptyState(message: 'لا توجد منتجات', icon: Icons.inventory_2)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _products.length,
                        itemBuilder: (_, i) {
                          final p = _products[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: p.isLowStock
                                    ? AppTheme.warning.withAlpha(26)
                                    : AppTheme.success.withAlpha(26),
                                child: Icon(Icons.inventory_2,
                                    color: p.isLowStock ? AppTheme.warning : AppTheme.success),
                              ),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${p.code ?? ''} ${p.warehouseName != null ? '• ${p.warehouseName}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('${p.quantity.toStringAsFixed(p.quantity == p.quantity.truncate() ? 0 : 2)} ${p.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: p.isLowStock ? AppTheme.warning : AppTheme.primary,
                                    )),
                                Text(formatAmount(p.salePrice), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ]),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Column(children: [
                                    Row(children: [
                                      _infoChip('سعر البيع', formatAmount(p.salePrice)),
                                      const SizedBox(width: 8),
                                      _infoChip('التكلفة المرجحة', formatAmount(p.averageCost)),
                                      const SizedBox(width: 8),
                                      _infoChip('الحد الأدنى', '${p.minQuantity} ${p.unit}'),
                                    ]),
                                    const SizedBox(height: 10),
                                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.move_to_inbox, size: 16),
                                        label: const Text('حركة مخزن', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _showMovementDialog(p),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.history, size: 16),
                                        label: const Text('السجل', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _showMovementHistory(p),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _showProductDialog(product: p),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete, size: 16, color: AppTheme.error),
                                        label: const Text('حذف', style: TextStyle(fontSize: 12, color: AppTheme.error)),
                                        onPressed: () => _confirmDelete(p),
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

  Widget _infoChip(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ]),
    ),
  );

  void _showProductDialog({Product? product}) async {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final codeCtrl = TextEditingController(text: product?.code ?? '');
    final catCtrl = TextEditingController(text: product?.category ?? '');
    final unitCtrl = TextEditingController(text: product?.unit ?? 'قطعة');
    final buyCtrl = TextEditingController(text: product?.purchasePrice.toStringAsFixed(0) ?? '0');
    final sellCtrl = TextEditingController(text: product?.salePrice.toStringAsFixed(0) ?? '0');
    final initialQtyCtrl = TextEditingController(text: '0');
    final minCtrl = TextEditingController(text: product?.minQuantity.toStringAsFixed(0) ?? '0');
    final notesCtrl = TextEditingController(text: product?.notes ?? '');
    int? selectedWarehouse = product?.warehouseId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEdit ? 'تعديل المنتج' : 'منتج جديد'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج *')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'الكود'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'الوحدة'))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'الفئة')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: buyCtrl, decoration: const InputDecoration(labelText: 'سعر الشراء المرجعي'),
                        keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: sellCtrl, decoration: const InputDecoration(labelText: 'سعر البيع'),
                        keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
                  ]),
                  const SizedBox(height: 10),
                  if (isEdit)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('الكمية الحالية: ${product.quantity} ${product.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('التكلفة المرجحة: ${formatAmount(product.averageCost)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text('لتغيير الكمية استخدم زر "حركة مخزن" — لا يمكن تعديلها هنا مباشرة حفاظاً على دقة السجل.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ]),
                    )
                  else
                    TextField(controller: initialQtyCtrl, decoration: const InputDecoration(labelText: 'الكمية الافتتاحية'),
                        keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
                  const SizedBox(height: 10),
                  TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'الحد الأدنى (تنبيه نقص)'),
                      keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    value: selectedWarehouse,
                    decoration: const InputDecoration(labelText: 'المخزن'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('بدون مخزن')),
                      ..._warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
                    ],
                    onChanged: (v) => setS(() => selectedWarehouse = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 2),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    final p = Product(
                      id: product?.id,
                      name: nameCtrl.text.trim(),
                      code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                      category: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                      unit: unitCtrl.text.trim().isEmpty ? 'قطعة' : unitCtrl.text.trim(),
                      purchasePrice: double.tryParse(buyCtrl.text) ?? 0,
                      salePrice: double.tryParse(sellCtrl.text) ?? 0,
                      quantity: isEdit ? product.quantity : (double.tryParse(initialQtyCtrl.text) ?? 0),
                      minQuantity: double.tryParse(minCtrl.text) ?? 0,
                      warehouseId: selectedWarehouse,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    if (isEdit) { await _db.updateProduct(p); } else { await _db.insertProduct(p); }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
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

  void _showMovementDialog(Product p) async {
    MovementType selectedType = MovementType.incoming;
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isAdjustment = selectedType == MovementType.adjustment;
          final qtyLabel = isAdjustment ? 'الكمية الفعلية بعد الجرد *' : 'الكمية *';
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('حركة مخزن: ${p.name}'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: AppTheme.primary.withAlpha(13), borderRadius: BorderRadius.circular(8)),
                    child: Text('الكمية الحالية: ${p.quantity} ${p.unit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  DropdownButtonFormField<MovementType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'نوع الحركة'),
                    items: MovementType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.nameAr))).toList(),
                    onChanged: (v) { if (v != null) setS(() => selectedType = v); },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: qtyCtrl, decoration: InputDecoration(labelText: qtyLabel),
                      keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
                  const SizedBox(height: 12),
                  if (selectedType == MovementType.incoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: TextEditingController(text: p.purchasePrice.toStringAsFixed(0)),
                        decoration: const InputDecoration(labelText: 'تكلفة الوحدة الواردة'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        onChanged: (v) => p.purchasePrice = double.tryParse(v) ?? p.purchasePrice,
                      ),
                    ),
                  TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'السبب / الملاحظة'), maxLines: 2),
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
                  if (selectedType == MovementType.damage || selectedType == MovementType.loss)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppTheme.error.withAlpha(13), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.error.withAlpha(51))),
                        child: Row(children: [
                          const Icon(Icons.warning, color: AppTheme.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('سيتم إنقاص ${selectedType.nameAr} من المخزون بالتكلفة المرجحة الحالية، وتسجيلها في السجل بشكل دائم', style: const TextStyle(fontSize: 12, color: AppTheme.error))),
                        ]),
                      ),
                    ),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    final qty = double.tryParse(qtyCtrl.text) ?? 0;
                    if (qty < 0 || (qty == 0 && !isAdjustment)) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('أدخل كمية صحيحة'), backgroundColor: AppTheme.error));
                      return;
                    }
                    try {
                      await _db.addWarehouseMovement(WarehouseMovement(
                        productId: p.id!,
                        warehouseId: p.warehouseId,
                        movementType: selectedType,
                        quantity: qty,
                        unitPrice: p.purchasePrice,
                        date: date,
                        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                      ));
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
          );
        },
      ),
    );
  }

  void _showMovementHistory(Product p) async {
    var movements = await _db.getWarehouseMovements(productId: p.id);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('سجل: ${p.name}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: movements.isEmpty
                  ? const Center(child: Text('لا توجد حركات'))
                  : ListView.builder(
                      itemCount: movements.length,
                      itemBuilder: (_, i) {
                        final m = movements[i];
                        final isIn = m.movementType == MovementType.incoming;
                        final isNeg = m.movementType == MovementType.outgoing || m.movementType == MovementType.damage || m.movementType == MovementType.loss;
                        return ListTile(
                          dense: true,
                          leading: Icon(isIn ? Icons.add_circle : Icons.remove_circle,
                              color: isNeg ? AppTheme.error : AppTheme.success, size: 20),
                          title: Text('${m.movementType.nameAr}: ${m.quantity} ${p.unit} @ ${formatAmount(m.unitPrice, symbol: '')}', style: const TextStyle(fontSize: 13)),
                          subtitle: Text('${formatDate(m.date)}${m.reason != null ? ' • ${m.reason}' : ''}${m.reference != null ? ' • ${m.reference}' : ''}', style: const TextStyle(fontSize: 11)),
                          trailing: m.invoiceId != null
                              ? Tooltip(message: 'من فاتورة، لا يمكن حذفها هنا', child: Icon(Icons.lock_outline, size: 18, color: Colors.grey[400]))
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (c2) => Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: AlertDialog(
                                          title: const Text('حذف الحركة'),
                                          content: const Text('سيُعاد حساب رصيد المنتج بعد الحذف. هل تريد المتابعة؟'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('إلغاء')),
                                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                                                onPressed: () => Navigator.pop(c2, true), child: const Text('حذف')),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await _db.deleteWarehouseMovement(m.id!);
                                      final refreshed = await _db.getWarehouseMovements(productId: p.id);
                                      setS(() => movements = refreshed);
                                      _load();
                                    } catch (e) {
                                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                                    }
                                  },
                                ),
                        );
                      },
                    ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Product p) async {
    try {
      final canDelete = await _db.canDeleteProduct(p.id!);
      if (!mounted) return;
      if (!canDelete) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('لا يمكن حذف "${p.name}" لأن له مخزون. سجّل حركة تالف أو فاقد أولاً.'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
        ));
        return;
      }
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف المنتج'),
            content: Text('حذف "${p.name}"؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () async { await _db.deleteProduct(p.id!); if (ctx.mounted) Navigator.pop(ctx); _load(); },
                child: const Text('حذف'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }
}
