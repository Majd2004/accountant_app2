import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});
  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  final _db = DatabaseHelper.instance;
  List<Warehouse> _warehouses = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final warehouses = await _db.getWarehouses();
    if (mounted) setState(() { _warehouses = warehouses; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المخازن')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showDialog(),
          icon: const Icon(Icons.add),
          label: const Text('مخزن جديد'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _warehouses.isEmpty
                ? const EmptyState(message: 'لا توجد مخازن', icon: Icons.warehouse)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _warehouses.length,
                    itemBuilder: (_, i) {
                      final w = _warehouses[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF3E5AB),
                            child: Icon(Icons.warehouse, color: Color(0xFF4E342E)),
                          ),
                          title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: w.location != null && w.location!.isNotEmpty ? Text(w.location!) : null,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showDialog(warehouse: w)),
                            IconButton(icon: const Icon(Icons.delete, size: 20, color: AppTheme.error), onPressed: () => _confirmDelete(w)),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  void _showDialog({Warehouse? warehouse}) {
    final nameCtrl = TextEditingController(text: warehouse?.name ?? '');
    final locationCtrl = TextEditingController(text: warehouse?.location ?? '');
    final notesCtrl = TextEditingController(text: warehouse?.notes ?? '');
    final isEdit = warehouse != null;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isEdit ? 'تعديل المخزن' : 'مخزن جديد'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المخزن *')),
            const SizedBox(height: 10),
            TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'الموقع')),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 2),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  final w = Warehouse(id: warehouse?.id, name: nameCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
                  if (isEdit) { await _db.updateWarehouse(w); } else { await _db.insertWarehouse(w); }
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
    );
  }

  void _confirmDelete(Warehouse w) async {
    final canDelete = await _db.canDeleteWarehouse(w.id!);
    if (!mounted) return;
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('لا يمكن حذف "${w.name}" لأنه يحتوي على بضاعة'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المخزن'),
          content: Text('حذف "${w.name}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async { await _db.deleteWarehouse(w.id!); if (ctx.mounted) Navigator.pop(ctx); _load(); },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}
