import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = DatabaseHelper.instance;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  Future<void> _search(String query) async {
    if (query.trim().length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    final results = await _db.globalSearch(query.trim());
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'account': return Icons.account_circle;
      case 'journal': return Icons.edit_document;
      case 'product': return Icons.inventory_2;
      default: return Icons.search;
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'account': return 'حساب';
      case 'journal': return 'قيد';
      case 'product': return 'منتج';
      default: return '';
    }
  }

  void _openResult(Map<String, dynamic> r) {
    final source = r['source'] as String;
    if (source == 'account') {
      Navigator.pushNamed(context, '/accounts');
    } else if (source == 'journal') {
      Navigator.pushNamed(context, '/journal');
    } else if (source == 'product') {
      Navigator.pushNamed(context, '/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث السريع')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ابحث عن حساب، قيد، منتج...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _ctrl.clear(); setState(() => _results = []); })
                    : null,
              ),
              onChanged: _search,
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.search, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(_ctrl.text.isEmpty ? 'اكتب للبحث...' : 'لا توجد نتائج',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ]))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      final source = r['source'] as String;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withAlpha(26),
                          child: Icon(_sourceIcon(source), color: AppTheme.primary, size: 20),
                        ),
                        title: Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_sourceLabel(source)),
                        trailing: const Icon(Icons.chevron_left, size: 18),
                        onTap: () => _openResult(r),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
